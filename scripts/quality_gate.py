#!/usr/bin/env python3
"""运行 AreaChain 的可重复质量门禁；不安装、启动或修改应用及用户数据。"""

import argparse
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SUFFIXES = {".swift", ".py", ".sh", ".yml", ".yaml", ".xcconfig"}
SOURCE_DIRECTORIES = ("AreaChain", "AreaChainTests", "scripts", ".github", "Config")
PROFILES = ("auto", "docs", "static", "swift", "performance", "full", "release")


def gate(name, status, detail="", command=None, issues=None, duration=0.0):
    return {
        "name": name,
        "status": status,
        "detail": detail,
        "command": command,
        "issues": issues or [],
        "durationSeconds": round(duration, 3),
    }


def run_command(arguments, cwd=ROOT, timeout=900):
    started = time.monotonic()
    try:
        completed = subprocess.run(
            arguments,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return completed.returncode, completed.stdout, completed.stderr, time.monotonic() - started
    except FileNotFoundError as error:
        return 127, "", str(error), time.monotonic() - started
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or "") if isinstance(error.stdout, str) else ""
        return 124, output, "命令超时。", time.monotonic() - started


def changed_files(root=ROOT, base_ref=None):
    """返回基线、工作树与未跟踪差异；Git 取证失败时停止而非退化为空。"""
    commands = []
    if base_ref:
        commands.append(["git", "diff", "--name-only", "-z", "--diff-filter=ACMRD", base_ref, "HEAD"])
    commands.extend([
        ["git", "diff", "--name-only", "-z", "--diff-filter=ACMRD", "HEAD"],
        ["git", "ls-files", "--others", "--exclude-standard", "-z"],
    ])
    paths = set()
    for command in commands:
        code, stdout, stderr, _ = run_command(command, root, 30)
        if code != 0:
            detail = summarize_output(stdout, stderr) or f"退出码 {code}"
            raise RuntimeError(f"无法确定变更范围：{' '.join(command)}：{detail}")
        paths.update(path for path in stdout.split("\0") if path)
    return sorted(paths)


def infer_profile(paths, root=ROOT):
    if not paths:
        return "static"
    performance_scopes = {"docs/performance-baselines.json"}
    data, _ = load_performance_manifest(root)
    if isinstance(data, dict) and isinstance(data.get("entries"), list):
        performance_scopes.update(
            entry.get("scope") for entry in data["entries"]
            if isinstance(entry, dict) and isinstance(entry.get("scope"), str)
        )
    if any(path in performance_scopes for path in paths):
        return "performance"
    if any(path.endswith(".swift") or path.endswith(".xcodeproj/project.pbxproj") for path in paths):
        return "swift"
    if any(path.startswith("scripts/") and path.endswith((".py", ".sh")) for path in paths):
        return "static"
    return "docs"


def needs_swift_toolchain(profile):
    """只有 macOS Swift profile 才要求 SwiftLint/Xcode；静态 CI 保持跨平台。"""
    return profile in ("swift", "performance", "full", "release")


