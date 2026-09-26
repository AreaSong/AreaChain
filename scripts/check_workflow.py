#!/usr/bin/env python3
"""只读检查工作流引用、Domain 显式 UI 导入与项目技能 Git 边界；不运行应用。"""

import argparse
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
SKILLS = ("areachain-workflow", "areachain-ui", "areachain-verify")
REQUIRED_DOCS = (
    "AGENTS.md", "README.md", "docs/README.md", "docs/architecture.md",
    "docs/signing.md", "docs/engineering.md", "skill-routing.md",
    "docs/component-catalog.md", "docs/quality-gates.md",
)
LINK = re.compile(r"\[[^\]\n]*\]\((?:<([^>\n]+)>|([^\s)]+))(?:\s+\"[^\"]*\")?\)")
IMPORT = re.compile(r"\bimport\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?(AppKit|SwiftUI|Cocoa)\b")
LIMITATIONS = [
    "文档检查覆盖内联本地链接及 Markdown 标题/显式锚点；不访问远端链接，不验证内容语义。",
    "Domain 检查仅识别显式 import；不替代 Swift 编译、宏展开或完整符号依赖分析。",
    "skill-format 只核对 frontmatter 名称/描述和 openai.yaml 的显示字段；不证明模型发现或调用。",
    "技能 Git 边界不证明发现或调用成功；本地通过不代表 CI、运行验收或发行通过。",
    "theme-tokens 只匹配 Features/Theme 里的字面模式，并跳过同行的 control 与 token-exempt 注释；不证明视觉一致。",
    "workflow-contract 只核对项目级路由、复用目录和编排技能的关键入口；不证明模型实际发现或调用技能。",
    "component-catalog 只核对少量稳定入口的文件和符号仍存在；不把所有内部类型自动变成公共 API。",
    "ci-contract 只核对工作流中的关键文本标记与 checkout revision；不替代 GitHub Actions YAML 语义或远端运行验证。",
    "swift-file-size 只数源码行数，不判断函数是否该拆，也不证明行为等价。",
]

WORKFLOW_CONTRACT = {
    "AGENTS.md": (
        "skill-routing.md", "component-catalog.md", "quality-gates.md",
        "areachain-workflow", "白话请求默认行为", "不把 `.cursor/plans` 当项目路线",
    ),
    "skill-routing.md": (
        "areachain-workflow", "areachain-ui", "areachain-verify",
        "docs/component-catalog.md", "docs/quality-gates.md", "用户输入契约",
        "三个项目技能",
    ),
    "docs/component-catalog.md": (
        "DaybookInputShell", "ModelChanges", "新公共组件",
    ),
    ".agents/skills/areachain-workflow/SKILL.md": (
        "skill-routing.md", "component-catalog.md", "areachain-verify",
        "quality-gates.md", "用户无需调用本技能", "skill-format",
    ),
    "docs/quality-gates.md": (
        "quality_gate.py", "performance-baselines.json", "security-static",
        "comment-contract",
    ),
}

COMPONENT_ENTRIES = (
    ("AreaChain/Theme/DaybookInputShell.swift", "DaybookInputShell"),
    ("AreaChain/Theme/DaybookTextField.swift", "DaybookTextField"),
    ("AreaChain/Theme/SyntaxTextField.swift", "SyntaxTextField"),
    ("AreaChain/Theme/DaybookButtonStyle.swift", "DaybookButtonStyle"),
    ("AreaChain/Theme/DaybookSurface.swift", "daybookSurface"),
    ("AreaChain/Features/Tasks/TaskRow.swift", "TaskRow"),
    ("AreaChain/Features/Tasks/DayBoardList.swift", "DayBoardList"),
    ("AreaChain/Domain/Classification.swift", "BoardFilter"),
    ("AreaChain/Domain/BoardSearch.swift", "BoardSearch"),
    ("AreaChain/Domain/DayKey.swift", "DayKey"),
    ("AreaChain/Domain/AgendaProjection.swift", "AgendaProjection"),
    ("AreaChain/Features/Tasks/DayBoardMutations.swift", "DayBoardMutations"),
    ("AreaChain/Services/ModelChanges.swift", "ModelChanges"),
)


