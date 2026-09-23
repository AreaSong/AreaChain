# 任务：AreaChain 设计系统收敛 · 阶段 P6 Theme 双语 · 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 只改下面点名的文件。
2. 每一处都按给出的原文替换。不要自己再找「类似的中文」去改。
3. 不 `git commit` / `git push` / 安装 / 发布。不要删测试。
4. 先读 `AGENTS.md`，再读本文。
5. 做完不宣布「通过」。验收按 `design-system-P6-theme-l10n-verify.md`。
6. **不要删除 `DaybookTheme`，不要改 `DaybookPalette.swift`，不要改颜色和字号。**

界面上已经用 `LocalizedStringKey` 显示副标题和卡片标题。这一份只把硬编码中文换成 key，并在 `Localizable.xcstrings` 里同时写上英文和简体中文。

筛选不能坏。用户输入 `重要` 仍要能筛出 p1 和 p2，输入 `urgent` 仍要能筛出 p1 和 p3，输入 `早上` 仍要能筛出 09:00。所以中文留在 `matchText` 里，显示用 key。

范例正文（`写周报 #工作`、`修线上Bug !p1`、`开晨会 @10:00` 这些演示句子）不要翻译，也不要拆开。

## 开始前必读

`AreaChain/Domain/SyntaxAutocomplete.swift` 里的 `priorityCandidates`、`timeCandidates`、`formatCustomTime`。

`AreaChain/Resources/Localizable.xcstrings` 里已有的 `"syntax.guide.title"` 条目，确认它后面是 `"syntax.section.input"`。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/SyntaxAutocompleteTests
```

---

## 步骤 1：`AreaChain/Domain/SyntaxAutocomplete.swift`

把

```swift
                    subtitle: context.isSearch ? "syntax.search.tag" : "标签",
```

换成

```swift
                    subtitle: context.isSearch ? "syntax.search.tag" : "syntax.tag.label",
