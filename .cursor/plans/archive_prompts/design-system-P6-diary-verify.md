# 任务：AreaChain 设计系统收敛 · 阶段 P6 Diary · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P6-diary-execute.md` 执行了手记模块清扫并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

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
rg -n '\.font\(\.system\(size:' AreaChain/Features/Diary | rg -v 'token-exempt:'

# A2 点名圆角（预期零输出）
rg -n 'cornerRadius:\s*(3\.5|2\.5)\b' AreaChain/Features/Diary

# A3 密码徽章不再写 Color.red（预期零输出）
rg -n 'Color\.red' AreaChain/Features/Diary

# A4 已点名透明度（预期零输出）
rg -n 'stamp\.opacity\(0\.35\)|stamp\.opacity\(0\.12\)' AreaChain/Features/Diary

# A5 新写法确实出现（预期各至少 1）
rg -c 'DaybookPalette\.status\.danger' AreaChain/Features/Diary/DiaryCardComponents.swift
rg -c 'DaybookPalette\.accent\.border' AreaChain/Features/Diary/DiaryNoteCard.swift
rg -c 'DaybookPalette\.accent\.fill' AreaChain/Features/Diary/DiarySummaryRow.swift
rg -c 'DaybookType\.caption' AreaChain/Features/Diary/DiaryQuickComposerView.swift
rg -c 'DaybookRadius\.xs' AreaChain/Features/Diary/DiaryNoteCard.swift
rg -c 'DaybookRadius\.xxs' AreaChain/Features/Diary/DiarySummaryRow.swift
```

### B. 不该放大的还在，而且有豁免注释

```bash
rg -n 'size: 8\.5|size: 9\.5|size: 14|size: 26|design: \.rounded|design: \.monospaced' AreaChain/Features/Diary
```

每一行都必须含 `token-exempt:`。少一行豁免，或 8.5 / 26 被改成了 `DaybookType` → FAIL。把不合规的行贴出来。9.5 如果已经换成 `DaybookType.micro`，这一条不会再出现，那是对的，不要算失败。

下面这些颜色透明度必须仍在，并且同一行有 `token-exempt:`：

```bash
rg -n 'hoverFill\.opacity\(0\.5\)|muted\.opacity\(0\.8\)|muted\.opacity\(0\.4\)|color\.opacity\(0\.12\)|color\.opacity\(0\.25\)|stamp\.opacity\(0\.28\)|muted\.opacity\(0\.65\)|stamp\.opacity\(0\.16\)|ink\.opacity\(0\.04\)|status\.danger\.opacity\(0\.85\)|status\.danger\.opacity\(0\.10\)' AreaChain/Features/Diary
```

标签色必须仍是原来的三个颜色，并且同一行有 `token-exempt:`。变成 `DiaryPreset` 或 `systemRed` → FAIL：

```bash
rg -n 'return \.red|return \.orange|return \.blue' AreaChain/Features/Diary/DiaryNoteCard.swift
```

预期正好 3 行。

这两处是按钮显隐，不是颜色。没有 `token-exempt:` 也算通过：

- `DiaryNoteCard.swift` 的 `.opacity(isHovered || isPasswordType || entry.isPinned ? 1.0 : 0.0)`
- `DiarySummaryRow.swift` 的 `.opacity((isHovered || isSelected || isHighlighted) && !isCommandPressed ? 1.0 : 0.0)`

`.animation(.easeInOut` 和 `withAnimation(.snappy)` 必须还在。被换成 `DaybookMotion` → FAIL。

```bash
rg -n 'easeInOut\(duration: 0\.2\)|easeInOut\(duration: 0\.15\)|withAnimation\(\.snappy\)' AreaChain/Features/Diary
```

预期正好 5 行：状态图标两处 `duration: 0.2`，卡片悬停一处 `duration: 0.15`，复制反馈两处 `withAnimation(.snappy)`。少一行就是被改掉了。

### C. 没越界

```bash
# C1 其他模块零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Workspace AreaChain/Theme
git diff --cached --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Workspace AreaChain/Theme

# C2 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

`DaybookPalette.swift` 出现在 Theme 的 diff 里 → FAIL。

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/DiaryComposerInteractionTests \
  --only-testing AreaChainTests/DiaryPrivacyTests \
  --only-testing AreaChainTests/PrivacyRenderingTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P6 Diary' .cursor/plans/design-system.md
rg -n 'P6 Diary 完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P6 Diary 验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A5 该换的已换 | ... | ... |
| B 小字号、圆体、等宽、26pt、未映射透明度和标签色仍在且有豁免 | ... | 不合规行 |
| C1–C2 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。C1 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P6 Diary 验收：通过 / 不通过（<原因>）`。
