# 任务：AreaChain 设计系统收敛 · 阶段 P6 Tasks · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P6-tasks-execute.md` 执行了任务模块清扫并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

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
rg -n '\.font\(\.system\(size:' AreaChain/Features/Tasks | rg -v 'token-exempt:'

# A2 点名圆角（预期零输出）
rg -n 'cornerRadius:\s*(10|3\.5|3|2\.5)\b' AreaChain/Features/Tasks

# A3 橙色（预期零输出）
rg -n 'Color\.orange' AreaChain/Features/Tasks

# A4 已点名透明度（预期零输出）
rg -n 'muted\.opacity\(0\.75\)|stamp\.opacity\(0\.35\)|stamp\.opacity\(0\.12\)' AreaChain/Features/Tasks

# A5 新写法确实出现（预期各至少 1）
rg -c 'DaybookPalette\.status\.pending' AreaChain/Features/Tasks/TaskRow+Badges.swift
rg -c 'DaybookPalette\.text\.tertiary' AreaChain/Features/Tasks/TaskRow+Badges.swift
rg -c 'DaybookPalette\.accent\.border' AreaChain/Features/Tasks/BatchActionBar.swift
rg -c 'DaybookPalette\.accent\.fill' AreaChain/Features/Tasks/BoardFilterBar.swift
rg -c 'DaybookRadius\.medium' AreaChain/Features/Tasks/BatchActionBar.swift
rg -c 'DaybookType\.caption' AreaChain/Features/Tasks/BatchActionBar.swift
```

### B. 不该放大的还在，而且有豁免注释

```bash
rg -n 'size: 7\.5|size: 8[,)]|size: 8\.5|design: \.rounded|design: \.monospaced' AreaChain/Features/Tasks
```

每一行都必须含 `token-exempt:`。少一行豁免，或这些字号被改成了 `DaybookType` → FAIL。把不合规的行贴出来。

下面这些颜色透明度必须仍在，并且同一行有 `token-exempt:`：

```bash
rg -n 'stamp\.opacity\(0\.14\)|stamp\.opacity\(0\.20\)|stamp\.opacity\(0\.16\)|ink\.opacity\(0\.05\)|ink\.opacity\(0\.06\)|ink\.opacity\(0\.04\)|muted\.opacity\(0\.65\)|muted\.opacity\(0\.85\)|stamp\.opacity\(0\.85\)|ink\.opacity\(0\.85\)|stamp\.opacity\(0\.05\)|muted\.opacity\(0\.4\)|rule\.opacity\(0\.35\)|stamp\.opacity\(0\.75\)|rule\.opacity\(0\.5\)|status\.pending\.opacity\(0\.12\)' AreaChain/Features/Tasks
```

`Divider()` 上的 `.opacity(0.35)`，以及 `TaskRow+Badges.swift` 里 `.opacity(isHovered || state.isSelected ? 1.0 : 0.65)`，是整块显隐，不是颜色。它们没有 `token-exempt:` 也算通过。不要把这两处算进失败。

### C. 没越界

```bash
# C1 其他模块零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Diary AreaChain/Features/Workspace AreaChain/Theme
git diff --cached --stat -- AreaChain/Features/MenuBar AreaChain/Features/Diary AreaChain/Features/Workspace AreaChain/Theme

# C2 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/TaskRowInteractionTests \
  --only-testing AreaChainTests/TaskRowBubbleTests \
  --only-testing AreaChainTests/BoardFilterBarTests \
  --only-testing AreaChainTests/WorkspaceRenderingTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P6 Tasks' .cursor/plans/design-system.md
rg -n 'P6 Tasks 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P6 Tasks 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A5 该换的已换 | ... | ... |
| B 小字号、圆体、等宽和未映射透明度仍在且有豁免 | ... | 不合规行 |
| C1–C2 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。C1 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P6 Tasks 验收：通过 / 不通过（<原因>）`。