def issue(path, message, line=1):
    return {"file": str(path), "line": line, "message": message}


def result(name, checked, issues, status=None):
    return {"name": name, "status": status or ("failed" if issues else "passed"),
            "checked": checked, "issues": issues}


def contained(path, root):
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except (ValueError, OSError, RuntimeError):
        return False


def prose_lines(text):
    """保留行号和标题正文，仅跳过围栏代码。"""
    fence = None
    for number, line in enumerate(text.splitlines(), 1):
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if marker:
            token = marker.group(1)
            if fence is None:
                fence = token
            elif token[0] == fence[0] and len(token) >= len(fence):
                fence = None
            continue
        if fence is None:
            yield number, line


def anchors(text):
    found = set()
    for _, line in prose_lines(text):
        found.update(re.findall(r'<a\s+(?:id|name)=[\"\']([^\"\']+)[\"\']', line))
        heading = re.match(r"^ {0,3}#{1,6}\s+(.+?)(?:\s+#+)?$", line)
        if not heading:
            continue
        label = LINK.sub(lambda match: match.group(0).split("]", 1)[0][1:], heading.group(1))
        base = re.sub(r"[^\w\- ]", "", label.strip().lower()).replace(" ", "-")
        slug, count = base, 0
        while slug in found:
            count += 1
            slug = f"{base}-{count}"
        found.add(slug)
    return found


def link_problem(source, target, root, allowed_targets=None):
    try:
        parts = urlsplit(target)
        if parts.scheme or parts.netloc:
            return None
        destination = source.parent / unquote(parts.path) if parts.path else source
        if not contained(destination, root):
            return "本地引用越出检查根目录，或通过符号链接指向外部：" + target
        if allowed_targets is not None and destination.resolve() not in allowed_targets:
            return "引用不属于本次允许读取的个人文档，未读取目标内容：" + target
        if not destination.exists():
            return "本地引用不存在：" + target
        if parts.fragment and destination.suffix.lower() == ".md":
            if unquote(parts.fragment) not in anchors(destination.read_text(encoding="utf-8")):
                return "Markdown 锚点不存在：" + target
    except (OSError, ValueError, UnicodeError, RuntimeError) as error:
        return f"无法核对引用 {target}：{type(error).__name__}"
    return None


def check_links(root, paths, name, restrict_targets=False):
    paths = sorted(set(paths))
    allowed = {root.resolve() / path.relative_to(root) for path in paths} if restrict_targets else None
    issues, checked = [], 0
    for path in paths:
        if not contained(path, root):
            issues.append(issue(path, "文档通过符号链接越出检查根目录。"))
            continue
        if allowed is not None and path.resolve() not in allowed:
            issues.append(issue(path, "个人文档指向本次读取范围以外，未读取正文。"))
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            issues.append(issue(path, f"无法读取必需文档：{type(error).__name__}"))
            continue
        checked += 1
        for number, line in prose_lines(content):
            line = re.sub(r"(`+).*?\1", "", line)
            for match in LINK.finditer(line):
                problem = link_problem(path, match.group(1) or match.group(2), root, allowed)
                if problem:
                    issues.append(issue(path, problem, number))
    return result(name, checked, issues)


def block_comment_end(text, start):
    depth, cursor = 1, start + 2
    for token in re.finditer(r"/\*|\*/", text[cursor:]):
        depth += 1 if token.group() == "/*" else -1
        if depth == 0:
            return cursor + token.end()
    return len(text)


def string_end(text, start):
    opening = re.match(r'(#+)?("""|")', text[start:])
    hashes, quote = opening.group(1) or "", opening.group(2)
    cursor = start + opening.end()
    closing = quote + hashes
    interpolation = "\\" + hashes + "("
    while cursor < len(text):
        if text.startswith(interpolation, cursor):
            cursor = interpolation_end(text, cursor + len(interpolation))
            continue
        if text.startswith(closing, cursor):
            return cursor + len(closing)
        if text.startswith("\\" + hashes, cursor):
            cursor += len(hashes) + 2
        else:
            cursor += 1
    return len(text)


