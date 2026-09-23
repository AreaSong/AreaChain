# 任务：AreaChain 设计系统收敛 · 阶段 P3b（Diary / Workspace / Theme / Quadrant 按钮）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 严格按步骤顺序执行；每个"检查点"必须跑通再进下一步；修不好就停下来问我。
2. 代码块**原样粘贴**；替换用精确字符串定位，行号只是提示。
3. 只改本文列出的文件。
4. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
5. 先读 `AGENTS.md`，再读 `.cursor/plans/design-system.md` 第 0、1、2、5 节和「P3b」段，再读本文。不读其他文档，不全仓库扫描。
6. 没写清楚的取舍 → 用提问工具问我，复述我的回答，我说"对"才继续。
7. 做完不宣布"通过"，只按"汇报格式"交证据；验收由另一个对话按 `design-system-P3b-verify.md` 做。
8. **不要新增** `DaybookButtonVariant` 或 `DaybookButtonSize`。基座在 `AreaChain/Theme/DaybookButtonStyle.swift`，P3a 已完成。
9. MenuBar / Tasks / Board / Search 里已有的 `// control:` **一个字都不要改**。

## 背景

P3a 已把菜单栏、任务、看板、搜索的按钮迁到 `DaybookButtonStyle` / `DaybookIconButton` / `daybookMenuLabel`。还剩日记 21 处、工作台 24 处、主题 13 处、象限 1 处 `.buttonStyle(.plain)`。

**视觉基准不变**：悬停淡灰圆角底，没有蓝环。点击区 regular 28 / compact 22 / inline 18。

两类处理：

- **A. 按钮语义** → `DaybookButtonStyle` 或 `DaybookIconButton` 或 `daybookMenuLabel`。删掉 label 里自己画的 `.frame(width:height:)`、`.background`、`.overlay`、`.foregroundStyle`、`.contentShape`、`.onHover`（样式自己做悬停）。
- **B. 非按钮控件**（胶囊芯片、复选框、整行点击、固定几何的属性按钮、悬停会替换正文的语法行）→ 保留 `.plain`，同一行末尾加本文给出的 `// control:` 注释，注释原文不许改。

**已复制状态不再用绿色。** 复制成功用 `.iconActive` 或 `.active`（强调色）。`Color.green` 留给 P6。

**不要改** `.buttonStyle(.bordered)` 和 `.buttonStyle(.borderedProminent)`。`DiaryWindowView` 有 3 处（置顶、显示、保存），`DiaryCardComponents` 有 1 处（保存）。`PrivacyUnlockPresenter.swift` 不在本阶段文件列表里，不要打开。

## 开始前必读