def summarize_output(stdout, stderr, limit=12):
    text = "\n".join(part for part in (stdout, stderr) if part).strip()
    if not text:
        return ""
    lines = text.splitlines()
    if len(lines) <= limit:
        return "\n".join(lines)
    return "\n".join(lines[: limit // 2] + [f"...（省略 {len(lines) - limit} 行）..."] + lines[-limit // 2 :])


def run_workflow_check():
    command = [sys.executable, "-B", "scripts/check_workflow.py", "--format", "json"]
    code, stdout, stderr, duration = run_command(command)
    detail = summarize_output(stdout, stderr)
    status = "passed" if code == 0 else ("blocked" if code == 127 else "failed")
    return gate("workflow-contract", status, detail, command, duration=duration)


def trailing_whitespace_issues(root, paths):
    issues = []
    for relative in paths:
        path = root / relative
        if not path.is_file():
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError):
            continue
        for number, line in enumerate(lines, 1):
            if line.endswith((" ", "\t")):
                issues.append({"file": str(path), "line": number, "detail": "行尾存在空白字符。"})
    return issues


def run_diff_check(root, paths, base_ref=None):
    commands = []
    if base_ref:
        commands.append(["git", "diff", "--check", base_ref, "HEAD"])
    commands.append(["git", "diff", "--check", "HEAD"])
    outputs = []
    duration = 0.0
    blocked = False
    failed = False
    for command in commands:
        code, stdout, stderr, elapsed = run_command(command, root, 30)
        duration += elapsed
        outputs.append(summarize_output(stdout, stderr))
        if code == 127:
            blocked = True
        elif code != 0:
            failed = True
    issues = trailing_whitespace_issues(root, paths)
    status = "blocked" if blocked else ("failed" if failed or issues else "passed")
    return gate("diff-whitespace", status, "\n".join(part for part in outputs if part),
                commands, issues, duration)


def run_python_tests():
    command = [sys.executable, "-B", "-m", "unittest", "discover", "-s", "scripts/tests", "-v"]
    code, stdout, stderr, duration = run_command(command, timeout=900)
    status = "passed" if code == 0 else ("blocked" if code == 127 else "failed")
    return gate("script-tests", status, summarize_output(stdout, stderr), command, duration=duration)


def run_shell_syntax(root, paths):
    if paths:
        shell_paths = [root / path for path in paths
                       if path.startswith("scripts/") and path.endswith(".sh") and (root / path).is_file()]
    else:
        shell_paths = sorted((root / "scripts").rglob("*.sh")) if (root / "scripts").is_dir() else []
    if not shell_paths:
        return gate("shell-syntax", "skipped", "没有适用的 Shell 脚本。")
    issues = []
    started = time.monotonic()
    for path in shell_paths:
        code, stdout, stderr, _ = run_command(["bash", "-n", str(path)], root, 30)
        if code != 0:
            issues.append({"file": str(path), "detail": summarize_output(stdout, stderr)})
    status = "passed" if not issues else "failed"
    return gate("shell-syntax", status, "检查变更中的 Shell 脚本。", ["bash", "-n"], issues,
                time.monotonic() - started)


def source_paths(root, paths):
    selected = [root / path for path in paths if Path(path).suffix in SOURCE_SUFFIXES]
    if selected:
        return [path for path in selected if path.is_file() and "build" not in path.parts and ".build" not in path.parts]
    result = []
    for name in SOURCE_DIRECTORIES:
        directory = root / name
        if directory.is_dir():
            result.extend(path for path in directory.rglob("*")
                          if path.is_file() and path.suffix in SOURCE_SUFFIXES
                          and "build" not in path.parts and ".build" not in path.parts)
    return sorted(result)


PRIVATE_KEY = re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")
ACCESS_KEY = re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")
TOKEN = re.compile(
    r"\b(?:ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_\-]{20,})\b"
)
SENSITIVE_LOG = re.compile(
    r"(?:NSLog|print|Logger|logger\.[A-Za-z]+)\s*\([^\n]*(?:request\.title|\.notes\b|password|secret|clipboard|accessToken|apiKey)",
    re.IGNORECASE,
)


def security_findings(paths):
    findings = []
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError):
            continue
        for number, line in enumerate(text.splitlines(), 1):
            if "security: fixture" in line:
                continue
            if PRIVATE_KEY.search(line) or ACCESS_KEY.search(line) or TOKEN.search(line):
                findings.append({"severity": "high", "file": str(path), "line": number,
                                 "detail": "疑似硬编码凭据或私钥。"})
            elif SENSITIVE_LOG.search(line):
                findings.append({"severity": "medium", "file": str(path), "line": number,
                                 "detail": "日志可能包含用户正文、秘密或敏感标识。"})
    return findings


def run_security_check(root, paths):
    selected = source_paths(root, paths)
    findings = security_findings(selected)
    high = [item for item in findings if item["severity"] == "high"]
    medium = [item for item in findings if item["severity"] == "medium"]
    if high:
        status = "failed"
    elif medium:
        status = "warning"
    else:
        status = "passed"
    detail = f"扫描 {len(selected)} 个源码文件；高风险 {len(high)}，敏感日志候选 {len(medium)}。"
    return gate("security-static", status, detail, ["内置静态扫描"], findings)


