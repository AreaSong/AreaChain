# 任务：AreaChain 设计系统收敛 · 阶段 P3a（按钮基座 + MenuBar / Tasks / Board / Search）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P3a-execute.md` 执行了 P3a 并声称完成。你**不相信它的任何一句话**：自己重跑命令、自己看文件、自己看 diff，逐项打 PASS / FAIL / BLOCKED，最后给"通过 / 不通过"和整改清单。

规则：
1. **只读**。不改源码、测试、文档；不 `git add/commit/stash/checkout`；不安装不发布。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须**亲自运行并粘贴原样输出**。
3. 命令跑不起来 → BLOCKED。
4. 发现问题只记录，不动手修。
5. 先读 `.cursor/plans/design-system-P3a-execute.md` 全文，特别是"两类 `.buttonStyle(.plain)` 的处理规则"。

---

## 检查清单

### A. 旧 API 消失、新基座存在

```bash
# A1 预期零输出
rg -n 'DaybookQuietButtonStyle|RowIconButton|DaybookNavButton|ComposerAddButton|WorkspaceSidebarHeaderAction|FooterActionItemModifier|isButtonHovered' AreaChain AreaChainTests

# A2 预期存在
ls AreaChain/Theme/DaybookButtonStyle.swift AreaChainTests/Theme/DaybookButtonStyleTests.swift

# A3 基座内容抽查（预期各 1；最后一条预期 9）
rg -c 'struct DaybookButtonStyle: ButtonStyle' AreaChain/Theme/DaybookButtonStyle.swift
rg -c 'struct DaybookIconButton: View' AreaChain/Theme/DaybookButtonStyle.swift
rg -c 'func daybookMenuLabel\(' AreaChain/Theme/DaybookButtonStyle.swift
rg -c 'init\(_ variant: DaybookButtonVariant = .quiet, size: DaybookButtonSize = .regular, isFocused: Bool = false\)' AreaChain/Theme/DaybookButtonStyle.swift
rg -c 'hovering && isEnabled \? DaybookPalette.fill.hover : .clear' AreaChain/Theme/DaybookButtonStyle.swift
rg -c '^    case (quiet|subtle|prominent|destructive|active|pill\(tint: Color\)|icon|iconActive|iconDestructive)$' AreaChain/Theme/DaybookButtonStyle.swift

# A4 基座里不允许出现蓝色悬停环或系统色（预期零输出）
rg -n 'focusRing|DaybookTheme\.|Color\.(orange|red|green|blue|white|black)' AreaChain/Theme/DaybookButtonStyle.swift
```

### B. 四个模块的 `.plain` 处理

```bash
# B1 预期零输出：没有裸 .plain
rg -n '\.buttonStyle\(\.plain\)' AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Board AreaChain/Features/Search | rg -v '// control:'

# B2 预期恰好 11 条，且每条都能在下面的清单里找到
rg -n '\.buttonStyle\(\.plain\) // control:' AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Board AreaChain/Features/Search
```

B2 允许的 11 处（逐条对照；多一处说明执行者把按钮偷懒标成了 control，少一处说明它把控件改成了按钮，两种都 → FAIL）：
- `MenuBar/MenuBarControls.swift`（分段切换滑块）
- `MenuBar/MenuBarSearchField.swift`（token 移除角标）
- `Tasks/AttachmentThumbnails.swift`（缩略图）
- `Tasks/DayBoardSections.swift`（分节折叠头）
- `Tasks/TaskRow+Badges.swift`（时间胶囊）
- `Tasks/TaskRowSubtaskMiniViews.swift` × 2（计数芯片、复选框）
- `Tasks/TasksPage+Header.swift`（token 移除角标）
- `Tasks/TasksPage+Sections.swift` × 2（胶囊操作、遗留芯片）
- `Search/BoardSearchHitRow.swift`（整行点击区）
- `Board/BoardCommandStrip.swift` 不得出现（它的按钮必须已迁到 `DaybookButtonStyle`）。

