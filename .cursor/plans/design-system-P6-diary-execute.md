# 任务：AreaChain 设计系统收敛 · 阶段 P6 Diary（颜色、字号、圆角）· 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 只改 `AreaChain/Features/Diary/` 里下面点名的文件。
2. 每一处都按给出的原文替换。不要看了规则自己去文件里找「类似的」再改。
3. 不 `git commit` / `git push` / 安装 / 发布；不删测试、不注释测试。
4. 先读 `AGENTS.md`，再读本文。不要扫 MenuBar、Tasks、Workspace、Theme。
5. 做完不宣布「通过」。验收按 `design-system-P6-diary-verify.md`。
6. 小于 9pt 的图标、圆体、等宽字体，保持原字号。只在该行末尾加给出的 `// token-exempt:`，注释原文不要改。
7. 本阶段不删 `DaybookTheme`。手记里继续写 `DaybookTheme.ink`、`muted`、`stamp`、`rule`、`destructive`、`hoverFill`。总计划里「模块目录下 `DaybookTheme` 为空」要等 P6 Theme 做完才要求。
8. 同一文件里有多处相同原文时，按该步骤从上到下替换。先换更长的那一段，再换剩下的短行，否则短行先被换掉，长段就对不上。
9. 不改动画。`.animation(.easeInOut(duration: 0.2)`、`.animation(.easeInOut(duration: 0.15)`、`withAnimation(.snappy)` 保持原样。
10. `.buttonStyle(.bordered)` 和 `.buttonStyle(.borderedProminent)` 保持原样。

## 为什么有的换、有的不换

`DaybookType.micro` 是 9pt medium，`badge` 是 10pt medium，`caption` 是 11pt medium，`display` 是 26pt light。差 0.5pt 以内才换字号。没有写 weight 的字面字号，换成对应令牌（令牌自带的字重就是本阶段接受的结果，任务模块已经这样换过）。

`display` 不要用。锁图标现在是 26pt 默认字重，`DaybookType.display` 是 light，换过去会变细。

8.5pt 不要放成 `DaybookType.kbd`。`kbd` 是 8.5pt semibold 等宽，手记里的 8.5 是普通图标。

颜色只换有现成令牌的：`stamp` 的 35% 是 `DaybookPalette.accent.border`，`stamp` 的 12% 是 `DaybookPalette.accent.fill`，密码徽章上的 `Color.red` 换成 `DaybookPalette.status.danger`。透明度 85% 和 10% 没有令牌，数字留下并写豁免。

`DiaryTagChrome` 里的 `.red`、`.orange`、`.blue` 不要换成 `DaybookPalette.diaryPreset`。这个函数还被菜单栏、任务筛选、看板调用。预置色是 `systemRed` / `systemOrange` / `systemBlue`，和 `Color.red` / `.orange` / `.blue` 不是同一个颜色。只加豁免注释。

标签药丸上的 `color.opacity(0.12)` 和 `color.opacity(0.25)` 的底色是标签自己的颜色，不是印章色。不要换成 `accent.fill`。

圆角：3.5 收到 `DaybookRadius.xs`（4），2.5 就是 `DaybookRadius.xxs`。`lineWidth` 的数字不要改。

## 开始前必读

`AreaChain/Theme/DaybookTokens.swift` 里的 `DaybookType` 和 `DaybookRadius`。确认 `micro` 是 9、`badge` 是 10、`caption` 是 11、`xs` 是 4、`xxs` 是 2.5。`display` 是 26pt light。

基线（必须绿）：

```bash
./scripts/build.sh test --only-testing AreaChainTests/DiarySummaryRowTests --only-testing AreaChainTests/DiaryComposerInteractionTests
```

---

## 步骤 1：`DiaryWindowView.swift`

把

```swift
                Image(systemName: "lock.shield").font(.system(size: 26))
```

换成

```swift
                Image(systemName: "lock.shield").font(.system(size: 26)) // token-exempt: display 令牌是 26pt light，这处是默认字重
```

---

## 步骤 2：`DiaryQuickComposerView.swift`

把

```swift
                .fill(DaybookTheme.hoverFill.opacity(0.5)))
```

换成

```swift
                .fill(DaybookTheme.hoverFill.opacity(0.5))) // token-exempt: 悬停底 50% 没有对应令牌
```

把

```swift
            return DaybookTheme.muted.opacity(0.8)
```

换成

```swift
            return DaybookTheme.muted.opacity(0.8) // token-exempt: 80% 次要色没有对应令牌
```

把

```swift
            .font(.system(size: 11.5, weight: .semibold))
```

换成

```swift
            .font(DaybookType.caption.weight(.semibold))
```

把

```swift
                .font(.system(size: 11))
```

换成

```swift
                .font(DaybookType.caption)
```

这一处在标签图标上。同文件第 130、131 行的 `.animation(.easeInOut(duration: 0.2)` 不要改。

---

## 步骤 3：`DiaryPage.swift`

把

```swift
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
```

