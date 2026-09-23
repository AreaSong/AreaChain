# 任务：AreaChain 设计系统收敛 · 阶段 P6 Theme 语法表面 · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P6-theme-syntax-execute.md` 执行了语法卡片、自动补全和实时预览头的清扫并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读执行稿的「为什么有的换、有的不换」和「绝对不要做」。
5. 字号检查必须是 `.font(.system(size:` 后面紧跟数字。

只检查这三个文件：

```text
AreaChain/Theme/SyntaxHelpCard.swift
AreaChain/Theme/SyntaxAutocompleteView.swift
AreaChain/Theme/LiveComposerPreviewHeader.swift
```

---

## 检查清单

### A. 该换的已经换了

```bash
# A1 未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:\s*[0-9]' \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift \
  | rg -v 'token-exempt:'

# A2 未豁免的字面圆角（预期零输出）
rg -n 'cornerRadius:\s*[0-9]' \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift \
  | rg -v 'token-exempt:'

# A3 Color.orange 消失（预期零输出）
rg -n 'Color\.orange' AreaChain/Theme/SyntaxHelpCard.swift

# A4 新写法确实出现（预期各至少 1）
rg -c 'DaybookPalette\.status\.pending' AreaChain/Theme/SyntaxHelpCard.swift
rg -c 'DaybookType\.kbd' AreaChain/Theme/SyntaxAutocompleteView.swift
rg -c 'DaybookPalette\.accent\.fill' AreaChain/Theme/SyntaxAutocompleteView.swift
rg -c 'DaybookPalette\.text\.tertiary' AreaChain/Theme/LiveComposerPreviewHeader.swift
rg -c 'DaybookRadius\.regular' AreaChain/Theme/LiveComposerPreviewHeader.swift
```

`DaybookType.kbd` 在自动补全里应该至少 3。`DaybookRadius.regular` 在实时预览头里应该至少 4。少了 → FAIL。

### B. 不该改掉的还在，而且该豁免的有注释

剩下的字面字号和 5pt 圆角，每一行都必须含 `token-exempt:`：

```bash
rg -n '\.font\(\.system\(size:\s*[0-9]|cornerRadius:\s*5' \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift
```

10.5pt 等宽被收成 `DaybookType.kbd`，或 5pt 圆角被收成 `DaybookRadius` → FAIL。

下面这些必须仍在，并且同一行有 `token-exempt:`：

```bash
rg -n 'systemIndigo|status\.pending\.opacity\(0\.9\)|color\.opacity\(0\.14\)|stamp\.opacity\(0\.06\)|rule\.opacity\(0\.6\)|rule\.opacity\(0\.7\)|rule\.opacity\(0\.8\)|ink\.opacity\(0\.06\)|ink\.opacity\(0\.02\)|ink\.opacity\(0\.04\)|muted\.opacity\(0\.8\)|rule\.opacity\(0\.4\)' \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift
```

`systemIndigo` 预期至少 4 行，并且颜色没有被换成别的令牌。

中文必须原样还在。被改成 key 或英文 → FAIL：

```bash
rg -n '填入试用|标签分类|综合范例' AreaChain/Theme/SyntaxHelpCard.swift
rg -n 'Text\("切换"\)|Text\("补全"\)|Text\("关闭"\)' AreaChain/Theme/SyntaxAutocompleteView.swift
rg -n '全部标签' AreaChain/Theme/LiveComposerPreviewHeader.swift
```

`填入试用` 预期至少 2。`切换`、`补全`、`关闭`、`全部标签`、`标签分类`、`综合范例` 各至少 1。

`Circle()` 必须还在实时预览头里，预期至少 1：

```bash
rg -n 'Circle\(\)' AreaChain/Theme/LiveComposerPreviewHeader.swift
```

`.buttonStyle(.plain)` 的每一行都必须仍含 `// control:`：

```bash
rg -n 'buttonStyle\(\.plain\)' AreaChain/Theme/SyntaxHelpCard.swift
```

### C. 没越界

```bash
# C1 其他目录零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Features AreaChain/Domain AreaChain/Services AreaChain/Resources
git diff --cached --stat -- AreaChain/Features AreaChain/Domain AreaChain/Services AreaChain/Resources

# C2 DaybookTheme 和 DaybookPalette 零 diff（预期零输出；两条都跑）
git diff --stat -- AreaChain/Theme/DaybookTheme.swift AreaChain/Theme/DaybookPalette.swift
git diff --cached --stat -- AreaChain/Theme/DaybookTheme.swift AreaChain/Theme/DaybookPalette.swift

# C3 测试没有被删（预期零输出；两条都跑）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

### D. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/SyntaxAutocompleteTests \
  --only-testing AreaChainTests/SyntaxOverlayPlacementTests \
  --only-testing AreaChainTests/InputSyntaxInteractionTests
echo "EXIT=$?"
```

`EXIT=0` → PASS；非 0 → FAIL，贴最后 60 行。运行期间不要操作其他窗口。

### E. 工作流与计划状态

```bash
python3 -B scripts/check_workflow.py; echo "EXIT=$?"
rg -n '\[x\] P6 Theme 语法卡片 / 自动补全 / 实时预览' .cursor/plans/design-system.md
rg -n 'P6 Theme 语法表面完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P6 Theme 语法表面验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A1–A4 该换的已换 | ... | ... |
| B 等宽、5pt 圆角、靛蓝、中文和圆圈仍在 | ... | 不合规行 |
| C1–C3 未越界 | ... | ... |
| D 编译与测试 | ... | EXIT=? |
| E check_workflow 与计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D 任一 FAIL 或 BLOCKED → 不通过。C1 或 C2 有 diff → 不通过。只有 E 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P6 Theme 语法表面验收：通过 / 不通过（<原因>）`。