def run_comment_check(root, paths):
    selected = [path for path in source_paths(root, paths) if path.suffix == ".swift"]
    if not selected:
        return gate("comment-contract", "skipped", "当前差异没有 Swift 源码。")
    findings = []
    marker = re.compile(r"\b(TODO|FIXME|HACK|XXX)\b")
    suppression = re.compile(r"swiftlint:(?:disable|enable)")
    for path in selected:
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (OSError, UnicodeError):
            continue
        for number, line in enumerate(lines, 1):
            if marker.search(line) and not re.search(r"(?:TODO|FIXME|HACK|XXX)\s*\([^)]{2,}\)", line):
                findings.append({"severity": "medium", "file": str(path), "line": number,
                                 "detail": "临时注释需要可追踪标识和后续动作。"})
            if suppression.search(line) and "reason:" not in line.lower():
                findings.append({"severity": "medium", "file": str(path), "line": number,
                                 "detail": "静态检查豁免需要说明 reason 和作用范围。"})
    status = "warning" if findings else "passed"
    return gate("comment-contract", status,
                "机械检查不替代人工判断注释是否解释了原因和不变量。", ["注释契约扫描"], findings)


def reject_json_constant(value):
    raise ValueError(f"JSON 不允许非有限数字：{value}")


def load_performance_manifest(root):
    path = root / "docs/performance-baselines.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"), parse_constant=reject_json_constant)
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as error:
        return None, [{"file": str(path), "detail": f"无法读取性能基线：{error}"}]
    return data, []


def run_performance_contract(root, paths, require_measurement=False):
    data, issues = load_performance_manifest(root)
    if data is None:
        return gate("performance-contract", "failed", "性能基线清单不可读。", issues=issues)
    if not isinstance(data, dict):
        issues.append({"file": "docs/performance-baselines.json", "detail": "性能基线清单顶层必须是对象。"})
        return gate("performance-contract", "failed", "性能基线清单结构无效。", issues=issues)
    entries = data.get("entries")
    if data.get("schemaVersion") != 1 or not isinstance(entries, list) or not entries:
        issues.append({"file": "docs/performance-baselines.json", "detail": "基线清单结构或版本不正确。"})
        return gate("performance-contract", "failed", "性能基线清单结构无效。", issues=issues)
    policy = data.get("measurementPolicy")
    required_measurement_fields = []
    if not isinstance(policy, dict):
        issues.append({"file": "docs/performance-baselines.json", "detail": "缺少 measurementPolicy。"})
    else:
        required_measurement_fields = policy.get("requiredFields")
        if (not isinstance(required_measurement_fields, list) or not required_measurement_fields
                or not all(isinstance(field, str) and field.strip() for field in required_measurement_fields)):
            issues.append({"file": "docs/performance-baselines.json", "detail": "measurementPolicy.requiredFields 无效。"})
            required_measurement_fields = []
    not_established = 0
    pending_entries = []
    identifiers = set()
    for entry in entries or []:
        required = {"id", "scope", "test", "testFilter", "metric", "budget", "status", "source", "note"}
        if not isinstance(entry, dict):
            issues.append({"file": "docs/performance-baselines.json", "detail": "性能条目必须是对象。"})
            continue
        missing = required - set(entry)
        if missing:
            issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry.get('id', '<unknown>')} 缺少 {sorted(missing)}。"})
            continue
        entry_id = entry["id"]
        if not isinstance(entry_id, str) or not entry_id.strip():
            issues.append({"file": "docs/performance-baselines.json", "detail": "性能条目 id 必须是非空字符串。"})
        elif entry_id in identifiers:
            issues.append({"file": "docs/performance-baselines.json", "detail": f"性能条目 id 重复：{entry_id}。"})
        else:
            identifiers.add(entry_id)
        for field in ("metric", "note"):
            if not isinstance(entry[field], str) or not entry[field].strip():
                issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry_id or '<unknown>'} 的 {field} 必须是非空字符串。"})
        if entry["status"] not in ("observed", "provisional", "not-established"):
            issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 状态无效。"})
        elif entry["status"] != "not-established":
            budget = entry["budget"]
            if (not isinstance(budget, (int, float)) or isinstance(budget, bool)
                    or not math.isfinite(budget) or budget <= 0):
                issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 缺少有限且大于零的预算。"})
            if not isinstance(entry["test"], str) or not entry["test"].strip():
                issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 已建立但缺少可执行测试。"})
            if not isinstance(entry["source"], str) or not entry["source"].strip():
                issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 已建立但缺少证据来源。"})
            if entry["status"] == "observed":
                measurement = entry.get("measurement")
                if not isinstance(measurement, dict):
                    issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} observed 条目缺少 measurement。"})
                else:
                    text_fields = [field for field in required_measurement_fields if field != "sampleCount"]
                    missing_measurement = [field for field in text_fields
                                           if not isinstance(measurement.get(field), str)
                                           or not measurement[field].strip()]
                    if missing_measurement:
                        issues.append({"file": "docs/performance-baselines.json",
                                       "detail": f"{entry['id']} measurement 缺少 {missing_measurement}。"})
                    sample_count = measurement.get("sampleCount")
                    if ("sampleCount" in required_measurement_fields
                            and (not isinstance(sample_count, int) or isinstance(sample_count, bool)
                                 or sample_count <= 0)):
                        issues.append({"file": "docs/performance-baselines.json",
                                       "detail": f"{entry['id']} measurement.sampleCount 必须为正整数。"})
        elif entry["budget"] is not None:
            issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 尚未建立却声明了预算。"})
        if entry["status"] == "not-established":
            not_established += 1
            pending_entries.append(entry)
        scope_value = entry["scope"]
        if not isinstance(scope_value, str) or not scope_value:
            issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 的 scope 无效。"})
        else:
            scope = root / scope_value
            if not scope.is_file() or not scope.resolve().is_relative_to(root.resolve()):
                issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 的 scope 不存在：{scope_value}。"})
        test = entry.get("test")
        if test is not None and (not isinstance(test, str) or not test.strip()):
            issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 的 test 无效。"})
        elif test and (not (root / test).is_file()
                       or not (root / test).resolve().is_relative_to(root.resolve())):
            issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 的 test 不存在：{test}。"})
        test_filter = entry.get("testFilter")
        if entry["status"] != "not-established":
            if not isinstance(test_filter, str) or not test_filter.startswith("AreaChainTests/"):
                issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 缺少有效 testFilter。"})
        elif test_filter is not None:
            issues.append({"file": "docs/performance-baselines.json", "detail": f"{entry['id']} 尚未建立却声明了 testFilter。"})
    manifest_changed = "docs/performance-baselines.json" in paths
    relevant_pending = [entry for entry in pending_entries
                        if manifest_changed or entry.get("scope") in paths]
    detail = (f"已核对 {len(data.get('entries', []))} 条基线；{not_established} 条仍未建立，"
              f"其中 {len(relevant_pending)} 条与当前性能范围相关。")
    if issues:
        status = "failed"
    elif require_measurement and relevant_pending:
        status = "warning"
    else:
        status = "passed"
    return gate("performance-contract", status, detail, ["读取 docs/performance-baselines.json"], issues)


