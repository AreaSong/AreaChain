# 任务：AreaChain 设计系统收敛 · 阶段 P0（令牌落地）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话已经按 `.cursor/plans/design-system-P0-execute.md` 执行了 P0，并声称完成。你的工作是**不相信它的任何一句话**，自己重跑命令、自己看文件、自己看 diff，对照下面的清单逐项打 PASS / FAIL / BLOCKED，最后给出"通过"或"不通过"以及整改清单。

规则：

1. **只读**。不修改任何源码、测试、文档、计划文件；不 `git add` / `git commit` / `git stash` / `git checkout`；不运行安装或发布脚本。你唯一允许的写操作是最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每一项都必须**亲自运行命令并粘贴原样输出**作为证据。没有输出的项不能打 PASS。
3. 命令跑不起来（例如 xcodebuild 启动失败、rg 不存在）打 BLOCKED，并写明原因，不能当 PASS。
4. 发现问题只记录、只给整改建议，**不动手修**。
5. 先读 `.cursor/plans/design-system-P0-execute.md` 全文，知道执行者应该做什么，再开始下面的检查。不需要读其他文档。

---

## 检查清单

### A. 改动范围（最重要，先做）

A1. 运行并粘贴：

```bash
git status --short
```

对照白名单。**允许出现的文件只有以下这些**（`??` 新增或 ` M` 修改）：

新增（必须全部存在）：
- `AreaChain/Theme/DaybookTokens.swift`
- `AreaChain/Theme/DaybookPalette.swift`
- `AreaChain/Theme/DaybookMetrics.swift`
- `AreaChain/Theme/DaybookElevation.swift`
- `AreaChain/Theme/WorkspaceLayout.swift`
- `AreaChainTests/Theme/DaybookTokenTests.swift`

修改（允许，不要求全部出现）：
- `AreaChain/Theme/DaybookTheme.swift`
- `AreaChain/Theme/DaybookWorkspaceStyle.swift`
- `AreaChain/Theme/DaybookChrome.swift`
- `AreaChain/Theme/DaybookPage.swift`
- `AreaChain/Theme/BoardCaptureRow.swift`
- `AreaChain/Theme/ModernComponents.swift`
- `AreaChain/Theme/SyntaxHighlighter.swift`
- `AreaChain/Theme/LiveComposerPreviewHeader.swift`
- `AreaChain/Theme/QuadrantMiniMark.swift`
- `AreaChain/Theme/SyntaxAutocompleteView.swift`
- `AreaChain/Features/Tasks/TaskRow+Badges.swift`
- `AreaChain/Features/Workspace/WorkspaceHeaderBar.swift`
- `AreaChain/Features/Workspace/WorkspaceSidebarView.swift`
- `AreaChainTests/Theme/WorkspaceStyleTests.swift`
- `AreaChainTests/Theme/SyntaxHighlighterTests.swift`
- `.cursor/plans/design-system.md`

判定：白名单之外出现任何文件 → **A1 FAIL**，在整改清单写"回滚 <文件>"。6 个新增文件缺任何一个 → **A1 FAIL**。

A2. 运行并粘贴：

```bash
git diff --stat -- AreaChain/Features
```

预期恰好三个文件：`TaskRow+Badges.swift`、`WorkspaceHeaderBar.swift`、`WorkspaceSidebarView.swift`。多或少 → FAIL。

A3. 确认 Features 里的改动只是符号改名，没有偷改逻辑：

```bash
git diff -- AreaChain/Features | rg '^[+-]' | rg -v '^(\+\+\+|---)' | rg -v 'DaybookTheme\.Syntax|DaybookPalette\.Syntax|WorkspaceStyle\.(headerHeight|sidebarTopInset)|WorkspaceLayout\.(headerHeight|sidebarTopInset)'
```

预期**零输出**。有输出说明 Features 里改了别的东西 → FAIL，把输出贴进整改清单。

### B. 新文件内容抽查（防止执行者改名、改值、漏写）

对每一条运行 `rg -c`（统计匹配行数），预期值写在后面；不等于预期 → 该项 FAIL。

