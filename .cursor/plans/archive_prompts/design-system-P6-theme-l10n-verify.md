# 任务：AreaChain 设计系统收敛 · 阶段 P6 Theme 双语 · 独立验收提示词

## 你是谁、怎么工作

你是**独立验收员**。另一个对话按 `.cursor/plans/design-system-P6-theme-l10n-execute.md` 把补全副标题、页脚和语法卡片的中文换成了本地化 key，并声称完成。你不相信汇报：自己重跑命令、自己看 diff，逐项打 PASS / FAIL / BLOCKED。

规则：
1. **只读**。不改源码和测试。唯一允许的写操作：最后在 `.cursor/plans/design-system.md` 第 8 节追加一行验收结论。
2. 每项必须亲自运行并粘贴原样输出。
3. 命令跑不起来 → BLOCKED。
4. 先读执行稿的「绝对不要做」。
5. 这一份不要求删除 `DaybookTheme`。文件还在 → 通过。文件被删了 → FAIL。

---

## 检查清单

### A. 界面中文换成了 key，筛选词还在

```bash
# A1 硬编码界面文案消失（预期零输出）
rg -n 'Text\("切换"\)|Text\("补全"\)|Text\("关闭"\)|Text\("填入试用"\)|Text\("全部标签"\)|title: "标签分类"|title: "四象限优先级"|: "标签",' \
  AreaChain/Domain/SyntaxAutocomplete.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift

# A2 显示用的是 key（预期各至少 1）
rg -c 'syntax.priority.p1' AreaChain/Domain/SyntaxAutocomplete.swift
rg -c 'syntax.time.morning' AreaChain/Domain/SyntaxAutocomplete.swift
rg -c 'syntax.footer.navigate' AreaChain/Theme/SyntaxAutocompleteView.swift
rg -c 'syntax.guide.try' AreaChain/Theme/SyntaxHelpCard.swift
rg -c 'syntax.preview.allTags' AreaChain/Theme/LiveComposerPreviewHeader.swift
rg -c 'syntax.preview.tagCount' AreaChain/Theme/LiveComposerPreviewHeader.swift

# A3 中文和英文筛选词还在代码里（预期各至少 1）
rg -n '重要且紧急 important urgent|早上 morning' AreaChain/Domain/SyntaxAutocomplete.swift
```

`syntax.guide.try` 应该至少 2。少一处 → FAIL。

范例正文必须还在，预期各至少 1。被翻译或删掉 → FAIL：

```bash
rg -n '写周报|修线上Bug|开晨会' AreaChain/Theme/SyntaxHelpCard.swift
```

### B. 字符串表中英都有，JSON 合法

```bash
python3 -c 'import json; json.load(open("AreaChain/Resources/Localizable.xcstrings")); print("JSON_OK")'
python3 - <<'PY'
import json
data = json.load(open("AreaChain/Resources/Localizable.xcstrings"))
keys = [
    "syntax.tag.label","syntax.priority.p1","syntax.priority.p2","syntax.priority.p3","syntax.priority.p4",
    "syntax.time.morning","syntax.time.noon","syntax.time.afternoon","syntax.time.evening","syntax.time.night",
    "syntax.time.hour","syntax.time.custom","syntax.footer.navigate","syntax.footer.complete","syntax.footer.dismiss",
    "syntax.guide.tag","syntax.guide.priority","syntax.guide.time","syntax.guide.diary","syntax.guide.note",
    "syntax.guide.try","syntax.guide.example","syntax.preview.allTags","syntax.preview.tagCount",
]
bad = []
for key in keys:
    locs = data["strings"].get(key, {}).get("localizations", {})
    en = locs.get("en", {}).get("stringUnit", {}).get("value", "")
    zh = locs.get("zh-Hans", {}).get("stringUnit", {}).get("value", "")
    if not en or not zh or en == zh:
        bad.append(f"{key} en={en!r} zh={zh!r}")
print("OK" if not bad else "BAD")
print("\n".join(bad))
PY
```

`syntax.preview.tagCount` 的英文必须含 `%lld`，中文必须含 `%lld`。否则 FAIL。

中英值完全相同 → FAIL。只有一种语言 → FAIL。

### C. 测试期望跟着改了，别的测试没被删

```bash
rg -n 'syntax.priority.p1|priorityAndTimeCandidatesStillMatchSpokenWords' AreaChainTests/Domain/SyntaxAutocompleteTests.swift
rg -n 'subtitle == "重要且紧急"' AreaChainTests
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'
```

`syntax.priority.p1` 和 `priorityAndTimeCandidatesStillMatchSpokenWords` 都必须在。旧的 `subtitle == "重要且紧急"` 必须是零输出。有 `@Test` 被删掉 → FAIL。

### D. 没删主题，也没改调色板

```bash
rg -n 'enum DaybookTheme' AreaChain/Theme/DaybookTheme.swift
git diff --stat -- AreaChain/Theme/DaybookPalette.swift AreaChain/Theme/DaybookTheme.swift
git diff --cached --stat -- AreaChain/Theme/DaybookPalette.swift AreaChain/Theme/DaybookTheme.swift
```

`enum DaybookTheme` 预期至少 1。调色板或 `DaybookTheme.swift` 有 diff → FAIL。

### E. 编译并跑测试

```bash
./scripts/build.sh test \
  --only-testing AreaChainTests/SyntaxAutocompleteTests \
  --only-testing AreaChainTests/InputSyntaxInteractionTests
echo "EXIT=$?"
python3 -B scripts/check_workflow.py; echo "WORKFLOW=$?"
```

`EXIT=0` 且 `WORKFLOW=0` → PASS。运行期间不要操作其他窗口。

### F. 计划状态

```bash
rg -n '\[x\] P6 Theme 双语' .cursor/plans/design-system.md
rg -n 'P6 Theme 双语完成' .cursor/plans/design-system.md
```

---

## 输出格式

```
## P6 Theme 双语验收报告

| 项 | 结果 | 证据 |
|---|---|---|
| A 界面 key 与筛选词 | ... | ... |
| B 字符串表中英齐全 | ... | ... |
| C 测试期望 | ... | ... |
| D DaybookTheme 仍在 | ... | ... |
| E 编译、测试、check_workflow | ... | EXIT=? |
| F 计划状态 | ... | ... |

## 结论
通过 / 不通过

## 整改清单（不通过时必填：文件 — 现在是什么 — 应该是什么）
```

结论规则：A、B、C、D、E 任一 FAIL 或 BLOCKED → 不通过。只有 F 的计划状态 FAIL → 通过，但写入整改清单。

最后在 `.cursor/plans/design-system.md` 第 8 节「决策记录」末尾追加：`- <日期> P6 Theme 双语验收：通过 / 不通过（<原因>）`。