1. `AreaChain/Theme/DaybookButtonStyle.swift` 全文（看 `DaybookIconButton` 的参数：`systemName`、`label`、`size`、`role`、`isActive`、`enabled`、`action`）。
2. `AreaChain/Features/Tasks/TaskRow+Menus.swift` 里现有的 `copyButton` 与 `moreMenu`（P3a 已改好，日记行要照这个形状写）。
3. `AreaChain/Theme/CommandReturnButton.swift` 全文。
4. `AreaChain/Theme/CaptureAttributesView.swift` 第 29–104 行。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DaybookButtonStyleTests --only-testing AreaChainTests/DiarySummaryRowTests --only-testing AreaChainTests/DiaryComposerInteractionTests
```

---

## 步骤 1：Diary

### 1.1 `AreaChain/Features/Diary/DiaryQuickComposerView.swift`

a. 弹出小窗按钮（A）。把 `if let onOpenWindow { Button { ... } ... }` 整段替换为：

```swift
                if let onOpenWindow {
                    Button {
                        guard !hasMarkedText else { return }
                        onOpenWindow()
                    } label: {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
                    .help(canSubmit ? "diary.window.continue" : "diary.window.new")
                    .accessibilityLabel(canSubmit ? "diary.window.continue" : "diary.window.new")
                    .background(SyntaxViewAnchor("syntax.diary.popout"))
                }
```

然后删除 `@State private var isPopoutHovered = false`（替换后它没有引用了）。

b. 标签芯片（B）。`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 手记标签芯片，P5 迁 DaybookChip(.tag)`。胶囊外观不要动。

c. `standardSubmitButton`（A，实心印章按钮改成强调文字按钮）。整个属性替换为：

```swift
    private var standardSubmitButton: some View {
        Button(action: onSubmit) {
            HStack(spacing: 4) {
                Image(systemName: "square.and.pencil")
                Text("diary.composer.save")
            }
            .font(DaybookType.caption.weight(.semibold))
        }
        .buttonStyle(DaybookButtonStyle(.prominent, size: .compact))
        .disabled(!canSubmit)
        .keyboardShortcut(.return, modifiers: .command)
    }
```

### 1.2 `AreaChain/Features/Diary/DiaryPage.swift`

a. 搜索放大镜（A）。`searchChrome` 的 `leading` 槽里，把

```swift
            Button { searchFocused = true } label: {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(showsPageHeader ? KeyboardShortcut("f", modifiers: .command) : nil)
            .accessibilityLabel("diary.search.placeholder")
```

替换为

```swift
            DaybookIconButton(systemName: "magnifyingglass", label: "diary.search.placeholder", size: .inline) {
                searchFocused = true
            }
            .keyboardShortcut(showsPageHeader ? KeyboardShortcut("f", modifiers: .command) : nil)
```

b. 清空（A）。`trailing` 槽里的清空 `Button { ... }` 整段替换为：

```swift
                DaybookIconButton(systemName: "xmark.circle.fill", label: "footer.search.clear", size: .inline) {
                    searchQuery = ""
                }
```

c. `filterPill`（B）。`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 手记筛选胶囊，P5 迁 DaybookChip(.filter)`。`standardFilterLabel` 不要动。

### 1.3 `AreaChain/Features/Diary/DiarySummaryRow.swift`

a. `copyButton`（A）整段替换为：

```swift
    private var copyButton: some View {
        Button(action: copy) {
            Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .semibold))
        }
        .buttonStyle(DaybookButtonStyle(hasCopied ? .iconActive : .icon, size: .compact))
        .help(L10n.string(hasCopied ? "diary.copied" : "diary.quick.copy", locale: locale))
        .accessibilityLabel(L10n.string(hasCopied ? "diary.copied" : "diary.quick.copy", locale: locale))
        .fixedSize()
    }
```

b. `moreMenu` 的 label 与 `.buttonStyle(.plain)`（A）。把

```swift
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(DaybookTheme.muted)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(DaybookTheme.ink.opacity(0.06))
                )
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
```

替换为

```swift
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .daybookMenuLabel(size: .compact)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
```

后面的 `.help("footer.more")`、`.accessibilityLabel("footer.more")`、`.fixedSize()` 保留。`actionCluster` 的 48×22 外框保留。

### 1.4 `AreaChain/Features/Diary/DiaryWindowView.swift`（A，三处文字/图标）

- `Button("diary.mask") { session.mask() }` 下一行 `.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))`
- 附件按钮整段

```swift
                    Button { attach(to: record) } label: { Image(systemName: "photo") }
                        .buttonStyle(.plain).accessibilityLabel("diary.attach").help("diary.attach")
```

替换为

```swift
                    DaybookIconButton(systemName: "photo", label: "diary.attach", size: .compact) {
                        attach(to: record)
                    }