def interpolation_end(text, cursor):
    depth = 1
    while cursor < len(text):
        if text.startswith("//", cursor):
            newline = text.find("\n", cursor)
            cursor = len(text) if newline == -1 else newline
        elif text.startswith("/*", cursor):
            cursor = block_comment_end(text, cursor)
        elif re.match(r'#*"', text[cursor:]):
            cursor = string_end(text, cursor)
        else:
            if text[cursor] == "(":
                depth += 1
            elif text[cursor] == ")":
                depth -= 1
                if depth == 0:
                    return cursor + 1
            cursor += 1
    return len(text)


def swift_code(text):
    """仅屏蔽注释与字符串以减少 import 检查误报；不是 Swift 语法分析器。"""
    masked, cursor = list(text), 0
    token_pattern = re.compile(r'//|/\*|#*"')
    while token := token_pattern.search(text, cursor):
        start = token.start()
        if token.group() == "//":
            end = text.find("\n", start)
            end = len(text) if end == -1 else end
        elif token.group() == "/*":
            end = block_comment_end(text, start)
        else:
            end = string_end(text, start)
        masked[start:end] = ["\n" if char == "\n" else " " for char in text[start:end]]
        cursor = end
    return "".join(masked)


def check_domain(root):
    paths = sorted((root / "AreaChain/Domain").rglob("*.swift"))
    issues = []
    if not paths:
        issues.append(issue(root / "AreaChain/Domain", "没有找到 Domain Swift 源文件。"))
    for path in paths:
        if not contained(path, root):
            issues.append(issue(path, "源文件通过符号链接越出检查根目录。"))
            continue
        try:
            content = swift_code(path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError, RuntimeError) as error:
            issues.append(issue(path, f"无法读取领域文件：{type(error).__name__}"))
            continue
        for match in IMPORT.finditer(content):
            issues.append(issue(path, f"Domain 不允许导入 {match.group(1)}。",
                                content.count("\n", 0, match.start()) + 1))
    return result("domain-imports", len(paths), issues)


THEME_LINE = re.compile(
    r"\.font\(\.system\(|cornerRadius:\s*[0-9]|"
    r"\bColor\.(?:orange|red|green|white|black|blue|gray|primary|secondary|"
    r"yellow|indigo|mint|cyan|brown|teal|purple)\b|"
    r"\.buttonStyle\(\.plain\)|\bDaybookTheme\.|\bisWorkspace\b|\.shadow\("
)
THEME_SHAPE = re.compile(r"(?<![A-Za-z])(?:RoundedRectangle|Capsule|Circle)\(")
THEME_OPACITY = re.compile(r"\.opacity\([^)]+\)")
THEME_COLORISH = re.compile(r"DaybookPalette|Color\.")
THEME_LAYOUT = re.compile(r"\bWorkspaceLayout\.")
THEME_EMBEDDED = re.compile(r"\bembedded\b.*(?:DaybookPalette|DaybookType|\.opacity\(|Color\.)")
THEME_LAYOUT_FILES = {
    "AreaChain/Features/Workspace/MainSplitWorkspaceView.swift",
    "AreaChain/Features/Workspace/WorkspaceSidebarView.swift",
    "AreaChain/Features/Workspace/WorkspaceHeaderBar.swift",
}


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
            if "// token-exempt:" in raw:
                continue
            if "// control:" in raw:
                # // control: 仅放行 .buttonStyle(.plain)，其余字面视觉违规仍须拦截
                code = re.sub(r"\.buttonStyle\(\.plain\)", "                    ", code)
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
    theme_directory = root / "AreaChain/Theme"
    theme_paths = sorted(theme_directory.rglob("*.swift")) if theme_directory.is_dir() else []
    for path in theme_paths:
        if not contained(path, root):
            continue
        try:
            original = path.read_text(encoding="utf-8")
            masked = swift_code(original)
        except (OSError, UnicodeError, RuntimeError) as error:
            issues.append(issue(path, f"无法读取主题文件：{type(error).__name__}"))
            continue
        for number, (raw, code) in enumerate(zip(original.splitlines(), masked.splitlines()), 1):
            if re.search(r"\bDiaryContent\b", code):
                issues.append(issue(path, "Theme 出现对 Services 层 DiaryContent 的反向依赖。", number))
    return result("theme-tokens", len(paths) + len(theme_paths), issues)