```bash
rg -c 'static let inputHeight: CGFloat = 34' AreaChain/Theme/DaybookMetrics.swift            # 预期 1
rg -c 'static let rowHeight: CGFloat = 36' AreaChain/Theme/DaybookMetrics.swift              # 预期 1
rg -c 'static let inputComposer: CGFloat = 8' AreaChain/Theme/DaybookMetrics.swift           # 预期 1
rg -c 'static let inputSearch: CGFloat = 10' AreaChain/Theme/DaybookMetrics.swift            # 预期 1
rg -c 'static let floating = DaybookElevation\(color: Color.black.opacity\(0.14\), radius: 8, y: 2\)' AreaChain/Theme/DaybookElevation.swift   # 预期 1
rg -c 'static let raised = DaybookElevation\(color: Color.black.opacity\(0.08\), radius: 1.5, y: 0.5\)' AreaChain/Theme/DaybookElevation.swift  # 预期 1
rg -c 'static let flat = ' AreaChain/Theme/DaybookElevation.swift                            # 预期 1
rg -c 'func daybookElevation' AreaChain/Theme/DaybookElevation.swift                         # 预期 1
rg -c 'focus: alpha\("palette.border.focus", DaybookSwatch.inkLight, DaybookSwatch.inkDark, 0.35\)' AreaChain/Theme/DaybookPalette.swift   # 预期 1（聚焦色必须是 ink 灰，不是 stamp 蓝）
rg -c 'pending: Color\(nsColor: .systemOrange\)' AreaChain/Theme/DaybookPalette.swift        # 预期 1
rg -c 'enum DaybookSwatch' AreaChain/Theme/DaybookPalette.swift                              # 预期 1
rg -c 'enum Syntax' AreaChain/Theme/DaybookPalette.swift                                     # 预期 1
rg -c 'static func priorityColor\(isImportant: Bool, isUrgent: Bool\)' AreaChain/Theme/DaybookPalette.swift   # 预期 1（证明 Syntax 是原文搬入）
rg -c 'static func diaryPreset\(forTagName' AreaChain/Theme/DaybookPalette.swift             # 预期 1
rg -c 'static let xxs: CGFloat = 2.5' AreaChain/Theme/DaybookTokens.swift                    # 预期 1
rg -c 'static let regular: CGFloat = 8' AreaChain/Theme/DaybookTokens.swift                  # 预期 1
rg -c 'static let (kbd|micro|bodyLarge|display): Font' AreaChain/Theme/DaybookTokens.swift   # 预期 4
rg -c 'static let headerHeight: CGFloat = 50' AreaChain/Theme/WorkspaceLayout.swift          # 预期 1
rg -c 'static let maxContentWidth: CGFloat = 880' AreaChain/Theme/WorkspaceLayout.swift      # 预期 1
rg -c 'struct (DaybookPageHeader|WorkspaceSidebarHeaderAction|WorkspaceSidebarRow)' AreaChain/Theme/WorkspaceLayout.swift   # 预期 3
rg -c 'static let fade: Animation = .easeInOut\(duration: 0.15\)' AreaChain/Theme/DaybookChrome.swift   # 预期 1
rg -c '@Test' AreaChainTests/Theme/DaybookTokenTests.swift                                   # 预期 6
```

### C. 旧符号必须消失、该留的必须还在