```

- `Button("diary.window.reload") { confirmsReload = true }` 下一行 `.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))`

`.buttonStyle(.borderedProminent)` 和 `.buttonStyle(.bordered)` **不要改**。

### 1.5 `AreaChain/Features/Diary/DiaryNoteCard.swift`（B）

已打标签胶囊那颗按钮的 `.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 已打标签胶囊，P5 迁 DaybookChip(.tag)`。胶囊和 `addTagMenu` 不要动（`addTagMenu` 没有 `.plain`）。

### 1.6 `AreaChain/Features/Diary/DiaryCardComponents.swift`

a. 取消（A）：`Button("alert.cancel", action: discardEditingDraft)` 下一行 `.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))`。下一行的 `.buttonStyle(.borderedProminent)` 不要改。

b. 「显示」胶囊（A）。把 `maskedPasswordContentView` 里的 `Button { revealContent() } ... .buttonStyle(.plain)` 整段替换为：

```swift
            Button {
                revealContent()
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "eye")
                    Text("diary.reveal")
                }
                .font(DaybookType.caption)
            }
            .buttonStyle(DaybookButtonStyle(.pill(tint: DaybookPalette.accent.base), size: .compact))
```

c. 复制密码（A，去掉绿色）。把 `copyAndMaskButtons` 里第一个 `Button(action: copyContent)` 到它的 `.buttonStyle(.plain)` 整段替换为：

```swift
            Button(action: copyContent) {
                HStack(spacing: 2) {
                    Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                    Text(hasCopied ? "diary.copied" : "diary.copy.password")
                }
                .font(DaybookType.badge.weight(.medium))
            }
            .buttonStyle(DaybookButtonStyle(hasCopied ? .active : .prominent, size: .compact))
            .help("diary.copy.password.help")
```

d. 眼睛（A）：

```swift
            Button {
                if canRevealContent { maskContent() }
                else { revealContent() }
            } label: {
                Image(systemName: isMasked ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .foregroundStyle(DaybookTheme.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(isMasked ? "diary.unmask" : "diary.mask")
```

替换为

```swift
            Button {
                if canRevealContent { maskContent() }
                else { revealContent() }
            } label: {
                Image(systemName: isMasked ? "eye" : "eye.slash")
            }
            .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
            .help(isMasked ? "diary.unmask" : "diary.mask")
            .accessibilityLabel(isMasked ? "diary.unmask" : "diary.mask")
```

e. 非密码的复制图标（A）：

```swift
            Button(action: copyContent) {
                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(hasCopied ? Color.green : DaybookTheme.muted)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("diary.copy")
```

替换为

```swift
            Button(action: copyContent) {
                Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(DaybookButtonStyle(hasCopied ? .iconActive : .icon, size: .compact))
            .help("diary.copy")
            .accessibilityLabel("diary.copy")
```

f. `pinActionButton`（A）整段替换为：

```swift
    private var pinActionButton: some View {
        Button {
            DayBoardMutations.togglePinDiary(entry)
        } label: {
            Image(systemName: entry.isPinned ? "pin.fill" : "pin")
        }
        .buttonStyle(DaybookButtonStyle(entry.isPinned ? .iconActive : .icon, size: .compact))
        .help(entry.isPinned ? "diary.unpin" : "diary.pin")
        .accessibilityLabel(entry.isPinned ? "diary.unpin" : "diary.pin")
    }
```

g. `editActionButton`（A）整段替换为：

```swift
    private var editActionButton: some View {
        Button {
            guard !(isPasswordType && isMasked) else { return }
            beginEditing()
        } label: {
            Image(systemName: "pencil")
        }
        .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
        .disabled(isPasswordType && isMasked)
        .help(isPasswordType && isMasked ? "diary.unmask.first" : "diary.edit.help")
        .accessibilityLabel("diary.edit.help")
    }
```

h. `attachActionButton`（A）整段替换为：

```swift
    private var attachActionButton: some View {
        Button {
            guard !(isPasswordType && isMasked) else { return }
            AttachmentActions.pickDiaryImage(entry, context: modelContext, vault: privacyVault)
        } label: {
            Image(systemName: "photo")
        }
        .buttonStyle(DaybookButtonStyle(.icon, size: .compact))
        .disabled(isPasswordType && isMasked)
        .help(isPasswordType && isMasked ? "diary.unmask.first" : "diary.attach")
        .accessibilityLabel("diary.attach")
    }
```

i. `deleteActionButton`（A）整段替换为：

```swift
    private var deleteActionButton: some View {
        DaybookIconButton(systemName: "trash", label: "alert.trash.move", size: .compact, role: .destructive, action: onDelete)
    }
```

检查点：

```bash
rg -n '\.buttonStyle\(\.plain\)' AreaChain/Features/Diary | rg -v '// control:'
rg -n 'Color\.green' AreaChain/Features/Diary
./scripts/build.sh
```

前两条预期零输出。

---

## 步骤 2：Workspace

### 2.1 `AreaChain/Features/Workspace/TaskDetailSubtasksView.swift`

- 新增子任务的「添加」（A）：`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.prominent, size: .inline))`，并删除 label 里的 `.foregroundStyle(DaybookTheme.stamp)`。
- `toggleCheckboxButton`（B）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 子任务复选框，非按钮语义`
- 标签移除芯片（B）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 子任务标签移除芯片，P5 迁 DaybookChip(.token)`。胶囊不要动。
- 铅笔（A）整段替换为：

```swift
            DaybookIconButton(systemName: "pencil", label: "drawer.subtasks.edit", size: .inline, action: startEdit)
```

- 垃圾桶（A）整段替换为：

```swift
            DaybookIconButton(systemName: "trash", label: "drawer.subtasks.delete", size: .inline, action: onDelete)
```

### 2.2 `AreaChain/Features/Workspace/TaskDetailDrawer.swift`（A）

`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))`（关闭预览）。

### 2.3 `AreaChain/Features/Workspace/TaskDetailNotesView.swift`

- 「保存」（A）：`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.prominent, size: .compact))`，删除下一行 `.foregroundStyle(DaybookTheme.stamp)`。`.font(DaybookType.caption)` 与 `.help` 保留。
- 链接按钮（B）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 备注链接芯片，P5 迁 DaybookChip`。链接的圆角底不要动。

