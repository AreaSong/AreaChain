# 任务：AreaChain 设计系统收敛 · 阶段 P2（统一输入壳）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P2-execute.md` 执行了 P2 并声称完成。你**不相信它的任何一句话**：自己重跑命令、自己看文件、自己看 diff，逐项打 PASS / FAIL / BLOCKED，最后给"通过 / 不通过"和整改清单。

规则：
1. **只读**。不改源码、测试、文档；不 `git add/commit/stash/checkout`；不安装不发布。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须**亲自运行并粘贴原样输出**。没有输出不能打 PASS。
3. 命令跑不起来 → BLOCKED，写明原因。
4. 发现问题只记录、给整改建议，不动手修。
5. 先读 `.cursor/plans/design-system-P2-execute.md` 全文。

---

## 检查清单

### A. 旧壳消失、新壳存在

```bash
# A1 预期零输出
rg -n 'BoardCaptureRow|DaybookInputChrome|daybookInputChrome|DaybookField\b|locksHeight|showsFocusShadow|paintsChrome' AreaChain AreaChainTests

# A2 预期 "No such file"
ls AreaChain/Theme/BoardCaptureRow.swift

# A3 预期存在
ls AreaChain/Theme/DaybookInputShell.swift AreaChainTests/Theme/DaybookInputShellTests.swift

# A4 DaybookInputKind 只在新文件定义（预期只有 DaybookInputShell.swift 一行）
rg -n 'enum DaybookInputKind' AreaChain
```

### B. 新壳内容抽查（防改名、改值、加颜色参数）

```bash
rg -c 'struct DaybookInputShellConfiguration' AreaChain/Theme/DaybookInputShell.swift                          # 预期 1
rg -c 'static func standard\(for kind: DaybookInputKind\)' AreaChain/Theme/DaybookInputShell.swift            # 预期 1
rg -c 'height: DaybookMetrics.inputHeight' AreaChain/Theme/DaybookInputShell.swift                             # 预期 1
rg -c 'height: DaybookMetrics.controlHeight' AreaChain/Theme/DaybookInputShell.swift                           # 预期 1
rg -c 'focused \? DaybookPalette.fill.surface : DaybookPalette.fill.subtle' AreaChain/Theme/DaybookInputShell.swift   # 预期 1
rg -c 'focused \? DaybookPalette.border.focus : DaybookPalette.border.faint' AreaChain/Theme/DaybookInputShell.swift  # 预期 1
rg -c 'focused \? DaybookMetrics.Stroke.focus : DaybookMetrics.Stroke.regular' AreaChain/Theme/DaybookInputShell.swift # 预期 1
rg -c 'daybookHideInputChrome' AreaChain/Theme/DaybookInputShell.swift                                          # 预期 1
rg -c 'focusRing|stamp|Color\.' AreaChain/Theme/DaybookInputShell.swift                                          # 预期 0（壳里不能有蓝色或系统色）
rg -c 'var configure: \(\(inout DaybookInputShellConfiguration\) -> Void\)\? = nil' AreaChain/Theme/DaybookInputShell.swift  # 预期 1
```

### C. 令牌修正到位

```bash
rg -c 'static let inputSearch: CGFloat = 6' AreaChain/Theme/DaybookMetrics.swift                                # 预期 1
rg -c 'case .search: EdgeInsets\(top: 4, leading: 7, bottom: 4, trailing: 7\)' AreaChain/Theme/DaybookMetrics.swift  # 预期 1
rg -c 'let faint: Color' AreaChain/Theme/DaybookPalette.swift                                                   # 预期 1
rg -c 'faint: alpha\("palette.border.faint", DaybookSwatch.ruleLight, DaybookSwatch.ruleDark, 0.4\)' AreaChain/Theme/DaybookPalette.swift  # 预期 1
rg -c 'inputSearch == 6' AreaChainTests/Theme/DaybookTokenTests.swift                                           # 预期 1
rg -c 'search.top == 4' AreaChainTests/Theme/DaybookTokenTests.swift                                            # 预期 1
```

### D. 输入框都迁入壳，且没绕过壳