```

把 `priorityCandidates` 整段换成下面这一段。函数签名和 `insertText` 不要改：

```swift
    private static func priorityCandidates(query: String) -> [SyntaxCandidate] {
        let definitions: [(code: String, subtitleKey: String, matchText: String)] = [
            ("p1", "syntax.priority.p1", "重要且紧急 important urgent"),
            ("p2", "syntax.priority.p2", "重要不紧急 important"),
            ("p3", "syntax.priority.p3", "紧急不重要 urgent"),
            ("p4", "syntax.priority.p4", "不重要不紧急 neither")
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matches = definitions.filter { item in
            guard !trimmed.isEmpty else { return true }
            return item.code.contains(trimmed) || item.matchText.lowercased().contains(trimmed)
        }

        return matches.map { item in
            SyntaxCandidate(
                id: "priority_\(item.code)",
                title: "!\(item.code)",
                subtitle: item.subtitleKey,
                insertText: "!\(item.code) ",
                kind: .priority
            )
        }
    }
```

把 `timeCandidates` 整段换成下面这一段。自定义时刻仍用 `custom.label`，因为下一步会让它返回 key：

```swift
    private static func timeCandidates(query: String) -> [SyntaxCandidate] {
        let presets: [(time: String, subtitleKey: String, matchText: String)] = [
            ("09:00", "syntax.time.morning", "早上 morning"),
            ("12:00", "syntax.time.noon", "中午 noon"),
            ("15:00", "syntax.time.afternoon", "下午 afternoon"),
            ("18:00", "syntax.time.evening", "傍晚 evening"),
            ("21:00", "syntax.time.night", "晚上 night")
        ]

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let needle = trimmed.lowercased()
        var list: [SyntaxCandidate] = []

        if !trimmed.isEmpty, let custom = formatCustomTime(trimmed) {
            list.append(
                SyntaxCandidate(
                    id: "time_custom_\(custom.time)",
                    title: "@\(custom.time)",
                    subtitle: custom.label,
                    insertText: "@\(custom.time) ",
                    kind: .time,
                    isCreation: true
                )
            )
        }

        let filtered = presets.filter { item in
            guard !trimmed.isEmpty else { return true }
            return item.time.contains(trimmed) || item.matchText.lowercased().contains(needle)
        }

        for item in filtered {
            if !list.contains(where: { $0.title == "@\(item.time)" }) {
                list.append(
                    SyntaxCandidate(
                        id: "time_\(item.time)",
                        title: "@\(item.time)",
                        subtitle: item.subtitleKey,
                        insertText: "@\(item.time) ",
                        kind: .time
                    )
                )
            }
        }

        return list
    }
```

`formatCustomTime` 里两处返回值：

```swift
            return (formatted, "整点")
```

换成

```swift
            return (formatted, "syntax.time.hour")
```

```swift
                return (formatted, "自定义时刻")
```

换成

```swift
                return (formatted, "syntax.time.custom")
```

---

## 步骤 2：`AreaChain/Theme/SyntaxAutocompleteView.swift`

三处页脚文字：

```swift
                Text("切换")
```

换成

```swift
                Text("syntax.footer.navigate")
```

```swift
                Text("补全")
```

换成

```swift
                Text("syntax.footer.complete")
```

```swift
                Text("关闭")
```

换成

```swift
                Text("syntax.footer.dismiss")
```

`↑↓`、`⇥ / ↵`、`Esc` 不要改。字号和 `token-exempt` 注释不要改。

---

## 步骤 3：`AreaChain/Theme/SyntaxHelpCard.swift`

五个标题：

```swift
                title: "标签分类",
```

换成

```swift
                title: "syntax.guide.tag",
```

```swift
                title: "四象限优先级",
```

换成

```swift
                title: "syntax.guide.priority",
```

```swift
                    title: "时刻提醒",
```

换成

```swift
                    title: "syntax.guide.time",
```

```swift
                    title: "直接存入手记",
```

换成

```swift
                    title: "syntax.guide.diary",
```

```swift
                    title: "换行输入备注",
```

换成

```swift
                    title: "syntax.guide.note",
```

两处

```swift
                            Text("填入试用")
```

和底部缩进不同的那一处 `Text("填入试用")`，字符串都换成 `syntax.guide.try`。前面的空格不要动。两处都要换。

```swift
                    Text("综合范例：全属性完整待办 · 顺序自由，点击一键试用")
```

换成

```swift
                    Text("syntax.guide.example")
```

`exampleSnippet` 和 `exampleText` 里的 `写周报`、`修线上Bug`、`开晨会`、`买牛奶`、`整理书架` 不要改。

---

## 步骤 4：`AreaChain/Theme/LiveComposerPreviewHeader.swift`

在

```swift
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
```

下面加一行：

```swift
    @Environment(\.locale) private var locale
```

```swift
                Text("全部标签")
```

换成

```swift
                Text("syntax.preview.allTags")
```

```swift
                    .help("共 \(previewTags.count) 个标签")
```

换成

```swift
                    .help(L10n.format("syntax.preview.tagCount", locale: locale, previewTags.count))
```

---

## 步骤 5：`AreaChain/Resources/Localizable.xcstrings`

在 `"syntax.guide.title"` 这个条目结束、`"syntax.section.input"` 开始之前，插入下面整段。不要改已有条目。

```json
    "syntax.footer.complete": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Complete" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "补全" } }
      }
    },
    "syntax.footer.dismiss": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Close" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "关闭" } }
      }
    },
    "syntax.footer.navigate": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Move" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "切换" } }
      }
    },
    "syntax.guide.diary": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Save as diary" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "直接存入手记" } }
      }
    },
    "syntax.guide.example": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Full example · any order, click to try" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "综合范例：全属性完整待办 · 顺序自由，点击一键试用" } }
      }
    },
    "syntax.guide.note": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Note on the next line" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "换行输入备注" } }
      }
    },
    "syntax.guide.priority": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Priority" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "四象限优先级" } }
      }
    },
    "syntax.guide.tag": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Tags" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "标签分类" } }
      }
    },
    "syntax.guide.time": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Reminder" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "时刻提醒" } }
      }
    },
    "syntax.guide.try": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Try it" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "填入试用" } }
      }
    },
    "syntax.preview.allTags": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "All tags" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "全部标签" } }
      }
    },
    "syntax.preview.tagCount": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "%lld tags" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "共 %lld 个标签" } }
      }
    },
    "syntax.priority.p1": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Important and urgent" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "重要且紧急" } }
      }
    },
    "syntax.priority.p2": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Important, not urgent" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "重要不紧急" } }
      }
    },
    "syntax.priority.p3": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Urgent, not important" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "紧急不重要" } }
      }
    },
    "syntax.priority.p4": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Neither" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "不重要不紧急" } }
      }
    },
    "syntax.tag.label": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Tag" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "标签" } }
      }
    },
    "syntax.time.afternoon": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Afternoon" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "下午" } }
      }
    },
    "syntax.time.custom": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Custom time" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "自定义时刻" } }
      }
    },
    "syntax.time.evening": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Evening" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "傍晚" } }
      }
    },
    "syntax.time.hour": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "On the hour" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "整点" } }
      }
    },
    "syntax.time.morning": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Morning" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "早上" } }
      }
    },
    "syntax.time.night": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Night" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "晚上" } }
      }
    },
    "syntax.time.noon": {
      "extractionState": "manual",
      "localizations": {
        "en": { "stringUnit": { "state": "translated", "value": "Noon" } },
        "zh-Hans": { "stringUnit": { "state": "translated", "value": "中午" } }
      }
    },