### 2.4 `AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift`（B）

`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 象限选择格，P4 迁 daybookSurface(.cell)`。格子自绘不要动。

### 2.5 `AreaChain/Features/Workspace/TaskDetailSections.swift`

- 选图、粘贴（A）两处：各自改成 `DaybookIconButton`，删掉手写 Image 的 font 和 foregroundStyle。

选图：

```swift
                DaybookIconButton(systemName: "plus", label: "drawer.attachments.pick", size: .inline) {
                    AttachmentActions.pickImage(ownerKind: props.ownerKind, ownerID: props.ownerID, context: modelContext)
                }
```

粘贴：

```swift
                DaybookIconButton(systemName: "doc.on.clipboard", label: "drawer.attachments.paste", size: .inline) {
                    _ = AttachmentActions.pasteImage(ownerKind: props.ownerKind, ownerID: props.ownerID, context: modelContext)
                }
```

- 缩略图上的删除（A）。把 `Button { DayBoardMutations.trashAttachment(att) } ... .buttonStyle(.plain)` 整段替换为：

```swift
            DaybookIconButton(systemName: "xmark.circle.fill", label: "alert.trash.move", size: .inline) {
                DayBoardMutations.trashAttachment(att)
            }
            .padding(2)
```

### 2.6 `AreaChain/Features/Workspace/TaskDetailClassificationSection.swift`（A）

新建标签按钮整段替换为：

```swift
                DaybookIconButton(systemName: "plus.circle", label: "drawer.tag.add", size: .inline) {
                    createError = nil
                    newTagName = ""
                    isCreatingTag = true
                }
```

### 2.7 `AreaChain/Features/Workspace/TaskDetailScheduleSection.swift`

- 清除提醒（A）整段替换为：

```swift
                    DaybookIconButton(systemName: "xmark.circle.fill", label: "row.time.clear", size: .inline) {
                        onSelectMinutes(nil)
                    }
```

