import AppKit
import SwiftData
import SwiftUI
import WidgetKit

enum QuickEntryMode: String, CaseIterable {
    case task = "task"
    case diary = "diary"

    var title: String {
        switch self {
        case .task: return "⚡️ 新建待办"
        case .diary: return "📖 极速手记"
        }
    }

    var shortcutHint: String {
        switch self {
        case .task: return "⏎ 保存"
        case .diary: return "⌘⏎ 保存"
        }
    }
}

struct QuickEntryView: View {
    @State var mode: QuickEntryMode = .task
    @State private var inputText: String = ""
    @FocusState private var isFieldFocused: Bool

    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶栏模式切换与快捷键提示
            headerBar

            Divider()
                .background(DaybookPalette.border.default)

            // 输入正文区
            Group {
                if mode == .task {
                    taskInputField
                } else {
                    diaryInputField
                }
            }
            .padding(.horizontal, DaybookSpacing.page)
            .padding(.vertical, DaybookSpacing.sm)

            Divider()
                .background(DaybookPalette.border.subtle)

            // 底栏操作区
            footerBar
        }
        .background(
            RoundedRectangle(cornerRadius: DaybookRadius.card)
                .fill(DaybookPalette.fill.page)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DaybookRadius.card)
                .stroke(DaybookPalette.border.default, lineWidth: 1)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFieldFocused = true
            }
        }
    }

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: DaybookSpacing.sm) {
            HStack(spacing: DaybookSpacing.xs) {
                ForEach(QuickEntryMode.allCases, id: \.self) { item in
                    let isSelected = mode == item
                    Button {
                        mode = item
                    } label: {
                        Text(item.title)
                            .font(DaybookType.caption)
                            .padding(.horizontal, DaybookSpacing.sm)
                            .padding(.vertical, DaybookSpacing.xs)
                            .background(isSelected ? DaybookPalette.accent.fill : Color.clear)
                            .foregroundStyle(isSelected ? DaybookPalette.accent.base : DaybookPalette.text.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.small))
                    }
                    .buttonStyle(.plain) // control: mode switch
                }
            }

            Spacer()

            Text("\(mode.shortcutHint) · Esc 取消")
                .font(DaybookType.caption)
                .foregroundStyle(DaybookPalette.text.secondary)
        }
        .padding(.horizontal, DaybookSpacing.page)
        .padding(.top, DaybookSpacing.md)
        .padding(.bottom, DaybookSpacing.sm)
    }

    @ViewBuilder
    private var footerBar: some View {
        HStack {
            if mode == .task {
                let parsed = NaturalLanguageParser.parseTaskCapture(inputText)
                if parsed.hasTokens {
                    HStack(spacing: DaybookSpacing.xs) {
                        if let time = parsed.timeLabel {
                            Text("⏰ \(time)")
                                .font(DaybookType.badge)
                                .padding(.horizontal, DaybookSpacing.xs)
                                .padding(.vertical, DaybookSpacing.xxs)
                                .background(DaybookPalette.fill.subtle)
                                .foregroundStyle(DaybookPalette.accent.base)
                                .clipShape(Capsule()) // token-exempt: capsule badge
                        }
                        if parsed.isImportant || parsed.isUrgent {
                            Text(parsed.isImportant && parsed.isUrgent ? "🔴 重要且紧急" : (parsed.isImportant ? "🔵 重要" : "🟡 紧急"))
                                .font(DaybookType.badge)
                                .padding(.horizontal, DaybookSpacing.xs)
                                .padding(.vertical, DaybookSpacing.xxs)
                                .background(DaybookPalette.fill.subtle)
                                .foregroundStyle(DaybookPalette.text.primary)
                                .clipShape(Capsule()) // token-exempt: capsule badge
                        }
                        if let tag = parsed.tagName {
                            Text("#\(tag)")
                                .font(DaybookType.badge)
                                .foregroundStyle(DaybookPalette.text.secondary)
                        }
                    }
                } else {
                    Text("支持自然语言：如「明天15:00 开会 #工作 !重要」")
                        .font(DaybookType.badge)
                        .foregroundStyle(DaybookPalette.text.secondary)
                }
            } else {
                Text("\(inputText.count) 字 · 随想灵感即刻存入今日手记")
                    .font(DaybookType.badge)
                    .foregroundStyle(DaybookPalette.text.secondary)
            }

            Spacer()

            Button("取消") {
                onDismiss()
            }
            .font(DaybookType.caption)
            .buttonStyle(.plain) // control: dismiss action
            .foregroundStyle(DaybookPalette.text.secondary)

            Button {
                commitEntry()
            } label: {
                Text("保存")
                    .font(DaybookType.caption)
                    .padding(.horizontal, DaybookSpacing.md)
                    .padding(.vertical, DaybookSpacing.xs)
                    .background(canSubmit ? DaybookPalette.accent.base : DaybookPalette.fill.subtle)
                    .foregroundStyle(canSubmit ? DaybookPalette.text.onAccent : DaybookPalette.text.disabled)
                    .clipShape(RoundedRectangle(cornerRadius: DaybookRadius.xs))
            }
            .buttonStyle(.plain) // control: commit action
            .disabled(!canSubmit)
        }
        .padding(.horizontal, DaybookSpacing.page)
        .padding(.vertical, DaybookSpacing.sm)
    }

    @ViewBuilder
    private var taskInputField: some View {
        TextField("输入待办标题...", text: $inputText)
            .textFieldStyle(.plain)
            .font(DaybookType.bodyLarge)
            .foregroundStyle(DaybookPalette.text.primary)
            .focused($isFieldFocused)
            .onSubmit {
                commitEntry()
            }
            .frame(height: 32) // token-exempt: input line height
    }

    @ViewBuilder
    private var diaryInputField: some View {
        TextEditor(text: $inputText)
            .font(DaybookType.body)
            .foregroundStyle(DaybookPalette.text.primary)
            .scrollContentBackground(.hidden)
            .focused($isFieldFocused)
            .frame(height: 90) // token-exempt: diary editor minimum height
            .overlay(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("写下此刻的灵感、反思或随笔...")
                        .font(DaybookType.body)
                        .foregroundStyle(DaybookPalette.text.tertiary)
                        .padding(.top, DaybookSpacing.xs)
                        .padding(.leading, DaybookSpacing.xs)
                        .allowsHitTesting(false)
                }
            }
            .onExitCommand {
                onDismiss()
            }
    }

    private func commitEntry() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let context = Persistence.session.container.mainContext
        let todayKey = DayKey.today()

        if mode == .task {
            let parsed = NaturalLanguageParser.parseTaskCapture(trimmed)
            _ = ModelChanges.perform(in: context) {
                let todo = TodoItem(
                    title: parsed.cleanTitle.isEmpty ? trimmed : parsed.cleanTitle,
                    isDone: false,
                    dayKey: todayKey,
                    remindMinutes: parsed.remindMinutes,
                    isImportant: parsed.isImportant,
                    isUrgent: parsed.isUrgent,
                    notes: parsed.notes,
                    dueMinutes: parsed.remindMinutes
                )
                context.insert(todo)
            }
        } else {
            _ = ModelChanges.perform(in: context) {
                let diary = DiaryEntry(
                    text: trimmed,
                    dayKey: todayKey,
                    createdAt: Date()
                )
                context.insert(diary)
            }
        }

        // 立即通知 WidgetKit 刷新桌面全部小组件
        WidgetCenter.shared.reloadAllTimelines()

        inputText = ""
        onDismiss()
    }
}