```bash
# D1 预期 ≥ 12。DiaryPage 锁定草稿提示框保持现有 token-exempt 自绘（P4 再迁 banner），不要把它再包进壳，所以不计入这 12 处。
rg -c 'DaybookInputShell\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# D2 每个文件至少 1（逐个核对；缺任何一个 → FAIL）
for f in Features/MenuBar/CaptureField.swift Theme/DaybookPage.swift Features/Diary/DiaryQuickComposerView.swift Features/Diary/DiaryPage.swift Features/Diary/DiaryCardComponents.swift Features/Search/SearchPage.swift Features/MenuBar/MenuBarSearchField.swift Features/Workspace/WorkspaceHeaderBar.swift Features/Workspace/TaskDetailSubtasksView.swift Features/Workspace/TaskDetailNotesView.swift Features/Diary/DiaryWindowView.swift; do printf "%-55s " "$f"; rg -c 'DaybookInputShell\(' "AreaChain/$f"; done

# D3 DiaryQuickComposerView 里应有 2 处（compact + editor）
rg -c 'DaybookInputShell\(' AreaChain/Features/Diary/DiaryQuickComposerView.swift   # 预期 2

# D4 输入框不得自绘 focusRing。全量扫描只允许 FooterBar.swift 的 FooterActionItemModifier 按钮描边（留给 P3 删除）；去掉该文件后预期零输出。
rg -n 'focusRing' AreaChain/Features
rg -n 'focusRing' AreaChain/Features --glob '!**/FooterBar.swift'
rg -n 'Capsule\(\)' AreaChain/Features/Workspace/WorkspaceHeaderBar.swift        # 预期零输出（搜索胶囊已换成壳）

# D5 没有人用 configure 改颜色（预期零输出）
rg -n 'configure.*(Palette|Theme|Color|opacity)' AreaChain
```

### E. 行为契约未动

```bash
# E1 预期零输出：输入行为层文件完全没改
git diff --stat -- AreaChain/Theme/DaybookTextField.swift AreaChain/Theme/DaybookTextEditor.swift AreaChain/Theme/SyntaxTextField.swift AreaChain/Theme/SyntaxTextEditor.swift AreaChain/Theme/SyntaxOverlay.swift AreaChain/Theme/SyntaxAutocompleteView.swift
git diff --cached --stat -- AreaChain/Theme/DaybookTextField.swift AreaChain/Theme/DaybookTextEditor.swift AreaChain/Theme/SyntaxTextField.swift AreaChain/Theme/SyntaxTextEditor.swift AreaChain/Theme/SyntaxOverlay.swift AreaChain/Theme/SyntaxAutocompleteView.swift

# E2 关键锚点与无障碍标识仍在（预期各 ≥ 1）
rg -c 'SyntaxViewAnchor\("syntax.diary.composer"\)' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'SyntaxViewAnchor\("syntax.diary.popout"\)' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'accessibilityIdentifier\("menubar.search.input"\)' AreaChain/Features/MenuBar/MenuBarSearchField.swift
rg -c 'accessibilityIdentifier\("workspace.header.search"\)' AreaChain/Features/Workspace/WorkspaceHeaderBar.swift
rg -c 'accessibilityLabel\("capture.placeholder.today"\)' AreaChain/Features/MenuBar/CaptureField.swift
rg -c 'onCommandReturn: \{ if allowsDiaryShortcut \{ onDiary\(\) \} \}' AreaChain/Features/MenuBar/CaptureField.swift
rg -c 'onCommandReturn: submitCompact' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'keyboardShortcut\("f", modifiers: .command\)' AreaChain/Features/MenuBar/MenuBarSearchField.swift AreaChain/Features/Workspace/WorkspaceHeaderBar.swift AreaChain/Features/Search/SearchPage.swift

# E3 测试没有被删（预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### F. 文档

```bash
# F1 预期零输出
rg -n 'DaybookInputChrome|BoardCaptureRow|DaybookField\b|动态智能属性按钮' AGENTS.md README.md docs .agents/skills --glob '*.md'
# F2 预期 ≥ 1
rg -c 'DaybookInputShell' AGENTS.md docs/architecture.md
```

### G. 真正编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookInputShellTests \
  --only-testing AreaChainTests/DaybookTokenTests \
  --only-testing AreaChainTests/WorkspaceLayoutTests \
  --only-testing AreaChainTests/DaybookTextFieldTests \
  --only-testing AreaChainTests/DaybookTextFieldSearchTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests \
  --only-testing AreaChainTests/InputSyntaxInteractionTests \
  --only-testing AreaChainTests/DiaryComposerInteractionTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/MenuBarToolbarStateTests \
  --only-testing AreaChainTests/DiaryWindowLifecycleTests \
  --only-testing AreaChainTests/PrivacyRenderingTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行；跑不起来 → BLOCKED。运行期间不要操作其他窗口。

### H. 工作流检查与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P2 输入壳' .cursor/plans/design-system.md
rg -n 'P2 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P2 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A4 旧壳消失 / 新壳存在 | ... | ... |
| B 新壳内容抽查（10 条） | ... | 不符项列出 |
| C 令牌修正（6 条） | ... | ... |
| D1–D5 消费者迁移与无绕过 | ... | 缺失文件列出 |
| E1–E3 行为契约与测试完整 | ... | ... |
| F 文档 | ... | ... |
| G 编译与测试 | ... | EXIT=? |
| H check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D、E、G 任一 FAIL 或 BLOCKED → **不通过**。E1 有输出（改了行为层文件）→ **不通过**，且整改清单第一条写"回滚该文件"。只有 F 或 H 计划状态 FAIL → 通过但列入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节"决策记录"末尾追加：`- <日期> P2 验收：通过 / 不通过（<原因>）`。