```bash
# B3 A 类迁移抽查（预期各 ≥ 1）
rg -c 'DaybookButtonStyle\(\.subtle, size: \.compact, isFocused: triggerFocused\)' AreaChain/Features/MenuBar/FooterBar.swift
rg -c 'DaybookButtonStyle\(\.pill\(tint: DaybookPalette\.accent\.base\), size: \.compact, isFocused: triggerFocused\)' AreaChain/Features/MenuBar/FooterBar.swift
rg -c 'DaybookIconButton\(systemName: "xmark", label: "common.close", size: \.regular\)' AreaChain/Features/MenuBar/FooterBar.swift
rg -c 'daybookMenuLabel\(size: \.regular, isFocused: moreFocused\)' AreaChain/Features/MenuBar/FooterBar.swift
rg -c 'DaybookButtonStyle\(isSelected \? \.active : \.quiet, size: \.compact\)' AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift   # 预期 2
rg -c 'DaybookButtonStyle\(\.prominent, size: \.inline\)' AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift                       # 预期 2
rg -c 'DaybookIconButton\(systemName: "magnifyingglass", label: "footer.search.label", size: \.inline\)' AreaChain/Features/MenuBar/MenuBarSearchField.swift
rg -c 'DaybookIconButton\(systemName: "xmark.circle.fill", label: "batch.clear", size: \.compact, action: onClear\)' AreaChain/Features/Tasks/BatchActionBar.swift
rg -c 'DaybookButtonStyle\(hasCopied \? \.iconActive : \.icon, size: \.compact\)' AreaChain/Features/Tasks/TaskRow+Menus.swift
rg -c 'daybookMenuLabel\(size: \.compact\)' AreaChain/Features/Tasks/TaskRow+Menus.swift
rg -c 'DaybookIconButton\(systemName: "checkmark", label: "row.save", action: saveEdit\)' AreaChain/Features/Tasks/TaskRow+Menus.swift
rg -c 'DaybookButtonStyle\(isDestructive \? \.iconDestructive : \(isActive \? \.iconActive : \.icon\), size: \.compact\)' AreaChain/Features/Board/BoardCommandStrip.swift
rg -c 'daybookMenuLabel\(size: \.compact, isActive: isActive\)' AreaChain/Features/Board/BoardCommandStrip.swift
rg -c 'DaybookIconButton\(systemName: "magnifyingglass", label: "search.placeholder", size: \.inline\)' AreaChain/Features/Search/SearchPage.swift
rg -c 'DaybookIconButton\(systemName: "plus", label: "sidebar.add.project", size: \.compact, action: onAddProject\)' AreaChain/Features/Workspace/WorkspaceSidebarView.swift
rg -c 'Button\("row.add", action: onSubmit\)' AreaChain/Theme/DaybookPage.swift

# B4 迁过去的按钮 label 里不应再自己画底（预期零输出）
rg -n -A8 'DaybookButtonStyle\(' AreaChain/Features/MenuBar/FooterBar.swift AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift AreaChain/Features/Tasks/TaskRow+Menus.swift AreaChain/Features/Tasks/BoardFilterBar.swift | rg 'RoundedRectangle\(cornerRadius: (4\.5|5|6),'

# B5 FilterDropdownItemRow 的自有 hover 状态已删（预期零输出）
rg -n 'isHovered' AreaChain/Features/Tasks/BoardFilterBar.swift
```

### C. 没越界

```bash
# C1 预期各 ≥ 1：Diary / Workspace / Theme 的 .plain 仍在（P3b 的事）
rg -c '\.buttonStyle\(\.plain\)' AreaChain/Features/Diary/DiaryCardComponents.swift
rg -c '\.buttonStyle\(\.plain\)' AreaChain/Features/Workspace/TaskDetailSubtasksView.swift
rg -c '\.buttonStyle\(\.plain\)' AreaChain/Theme/CommandReturnButton.swift

# C2 预期零输出：行为层与输入壳未改
git diff --stat -- AreaChain/Theme/DaybookTextField.swift AreaChain/Theme/DaybookTextEditor.swift AreaChain/Theme/DaybookInputShell.swift AreaChain/Theme/SyntaxOverlay.swift
git diff --cached --stat -- AreaChain/Theme/DaybookTextField.swift AreaChain/Theme/DaybookTextEditor.swift AreaChain/Theme/DaybookInputShell.swift AreaChain/Theme/SyntaxOverlay.swift

# C3 关键标识仍在（预期各 ≥ 1）
rg -c 'accessibilityIdentifier\("menubar.filter.open"\)' AreaChain/Features/MenuBar/FooterBar.swift
rg -c 'accessibilityIdentifier\("menubar.workspace.open"\)' AreaChain/Features/MenuBar/FooterBar.swift
rg -c 'accessibilityIdentifier\("menubar.more"\)' AreaChain/Features/MenuBar/FooterBar.swift
rg -c 'keyboardShortcut\("f", modifiers: \[\.command, \.shift\]\)' AreaChain/Features/MenuBar/FooterBar.swift   # 预期 2
rg -c 'keyboardShortcut\("0", modifiers: \.command\)' AreaChain/Features/MenuBar/FooterBar.swift               # 预期 2
rg -c 'BoardCommandHoverArea' AreaChain/Features/Board/BoardCommandStrip.swift                                  # 预期 ≥ 3

# C4 测试没被删（预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 真正编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookButtonStyleTests \
  --only-testing AreaChainTests/DaybookInputShellTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/MenuBarToolbarStateTests \
  --only-testing AreaChainTests/BoardFilterBarTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/TaskRowBubbleTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/WorkspaceLayoutTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行；跑不起来 → BLOCKED。运行期间不要操作其他窗口。

### E. 工作流检查与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P3a' .cursor/plans/design-system.md
rg -n 'P3a 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P3a 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A4 旧 API 消失 / 基座存在与内容 | ... | ... |
| B1 无裸 .plain | ... | ... |
| B2 control 清单（11 条逐条核对） | ... | 多出/缺失项 |
| B3 A 类迁移抽查（16 条） | ... | 不符项 |
| B4–B5 label 不再自绘 / hover 状态已删 | ... | ... |
| C1–C4 未越界、标识与测试完整 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → **不通过**。B2 不是恰好 11 条 → **不通过**（多了说明执行者用 control 注释逃避迁移，少了说明控件被误改成按钮）。只有 E 的计划状态 FAIL → 通过但列入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节"决策记录"末尾追加：`- <日期> P3a 验收：通过 / 不通过（<原因>）`。
