# 任务：AreaChain 设计系统收敛 · 阶段 P7 禁令、文档、全量回归 · 执行提示词

## 你是谁、怎么工作

你是这个 macOS 原生项目（SwiftUI + AppKit + SwiftData）的执行工程师。设计已完成，**你只负责照做**。规则：

1. 按步骤顺序做。检查器的函数按下面给出的原文放进 `scripts/check_workflow.py`，不要自己另写一套规则。
2. 不 `git commit` / `git push` / 安装 / 发布。不要删测试。
3. 先读 `AGENTS.md`，再读本文，再读 `scripts/check_workflow.py` 里的 `swift_code`、`check_domain`、`run_checks`、`LIMITATIONS`。
4. 做完不宣布「通过」。验收按 `design-system-P7-verify.md`。
5. 不要改颜色、字号、圆角的数值。步骤 2 只在点名的行尾加注释。
6. `AGENTS.md` 第 38 行已经指向 `DaybookPalette` / `DaybookMetrics` / `DaybookTokens`。不要重写它。

## 检查器怎么判

扫描 `AreaChain/Features/**/*.swift`。每一行先看**原文**：含 `// control:` 或 `// token-exempt:` 就跳过。其余行在 `swift_code()` 屏蔽注释和字符串之后的同一行上匹配。这样字符串里的 `Color.red` 和注释里的例子不会误报，豁免注释也不会被先抹掉。

这些模式命中就报：

- `.font(.system(`
- `cornerRadius:` 后面紧跟数字
- `Color.orange` / `red` / `green` / `white` / `black` / `blue` / `gray` / `primary` / `secondary`
- `.buttonStyle(.plain)`
- `DaybookTheme.`
- `isWorkspace`
- `.shadow(`
- `embedded` 同一行里又出现 `DaybookPalette`、`DaybookType`、`.opacity(` 或 `Color.`

`WorkspaceLayout.` 只允许出现在这三个文件，别的 Features 文件命中就报：

- `AreaChain/Features/Workspace/MainSplitWorkspaceView.swift`
- `AreaChain/Features/Workspace/WorkspaceSidebarView.swift`
- `AreaChain/Features/Workspace/WorkspaceHeaderBar.swift`

`RoundedRectangle(`、`Capsule(`、`Circle(` 只在这一行**没有** `DaybookRadius` 也没有 `DaybookMetrics` 时报。`WorkspaceHeaderSearchCapsule(` 不是 `Capsule(`，用「前面不是字母」来区分。

`.opacity(数字)` 只在同一行还有 `DaybookPalette` 或 `Color.` 时报。`Divider().opacity(0.35)` 和按钮显隐 `.opacity(0)` 不报。它们不是颜色。

这个检查只匹配字面文本，不证明界面看起来一致。

## 开始前必读

`scripts/check_workflow.py` 的 `swift_code` 和 `run_checks`。`scripts/tests/test_check_workflow.py` 里的 `test_default_checks_pass_in_isolated_repository`。

基线（必须绿）：

```bash
python3 -B scripts/check_workflow.py
python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v
```

---

## 步骤 1：把函数放进 `scripts/check_workflow.py`

在 `LIMITATIONS` 列表末尾加一条字符串，逗号不要漏：

```python
    "theme-tokens 只匹配 Features 里的字面模式，并跳过同行的 control 与 token-exempt 注释；不证明视觉一致。",
```

在 `check_domain` 函数结束后插入下面整段：

