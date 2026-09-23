# 任务：AreaChain 设计系统收敛 · 阶段 P6 其余页面 · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P6-rest-execute.md` 执行了 Search、Calendar、Quadrant、Gantt、Trash、Attachments、Settings 和 Board 命令条的清扫并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读执行稿的「为什么有的换、有的不换」和「绝对不要做」。
5. 字号检查必须匹配 `.font(.system(size:`。不要用单独的 `size: 36` 或 `size: 6` 去扫，那些是视图尺寸，不是字号。

范围目录：

```text
AreaChain/Features/Board
AreaChain/Features/Calendar
AreaChain/Features/Gantt
AreaChain/Features/Quadrant
AreaChain/Features/Search
AreaChain/Features/Trash
AreaChain/Features/Attachments
AreaChain/Features/Settings
```

---

## 检查清单

### A. 该换的已经换了

```bash
# A1 未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:' \
  AreaChain/Features/Board \
  AreaChain/Features/Calendar \
  AreaChain/Features/Gantt \
  AreaChain/Features/Quadrant \
  AreaChain/Features/Search \
  AreaChain/Features/Trash \
  AreaChain/Features/Attachments \
  AreaChain/Features/Settings \
  | rg -v 'token-exempt:'

# A2 字面圆角（预期零输出）
rg -n 'cornerRadius:\s*[0-9]' \
  AreaChain/Features/Board \
  AreaChain/Features/Calendar \
  AreaChain/Features/Gantt \
  AreaChain/Features/Quadrant \
  AreaChain/Features/Search \
  AreaChain/Features/Trash \
  AreaChain/Features/Attachments \
  AreaChain/Features/Settings

# A3 Color.red 和 12% 印章底（预期零输出）
rg -n 'Color\.red' \
  AreaChain/Features/Board \
  AreaChain/Features/Calendar \
  AreaChain/Features/Gantt \
  AreaChain/Features/Quadrant \
  AreaChain/Features/Search \
  AreaChain/Features/Trash \
  AreaChain/Features/Attachments \
  AreaChain/Features/Settings
rg -n 'stamp\.opacity\(0\.12\)' AreaChain/Features/Search

# A4 新写法确实出现（预期各至少 1）
rg -c 'DaybookPalette\.status\.danger' AreaChain/Features/Board/BoardCommandStrip.swift
rg -c 'DaybookPalette\.accent\.fill' AreaChain/Features/Search/BoardSearchHitRow.swift
rg -c 'DaybookType\.label' AreaChain/Features/Calendar/CalendarMonthGrid.swift
rg -c 'DaybookRadius\.xxs' AreaChain/Features/Gantt/GanttPage.swift
rg -c 'DaybookRadius\.xs' AreaChain/Features/Gantt/GanttPage.swift
rg -c 'DaybookRadius\.small' AreaChain/Features/Attachments/AttachmentBrowserPage.swift
rg -c 'DaybookType\.badge\.weight\(\.bold\)' AreaChain/Features/Trash/TrashPage.swift
```

### B. 不该改掉的还在，而且该豁免的有注释

剩下的字面字号必须正好是这三行，并且每一行都含 `token-exempt:`：

```bash
rg -n '\.font\(\.system\(size:' \
  AreaChain/Features/Board \
  AreaChain/Features/Calendar \
  AreaChain/Features/Gantt \
  AreaChain/Features/Quadrant \
  AreaChain/Features/Search \
  AreaChain/Features/Trash \
  AreaChain/Features/Attachments \
  AreaChain/Features/Settings
```

预期正好 3 行：命令提示的圆体、日历计数的圆体、附件占位的 18pt。多一行或少一行，或 18pt 被换成了 `DaybookType.entity` → FAIL。

下面这些必须仍在，并且同一行有 `token-exempt:`：

```bash
rg -n 'ink\.opacity\(0\.85\)|ink\.opacity\(0\.06\)|status\.danger\.opacity\(0\.08\)|stamp\.opacity\(0\.18\)|stamp\.opacity\(0\.4\)|rule\.opacity\(0\.3\)|stamp\.opacity\(0\.85\)' \
  AreaChain/Features/Board \
  AreaChain/Features/Calendar \
  AreaChain/Features/Gantt
```

日历三态注释必须仍在，预期至少 3 行：

```bash
rg -n '今日环、选中与投放三态' AreaChain/Features/Calendar/CalendarMonthGrid.swift
```

甘特色块注释必须仍在，预期至少 2 行，并且圆角已经是令牌：

```bash
rg -n '甘特色块是数据标记，不是卡片' AreaChain/Features/Gantt/GanttPage.swift
```

习惯点必须仍是圆。被改成圆角矩形 → FAIL：

```bash
rg -n 'Circle\(\)' AreaChain/Features/Gantt/GanttPage.swift
```

预期至少 1。

命令条动画必须仍是原来的 0.12 秒。被换成 `DaybookMotion` → FAIL：

```bash
rg -n 'easeInOut\(duration: 0\.12\)' AreaChain/Features/Board/BoardCommandStrip.swift
```

预期正好 1 行。

### C. 没越界

```bash
# C1 其他模块零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Diary AreaChain/Features/Workspace AreaChain/Theme
git diff --cached --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Diary AreaChain/Features/Workspace AreaChain/Theme

# C2 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/GanttLayoutTests \
  --only-testing AreaChainTests/GanttInteractionTests \
  --only-testing AreaChainTests/QuadrantLayoutTests \
  --only-testing AreaChainTests/PrivacyRenderingTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P6 Search / Calendar / Quadrant / Gantt / Trash / Attachments / Settings' .cursor/plans/design-system.md
rg -n 'P6 其余页面完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P6 其余页面验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A4 该换的已换 | ... | ... |
| B 圆体、18pt、未映射透明度、日历三态、甘特色块、圆点和动画仍在 | ... | 不合规行 |
| C1–C2 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。C1 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P6 其余页面验收：通过 / 不通过（<原因>）`。