```

插入后用 `python3 -c 'import json; json.load(open("AreaChain/Resources/Localizable.xcstrings"))'` 确认文件仍是合法 JSON。不合法就停下来，不要继续。

---

## 步骤 6：`AreaChainTests/Domain/SyntaxAutocompleteTests.swift`

把四行期望改成 key。不要删这个测试：

```swift
        #expect(candidates[0].subtitle == "重要且紧急")
        #expect(candidates[1].subtitle == "重要不紧急")
        #expect(candidates[2].subtitle == "紧急不重要")
        #expect(candidates[3].subtitle == "不重要不紧急")
```

换成

```swift
        #expect(candidates[0].subtitle == "syntax.priority.p1")
        #expect(candidates[1].subtitle == "syntax.priority.p2")
        #expect(candidates[2].subtitle == "syntax.priority.p3")
        #expect(candidates[3].subtitle == "syntax.priority.p4")
```

在这个测试函数后面加一个新测试，不要改别的测试：

```swift
    @Test func priorityAndTimeCandidatesStillMatchSpokenWords() {
        let important = SyntaxTrigger(kind: .priority, query: "重要", range: NSRange(location: 0, length: 2))
        #expect(SyntaxAutocompleteEngine.candidates(for: important).map(\.title) == ["!p1", "!p2"])

        let urgent = SyntaxTrigger(kind: .priority, query: "urgent", range: NSRange(location: 0, length: 6))
        #expect(SyntaxAutocompleteEngine.candidates(for: urgent).map(\.title) == ["!p1", "!p3"])

        let morning = SyntaxTrigger(kind: .time, query: "早上", range: NSRange(location: 0, length: 2))
        let morningHits = SyntaxAutocompleteEngine.candidates(for: morning)
        #expect(morningHits.map(\.title) == ["@09:00"])
        #expect(morningHits.first?.subtitle == "syntax.time.morning")
    }
```

---

## 最终验证

```bash
# 1. JSON 合法
python3 -c 'import json; json.load(open("AreaChain/Resources/Localizable.xcstrings"))'

# 2. 界面硬编码中文已换成 key（预期零输出）
rg -n 'Text\("切换"\)|Text\("补全"\)|Text\("关闭"\)|Text\("填入试用"\)|Text\("全部标签"\)|title: "标签分类"|subtitle: context.isSearch \? "syntax.search.tag" : "标签"' \
  AreaChain/Domain/SyntaxAutocomplete.swift \
  AreaChain/Theme/SyntaxAutocompleteView.swift \
  AreaChain/Theme/SyntaxHelpCard.swift \
  AreaChain/Theme/LiveComposerPreviewHeader.swift

# 3. 新 key 在字符串表里中英都有（每个 key 的 en 和 zh-Hans 都要出现）
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
missing = []
for key in keys:
    locs = data["strings"].get(key, {}).get("localizations", {})
    if "en" not in locs or "zh-Hans" not in locs:
        missing.append(key)
print("MISSING" if missing else "OK")
print("\n".join(missing))
PY

# 4. DaybookTheme 还在（预期至少 1）
rg -c 'enum DaybookTheme' AreaChain/Theme/DaybookTheme.swift

# 5. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/SyntaxAutocompleteTests \
  --only-testing AreaChainTests/InputSyntaxInteractionTests

# 6. 工作流检查
python3 -B scripts/check_workflow.py
```

第 5 条若失败，贴出失败信息停下问我。不要为了变绿去改期望以外的测试。

## 汇报格式

```
## P6 Theme 双语完成汇报
### 修改文件（路径 — 换了什么）
### 验证输出（1–6 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 Theme 双语` 改成 `- [x]`，决策记录追加 `- <日期> P6 Theme 双语完成：<一句话>`。

## 绝对不要做

- 不要删除 `DaybookTheme.swift`，不要改 `DaybookPalette.swift`。
- 不要翻译 `写周报`、`修线上Bug`、`开晨会` 这些范例正文。
- 不要把 `matchText` 里的中文删掉。
- 不要只写英文或只写中文。
- 不要 commit。