```python
THEME_LINE = re.compile(
    r"\.font\(\.system\(|cornerRadius:\s*[0-9]|"
    r"\bColor\.(?:orange|red|green|white|black|blue|gray|primary|secondary)\b|"
    r"\.buttonStyle\(\.plain\)|\bDaybookTheme\.|\bisWorkspace\b|\.shadow\("
)
THEME_SHAPE = re.compile(r"(?<![A-Za-z])(?:RoundedRectangle|Capsule|Circle)\(")
THEME_OPACITY = re.compile(r"\.opacity\([0-9.]+\)")
THEME_COLORISH = re.compile(r"DaybookPalette|Color\.")
THEME_LAYOUT = re.compile(r"\bWorkspaceLayout\.")
THEME_EMBEDDED = re.compile(r"\bembedded\b.*(?:DaybookPalette|DaybookType|\.opacity\(|Color\.)")
THEME_LAYOUT_FILES = {
    "AreaChain/Features/Workspace/MainSplitWorkspaceView.swift",
    "AreaChain/Features/Workspace/WorkspaceSidebarView.swift",
    "AreaChain/Features/Workspace/WorkspaceHeaderBar.swift",
}


def theme_line_allowed(original):
    return "// control:" in original or "// token-exempt:" in original


def check_theme_tokens(root):
    directory = root / "AreaChain/Features"
    paths = sorted(directory.rglob("*.swift")) if directory.is_dir() else []
    issues = []
    for path in paths:
        if not contained(path, root):
            issues.append(issue(path, "源文件通过符号链接越出检查根目录。"))
            continue
        try:
            original = path.read_text(encoding="utf-8")
            masked = swift_code(original)
        except (OSError, UnicodeError, RuntimeError) as error:
            issues.append(issue(path, f"无法读取界面文件：{type(error).__name__}"))
            continue
        relative = path.relative_to(root).as_posix()
        for number, (raw, code) in enumerate(zip(original.splitlines(), masked.splitlines()), 1):
            if theme_line_allowed(raw):
                continue
            if THEME_LINE.search(code):
                issues.append(issue(path, "Features 出现未豁免的字面视觉写法。", number))
            elif THEME_SHAPE.search(code) and "DaybookRadius" not in code and "DaybookMetrics" not in code:
                issues.append(issue(path, "Features 出现未豁免的自绘形状。", number))
            elif THEME_OPACITY.search(code) and THEME_COLORISH.search(code):
                issues.append(issue(path, "Features 对颜色使用了未豁免的透明度。", number))
            if relative not in THEME_LAYOUT_FILES and THEME_LAYOUT.search(code):
                issues.append(issue(path, "WorkspaceLayout 只允许白名单文件引用。", number))
            if THEME_EMBEDDED.search(code):
                issues.append(issue(path, "workspaceEmbedded 不能和颜色或字号写在同一行。", number))
    return result("theme-tokens", len(paths), issues)
```

在 `run_checks` 里，现有这三份检查的列表末尾加上 `check_theme_tokens(root)`：

```python
        checks.extend([check_links(root, project_docs(root), "project-links"),
                       check_domain(root), check_skill_scope(root), check_theme_tokens(root)])
```

---

## 步骤 2：给 18 行补上豁免注释

只在行尾加注释，代码不要改。每一行加完后，这一行必须同时有原来的形状和 `// token-exempt:`。

`AreaChain/Features/Diary/DiaryNoteCard.swift` 两处胶囊：

```swift
            .background(Capsule().fill(DaybookPalette.fill.hover))
```

换成

```swift
            .background(Capsule().fill(DaybookPalette.fill.hover)) // token-exempt: 加标签胶囊，圆角由形状决定
```

```swift
                Capsule().strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.7)
```

换成

```swift
                Capsule().strokeBorder(DaybookPalette.border.subtle, lineWidth: 0.7) // token-exempt: 加标签胶囊，圆角由形状决定
```

`AreaChain/Features/Gantt/GanttPage.swift`：

```swift
                Circle()
```

这一处是习惯完成点，行尾加 ` // token-exempt: 习惯完成点，不是按钮`。不要改甘特色块上已经有注释的圆角矩形。如果文件里有多处 `Circle()`，只改习惯点那一处，不要改别的。

`AreaChain/Features/MenuBar/FooterBar.swift`：

```swift
                .clipShape(Capsule())
```

换成

```swift
                .clipShape(Capsule()) // token-exempt: 计数胶囊裁切
```

`AreaChain/Features/MenuBar/MenuBarFilterFlyout.swift` 两处 `Circle()`，都是筛选圆点。两处行尾都加 ` // token-exempt: 筛选状态圆点`。

`AreaChain/Features/MenuBar/MenuBarPopoverView.swift` 两处 `Circle()`，都是头部状态点。两处行尾都加 ` // token-exempt: 头部状态圆点`。

`AreaChain/Features/MenuBar/MenuBarSearchField.swift`：

```swift
                        Circle().fill(dotColor).frame(width: 4.5, height: 4.5)
```