def run_swiftlint(root, paths, strict=False):
    requested_swift_paths = [path for path in paths if path.endswith(".swift")]
    swift_paths = [path for path in requested_swift_paths if (root / path).is_file()]
    executable = shutil.which("swiftlint")
    if executable is None:
        return gate("swiftlint", "blocked", "未找到 swiftlint，无法提供 Swift 静态质量证据。", ["swiftlint"])
    if strict:
        if not swift_paths:
            if requested_swift_paths:
                return gate("swiftlint", "skipped", "Swift 差异仅包含已删除文件，无可 lint 的源码。")
            return gate("swiftlint", "blocked", "严格 SwiftLint 没有可核对的 Swift 差异；请提供 --base-ref 或变更文件。")
        command = [executable, "lint", "--strict", "--quiet"] + swift_paths
    else:
        # Advisory mode keeps historical debt visible without linting generated .build files.
        command = [executable, "lint", "--lenient", "--quiet", "AreaChain", "AreaChainTests"]
    code, stdout, stderr, duration = run_command(command, root, 900)
    output = summarize_output(stdout, stderr)
    if code != 0:
        status = "failed" if strict else "warning"
    elif output:
        status = "failed" if strict else "warning"
    else:
        status = "passed"
    return gate("swiftlint", status, output or "SwiftLint 没有输出问题。", command, duration=duration)


def run_swift_tests():
    command = ["./scripts/build.sh", "test"]
    code, stdout, stderr, duration = run_command(command, timeout=1800)
    status = "passed" if code == 0 else ("blocked" if code in (126, 127) else "failed")
    return gate("swift-tests", status, summarize_output(stdout, stderr), command, duration=duration)


def run_release_build():
    command = ["./scripts/build.sh", "release"]
    code, stdout, stderr, duration = run_command(command, timeout=1800)
    status = "passed" if code == 0 else ("blocked" if code in (126, 127) else "failed")
    return gate("release-candidate", status, summarize_output(stdout, stderr), command, duration=duration)


