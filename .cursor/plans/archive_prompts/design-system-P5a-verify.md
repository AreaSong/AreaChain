# 任务：AreaChain 设计系统收敛 · 阶段 P5a（芯片）· 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P5a-execute.md` 执行了 P5a 并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读 `.cursor/plans/design-system-P5a-execute.md` 的「背景」和「绝对不要做」。

---

## 检查清单

### A. 旧芯片消失，新芯片存在

```bash
# A1 预期零输出
rg -n 'PillBadge|P5 迁 DaybookChip' AreaChain AreaChainTests

# A2 预期文件存在
ls AreaChain/Theme/DaybookChip.swift

# A3 外观规则还在（预期各 1）
rg -c 'tint\.opacity\(0\.14\)' AreaChain/Theme/DaybookChip.swift
rg -c 'tint\.opacity\(0\.35\)' AreaChain/Theme/DaybookChip.swift
rg -c 'struct DaybookChip' AreaChain/Theme/DaybookChip.swift
```

### B. 调用点

```bash
# B1 预期至少 10
rg -c 'DaybookChip\(' AreaChain --glob '*.swift' | awk -F: '{s+=$2} END {print s}'

# B2 这些文件都必须出现 DaybookChip（缺一个 → FAIL）
for f in \
  Features/Workspace/TaskDetailScheduleSection.swift \
  Features/Workspace/TaskDetailClassificationSection.swift \
  Features/Diary/DiaryNoteCard.swift \
  Features/Diary/DiaryQuickComposerView.swift \
  Features/Diary/DiaryPage.swift \
  Features/Tasks/TasksPage+Sections.swift \
  Features/Tasks/TaskRow+Badges.swift \
  Features/Tasks/TaskRowSubtaskMiniViews.swift \
  Features/Workspace/TaskDetailSubtasksView.swift \
  Features/Workspace/TaskDetailNotesView.swift \
  Features/Tasks/TasksPage+Header.swift \
  Features/MenuBar/MenuBarSearchField.swift
 do printf "%-62s " "$f"; rg -c 'DaybookChip\(' "AreaChain/$f" || echo 0; done
```

### C. 没越界

```bash
# C1 星期圆点还是圆（预期各至少 1）
rg -c '星期圆点选择器，不是胶囊' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
rg -c 'Circle\(\)' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift

# C2 这些胶囊本阶段不该被改掉（预期各至少 1）
rg -c 'Capsule\(\)' AreaChain/Theme/LiveComposerPreviewHeader.swift
rg -c 'Capsule\(\)' AreaChain/Theme/CaptureAttributesView.swift
rg -c 'SectionStamp\(' AreaChain/Features/Tasks/DayBoardSections.swift
rg -c 'struct DaybookQuietTabBar' AreaChain/Features/MenuBar/MenuBarControls.swift

# C3 表面和按钮基座零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Theme/DaybookSurface.swift AreaChain/Theme/DaybookButtonStyle.swift
git diff --cached --stat -- AreaChain/Theme/DaybookSurface.swift AreaChain/Theme/DaybookButtonStyle.swift

# C4 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/MenuBarPopoverRenderingTests \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/BoardFilterBarTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P5a' .cursor/plans/design-system.md
rg -n 'P5a 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P5a 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A3 旧芯片消失 / 新芯片规则 | ... | ... |
| B1–B2 调用点（12 个文件逐个） | ... | 缺失文件 |
| C1–C4 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。B2 缺任何一个文件 → 不通过。C3 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P5a 验收：通过 / 不通过（<原因>）`。
