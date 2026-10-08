import SwiftUI

/// 新增和标题修改共用效果展示，只消费已经形成的标签计划，不解析输入或改变顺序。
struct UnifiedSearchTaskTagSummary: View {
    let associations: [CommandTaskTagAssociation]
    @Environment(\.locale) private var locale

    var body: some View {
        Text(verbatim: L10n.format("unified.composition.tagSummary", locale: locale,
            associations.filter { $0.effect == .createAndAssociate }.count,
            associations.filter { $0.effect == .restoreAndAssociate }.count,
            associations.filter { $0.effect == .associateLive }.count))
            .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }
}

struct UnifiedSearchTaskTagEffects: View {
    let associations: [CommandTaskTagAssociation]
    @Environment(\.locale) private var locale
    private typealias Copy = UnifiedSearchTaskCompositionCopy

    var body: some View {
        ForEach(Array(associations.enumerated()), id: \.offset) { index, tag in
            Text(verbatim: "\(index + 1). " + Copy.name(tag.target) + " · " + L10n.format(Copy.effect(tag.effect), locale: locale)
                + " · " + tag.origins.map { L10n.format($0 == .titleSyntax
                    ? "unified.composition.syntax" : "unified.composition.explicit", locale: locale) }.joined(separator: " + "))
                .font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// 只呈现实际调用与已知处理结果；请求返回不等于授权、送达或同步成功。
struct UnifiedSearchTaskExternalFeedback: View {
    let authorizationCall: String
    let authorizationResult: String
    let notificationRequested: Bool?
    let calendarRequested: Bool?
    let unit: CommandExecutionUnit
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DaybookSpacing.xs) {
            Text("unified.composition.fake")
            Text(verbatim: L10n.format("unified.composition.authorization", locale: locale,
                L10n.format("unified.composition.call." + authorizationCall, locale: locale),
                L10n.format("unified.composition.authorization." + authorizationResult, locale: locale)))
            Text(verbatim: external("notification", requested: notificationRequested, result: unit.effects[.notification]))
            Text(verbatim: external("calendar", requested: calendarRequested, result: unit.effects[.calendar]))
        }.font(DaybookType.caption).fixedSize(horizontal: false, vertical: true)
    }

    private func external(_ name: String, requested: Bool?, result: CommandExternalResult?) -> String {
        let request = requested == true ? "returned" : requested == false ? "notCalled" : "unknown"
        let key = result == .succeeded ? "succeeded" : result == .failed ? "failed" : "unknown"
        return L10n.format("unified.composition." + name, locale: locale,
            L10n.format("unified.composition.call." + request, locale: locale),
            L10n.format("unified.composition.external." + key, locale: locale))
    }
}