def check_workflow_contract(root):
    """确认冷启动所需的项目路由、复用目录和编排技能没有断链。"""
    issues, checked = [], 0
    for relative, markers in WORKFLOW_CONTRACT.items():
        path = root / relative
        if not path.is_file():
            issues.append(issue(path, "工作流契约文件缺失。"))
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            issues.append(issue(path, f"无法读取工作流契约文件：{type(error).__name__}"))
            continue
        checked += 1
        for marker in markers:
            if marker not in content:
                issues.append(issue(path, f"工作流契约缺少关键入口：{marker}"))
    return result("workflow-contract", checked, issues)


def check_component_catalog(root):
    """确认复用目录没有脱离少量稳定的核心实现入口。"""
    catalog = root / "docs/component-catalog.md"
    issues, checked = [], 0
    if not catalog.is_file():
        return result("component-catalog", 0, [issue(catalog, "共享组件目录缺失。")])
    try:
        catalog_text = catalog.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return result("component-catalog", 0,
                      [issue(catalog, f"无法读取共享组件目录：{type(error).__name__}")])
    checked += 1
    for relative, symbol in COMPONENT_ENTRIES:
        source = root / relative
        if not source.is_file():
            issues.append(issue(source, f"组件目录对应源码缺失：{symbol}"))
            continue
        try:
            source_text = source.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            issues.append(issue(source, f"无法读取组件源码：{type(error).__name__}"))
            continue
        checked += 1
        if symbol not in catalog_text:
            issues.append(issue(catalog, f"组件目录未登记稳定入口：{symbol}"))
        if not re.search(r"\b" + re.escape(symbol) + r"\b", source_text):
            issues.append(issue(source, f"组件目录登记的符号不存在：{symbol}"))
    return result("component-catalog", checked, issues)