换成

```swift
                        Circle().fill(dotColor).frame(width: 4.5, height: 4.5) // token-exempt: 筛选色点
```

`AreaChain/Features/Search/BoardSearchHitRow.swift`：

```swift
                .background(Capsule().fill(DaybookPalette.accent.fill))
```

换成

```swift
                .background(Capsule().fill(DaybookPalette.accent.fill)) // token-exempt: 搜索种类胶囊
```

`AreaChain/Features/Tasks/BoardFilterBar.swift`：

```swift
        .contentShape(Capsule())
```

换成

```swift
        .contentShape(Capsule()) // token-exempt: 筛选胶囊点击区
```

```swift
                        .clipShape(Capsule())
```

换成

```swift
                        .clipShape(Capsule()) // token-exempt: 计数胶囊裁切
```

`AreaChain/Features/Tasks/DaybookProgressRing.swift` 两处 `Circle()`。第一处加 ` // token-exempt: 进度环轨道`，第二处加 ` // token-exempt: 进度环`。不要改已经有 `token-exempt` 的描边。

`AreaChain/Features/Tasks/TaskRowSubtaskMiniViews.swift` 两处 `Circle()`。描边那处加 ` // token-exempt: 子任务圆框`，填充那处加 ` // token-exempt: 子任务圆底`。

`AreaChain/Features/Tasks/TasksPage+Sections.swift`：

```swift
                    .clipShape(Capsule())
```

换成

```swift
                    .clipShape(Capsule()) // token-exempt: 计数胶囊裁切
```

`AreaChain/Features/Workspace/TaskDetailScheduleSection.swift` 星期选择器里的 `Circle()`，行尾加 ` // token-exempt: 星期圆点，不是胶囊`。不要改别的圆。

---

## 步骤 3：单测

在 `scripts/tests/test_check_workflow.py` 的 `test_default_checks_pass_in_isolated_repository` 里，期望的检查名集合加上 `"theme-tokens"`。现在是四项，改完是五项。空的临时仓库没有 Features 文件，这项必须是 passed。

在同一个测试类末尾加这四个测试。它们调用 `workflow.check_theme_tokens(self.root)`，不要启动应用：

```python
    def test_theme_tokens_flags_literal_shape_color_and_layout(self):
        self.write("AreaChain/Features/Sample.swift",
                   "RoundedRectangle(cornerRadius: 4)\n"
                   "Text(\"x\").font(.system(size: 11))\n"
                   "Color.red\n"
                   ".buttonStyle(.plain)\n"
                   "DaybookTheme.ink\n"
                   "if isWorkspace {}\n"
                   ".shadow(color: .black)\n"
                   "WorkspaceLayout.headerHeight\n"
                   "if embedded { DaybookPalette.text.primary }\n"
                   "Capsule().fill(DaybookPalette.accent.base.opacity(0.2))\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["status"], "failed")
        self.assertGreaterEqual(len(result["issues"]), 8)

    def test_theme_tokens_skip_control_exempt_and_token_radius(self):
        self.write("AreaChain/Features/Sample.swift",
                   "RoundedRectangle(cornerRadius: DaybookRadius.small)\n"
                   "Circle() // token-exempt: 状态点\n"
                   ".buttonStyle(.plain) // control: 整行点击\n"
                   "Divider().opacity(0.35)\n"
                   ".opacity(0)\n"
                   "let note = \"Color.red\"\n"
                   "// DaybookTheme.ink\n"
                   "WorkspaceHeaderSearchCapsule(navigation: navigation)\n")
        self.write("AreaChain/Features/Workspace/WorkspaceHeaderBar.swift",
                   "WorkspaceLayout.headerHeight\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["status"], "passed", result)

    def test_theme_tokens_embedded_layout_alone_is_allowed(self):
        self.write("AreaChain/Features/Sample.swift", "if embedded { showFilters }\n")
        self.write("AreaChain/Features/Workspace/MainSplitWorkspaceView.swift",
                   "WorkspaceLayout.maxContentWidth\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["issues"], [])

    def test_theme_tokens_reports_original_line_number(self):
        self.write("AreaChain/Features/Sample.swift", "let ok = 1\nColor.orange\n")
        result = workflow.check_theme_tokens(self.root)
        self.assertEqual(result["issues"][0]["line"], 2)
```

