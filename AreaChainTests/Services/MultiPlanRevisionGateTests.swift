import Foundation
import Testing
@testable import AreaChain

/// §9.100 整改第 6～8 条：默认装配（不支持修订）与旧单项设置适配不能接收、产生或封存修订来源。
@Suite(.serialized) @MainActor struct MultiPlanRevisionGateTests {
    /// 第 6 条：合并后的计划项带 mergedOrigins 与 executionOrigin，默认装配预检直接拒绝。
    @Test func defaultAssemblyRejectsMergedItems() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        _ = try fixture.queue(value: .choice("chinese"), realBaseline: false)
        _ = try fixture.queue(value: .choice("english"), realBaseline: false)
        let revisions = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
            adapters: .init(localSettings: fixture.adapter), supportsRevisions: true)
        let items = try fixture.state().plan.items
        try revisions.acceptMerge(revisions.proposeMerge(items[0].stamp, items[1].stamp, expecting: fixture.owned().lease),
                                  expecting: fixture.owned().lease)
        let merged = try #require(fixture.state().plan.items.first)
        #expect(!merged.mergedOrigins.isEmpty && merged.executionOrigin != nil)
        let standard = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(localSettings: fixture.adapter))
        let before = try fixture.state()
        #expect(throws: CommandMultiPlanIssue.unsupported) {
            try standard.prepare(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        }
        #expect(try fixture.state() == before)
        #expect(fixture.io.writes.isEmpty)
    }

    /// 第 6 条：返回编辑的计划项带 returnedAttempts，默认装配同样拒绝，不开始新运行。
    @Test func defaultAssemblyRejectsReturnedItems() throws {
        let fixture = try FileSettingCommandFixture(fault: .temporaryWrite)
        let group = try fixture.group(prepare: false)
        let revisions = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
            adapters: .init(fileSettings: fixture.adapter), supportsRevisions: true)
        try MultiPlanRevisionSupport.start(revisions, fixture.handoff)
        let run = try #require(fixture.state().execution)
        try fixture.adapter.recoverMultiBackend(#require(run.attempt(group)), expecting: fixture.owned().lease)
        _ = try MultiPlanRevisionSupport.returnAll(revisions, fixture.handoff)
        let items = try fixture.state().plan.items
        #expect(items.contains { !$0.returnedAttempts.isEmpty } && items.allSatisfy { $0.executionOrigin != nil })
        let standard = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator, adapters: .init(fileSettings: fixture.adapter))
        #expect(throws: CommandMultiPlanIssue.unsupported) {
            try standard.prepare(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        }
        #expect(try fixture.state().execution == nil)
    }

    /// 第 7 条：supportsRevisions 为 false 时合并与返回入口全部拒绝，计划与运行不变。
    @Test func defaultAssemblyRefusesMergeAndReturn() throws {
        let settings = try LocalSettingCommandFixture()
        defer { settings.cleanup() }
        _ = try settings.queue(value: .choice("chinese"), realBaseline: false)
        _ = try settings.queue(value: .choice("english"), realBaseline: false)
        let standard = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator, adapters: .init(localSettings: settings.adapter))
        let items = try settings.state().plan.items
        let plan = try settings.state().plan
        #expect(throws: CommandMultiPlanIssue.unsupported) {
            try standard.proposeMerge(items[0].stamp, items[1].stamp, expecting: settings.owned().lease)
        }
        #expect(try settings.state().plan == plan)

        let failed = try FileSettingCommandFixture(fault: .temporaryWrite)
        let group = try failed.group(prepare: false)
        let revisions = MultiPlanCommandAdapter(coordinator: failed.handoff.coordinator,
            adapters: .init(fileSettings: failed.adapter), supportsRevisions: true)
        try MultiPlanRevisionSupport.start(revisions, failed.handoff)
        let run = try #require(failed.state().execution)
        try failed.adapter.recoverMultiBackend(#require(run.attempt(group)), expecting: failed.owned().lease)
        let fallback = MultiPlanCommandAdapter(coordinator: failed.handoff.coordinator, adapters: .init(fileSettings: failed.adapter))
        #expect(throws: CommandMultiPlanIssue.recoveryUnavailable) { try fallback.prepareReturn(expecting: failed.owned().lease) }
        let ticket = try revisions.prepareReturn(expecting: failed.owned().lease)
        #expect(throws: CommandMultiPlanIssue.unsupported) { try fallback.returnRemaining(ticket, expecting: failed.owned().lease) }
        #expect(try failed.state().execution?.stamp == run.stamp)
    }

    /// 第 8 条：旧单项设置适配只接没有执行来源的单项计划；合并出的修订项不能经它封存。
    @Test func legacySingleSettingRefusesRevisedItem() throws {
        let fixture = try LocalSettingCommandFixture()
        defer { fixture.cleanup() }
        _ = try fixture.queue(value: .choice("chinese"), realBaseline: false)
        _ = try fixture.queue(value: .choice("english"), realBaseline: false)
        let revisions = MultiPlanCommandAdapter(coordinator: fixture.handoff.coordinator,
            adapters: .init(localSettings: fixture.adapter), supportsRevisions: true)
        let items = try fixture.state().plan.items
        try revisions.acceptMerge(revisions.proposeMerge(items[0].stamp, items[1].stamp, expecting: fixture.owned().lease),
                                  expecting: fixture.owned().lease)
        #expect(try fixture.state().plan.items.count == 1)
        #expect(throws: LocalSettingCommandIssue.multipleOperations) {
            try fixture.adapter.readiness(plan: fixture.state().plan.stamp, expecting: fixture.owned().lease)
        }
        #expect(try fixture.state().execution == nil && fixture.io.writes.isEmpty)
    }

    /// 第 8 条：文件后端单项与组入口同样拒绝带执行来源的计划项。
    @Test func fileSettingRefusesRevisedItem() throws {
        let settings = try FileSettingCommandFixture()
        _ = try settings.queue("/setting/appearance/light")
        _ = try settings.queue("/setting/appearance/dark")
        let revisions = MultiPlanCommandAdapter(coordinator: settings.handoff.coordinator,
            adapters: .init(fileSettings: settings.adapter), supportsRevisions: true)
        let group = try settings.state().plan.items
        try revisions.acceptMerge(revisions.proposeMerge(group[0].stamp, group[1].stamp, expecting: settings.owned().lease),
                                  expecting: settings.owned().lease)
        #expect(try settings.state().plan.items.first?.executionOrigin != nil)
        #expect(throws: FileLocalSettingCommandIssue.unsupportedScope) {
            try settings.adapter.prepareGroup(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        }
        #expect(throws: FileLocalSettingCommandIssue.unsupportedScope) {
            try settings.adapter.groupingEvent(plan: settings.state().plan.stamp, expecting: settings.owned().lease)
        }
        #expect(try settings.state().execution == nil)
    }
}
