# 任务：AreaChain 设计系统收敛 · 阶段 P1（删除双宿主分支）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P1-execute.md` 执行了 P1 并声称完成。你**不相信它的任何一句话**：自己重跑命令、自己看文件、自己看 diff，逐项打 PASS / FAIL / BLOCKED，最后给"通过 / 不通过"和整改清单。

规则：
1. **只读**。不改源码、测试、文档；不 `git add/commit/stash/checkout`；不安装不发布。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须**亲自运行并粘贴原样输出**。没有输出不能打 PASS。
3. 命令跑不起来 → BLOCKED，写明原因，不能当 PASS。
4. 发现问题只记录、给整改建议，不动手修。
5. 先读 `.cursor/plans/design-system-P1-execute.md` 全文，特别是"分支处理规则"一节，知道 A 类（视觉）和 B 类（能力）分支各应该怎么改。

---

## 检查清单

### A. 旧机制彻底消失

```bash
# A1 预期零输出
rg -n 'daybookViewStyle|DaybookViewStyle|isWorkspace|WorkspaceStyle\b|WorkspaceSwatch|WorkspaceFilterLabel|workspaceFilterChrome|workspaceCapsule' AreaChain AreaChainTests

# A2 预期两个文件都 "No such file or directory"
ls AreaChain/Theme/DaybookWorkspaceStyle.swift AreaChainTests/Theme/WorkspaceStyleTests.swift

# A3 预期存在
ls AreaChainTests/Theme/WorkspaceLayoutTests.swift

# A4 环境键已定义（预期各 1）
rg -c 'struct WorkspaceEmbeddedKey' AreaChain/Theme/WorkspaceLayout.swift
rg -c 'var workspaceEmbedded: Bool' AreaChain/Theme/WorkspaceLayout.swift

# A5 注入点已替换（预期 1）
rg -c '\.environment\(\\\.workspaceEmbedded, true\)' AreaChain/Features/Workspace/MainSplitWorkspaceView.swift
```

### B. 能力分支（B 类）保留且用法正确

```bash
# B1 预期零输出：embedded 不得与颜色/字体/透明度同行
rg -n 'embedded.*(DaybookPalette|DaybookTheme|DaybookType|\.opacity\(|Color\.)' AreaChain

# B2 列出全部 embedded 使用点，逐条核对下面的"必须存在"清单
rg -n '\bembedded\b' AreaChain --glob '*.swift'
```

B2 输出里**必须包含**以下每一处（缺一条 → FAIL，说明执行者把能力分支当视觉分支删了，功能丢失）：
- `Features/Calendar/CalendarPage.swift`：`compactDates: embedded &&`、`minWidth: embedded ? 0 : 420`、`if !embedded {`
- `Features/Diary/DiaryPage.swift`：`if !embedded { tagFilterBar }`、`if showsPageHeader && embedded { tagFilterBar }`
- `Features/Diary/DiaryStandaloneView.swift`：`minWidth: embedded ? 0 : 360`
- `Features/Quadrant/QuadrantPage.swift`：`if embedded {`
- `Features/Tasks/TaskRow.swift`：`if embedded {`（两处：`hasVisibleNote` 与备注摘要）、`!embedded && !editing`（两处）、`if !embedded, fullNoteText != nil`、`wideHost: embedded`、`.lineLimit(embedded ? 2 : 1)`
- `Features/Tasks/TasksPage+Header.swift`：`let hasFilters = embedded`、`if embedded {`
- `Theme/DaybookPage.swift`：`(embedded && !fullWidth)`、`minWidth: embedded ? 0 : minWidth`、`minHeight: embedded ? 0 : minHeight`
- `Theme/WorkspaceLayout.swift`：`minHeight: embedded ? WorkspaceLayout.headerHeight : nil`

```bash
# B3 预期零输出：气泡参数已改名
rg -n 'isWorkspace' AreaChain/Theme/DaybookRowBubbles.swift
# B4 预期 ≥ 5：wideHost 在用
rg -c 'wideHost' AreaChain AreaChainTests | awk -F: '{s+=$2} END {print s}'
```

### C. 视觉分支（A 类）取了标准侧