def check_performance_manifest(root):
    """确认性能基线清单可读，且登记的源码/测试仍存在。"""
    path = root / "docs/performance-baselines.json"
    if not path.is_file():
        return result("performance-baselines", 0, [issue(path, "性能基线清单缺失。")])
    try:
        manifest = json.loads(
            path.read_text(encoding="utf-8"),
            parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)),
        )
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        return result("performance-baselines", 0,
                      [issue(path, f"性能基线清单不可读：{type(error).__name__}")])
    issues, checked = [], 1
    if not isinstance(manifest, dict):
        return result("performance-baselines", checked,
                      [issue(path, "性能基线清单顶层必须是对象。")])
    entries = manifest.get("entries")
    if manifest.get("schemaVersion") != 1 or not isinstance(entries, list) or not entries:
        issues.append(issue(path, "性能基线清单缺少受支持的 schemaVersion 或 entries。"))
        return result("performance-baselines", checked, issues)
    policy = manifest.get("measurementPolicy")
    required_measurement_fields = []
    if not isinstance(policy, dict):
        issues.append(issue(path, "性能基线清单缺少 measurementPolicy。"))
    else:
        required_measurement_fields = policy.get("requiredFields")
        if (not isinstance(required_measurement_fields, list) or not required_measurement_fields
                or not all(isinstance(field, str) and field.strip() for field in required_measurement_fields)):
            issues.append(issue(path, "measurementPolicy.requiredFields 无效。"))
            required_measurement_fields = []
    allowed = {"observed", "provisional", "not-established"}
    required = {"id", "scope", "test", "testFilter", "metric", "budget", "status", "source", "note"}
    identifiers = set()
    for entry in manifest["entries"]:
        checked += 1
        missing = required - set(entry) if isinstance(entry, dict) else required
        if missing:
            issues.append(issue(path, f"性能条目缺少字段：{sorted(missing)}"))
            continue
        entry_id = entry["id"]
        if not isinstance(entry_id, str) or not entry_id.strip():
            issues.append(issue(path, "性能条目 id 必须是非空字符串。"))
        elif entry_id in identifiers:
            issues.append(issue(path, f"性能条目 id 重复：{entry_id}"))
        else:
            identifiers.add(entry_id)
        for field in ("metric", "note"):
            if not isinstance(entry[field], str) or not entry[field].strip():
                issues.append(issue(path, f"性能条目 {field} 不能为空：{entry_id}"))
        status_value = entry["status"]
        if not isinstance(status_value, str) or status_value not in allowed:
            issues.append(issue(path, f"性能条目状态无效：{entry['id']}"))
        elif status_value != "not-established":
            budget = entry["budget"]
            if (not isinstance(budget, (int, float)) or isinstance(budget, bool)
                    or not math.isfinite(budget) or budget <= 0):
                issues.append(issue(path, f"已建立性能条目缺少有限且大于零的预算：{entry['id']}"))
            if not isinstance(entry["test"], str) or not entry["test"].strip():
                issues.append(issue(path, f"已建立性能条目缺少测试：{entry['id']}"))
            if not isinstance(entry["testFilter"], str) or not entry["testFilter"].startswith("AreaChainTests/"):
                issues.append(issue(path, f"已建立性能条目缺少有效 testFilter：{entry['id']}"))
            if not isinstance(entry["source"], str) or not entry["source"].strip():
                issues.append(issue(path, f"已建立性能条目缺少来源：{entry['id']}"))
            if status_value == "observed":
                measurement = entry.get("measurement")
                if not isinstance(measurement, dict):
                    issues.append(issue(path, f"observed 性能条目缺少 measurement：{entry['id']}"))
                else:
                    text_fields = [field for field in required_measurement_fields if field != "sampleCount"]
                    missing_measurement = [field for field in text_fields
                                           if not isinstance(measurement.get(field), str)
                                           or not measurement[field].strip()]
                    if missing_measurement:
                        issues.append(issue(path, f"性能测量缺少字段 {missing_measurement}：{entry['id']}"))
                    sample_count = measurement.get("sampleCount")
                    if ("sampleCount" in required_measurement_fields
                            and (not isinstance(sample_count, int) or isinstance(sample_count, bool)
                                 or sample_count <= 0)):
                        issues.append(issue(path, f"性能测量 sampleCount 必须为正整数：{entry['id']}"))
        else:
            if entry["budget"] is not None:
                issues.append(issue(path, f"未建立性能条目不应声明预算：{entry['id']}"))
            if entry["testFilter"] is not None:
                issues.append(issue(path, f"未建立性能条目不应声明 testFilter：{entry['id']}"))
        scope_value = entry["scope"]
        if not isinstance(scope_value, str) or not scope_value:
            issues.append(issue(path, f"性能条目源码路径无效：{entry['id']}"))
        else:
            scope = root / scope_value
            if not contained(scope, root) or not scope.is_file():
                issues.append(issue(path, f"性能条目源码不存在：{scope_value}"))
        test_value = entry["test"]
        if test_value is not None and not isinstance(test_value, str):
            issues.append(issue(path, f"性能条目测试路径无效：{entry['id']}"))
        elif test_value is not None:
            test = root / test_value
            if not contained(test, root) or not test.is_file():
                issues.append(issue(path, f"性能条目测试不存在：{test_value}"))
    return result("performance-baselines", checked, issues)


def check_ci_contract(root):
    """确认仓库 CI 入口使用统一质量脚本和只读权限。"""
    path = root / ".github/workflows/quality.yml"
    if not path.is_file():
        return result("ci-contract", 0, [issue(path, "CI 质量工作流缺失。")])
    try:
        content = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        return result("ci-contract", 0, [issue(path, f"无法读取 CI 工作流：{type(error).__name__}")])
    issues = []
    required = (
        "workflow_dispatch",
        "permissions:",
        "contents: read",
        "scripts/quality_gate.py --profile static --strict --format json",
        "fetch-depth: 2",
        "scripts/quality_gate.py --profile swift --strict --base-ref HEAD^ --format json",
        "macos-15",
        "brew install swiftlint",
    )
    for marker in required:
        if marker not in content:
            issues.append(issue(path, f"CI 工作流缺少关键入口：{marker}"))
    if not re.search(r"actions/checkout@[0-9a-f]{40}", content):
        issues.append(issue(path, "CI checkout action 必须固定到不可变 commit。"))
    return result("ci-contract", len(required) + 2, issues)