换成

```swift
                        .font(.system(size: 9.5, weight: .bold, design: .rounded)) // token-exempt: 筛选计数用圆体
```

把

```swift
                .foregroundStyle(DaybookTheme.muted.opacity(0.4))
```

换成

```swift
                .foregroundStyle(DaybookTheme.muted.opacity(0.4)) // token-exempt: 40% 次要色没有对应令牌
```

---

## 步骤 4：`DiaryNoteCard.swift`

`DiaryTagChrome` 三行颜色只加注释，不要改颜色：

```swift
        if DiaryMemoTags.isPasswordName(name) { return .red }
        if name == DiaryMemoTags.idea { return .orange }
        if name == DiaryMemoTags.journal { return .blue }
```

换成

```swift
        if DiaryMemoTags.isPasswordName(name) { return .red } // token-exempt: 菜单栏和筛选共用，systemRed 不是同一个红
        if name == DiaryMemoTags.idea { return .orange } // token-exempt: 菜单栏和筛选共用，systemOrange 不是同一个橙
        if name == DiaryMemoTags.journal { return .blue } // token-exempt: 菜单栏和筛选共用，systemBlue 不是同一个蓝
```

`return DaybookTheme.stamp` 不要动。

标签药丸整段一起换。先换这一段，再换别的圆角：

```swift
            .font(.system(size: 9.5, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(color.opacity(0.12))
            )
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
            )
```

换成

```swift
            .font(DaybookType.micro.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .fill(color.opacity(0.12)) // token-exempt: 标签色 12% 底不是印章色
            )
            .foregroundStyle(color)
            .overlay(
                RoundedRectangle(cornerRadius: DaybookRadius.xs, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.5) // token-exempt: 标签色 25% 描边没有对应令牌
            )
```

置顶描边。现在这行已经有一句旧注释，整行换掉：

```swift
                    .strokeBorder(DaybookTheme.stamp.opacity(0.35), lineWidth: 1.2) // token-exempt: 置顶手记的第三态描边，表面选中态留给高亮
```

换成

```swift
                    .strokeBorder(DaybookPalette.accent.border, lineWidth: 1.2) // 置顶手记的第三态描边，表面选中态留给高亮
```

加标签菜单：

```swift
                    .font(.system(size: 8.5, weight: .bold))
```

换成

```swift
                    .font(.system(size: 8.5, weight: .bold)) // token-exempt: 小于 9pt 的加号，kbd 是等宽
```

只改 `DiaryNoteCard.swift`。`DiaryCardComponents.swift` 里还有一处相同字号，留给步骤 6：

```swift
                        .font(.system(size: 10, weight: .medium))
```

换成

```swift
                        .font(DaybookType.badge.weight(.medium))
```

第 136 行 `.animation(.easeInOut(duration: 0.15)` 和第 242 行 `.opacity(isHovered || isPasswordType || entry.isPinned ? 1.0 : 0.0)` 不要改。第 255、257 行 `withAnimation(.snappy)` 不要改。

---

## 步骤 5：`DiarySummaryRow.swift`

置顶描边没有 35% 令牌，只加注释：

```swift
                        ? DaybookTheme.stamp.opacity(0.28)
```

换成

```swift
                        ? DaybookTheme.stamp.opacity(0.28) // token-exempt: 28% 印章色没有对应令牌
```

备注图标，两行一起换：

```swift
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(hasNoteCopied ? DaybookTheme.stamp : (isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65)))
```

换成

```swift
            .font(DaybookType.micro.weight(.medium))
            .foregroundStyle(hasNoteCopied ? DaybookTheme.stamp : (isNoteHovered ? DaybookTheme.stamp : DaybookTheme.muted.opacity(0.65))) // token-exempt: 65% 次要色没有对应令牌
```

圆角和底色一起换：

```swift
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(hasNoteCopied ? DaybookTheme.stamp.opacity(0.16) : (isNoteHovered ? DaybookTheme.stamp.opacity(0.12) : DaybookTheme.ink.opacity(0.04)))
```

换成

```swift
                RoundedRectangle(cornerRadius: DaybookRadius.xxs, style: .continuous)
                    .fill(hasNoteCopied ? DaybookTheme.stamp.opacity(0.16) : (isNoteHovered ? DaybookPalette.accent.fill : DaybookTheme.ink.opacity(0.04))) // token-exempt: 16% 与 4% 没有对应令牌
```

复制按钮和更多菜单两处相同，都换：

```swift
                .font(.system(size: 11, weight: .semibold))
```

换成

```swift
                .font(DaybookType.caption.weight(.semibold))
```

元数据行两处相同，都换。只改这个文件，不要全目录替换：

```swift
                    .font(.system(size: 8.5))
```

换成

```swift
                    .font(.system(size: 8.5)) // token-exempt: 小于 9pt 的图钉和锁图标
```

第 316 行 `.opacity((isHovered || isSelected || isHighlighted) && !isCommandPressed ? 1.0 : 0.0)` 是按钮显隐，不是颜色。不要改，也不要加注释。