```bash
# C1 DaybookGroupedCard 不再画白卡（预期零输出）
rg -n 'RoundedRectangle|strokeBorder|shadow' AreaChain/Theme/ModernComponents.swift | rg -n 'DaybookGroupedCard' ; rg -n -A6 'struct DaybookGroupedCard' AreaChain/Theme/ModernComponents.swift | rg 'RoundedRectangle|strokeBorder|\.shadow'

# C2 ModernRowModifier 没有工作台 padding 4/1.5（预期零输出）
rg -n 'padding\(\.horizontal, 4\)|padding\(\.vertical, 1\.5\)' AreaChain/Theme/ModernComponents.swift

# C3 抽屉分节标题不再大写（预期零输出）
rg -n 'textCase' AreaChain/Features/Workspace/TaskDetailDrawer.swift

# C4 任务行高来自令牌（预期 1）
rg -c 'minHeight: DaybookMetrics.rowHeight' AreaChain/Features/Tasks/TaskRow.swift

# C5 DaybookInputChrome 已搬到 DaybookChrome.swift 且无分支（预期各 1，且 C5b 零输出）
rg -c 'enum DaybookInputKind' AreaChain/Theme/DaybookChrome.swift
rg -c 'private struct DaybookInputChrome' AreaChain/Theme/DaybookChrome.swift
rg -n 'minimumHeight|style\.' AreaChain/Theme/DaybookChrome.swift | rg -n 'DaybookInputChrome|minimumHeight'

# C6 BoardFilterBar 只剩 standardCapsule（预期 1 / 0）
rg -c 'standardCapsule' AreaChain/Features/Tasks/BoardFilterBar.swift
rg -c 'workspaceCapsule|var style' AreaChain/Features/Tasks/BoardFilterBar.swift

# C7 DiaryPage / TasksPage+Sections 不再有 WorkspaceFilterLabel 分支（预期零输出）
rg -n 'WorkspaceFilterLabel' AreaChain/Features
```

### D. 不该动的没动

```bash
# D1 预期各 ≥ 1：P2/P4/P5 才删的东西还在
rg -c 'func daybookInputChrome' AreaChain/Theme/DaybookChrome.swift
rg -c 'struct DaybookGroupedCard' AreaChain/Theme/ModernComponents.swift
rg -c 'struct PillBadge' AreaChain/Theme/ModernComponents.swift
rg -c 'struct SectionStamp' AreaChain/Theme/DaybookTheme.swift
rg -c 'enum DiaryTagChrome' AreaChain/Features/Diary/DiaryNoteCard.swift

# D2 预期零输出：Features 没有提前迁到 palette 文本色（P6 的事）
rg -n 'DaybookPalette\.text\.' AreaChain/Features

# D3 预期零输出：原生输入层未被改动
git diff --stat -- AreaChain/Theme/DaybookTextField.swift AreaChain/Theme/DaybookTextEditor.swift AreaChain/Theme/SyntaxOverlay.swift

# D4 测试没有被删：除了整文件删除的 WorkspaceStyleTests，其他测试文件不允许出现 -@Test
git diff -- AreaChainTests | rg '^-\s*@Test' | rg -v 'WorkspaceStyleTests'
git diff --cached -- AreaChainTests | rg '^-\s*@Test' | rg -v 'WorkspaceStyleTests'
```

D4 两条都应零输出（`WorkspaceStyleTests` 的 `-@Test` 会以整文件删除形式出现，如果在这里被 `rg -v` 过滤后仍有输出 → FAIL）。

### E. 文档无悬空引用

```bash
# E1 预期零输出
rg -n 'DaybookWorkspaceStyle|DaybookViewStyle|WorkspaceStyle\b|WorkspaceSwatch|WorkspaceStyleTests' AGENTS.md README.md docs .agents/skills --glob '*.md'
# E2 预期 ≥ 1：AGENTS.md 已写入新规则
rg -c 'workspaceEmbedded' AGENTS.md docs/architecture.md
```

### F. 真正编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/WorkspaceLayoutTests \
  --only-testing AreaChainTests/DaybookTokenTests \
  --only-testing AreaChainTests/DaybookContrastTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/GanttInteractionTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/BoardFilterBarTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行；跑不起来 → BLOCKED。运行期间不要操作其他窗口（原生焦点测试）。

### G. 工作流检查与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P1 删除双宿主分支' .cursor/plans/design-system.md
rg -n 'P1 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P1 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A5 旧机制消失 | PASS/FAIL/BLOCKED | ... |
| B1 embedded 未用于颜色/字体 | ... | ... |
| B2 能力分支全部保留（逐条勾） | ... | 缺失项列出 |
| B3–B4 气泡参数改名 | ... | ... |
| C1–C7 视觉分支取标准侧 | ... | ... |
| D1–D4 不该动的没动、测试完整 | ... | ... |
| E1–E2 文档 | ... | ... |
| F 编译与测试 | ... | EXIT=? |
| G check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D、F 任一 FAIL 或 BLOCKED → **不通过**。B2 缺任何一条 → **不通过**（功能丢失，最严重）。只有 E 或 G 的计划状态项 FAIL → 通过但列入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节"决策记录"末尾追加：`- <日期> P1 验收：通过 / 不通过（<原因>）`。