def git(root, arguments, stdin=None):
    return subprocess.run(["git", "-C", str(root), *arguments], input=stdin,
                          text=True, capture_output=True, timeout=15, check=False)


def required_skill_files(root, prefixes):
    required = {prefix + suffix for prefix in prefixes
                for suffix in ("SKILL.md", "agents/openai.yaml")}
    for prefix in prefixes:
        for path in (root / prefix).rglob("*.md"):
            required.add(path.relative_to(root).as_posix())
            if not contained(path, root):
                continue
            for _, line in prose_lines(path.read_text(encoding="utf-8")):
                line = re.sub(r"(`+).*?\1", "", line)
                for match in LINK.finditer(line):
                    parts = urlsplit(match.group(1) or match.group(2))
                    if parts.scheme or parts.netloc or not parts.path:
                        continue
                    target = path.parent / unquote(parts.path)
                    if contained(target, root) and target.is_file():
                        lexical = Path(os.path.abspath(target)).relative_to(root.absolute()).as_posix()
                        if lexical.startswith(prefixes):
                            required.add(lexical)
                        relative = target.resolve().relative_to(root.resolve()).as_posix()
                        if relative.startswith(prefixes):
                            required.add(relative)
    return sorted(required)


def check_swift_file_size(root, limit=500):
    """拦住单文件重新超过结构上限；不评价函数长短。"""
    issues, checked = [], 0
    for folder in ("AreaChain", "AreaChainTests"):
        directory = root / folder
        if not directory.is_dir():
            continue
        for path in sorted(directory.rglob("*.swift")):
            checked += 1
            if not contained(path, root):
                issues.append(issue(path, "源文件通过符号链接越出检查根目录。"))
                continue
            try:
                count = len(path.read_text(encoding="utf-8").splitlines())
            except (OSError, UnicodeError) as error:
                issues.append(issue(path, f"无法读取 Swift 文件：{type(error).__name__}"))
                continue
            if count > limit:
                issues.append(issue(path, f"Swift 文件超过 {limit} 行：{count}。"))
    return result("swift-file-size", checked, issues)


def frontmatter_fields(text):
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None
    closing = next((index for index, line in enumerate(lines[1:], 1) if line.strip() == "---"), None)
    if closing is None:
        return None
    fields, key = {}, None
    for line in lines[1:closing]:
        if key and line[:1] in " \t":
            fields[key] += " " + line.strip().strip("\"'")
            continue
        if ":" not in line or line.lstrip().startswith("#"):
            continue
        key, value = line.split(":", 1)
        key, value = key.strip(), value.strip().strip("\"'")
        if key:
            fields[key] = value
    return fields


def yaml_scalar_keys(text):
    found = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or ":" not in stripped:
            continue
        name, value = stripped.split(":", 1)
        name, value = name.strip(), value.strip().strip("\"'")
        if name and value:
            found[name] = value
    return found