- 星期圆点（B）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 星期圆点，P5 迁 DaybookChip(.filter)`。圆圈自绘不要动。

### 2.8 `AreaChain/Features/Workspace/ResidentsPage.swift`

- 检查器按钮（A）整段替换为：

```swift
            DaybookIconButton(
                systemName: "sidebar.trailing",
                label: "drawer.inspector.toggle",
                size: .regular,
                isActive: isSelected
            ) {
                navigation.inspectTask(routine.id)
            }
```

- `Button("row.time.set")` 的 `.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.subtle, size: .compact))`，删除 `.foregroundStyle(DaybookTheme.muted)`。
- `Button("row.time.clear")` 的 `.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.subtle, size: .compact))`，删除 `.foregroundStyle(DaybookTheme.muted)`。

### 2.9 `AreaChain/Features/Workspace/WorkspaceHeaderBar.swift`

- 清空搜索（A）整段替换为：

```swift
                DaybookIconButton(systemName: "xmark.circle.fill", label: "footer.search.clear", size: .inline) {
                    navigation.clearSearch()
                    navigation.isSearchFocused = true
                }
```

- `WorkspaceHeaderInspectorToggle` 的 `var body`（A）整段替换为：

```swift
    var body: some View {
        DaybookIconButton(
            systemName: "sidebar.trailing",
            label: "drawer.inspector.toggle",
            size: .regular,
            isActive: navigation.isInspectorPresented
        ) {
            navigation.isInspectorPresented.toggle()
        }
        .accessibilityIdentifier("workspace.header.inspector.toggle")
    }
```

隐藏的 ⌘F `Button("")` **没有** `.plain`，不要动。`⌘F` 文字标签不要动。

### 2.10 `AreaChain/Features/Workspace/WorkspaceFilteredListView.swift`

- 全选（A）。把 `Button { withAnimation... } label: { Image ... } .buttonStyle(.plain) .help(...)` 整段替换为：

```swift
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        if navigation.selectedTaskIDs.isEmpty {
                            navigation.selectAllTasks(in: orderedVisibleIDs)
                        } else {
                            navigation.clearSelection()
                        }
                    }
                } label: {
                    Image(systemName: navigation.selectedTaskIDs.isEmpty ? "checklist" : "checklist.checked")
                }
                .buttonStyle(DaybookButtonStyle(navigation.selectedTaskIDs.isEmpty ? .icon : .iconActive, size: .compact))
                .help(navigation.selectedTaskIDs.isEmpty ? "batch.select.all" : "batch.exit")
                .accessibilityLabel(navigation.selectedTaskIDs.isEmpty ? "batch.select.all" : "batch.exit")
```

- 父任务标题（A）：`.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.subtle, size: .compact))`。`.font` 与 `.foregroundStyle` 删除（样式负责颜色；字号用默认）。
- 已完成折叠头（B）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 已完成折叠头，整行点击`

### 2.11 `AreaChain/Features/Workspace/WorkspaceGlobalSearchView.swift`（B）

`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 附件结果整行点击区，P4 迁 daybookSurface(.row)`

检查点：

```bash
rg -n '\.buttonStyle\(\.plain\)' AreaChain/Features/Workspace | rg -v '// control:'
./scripts/build.sh
```

第一条预期零输出。

---

## 步骤 3：Quadrant

`AreaChain/Features/Quadrant/QuadrantPage.swift`（B）：

`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 象限任务卡整行点击，P4 迁 daybookSurface(.card)`

`modernCard` 与 `.draggable` 不要动。

---

## 步骤 4：Theme

### 4.1 `AreaChain/Theme/CommandReturnButton.swift`（A）

`var body` 整段替换为：

