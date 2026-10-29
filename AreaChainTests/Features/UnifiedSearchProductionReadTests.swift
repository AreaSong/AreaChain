import Foundation
import SwiftData
import Testing
@testable import AreaChain

/// 正式版读取接线。同一份装配、内存容器、私有事件中心；不开窗口。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchProductionReadTests {
    static func query(_ text: String) -> ContentQuerySession {
        let page = QuerySessionFixture.page(.today(.init()), host: UnifiedSearchProductionAssembly.workspaceHost)
        return ContentQueryReducer.reduce(.init(page: page), .setInput(text)).state
    }

    @Test func routeFollowsQueryScope() {
        #expect(ContentQueryProductionReads.route(Self.query("/clipboard Alpha")) == .clipboard)
        #expect(ContentQueryProductionReads.route(Self.query("/trash needle")) == .trash)
        #expect(ContentQueryProductionReads.route(Self.query("needle #工作")) == .content)
        #expect(ContentQueryProductionReads.route(Self.query("")) == .content)
    }

    static func type(_ controller: UnifiedSearchController, _ text: String) -> UnifiedSearchBuffer? {
        controller.edit(.init(source: controller.buffer, text: text, selection: NSRange(location: text.utf16.count, length: 0)))
    }

    static func published(_ controller: UnifiedSearchController, after previous: UUID? = nil,
                          timeout: Int = 300) async throws -> ContentQueryReadPublication {
        for _ in 0..<timeout {
            if let page = try? controller.session.presentation(), page.pagination.snapshot.version != previous { return page }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw ContentQueryReadSessionError.noPresentation
    }

    @Test func newInputCancelsOlderQueryAndReadIsScheduledOffTheKeystroke() async throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let todo = try fixture.insert(TodoItem(title: "needle 合成任务", dayKey: UnifiedSearchProductionFixture.today))
        try fixture.insert(TodoItem(title: "nee 另一条", dayKey: UnifiedSearchProductionFixture.today))
        fixture.saves = 0
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = assembly.workspace!
        var publications = 0
        let token = controller.session.displayUpdates.observe { if $0 == .published { publications += 1 } }
        defer { controller.session.displayUpdates.remove(token) }
        #expect(Self.type(controller, "nee") != nil)
        // 按键处理同步返回，读取在合并等待之后才在主线程执行：此刻还没有任何发布。
        #expect(publications == 0 && (try? controller.session.presentation()) == nil)
        #expect(Self.type(controller, "needle") != nil)
        let page = try await Self.published(controller)
        try await Task.sleep(for: .milliseconds(300))
        // 旧查询被新输入取消，只发布最后一次；结果属于新查询。
        #expect(publications == 1)
        #expect(page.pagination.snapshot.visible.contains(.init(type: .todo, id: todo.id)))
        #expect(try fixture.context.fetch(FetchDescriptor<TodoItem>()).count == 2)
        #expect(fixture.saves == 0 && fixture.probe.total == 0)
    }

    @Test func privacyLockClearsResultsAndPreview() async throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        try fixture.insert(TodoItem(title: "needle 合成任务", dayKey: UnifiedSearchProductionFixture.today))
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = assembly.workspace!
        _ = Self.type(controller, "needle")
        _ = try await Self.published(controller)
        // 正式版保险箱在 default 中心发锁定事件；这里在装配的私有中心发同名事件、同一保险箱对象。
        fixture.center.post(name: .privacyWillLock, object: fixture.vault)
        for _ in 0..<100 where controller.messageKey != "unified.results.invalidated" {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(controller.messageKey == "unified.results.invalidated")
        #expect(controller.buffer.text.isEmpty)
        #expect((try? controller.session.presentation()) == nil)
        #expect(!controller.session.hasRetainedPresentation)
    }

    /// 与 ContentQueryBodyReadTests／ImageContentQueryPrivacyTests 的旧格式隐私用例同一组手记，
    /// 改走正式版唯一装配点；结果、摘要、预览与图片关联里都不能出现这些手记的正文或附件文件名。
    @Test func legacySensitiveDiariesStayHiddenThroughProductionAssembly() async throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let day = UnifiedSearchProductionFixture.today
        let privateTag = try fixture.insert(TagItem(name: "private-category", sortOrder: 0, isPrivateDiary: true))
        let passwordTag = try fixture.insert(TagItem(name: "password", sortOrder: 1))
        let secret = "M6R_SECRET_BODY"
        let hidden = [
            DiaryEntry(text: "needle \(secret) #password", dayKey: day),
            DiaryEntry(text: "needle \(secret)", dayKey: day, tagIDs: privateTag.id.uuidString),
            DiaryEntry(text: "needle \(secret) #private-category", dayKey: day),
            DiaryEntry(text: "needle \(secret)", dayKey: day, tagIDs: passwordTag.id.uuidString),
            DiaryEntry(text: "needle \(secret)", dayKey: day, tagIDs: UUID().uuidString),
            DiaryEntry(text: "needle \(secret)", dayKey: day, tagIDs: "broken-tag-id"),
            DiaryEntry(text: "needle \(secret)", dayKey: day),
        ]
        hidden[6].isPrivate = true
        let visible = DiaryEntry(text: "needle M6R_PUBLIC_BODY", dayKey: day)
        for entry in hidden + [visible] {
            fixture.context.insert(entry)
            fixture.context.insert(AttachmentItem(ownerKind: AttachmentOwner.diary.rawValue, ownerID: entry.id,
                filename: entry.id == visible.id ? "m6r-public.png" : "M6R_HIDDEN.png"))
        }
        try fixture.context.save()
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = assembly.workspace!
        _ = Self.type(controller, "needle")
        let content = try await Self.published(controller)
        let hiddenIDs = Set(hidden.map(\.id))
        // 普通手记确实走了正文读取（能命中），保护／旧格式手记一条都不作为结果出现。
        #expect(content.pagination.snapshot.visible.contains { $0.type == .diary && $0.id == visible.id })
        #expect(!content.pagination.snapshot.visible.contains { $0.type == .diary && hiddenIDs.contains($0.id) })
        let strings = TrashQueryFixture.strings(content)
        #expect(!strings.contains { $0.contains(secret) } && !strings.contains { $0.contains("M6R_HIDDEN") })
        _ = Self.type(controller, "/images")
        let images = try await Self.published(controller, after: content.pagination.snapshot.version)
        let response = try SearchReadFixture.images(images)
        #expect(response.matches.map(\.owner.id) == [visible.id])
        for entry in hidden {
            #expect(response.associations[.init(kind: .diary, id: entry.id)]?.presence == .protected)
        }
        #expect(!TrashQueryFixture.strings(images).contains { $0.contains("M6R_HIDDEN") || $0.contains(secret) })
    }

    @Test func modelChangeInvalidatesShownResults() async throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        try fixture.insert(TodoItem(title: "needle 合成任务", dayKey: UnifiedSearchProductionFixture.today))
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = assembly.workspace!
        _ = Self.type(controller, "needle")
        let first = try await Self.published(controller)
        fixture.center.post(name: .boardDidChange, object: nil)
        for _ in 0..<100 where (try? controller.session.presentation()) != nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect((try? controller.session.presentation())?.pagination.snapshot.version != first.pagination.snapshot.version)
    }
}