```bash
# C1 预期零输出
rg -n 'DaybookShadow|DaybookTheme\.Syntax' AreaChain AreaChainTests

# C2 预期零输出（这些定义必须已离开 DaybookTheme.swift）
rg -n 'enum (DaybookRadius|DaybookSpacing|DaybookType|DaybookSwatch|DaybookShadow)' AreaChain/Theme/DaybookTheme.swift

# C3 预期零输出（三个组件必须已离开 DaybookWorkspaceStyle.swift）
rg -n 'struct (DaybookPageHeader|WorkspaceSidebarHeaderAction|WorkspaceSidebarRow)' AreaChain/Theme/DaybookWorkspaceStyle.swift

# C4 预期零输出（6 个布局常量必须已离开 WorkspaceStyle）
rg -n 'WorkspaceStyle\.(headerHeight|maxContentWidth|sidebarRowHeight|sidebarRowVerticalPadding|sidebarRowHorizontalPadding|sidebarTopInset)' AreaChain AreaChainTests

# C5 预期 ≥ 8 行（DaybookTheme 基色必须还在，执行者不得越界删除）
rg -c 'static let (ink|muted|rule|stamp|paper|done|destructive|checkmark) = ' AreaChain/Theme/DaybookTheme.swift

# C6 预期各 1 行（P1 才删的东西必须还在）
rg -c 'enum DaybookViewStyle' AreaChain/Theme/DaybookWorkspaceStyle.swift
rg -c 'enum WorkspaceStyle' AreaChain/Theme/DaybookWorkspaceStyle.swift
rg -c 'enum WorkspaceSwatch' AreaChain/Theme/DaybookWorkspaceStyle.swift
rg -c 'struct DaybookInputChrome' AreaChain/Theme/DaybookWorkspaceStyle.swift

# C7 预期零输出（执行者不得提前把 Features 的基色迁到 palette，那是 P6）
rg -n 'DaybookPalette\.(text|fill|border|status|accent)\.' AreaChain/Features
```

### D. 测试没有被删或注释

```bash
# D1 预期零输出：任何测试文件里都不允许出现被删除的 @Test 行
git diff -- AreaChainTests | rg '^-\s*@Test'

# D2 预期零输出：不允许新增被注释掉的 @Test
git diff -- AreaChainTests | rg '^\+\s*//\s*@Test'

# D3 预期只有一行改动且是 headerHeight 改名
git diff -- AreaChainTests/Theme/WorkspaceStyleTests.swift | rg '^[+-]' | rg -v '^(\+\+\+|---)'
```

D3 预期恰好两行：一行 `-` 含 `WorkspaceStyle.headerHeight`，一行 `+` 含 `WorkspaceLayout.headerHeight`。多了 → FAIL。

### E. 真正编译并跑测试（不信执行者的日志）

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DaybookTokenTests \
  --only-testing AreaChainTests/DaybookContrastTests \
  --only-testing AreaChainTests/WorkspaceStyleTests \
  --only-testing AreaChainTests/SyntaxHighlighterTests
echo "EXIT=$?"
```

判定：`EXIT=0` 且输出中能看到 `DaybookTokenTests` 相关的通过信息 → PASS。`EXIT` 非 0 → FAIL，把最后 60 行输出贴进整改清单。命令本身跑不起来 → BLOCKED。

### F. 工作流检查

```bash
python3 -B scripts/check_workflow.py
echo "EXIT=$?"
```

预期四项 `passed` 且 `EXIT=0`。

### G. 计划文件状态

```bash
rg -n '\[x\] P0 令牌落地' .cursor/plans/design-system.md
rg -n 'P0 完成' .cursor/plans/design-system.md
```

各预期 1 行。没有 → FAIL（属于轻微项，但仍要在整改清单里写"更新计划文件状态"）。

---

## 输出格式（严格按此格式）

```
## P0 验收报告

| 项 | 结果 | 证据（命令输出摘要） |
|---|---|---|
| A1 改动范围白名单 | PASS/FAIL/BLOCKED | ... |
| A2 Features 三文件 | ... | ... |
| A3 Features 仅改名 | ... | ... |
| B 新文件内容抽查（22 条） | PASS 或 "FAIL：第 n 条实际 x 预期 y" | ... |
| C1–C7 旧符号与保留项 | ... | ... |
| D1–D3 测试完整性 | ... | ... |
| E 编译与测试 | ... | EXIT=? |
| F check_workflow | ... | EXIT=? |
| G 计划文件状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填；每条写清"文件 — 现在是什么 — 应该是什么"）
1. ...
```

结论规则：A、C、D、E、F 任一 FAIL 或 BLOCKED → **不通过**。只有 G FAIL → 通过，但整改清单写上"更新计划文件状态"。B 中任何一条 FAIL → **不通过**（说明执行者改了名字或数值，后续阶段会全部对不上）。

最后一步：在 `.cursor/plans/design-system.md` 第 8 节"决策记录"末尾追加一行：`- <今天日期> P0 验收：通过 / 不通过（<不通过时一句话原因>）`。这是你唯一允许的写操作。