def run_performance_tests(root):
    data, issues = load_performance_manifest(root)
    if data is None or issues or not isinstance(data, dict):
        return gate("performance-tests", "failed", "无法从性能清单确定测试。", issues=issues)
    entries = data.get("entries")
    if not isinstance(entries, list):
        return gate("performance-tests", "failed", "性能清单 entries 必须是数组。")
    filters = []
    for entry in entries:
        if isinstance(entry, dict) and entry.get("status") in ("observed", "provisional"):
            value = entry.get("testFilter")
            if isinstance(value, str) and value and value not in filters:
                filters.append(value)
    if not filters:
        return gate("performance-tests", "failed", "性能清单没有已建立条目的 testFilter。")
    command = ["./scripts/build.sh", "test"]
    for value in filters:
        command.extend(["--only-testing", value])
    code, stdout, stderr, duration = run_command(command, root, 1800)
    status = "passed" if code == 0 else ("blocked" if code in (126, 127) else "failed")
    return gate("performance-tests", status, summarize_output(stdout, stderr), command, duration=duration)


def overall_status(checks, strict=False):
    statuses = {check["status"] for check in checks}
    if "failed" in statuses:
        return "failed"
    if "blocked" in statuses:
        return "blocked"
    if strict and "warning" in statuses:
        return "failed"
    if "warning" in statuses:
        return "warning"
    return "passed"


def run_profile(root, profile, strict=False, base_ref=None):
    scope_error = None
    try:
        paths = changed_files(root, base_ref)
    except RuntimeError as error:
        paths = []
        scope_error = str(error)
    selected = infer_profile(paths, root) if profile == "auto" else profile
    checks = [gate("change-scope", "blocked", scope_error, ["git", "diff"]) if scope_error
              else gate("change-scope", "passed",
                        f"已确定 {len(paths)} 个变更路径。" + (f" 基线：{base_ref}。" if base_ref else "")),
              run_workflow_check(), run_diff_check(root, paths, base_ref),
              run_performance_contract(root, paths, require_measurement=selected == "performance")]
    if selected in ("docs",):
        checks.append(run_comment_check(root, paths))
    elif selected in ("static", "swift", "performance", "full", "release"):
        scan_paths = [] if selected == "static" else paths
        checks.extend([run_python_tests(), run_shell_syntax(root, scan_paths),
                       run_security_check(root, scan_paths), run_comment_check(root, scan_paths)])
    if needs_swift_toolchain(selected):
        checks.append(run_swiftlint(root, paths, strict=strict))
        checks.append(run_swift_tests())
    if selected == "release":
        checks.append(run_release_build())
    if selected == "performance":
        checks.append(run_performance_tests(root))
    return {
        "schemaVersion": 1,
        "profile": selected,
        "requestedProfile": profile,
        "changedFiles": paths,
        "status": overall_status(checks, strict),
        "checks": checks,
        "limitations": [
            "本地门禁不证明远端 CI 已启用或分支保护已要求通过。",
            "静态安全扫描不是完整漏洞审计；真实钥匙串、日历、安装、恢复和发行需要独立授权与证据。",
            "SwiftLint 非严格模式扫描 AreaChain/AreaChainTests；--strict 只阻断本次变更涉及的 Swift 文件。",
        ],
    }


def print_report(report, output_format):
    if output_format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return
    print(f"质量门禁 profile={report['profile']} status={report['status']}")
    for check in report["checks"]:
        print(f"[{check['status']}] {check['name']}: {check['detail']}")
        for finding in check.get("issues", [])[:8]:
            print(f"  - {finding}")
    if report["limitations"]:
        print("限制：")
        for item in report["limitations"]:
            print(f"  - {item}")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=PROFILES, default="auto")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    parser.add_argument("--strict", action="store_true", help="将 warning 也作为失败")
    parser.add_argument("--base-ref", help="可选：把此 Git revision 到 HEAD 的差异纳入门禁")
    args = parser.parse_args(argv)
    report = run_profile(ROOT, args.profile, strict=args.strict, base_ref=args.base_ref)
    print_report(report, args.format)
    return 0 if report["status"] in ("passed", "warning") else 1


if __name__ == "__main__":
    sys.exit(main())