/// 性能探针：合成大库，测“输入到首批结果可见”（含 120ms 合并等待）。只在 AREACHAIN_M6_PERF=1 时运行，数字写到标准输出。
@Suite(.serialized, .tags(.backgroundWindow)) @MainActor struct UnifiedSearchProductionPerformanceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["AREACHAIN_M6_PERF"] == "1"))
    func inputToFirstResultsOnSyntheticLibrary() async throws {
        let fixture = try UnifiedSearchProductionFixture()
        defer { fixture.cleanup() }
        let clock = ContinuousClock()
        let env = ProcessInfo.processInfo.environment
        func size(_ key: String, _ fallback: Int) -> Int { env["AREACHAIN_M6_PERF_" + key].flatMap(Int.init) ?? fallback }
        let (todos, routines, days, diaries) = (size("TODOS", 2000), size("ROUTINES", 200), size("DAYS", 365), size("DIARIES", 500))
        let seeding = clock.measure {
            for index in 0..<todos {
                fixture.context.insert(TodoItem(title: "合成待办 \(index) " + (index % 7 == 0 ? "会议" : "整理"),
                                                dayKey: UnifiedSearchProductionFixture.today))
            }
            for index in 0..<routines {
                let routine = DailyRoutine(title: "合成习惯 \(index)", sortOrder: index, createdDayKey: "2025-10-01")
                fixture.context.insert(routine)
                for day in 0..<days {
                    fixture.context.insert(RoutineCheck(dayKey: DayKey.shifted("2025-10-23", by: day),
                                                        isDone: day % 3 == 0, routine: routine))
                }
            }
            for index in 0..<diaries {
                fixture.context.insert(DiaryEntry(text: "合成手记 \(index) 会议纪要", dayKey: UnifiedSearchProductionFixture.today))
            }
        }
        try fixture.context.save()
        let assembly = try fixture.assembly()
        defer { assembly.discard() }
        let controller = assembly.workspace!
        var samples: [(String, Duration, Int)] = []
        for (label, text) in [("cold", "会议"), ("hot", "整理"), ("hot-repeat", "会议")] {
            let previous = try? controller.session.presentation().pagination.snapshot.version
            let start = clock.now
            _ = UnifiedSearchProductionReadTests.type(controller, text)
            let page = try await UnifiedSearchProductionReadTests.published(controller, after: previous, timeout: 6000)
            samples.append((label, clock.now - start, page.pagination.snapshot.visible.count))
        }
        let info = ProcessInfo.processInfo
        print("M6-PERF todos=\(todos) routines=\(routines)x\(days) diaries=\(diaries) seed=\(seeding) os=\(info.operatingSystemVersionString) cpus=\(info.activeProcessorCount)"
              + " memory=\(info.physicalMemory / 1_048_576)MB settle=120ms")
        for (label, duration, visible) in samples { print("M6-PERF \(label) inputToFirstResults=\(duration) visible=\(visible)") }
        #expect(samples.count == 3)
    }
}
