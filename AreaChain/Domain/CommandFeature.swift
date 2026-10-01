import Foundation

enum CommandFeature: String, CaseIterable, Sendable {
    case t1 = "T1", t2 = "T2", t3 = "T3", t4 = "T4", t5 = "T5"
    case t6 = "T6", t7 = "T7", t8 = "T8", t9 = "T9", t10 = "T10"
    case b1 = "B1", b2 = "B2", b3 = "B3"
    case j1 = "J1", j2 = "J2", j3 = "J3", g1 = "G1", g2 = "G2", a1 = "A1"
    case c1 = "C1", c2 = "C2", c3 = "C3", c4 = "C4", c5 = "C5", c6 = "C6"
    case s1 = "S1", s2 = "S2", s3 = "S3", s4 = "S4", s5 = "S5", s6 = "S6", s7 = "S7"
    case p1 = "P1", p2 = "P2", p3 = "P3", p4 = "P4"
    case d1 = "D1", d2 = "D2", d3 = "D3", d4 = "D4"
    case n1 = "N1", n2 = "N2", n3 = "N3", n4 = "N4", n5 = "N5", n6 = "N6", n7 = "N7", n8 = "N8"

    /// 对应权威设计第 8 节；原业务符号和安全差异继续在该单一来源维护。
    var source: String { "docs/unified-search-commands.md#\(rawValue)" }
}

struct CommandCoverage: Equatable, Hashable, Sendable {
    let feature: CommandFeature
    let action: String
}

/// 独立于目录项的动作清单。删除、重复绑定或拼错动作会被验证器检出。
enum CommandCoverageRequirements {
    static let actions: [CommandFeature: String] = [
        .t1: "create editTitle cancelTitle notes",
        .t2: "complete reopen cancelCompletion move reminder priority tags createTag due",
        .t3: "copyRecord copyTitle copyNotes trash",
        .t4: "create complete reopen editTitle cancelTitle tags reorder delete",
        .t5: "capture create title notes weekdays reminder priority tags enable pause reorder delete",
        .t6: "complete reopen skip inspectDate currentStreak bestStreak",
        .t7: "today tomorrow complete reopen addTags removeTags enable disable trash clearSelection",
        .t8: "todoToRoutine routineToTodo",
        .t9: "sections postponeYesterday filter clearFilter itemKind itemStatus select order",
        .t10: "capture",
        .b1: "mode previous next today selectDay dayList create move",
        .b2: "day previous next create priority complete inspect copy",
        .b3: "previous next currentMonth single multiple range shift complete inspect",
        .j1: "create body save reload discard tags classify",
        .j2: "pin unpin move tags reveal mask privateMark",
        .j3: "copyRecord copyTitle copyNotes toTodo trash",
        .g1: "create cancel rename color order search all frequent recent unused deleted",
        .g2: "merge unlinkObject unlinkGlobal trash restore delete cleanup",
        .a1: "pick paste capture preview browse trash",
        .c1: "browse search",
        .c2: "copy paste pastePlain",
        .c3: "pin unpin copyLetter delete clearUnpinned clearAll",
        .c4: "pause resume skipNext ignoreApp",
        .c5: "ignoreUniversal limit interval searchMode position clickAction plainText sound unignoreApp addPattern removePattern addType removeType",
        .c6: "open close pin unpin workspace",
        .s1: "language appearance truncation captureSource",
        .s2: "enable disable systemSettings",
        .s3: "status request test systemSettings",
        .s4: "complete snooze10 snooze60 open",
        .s5: "enable disable status retry systemSettings conflicts openLocal",
        .s6: "status",
        .s7: "record reset resetAll cancel",
        .p1: "create method tags protectExisting",
        .p2: "lock unlock enableSystem disableSystem setPassword changePassword removePassword idle tags",
        .p3: "unprotect",
        .p4: "retryImages retryKeys quitForCleanup",
        .d1: "browse restore delete empty",
        .d2: "export select validate preview apply",
        .d3: "export inspect preview restore",
        .d4: "status resetQuit",
        .n1: "dashboard today pending allItems calendar quadrant gantt diaries images clipboard tags privacy backup trash settings shortcuts tagList",
        .n2: "openWorkspace revealWorkspace closeWorkspace toggleOverlay overlayTasks overlayDiaries addRoutine manageRoutines",
        .n3: "open close selectObject selectDate selectAll clearSelection",
        .n4: "open draft pin unpin save close",
        .n5: "today pending streaks routines diaries trend heatmap activity openDay openActivity",
        .n6: "syntax page example",
        .n7: "version about discussion suggestion issue repository license",
        .n8: "quit"
    ]

    static var all: [CommandCoverage] {
        CommandFeature.allCases.flatMap { feature in
            (actions[feature] ?? "").split(separator: " ").map { CommandCoverage(feature: feature, action: String($0)) }
        }
    }
}
