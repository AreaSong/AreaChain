# 任务：AreaChain 设计系统收敛 · 阶段 P6 Workspace · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P6-workspace-execute.md` 执行了工作台清扫并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读执行稿的「为什么有的换、有的不换」和「绝对不要做」。

---

## 检查清单

### A. 该换的已经换了

```bash
# A1 未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:' AreaChain/Features/Workspace | rg -v 'token-exempt:'

# A2 字面圆角（预期零输出）
rg -n 'cornerRadius:\s*[0-9]' AreaChain/Features/Workspace

# A3 已点名系统色（预期零输出）
rg -n 'Color\.white|foregroundStyle\(\.orange\)' AreaChain/Features/Workspace

# A4 新写法确实出现（预期各至少 1）
rg -c 'DaybookPalette\.text\.onAccent' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
rg -c 'DaybookPalette\.status\.pending' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
rg -c 'DaybookPalette\.status\.danger' AreaChain/Features/Workspace/TaskDetailHeaderSection.swift
rg -c 'DaybookType\.label' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
rg -c 'DaybookRadius\.small' AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift
rg -c 'DaybookRadius\.xxs' AreaChain/Features/Workspace/TaskDetailSubtasksView.swift
rg -c 'DaybookRadius\.xs' AreaChain/Features/Workspace/TaskDetailSubtasksView.swift
rg -c 'DaybookType\.title' AreaChain/Features/Workspace/TaskDetailSections.swift
```

`DaybookType.label` 在星期标题和连击标题上应该至少 2。只有 1 也先记下来，对照执行稿：两处 `.font(.system(size: 10, weight: .semibold))` 都应换成 `label`。少一处 → FAIL。

### B. 不该改掉的还在，而且该豁免的有注释

```bash
rg -n 'size: 9\.5|\.font\(\.system\(size: 36|design: \.rounded|design: \.monospaced' AreaChain/Features/Workspace
```

`size: 36` 只匹配字体 `.font(.system(size: 36`。`DaybookProgressRing` 的 `size: 36` 是环的直径，不在这条里，也不要补 `token-exempt:`。

每一行都必须含 `token-exempt:`。少一行豁免，或 36pt 被改成了 `DaybookType.display` → FAIL。把不合规的行贴出来。

下面这些必须仍在，并且同一行有 `token-exempt:`：

```bash
rg -n 'muted\.opacity\(0\.6\)|muted\.opacity\(0\.7\)|muted\.opacity\(0\.5\)|muted\.opacity\(0\.8\)|rule\.opacity\(0\.18\)|rule\.opacity\(0\.25\)|rule\.opacity\(0\.3\)|stamp\.opacity\(0\.8\)|themeColor\.opacity\(0\.7\)|paper\.opacity\(0\.4\)|status\.danger\.opacity\(0\.85\)|foregroundStyle\(\.yellow\)|systemIndigo' AreaChain/Features/Workspace
```

象限底色必须仍是原来的填充，不能变成印章色：

```bash
rg -n 'slot\.themeFill|slot\.themeColor' AreaChain/Features/Workspace/TaskDetailQuadrantGrid.swift
```

预期 `themeFill` 至少 1，`themeColor` 至少 1。

星期选择器必须仍是圆，并且 `control:` 注释还在：

```bash
rg -n 'Circle\(\)|control: 星期圆点' AreaChain/Features/Workspace/TaskDetailScheduleSection.swift
```

预期 `Circle()` 至少 1，`control:` 至少 1。

下面这些是显隐，不是颜色。没有 `token-exempt:` 也算通过。数字被改了 → FAIL：

```bash
rg -n 'Divider\(\)\.padding\(\.leading, 36\)\.opacity|Divider\(\)\.opacity\(0\.2\)|\.opacity\(0\.3\)|\.opacity\(0\)' AreaChain/Features/Workspace
```

`.buttonStyle(.plain)` 的每一行都必须仍含 `// control:`：

```bash
rg -n 'buttonStyle\(\.plain\)' AreaChain/Features/Workspace
```

### C. 没越界

```bash
# C1 其他模块零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Diary AreaChain/Theme
git diff --cached --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Diary AreaChain/Theme

# C2 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/WorkspaceLayoutTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests \
  --only-testing AreaChainTests/CaptureOverlayLayoutTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P6 Workspace' .cursor/plans/design-system.md
rg -n 'P6 Workspace 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P6 Workspace 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A4 该换的已换 | ... | ... |
| B 圆体、等宽、36pt、未映射颜色和象限/星期圆点仍在 | ... | 不合规行 |
| C1–C2 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。C1 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P6 Workspace 验收：通过 / 不通过（<原因>）`。
