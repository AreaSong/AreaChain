#!/usr/bin/env python3
"""只读检查工作流引用、Domain 显式 UI 导入与项目技能 Git 边界；不运行应用。"""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
SKILLS = ("areachain-ui", "areachain-verify")
REQUIRED_DOCS = (
    "AGENTS.md", "README.md", "docs/README.md", "docs/architecture.md",
    "docs/signing.md", "docs/engineering.md",
)
LINK = re.compile(r"\[[^\]\n]*\]\((?:<([^>\n]+)>|([^\s)]+))(?:\s+\"[^\"]*\")?\)")
IMPORT = re.compile(r"\bimport\s+(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?(AppKit|SwiftUI)\b")
LIMITATIONS = [
    "文档检查覆盖内联本地链接及 Markdown 标题/显式锚点；不访问远端链接，不验证内容语义。",
    "Domain 检查仅识别显式 import；不替代 Swift 编译、宏展开或完整符号依赖分析。",
    "技能 Git 边界不证明发现或调用成功；本地通过不代表 CI、运行验收或发行通过。",
]


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
                       check_domain(root), check_skill_scope(root)])
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