第二个测试里，`WorkspaceHeaderBar.swift` 在白名单内，所以 `WorkspaceLayout` 可以通过。第一个测试的 `Sample.swift` 不在白名单，`WorkspaceLayout` 必须失败。

---

## 步骤 4：文档

`docs/architecture.md` 第 39 行目录树里的 Theme 说明换成：

```text
  Theme/          令牌（DaybookPalette / DaybookMetrics / DaybookTokens / DaybookColor）、基座（输入壳、按钮、表面、芯片、分节头）与页壳
```

第 49 行换成：

```text
- **Theme**：令牌层是 `DaybookPalette`、`DaybookMetrics`、`DaybookTokens`、`DaybookElevation`、`DaybookColor`；基座层是 `DaybookInputShell`、`DaybookButtonStyle`、`daybookSurface`、`DaybookChip`、`DaybookSectionHeader`、`DaybookDivider`、`DaybookSegmentedBar`。基准是菜单栏浮层任务页：输入高 34、聚焦为墨色 35% 描边、列表是纸底加分隔线、浮层阴影是黑 14% / 模糊 8 / 偏移 2。工作台只在 `WorkspaceLayout` 保留页头、侧栏和内容宽度。
```

第 53 行里「只守住 Domain 禁止显式导入 SwiftUI/AppKit 这一条可判定约束」换成：

```text
只守住 Domain 禁止显式导入 SwiftUI/AppKit，以及 Features 里未豁免的字面颜色、字号、圆角、阴影和旧主题名；不证明视觉一致，也不检查完整符号依赖或运行语义。
```

`docs/engineering.md` 质量门禁表第一行的「结果能证明什么」换成：

```text
内联本地引用/锚点、显式 import、已共享技能和本地状态忽略边界，以及 Features 的 theme-tokens 字面模式
```

同文件第 61 段后面加一句：

```text
`theme-tokens` 只扫描 `AreaChain/Features` 的字面模式。同行有 `// control:` 或 `// token-exempt:` 则跳过。圆角已经写成 `DaybookRadius` 的形状，以及不带颜色名的视图显隐透明度，不报。它不证明界面看起来一致。
```

---

## 最终验证

```bash
# 1. 检查器名字和限制都在
rg -n 'def check_theme_tokens|theme-tokens 只匹配' scripts/check_workflow.py

# 2. 当前仓库通过
python3 -B scripts/check_workflow.py
echo "WORKFLOW=$?"

# 3. 检查器单测
python3 -B -m unittest discover -s scripts/tests -p test_check_workflow.py -v
echo "UNIT=$?"

# 4. 脚本测试全套
python3 -B -m unittest discover -s scripts/tests -v
echo "SCRIPTS=$?"

# 5. 全量应用测试。时间会比较长。运行期间不要操作其他窗口。
./scripts/build.sh test
echo "TEST=$?"
```

第 2 条如果失败，先看是不是步骤 2 漏了一行形状。不要为了变绿去放宽检查器，也不要给整文件批量加注释。把失败行贴出来停下问我。

第 5 条若失败且测试名是 `priorityAndTimeCandidatesStillMatchSpokenWords`，不要修筛选。贴出来停下问我。那是双语阶段留下的问题。

## 汇报格式

```
## P7 完成汇报
### 修改文件（路径 — 改了什么）
### 补了豁免注释的行
### 验证输出（1–5 的退出码）
### 未做 / 发现的问题
```

最后把 `.cursor/plans/design-system.md` 第 8 节 `- [ ] P7 禁令、文档、全量回归` 改成 `- [x]`，决策记录追加 `- <日期> P7 完成：<一句话>`。

## 绝对不要做

- 不要把 `RoundedRectangle(cornerRadius: DaybookRadius` 改成别的组件。
- 不要把 `Divider().opacity` 或 `.opacity(0)` 当成颜色违规。
- 不要把 `WorkspaceHeaderSearchCapsule` 当成 `Capsule`。
- 不要重写 `AGENTS.md` 第 38 行。
- 不要改 `SyntaxAutocomplete.swift`。
- 不要 commit。