```swift
    var body: some View {
        Button(action: action) {
            HStack(spacing: 2.5) {
                Image(systemName: "command")
                Image(systemName: "return")
            }
            .font(.system(size: 10.5, weight: .semibold))
        }
        .buttonStyle(DaybookButtonStyle(enabled && isCommandPressed ? .iconActive : .icon, size: .compact))
        .focusable(false)
        .disabled(!enabled)
        .fixedSize()
        .accessibilityLabel(label)
        .help(help ?? label)
        .background(SyntaxViewAnchor("syntax.commandReturn.button"))
        .onAppear(perform: startObservingModifiers)
        .onDisappear(perform: stopObservingModifiers)
    }
```

然后删除不再使用的：`@Environment(\.accessibilityReduceMotion)`、`@State private var isHovered`、`private var isActive`、`private var animation`。`isCommandPressed` 和事件监视器保留。`SyntaxViewAnchor("syntax.commandReturn.button")` 必须还在。

### 4.2 `AreaChain/Features/Theme` 不对，文件是 `AreaChain/Theme/CaptureAttributesView.swift`

- 主按钮（B）：`.buttonStyle(.plain)`（约第 71 行，紧挨 `syntax.attributes.button` 之前）→ `.buttonStyle(.plain) // control: 属性按钮固定 58×22，胶囊留给 P5`。58×22 的 `frame` 和胶囊不要动。
- 关闭（A）。把

```swift
                Button { state.dismiss() } label: {
                    Image(systemName: "xmark").font(DaybookType.caption)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .background(SyntaxViewAnchor("syntax.attributes.close"))
                .accessibilityLabel("common.close")
                .accessibilityIdentifier("syntax.attributes.close")
```

替换为

```swift
                DaybookIconButton(systemName: "xmark", label: "common.close", size: .inline) {
                    state.dismiss()
                }
                .focusable(false)
                .background(SyntaxViewAnchor("syntax.attributes.close"))
                .accessibilityIdentifier("syntax.attributes.close")
```

### 4.3 `AreaChain/Theme/SyntaxHelpCard.swift`

- 关闭（A）。把带 `xmark`、18×18、`Circle` 底的 `Button` 整段替换为：

```swift
            DaybookIconButton(systemName: "xmark", label: "common.close", size: .inline) {
                withAnimation(DaybookMotion.interactive(reduceMotion)) {
                    isExpanded = false
                }
            }
```

- 语法行按钮（B，约第 237 行）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 语法条目悬停替换正文`。它自己的悬停底和 `onHover` 不要动。
- 综合范例（B，约第 308 行）：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 语法范例卡片，P4 迁 daybookSurface(.card)`。卡片自绘不要动。

### 4.4 `AreaChain/Theme/LiveComposerPreviewHeader.swift`（A）

关闭按钮整段替换为：

```swift
            DaybookIconButton(systemName: "xmark", label: "common.close", size: .inline, action: onClose)
```

### 4.5 `AreaChain/Theme/LiveDiaryComposerPreview.swift`

- `copyButton`（A）整段替换为：

```swift
    private var copyButton: some View {
        Button(action: copyTitle) {
            Image(systemName: hasCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(DaybookButtonStyle(hasCopied ? .iconActive : .icon, size: .compact))
        .help("diary.copy")
        .accessibilityLabel("diary.copy")
    }
```

- `moreMenu` 的 label 与 `.buttonStyle(.plain)`（A）。把 label 里的 Image 及其 `.foregroundStyle` / `.frame` / `.background` / `.contentShape` 换成：

```swift
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .medium))
                .daybookMenuLabel(size: .compact)
```

并删除 `.buttonStyle(.plain)` 那一行。`.menuStyle`、`.menuIndicator`、`.help`、`.accessibilityLabel`、`.fixedSize` 保留。

### 4.6 `AreaChain/Theme/SyntaxAutocompleteView.swift`（A）

候选按钮 `.buttonStyle(.plain)` → `.buttonStyle(DaybookButtonStyle(.quiet, size: .compact))`。`.focusable(false)`、`SyntaxViewAnchor("syntax.candidate." + item.id)`、`accessibilityIdentifier` 不要动。`candidateRow` 内部的选中底不要动。

### 4.7 三个控件（B，只加注释）

