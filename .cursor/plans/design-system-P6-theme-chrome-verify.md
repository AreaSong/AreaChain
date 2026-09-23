# 任务：AreaChain 设计系统收敛 · 阶段 P6 Theme 共享控件 · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P6-theme-chrome-execute.md` 执行了 Theme 共享控件清扫并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读执行稿的「为什么有的换、有的不换」和「绝对不要做」。
5. 字号检查必须是 `.font(.system(size:` 后面紧跟数字。不要把 `size: fontSize` 或视图的 `size:` 当成字号。

只检查这 9 个文件：

```text
AreaChain/Theme/CommandReturnButton.swift
AreaChain/Theme/DaybookSegmentedBar.swift
AreaChain/Theme/DaybookSectionHeader.swift
AreaChain/Theme/QuadrantMiniMark.swift
AreaChain/Theme/DaybookChrome.swift
AreaChain/Theme/DaybookPage.swift
AreaChain/Theme/CaptureAttributesView.swift
AreaChain/Theme/LiveDiaryComposerPreview.swift
AreaChain/Theme/DaybookRowBubbles.swift
```

---

## 检查清单

### A. 该换的已经换了

```bash
# A1 未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:\s*[0-9]' \
  AreaChain/Theme/CommandReturnButton.swift \
  AreaChain/Theme/DaybookSegmentedBar.swift \
  AreaChain/Theme/DaybookSectionHeader.swift \
  AreaChain/Theme/QuadrantMiniMark.swift \
  AreaChain/Theme/DaybookChrome.swift \
  AreaChain/Theme/DaybookPage.swift \
  AreaChain/Theme/CaptureAttributesView.swift \
  AreaChain/Theme/LiveDiaryComposerPreview.swift \
  AreaChain/Theme/DaybookRowBubbles.swift \
  | rg -v 'token-exempt:'

# A2 未豁免的字面圆角（预期零输出）
rg -n 'cornerRadius:\s*[0-9]' \
  AreaChain/Theme/CommandReturnButton.swift \
  AreaChain/Theme/DaybookSegmentedBar.swift \
  AreaChain/Theme/DaybookSectionHeader.swift \
  AreaChain/Theme/QuadrantMiniMark.swift \
  AreaChain/Theme/DaybookChrome.swift \
  AreaChain/Theme/DaybookPage.swift \
  AreaChain/Theme/CaptureAttributesView.swift \
  AreaChain/Theme/LiveDiaryComposerPreview.swift \
  AreaChain/Theme/DaybookRowBubbles.swift \
  | rg -v 'token-exempt:'

# A3 新写法确实出现（预期各至少 1）
rg -c 'DaybookType\.badge\.weight\(\.semibold\)' AreaChain/Theme/CommandReturnButton.swift
rg -c 'DaybookRadius\.regular' AreaChain/Theme/DaybookSegmentedBar.swift
rg -c 'DaybookRadius\.xs' AreaChain/Theme/QuadrantMiniMark.swift
rg -c 'DaybookPalette\.accent\.border' AreaChain/Theme/CaptureAttributesView.swift
rg -c 'DaybookPalette\.accent\.fill' AreaChain/Theme/LiveDiaryComposerPreview.swift
rg -c 'DaybookRadius\.small' AreaChain/Theme/DaybookRowBubbles.swift
```

`DaybookRadius.small` 在 `DaybookRowBubbles.swift` 里应该至少 3。少了 → FAIL。

### B. 不该改掉的还在，而且该豁免的有注释

```bash
rg -n '\.font\(\.system\(size:\s*[0-9]|cornerRadius:\s*7' \
  AreaChain/Theme/DaybookSectionHeader.swift \
  AreaChain/Theme/QuadrantMiniMark.swift \
  AreaChain/Theme/DaybookChrome.swift \
  AreaChain/Theme/DaybookRowBubbles.swift
```

每一行都必须含 `token-exempt:`。28pt 被换成 `DaybookType.display`，或 7pt 圆角被换成 `DaybookRadius` → FAIL。

下面这些必须仍在，并且同一行有 `token-exempt:`：

```bash
rg -n 'ink\.opacity\(0\.06\)|stamp\.opacity\(0\.85\)|ink\.opacity\(0\.88\)|paper\.opacity\(0\.94\)|muted\.opacity\(0\.8\)|stamp\.opacity\(state\.showsAttributes|muted\.opacity\(0\.40\)|rule\.opacity\(0\.7\)|muted\.opacity\(0\.65\)|ink\.opacity\(0\.04\)|stamp\.opacity\(0\.7\)|rule\.opacity\(0\.9\)|themeColor\.opacity' \
  AreaChain/Theme/DaybookSegmentedBar.swift \
  AreaChain/Theme/DaybookChrome.swift \
  AreaChain/Theme/DaybookPage.swift \
  AreaChain/Theme/CaptureAttributesView.swift \
  AreaChain/Theme/LiveDiaryComposerPreview.swift \
  AreaChain/Theme/DaybookRowBubbles.swift \
  AreaChain/Theme/QuadrantMiniMark.swift
```

象限色必须还在：

```bash
rg -n 'slot\.themeColor|slot\.themeFill' AreaChain/Theme/QuadrantMiniMark.swift
```

预期各至少 1。

动画必须仍是原来的 spring / easeInOut。被换成 `DaybookMotion` → FAIL：

```bash
rg -n '\.spring\(response:|\.easeInOut\(duration: 0\.2\)' \
  AreaChain/Theme/DaybookSegmentedBar.swift \
  AreaChain/Theme/DaybookRowBubbles.swift
```

预期至少 5 行：分段栏 1 处 spring，两个气泡各 1 处 spring 和 1 处 easeInOut。

`.buttonStyle(.plain)` 的每一行都必须仍含 `// control:`：

```bash
rg -n 'buttonStyle\(\.plain\)' \
  AreaChain/Theme/DaybookSegmentedBar.swift \
  AreaChain/Theme/CaptureAttributesView.swift
```

### C. 没越界

```bash
# C1 其他目录零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Features AreaChain/Domain AreaChain/Services
git diff --cached --stat -- AreaChain/Features AreaChain/Domain AreaChain/Services

# C2 点名不要改的 Theme 文件零 diff（预期零输出；两条都跑）
git diff --stat -- \
  AreaChain/Theme/DaybookTheme.swift \
  AreaChain/Theme/DaybookPalette.swift \
  AreaChain/Theme/DaybookElevation.swift \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift
git diff --cached --stat -- \
  AreaChain/Theme/DaybookTheme.swift \
  AreaChain/Theme/DaybookPalette.swift \
  AreaChain/Theme/DaybookElevation.swift \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift

# C3 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/TaskRowBubbleTests \
  --only-testing AreaChainTests/SyntaxOverlayPlacementTests \
  --only-testing AreaChainTests/QuadrantLayoutTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P6 Theme 共享控件' .cursor/plans/design-system.md
rg -n 'P6 Theme 共享控件完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P6 Theme 共享控件验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A3 该换的已换 | ... | ... |
| B 圆体、小字号、7pt 圆角、28pt、未映射透明度和动画仍在 | ... | 不合规行 |
| C1–C3 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。C1 或 C2 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P6 Theme 共享控件验收：通过 / 不通过（<原因>）`。
