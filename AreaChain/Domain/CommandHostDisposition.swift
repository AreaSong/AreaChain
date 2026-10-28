import Foundation

/// 修复批 M-7G：一条指令在当前宿主里怎么处理。只是判断结果的值，判断本身唯一在
/// `UnifiedSearchController.disposition(for:)`（沿与 Return 相同的真实路由）；候选标签、状态行与目录级用例都读这一个结果。
enum CommandHostDisposition: Equatable, Sendable {
    /// Return 开始草稿，预览后确认（已装配适配器）。
    case executable
    /// Return 直接前往或执行（导航、系统动作，不建草稿）。
    case navigates
    /// 在原页面完成：只导航，由原页面操作（CommandOriginalPage 有对照）；pageKey 是目的地名称的文案键。
    case originalPage(pageKey: String, finishesOnPage: Bool)
    /// 目录声明不可用或未定（CommandAvailability），reasonKey 是原因文案键。
    case catalogUnavailable(reasonKey: String)
    /// 以上都不是：能填写参数，但当前宿主没有接上执行。
    case unwired

    enum Kind: String, CaseIterable, Sendable { case executable, originalPage, catalogUnavailable, unwired }

    var kind: Kind {
        switch self {
        case .executable, .navigates: .executable
        case .originalPage: .originalPage
        case .catalogUnavailable: .catalogUnavailable
        case .unwired: .unwired
        }
    }

    /// 候选行与状态行共用的单行说明。
    func label(locale: Locale) -> String {
        switch self {
        case .executable: return L10n.format("unified.candidate.executable", locale: locale)
        case .navigates: return L10n.format("unified.candidate.navigates", locale: locale)
        case .originalPage(let page, let finishes):
            return L10n.format(finishes ? "unified.candidate.originalPage" : "unified.candidate.opens", locale: locale,
                               L10n.format(page, locale: locale))
        case .catalogUnavailable(let reason):
            return L10n.format("unified.candidate.catalogUnavailable", locale: locale, L10n.format(reason, locale: locale))
        case .unwired: return L10n.format("unified.input.unavailable", locale: locale)
        }
    }
}