- `AreaChain/Theme/ModernComponents.swift` 的 `ModernCheckbox`：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 复选框，非按钮语义`
- 同文件 `PillBadge`：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 胶囊徽章，P5 迁 DaybookChip`
- `AreaChain/Theme/WorkspaceLayout.swift` 侧栏行：`.buttonStyle(.plain)` → `.buttonStyle(.plain) // control: 侧栏导航行，非按钮语义`

检查点：

```bash
rg -n '\.buttonStyle\(\.plain\)' AreaChain/Theme AreaChain/Features/Quadrant | rg -v '// control:'
./scripts/build.sh
```

第一条预期零输出。

---

## 最终验证（全部必须通过）

```bash
# 1. 代码里没有裸 .plain（预期零输出；基座文档注释里的字面量不算）
rg -n '\.buttonStyle\(\.plain\)' AreaChain --glob '*.swift' | rg -v '// control:' | rg -v ':[0-9]+:[[:space:]]*///'

# 2. control 总数（预期 28 = P3a 的 11 + 本阶段 17）
rg -c '\.buttonStyle\(\.plain\) // control:' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# 3. 绿色复制态已离开日记卡片（预期零输出）
rg -n 'Color\.green' AreaChain/Features/Diary

# 4. 系统按钮还在（预期 4：DiaryWindowView 3 + DiaryCardComponents 1）
rg -c '\.buttonStyle\(\.bordered(Prominent)?\)' AreaChain/Features/Diary/DiaryCardComponents.swift AreaChain/Features/Diary/DiaryWindowView.swift | awk -F: '{s+=$2} END {print s}'

# 5. 锚点还在（预期各至少 1）
rg -c 'syntax\.diary\.popout' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'syntax\.commandReturn\.button' AreaChain/Theme/CommandReturnButton.swift
rg -c 'syntax\.attributes\.button' AreaChain/Theme/CaptureAttributesView.swift
rg -c 'syntax\.attributes\.close' AreaChain/Theme/CaptureAttributesView.swift
rg -c 'syntax\.candidate\.' AreaChain/Theme/SyntaxAutocompleteView.swift
rg -c 'workspace\.header\.inspector\.toggle' AreaChain/Features/Workspace/WorkspaceHeaderBar.swift

# 6. 测试（原生界面测试串行，期间不操作其他窗口）
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookButtonStyleTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/DiaryComposerInteractionTests \
  --only-testing AreaChainTests/DiaryWindowLifecycleTests \
  --only-testing AreaChainTests/PrivacyRenderingTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/TaskRowInteractionTests

# 7. 工作流检查
python3 -B scripts/check_workflow.py

# 8. 改动范围：不应出现 MenuBar / Tasks / Board / Search（Search 的 control 注释是 P3a 留下的，本阶段不该再改那些文件）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Board AreaChain/Features/Search
```

第 8 条预期**零输出**。有输出说明你改了 P3a 的模块，把那个文件回滚。

第 6 条若失败且信息是「某个尺寸与预期不符」，不要改测试，把失败信息原样贴出来停下问我。

## 汇报格式

```
## P3b 完成汇报
### 修改文件（路径 — 一句话）
### A 类迁移清单（file — variant/size）
### B 类保留清单（file — control 注释原文）
### 验证输出（最终验证 1–8 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P3b 按钮（Diary + Workspace + Theme）` 改成 `- [x]`，决策记录追加 `- <日期> P3b 完成：<一句话>`。

## 绝对不要做

- 不要改 `DaybookButtonStyle.swift` 的 variant / size / 颜色。
- 不要动 MenuBar、Tasks、Board、Search。
- 不要把 `.bordered` / `.borderedProminent` 改成 `DaybookButtonStyle`。
- 不要改任何 `accessibilityIdentifier`、`SyntaxViewAnchor` 字符串。
- 不要动 `DiaryOrganizeMenus.swift`（里面的菜单项没有 `.plain`）。
- 不要 commit。