def check_skill_format(root):
    """核对项目技能入口元数据，不替代发现或调用证据。"""
    issues, checked = [], 0
    required_yaml = ("display_name", "short_description")
    for name in SKILLS:
        skill = root / ".agents/skills" / name / "SKILL.md"
        checked += 1
        if not skill.is_file():
            issues.append(issue(skill, "项目技能 SKILL.md 缺失。"))
            continue
        try:
            fields = frontmatter_fields(skill.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            issues.append(issue(skill, f"无法读取技能文件：{type(error).__name__}"))
            continue
        if not fields:
            issues.append(issue(skill, "SKILL.md 缺少 YAML frontmatter。"))
        else:
            if fields.get("name") != name:
                issues.append(issue(skill, f"frontmatter name 必须是 {name}。"))
            if not fields.get("description"):
                issues.append(issue(skill, "frontmatter 缺少 description。"))
        yaml_path = root / ".agents/skills" / name / "agents/openai.yaml"
        checked += 1
        if not yaml_path.is_file():
            issues.append(issue(yaml_path, "项目技能 openai.yaml 缺失。"))
            continue
        try:
            values = yaml_scalar_keys(yaml_path.read_text(encoding="utf-8"))
        except (OSError, UnicodeError) as error:
            issues.append(issue(yaml_path, f"无法读取 openai.yaml：{type(error).__name__}"))
            continue
        for key in required_yaml:
            if key not in values:
                issues.append(issue(yaml_path, f"openai.yaml 缺少 {key}。"))
    return result("skill-format", checked, issues)


def check_skill_scope(root):
    prefixes = tuple(f".agents/skills/{name}/" for name in SKILLS)
    hidden = [".agents/workflow-check-local-state", ".agents/skills/workflow-check-unshared/SKILL.md"]
    try:
        visible = required_skill_files(root, prefixes)
        listed = git(root, ["ls-files", "--cached", "--others", "--exclude-standard", "-z", "--", ".agents"])
        ignored = git(root, ["check-ignore", "--no-index", "--stdin", "-z"], "\0".join(visible + hidden) + "\0")
        if listed.returncode != 0 or ignored.returncode not in (0, 1):
            return result("skill-git-scope", 0, [issue(root, "Git 作用域检查不可用；未证明忽略边界。")], "blocked")
    except (OSError, UnicodeError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        return result("skill-git-scope", 0, [issue(root, "技能文件/Git 输出无法读取，或检查超时。")], "blocked")
    exposed = set(filter(None, listed.stdout.split("\0")))
    ignored_paths = set(ignored.stdout.split("\0"))
    issues = [issue(root / path, "非本项目共享技能的 .agents 文件对 Git 可见。")
              for path in sorted(exposed) if not path.startswith(prefixes)]
    issues.extend(issue(root / path, "项目技能必需文件缺失或被忽略。")
                  for path in visible if path in ignored_paths or not (root / path).is_file())
    issues.extend(issue(root / path, "本地代理状态/非共享技能未被忽略（只读虚拟路径检查）。")
                  for path in hidden if path not in ignored_paths)
    return result("skill-git-scope", len(exposed) + len(visible) + len(hidden), issues)


def project_docs(root):
    paths = [root / name for name in REQUIRED_DOCS]
    paths.extend((root / "docs").rglob("*.md"))
    for name in SKILLS:
        directory = root / ".agents/skills" / name
        paths.append(directory / "SKILL.md")
        paths.extend(directory.rglob("*.md"))
    return paths


def personal_docs(root):
    # 只读明确指定的自有规则和技能，不扫描其他技能、插件缓存、配置或会话。
    directory = root / "skills/areasong-development"
    paths = [root / "AGENTS.md", root / "skill-routing.md", directory / "SKILL.md"]
    paths.extend((directory / "references").rglob("*.md"))
    return paths


def run_checks(root, personal_root=None):
    markers = ("AreaChain.xcodeproj", "AreaChainTests", "scripts/build.sh")
    missing = [issue(root / path, "不是可识别的 AreaChain 工作副本：缺少项目入口。")
               for path in markers if not (root / path).exists()]
    checks = [result("project-identity", len(markers), missing)]
    if not missing:
        checks.extend([check_links(root, project_docs(root), "project-links"),
                       check_workflow_contract(root), check_domain(root),
                       check_component_catalog(root), check_performance_manifest(root),
                       check_ci_contract(root), check_skill_format(root),
                       check_skill_scope(root), check_theme_tokens(root),
                       check_swift_file_size(root)])
    if personal_root is not None:
        checks.append(check_links(personal_root, personal_docs(personal_root), "personal-links", restrict_targets=True))
    passed = all(check["status"] == "passed" for check in checks)
    return {"schemaVersion": 1, "status": "passed" if passed else "failed",
            "checks": checks, "limitations": LIMITATIONS}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="项目工作副本根目录；默认脚本所属仓库")
    parser.add_argument("--personal-root", type=Path, help="可选：仅检查此目录的 AGENTS/路由/areasong-development 引用")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args()
    report = run_checks(args.root.resolve(), args.personal_root.resolve() if args.personal_root else None)
    if args.format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        for check in report["checks"]:
            print(f"{check['status']}: {check['name']} ({check['checked']} 项)")
            for problem in check["issues"]:
                print(f"  {problem['file']}:{problem['line']}: {problem['message']}")
        for limitation in report["limitations"]:
            print("边界：" + limitation)
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    sys.exit(main())