---

## 步骤 6：`DiaryCardComponents.swift`

置顶图钉：

```swift
                    .font(.system(size: 10))
```

换成

```swift
                    .font(DaybookType.badge)
```

密码徽章。先换这两行字号，再换颜色，避免和加标签菜单里的 10pt 搞混。这一处的 10pt 后面紧跟的是密码文案：

```swift
                        .font(.system(size: 9))
                    Text("diary.privacy")
                        .font(.system(size: 10, weight: .medium))
```

换成

```swift
                        .font(DaybookType.micro)
                    Text("diary.privacy")
                        .font(DaybookType.badge.weight(.medium))
```

```swift
                .foregroundStyle(Color.red.opacity(0.85))
```

换成

```swift
                .foregroundStyle(DaybookPalette.status.danger.opacity(0.85)) // token-exempt: 85% 危险色没有对应令牌
```

```swift
                .background(Capsule().fill(Color.red.opacity(0.10)))
```

换成

```swift
                .background(Capsule().fill(DaybookPalette.status.danger.opacity(0.10))) // token-exempt: 10% 危险色底没有对应令牌
```

取消和保存两处相同，都换。`.buttonStyle(.borderedProminent)` 不要改：

```swift
                .font(.system(size: 11))
```

换成

```swift
                .font(DaybookType.caption)
```

遮罩里的密码占位：

```swift
                .font(.system(size: 14, weight: .bold, design: .monospaced))
```

换成

```swift
                .font(.system(size: 14, weight: .bold, design: .monospaced)) // token-exempt: 密码占位用等宽粗体，bodyLarge 是 14pt 常规无衬线
```

---

## 最终验证

```bash
# 1. 手记模块里没有未豁免的字面字号（预期零输出）
rg -n '\.font\(\.system\(size:' AreaChain/Features/Diary | rg -v 'token-exempt:'

# 2. 已点名的字面圆角消失（预期零输出）
rg -n 'cornerRadius:\s*(3\.5|2\.5)\b' AreaChain/Features/Diary

# 3. 密码徽章不再写 Color.red（预期零输出）
rg -n 'Color\.red' AreaChain/Features/Diary

# 4. 已点名的透明度已换（预期零输出）
rg -n 'stamp\.opacity\(0\.35\)|stamp\.opacity\(0\.12\)' AreaChain/Features/Diary

# 5. 标签色仍是原来的系统色，并且有豁免（预期 3 行，每行都有 token-exempt）
rg -n 'return \.red|return \.orange|return \.blue' AreaChain/Features/Diary/DiaryNoteCard.swift

# 6. 其他模块零 diff（预期零输出）
git diff --stat -- AreaChain/Features/MenuBar AreaChain/Features/Tasks AreaChain/Features/Workspace AreaChain/Theme

# 7. 测试没被删（两条都跑；预期零输出）
git diff -- AreaChainTests | rg '^-\s*@Test'
git diff --cached -- AreaChainTests | rg '^-\s*@Test'

# 8. 测试
./scripts/build.sh test \
  --only-testing AreaChainTests/DiarySummaryRowTests \
  --only-testing AreaChainTests/DiaryComposerInteractionTests \
  --only-testing AreaChainTests/DiaryPrivacyTests \
  --only-testing AreaChainTests/PrivacyRenderingTests

# 9. 工作流检查
python3 -B scripts/check_workflow.py
```

第 1 条如果还有输出，就是漏改或漏了豁免注释。不要把 8.5pt 换成 `DaybookType.kbd` 或 `DaybookType.micro`。不要把 26pt 换成 `DaybookType.display`。

第 5 条必须仍是 `.red`、`.orange`、`.blue`。如果变成了 `DiaryPreset`，改回去。

第 8 条若失败且是「尺寸与预期不符」，不要改测试，贴出失败信息停下问我。运行期间不要操作其他窗口。

## 汇报格式

```
## P6 Diary 完成汇报
### 修改文件（路径 — 换了什么）
### 保留的 token-exempt 行（file:line — 注释）
### 验证输出（1–9 条原样输出）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P6 Diary` 改成 `- [x]`，决策记录追加 `- <日期> P6 Diary 完成：<一句话>`。

## 绝对不要做

- 不要改 MenuBar、Tasks、Workspace、Theme，也不要改 `DaybookPalette.swift`。
- 不要把 `DiaryTagChrome` 改成 `diaryPreset`。
- 不要把 8.5pt 放成 `DaybookType.micro` 或 `DaybookType.kbd`。
- 不要把 26pt 放成 `DaybookType.display`。
- 不要去掉 `.rounded` 和 `.monospaced`。
- 不要把 `color.opacity(0.12)` 换成 `accent.fill`。
- 不要新增字号或颜色令牌。
- 不要改 `lineWidth` 的数字，不要改动画，不要改 `.bordered` / `.borderedProminent`。
- 不要 commit。
