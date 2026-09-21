#!/usr/bin/env python3
"""只读核对构建配置与签名产物；不创建证书、不修改钥匙串、不启动应用。"""

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]


class SigningError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise SigningError(message)


def run_tool(arguments):
    result = subprocess.run(arguments, capture_output=True, timeout=60, check=False)
    if result.returncode:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        raise SigningError(f"{arguments[0]} 检查失败：{detail}")
    return result


def validate_settings(settings):
    mode = settings.get("AREACHAIN_SIGNING_MODE", "")
    bundle = settings.get("PRODUCT_BUNDLE_IDENTIFIER", "")
    team = settings.get("DEVELOPMENT_TEAM", "")
    identity = settings.get("CODE_SIGN_IDENTITY", "")
    require(all(isinstance(value, str) for value in (mode, bundle, team, identity)), "签名配置字段必须为字符串。")
    require(mode in ("local", "development"), "签名模式仅支持 local 或 development。")
    require(re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle), "应用标识格式不正确。")
    require(settings.get("CODE_SIGNING_ALLOWED", "YES") != "NO", "当前配置禁用了签名。")
    entitlement_file = Path(settings.get("CODE_SIGN_ENTITLEMENTS", "")).name
    if mode == "development":
        require(re.fullmatch(r"[A-Z0-9]{10}", team) and team != "YOURTEAMID", "请填写你自己的 10 位 Team ID。")
        require(bundle != "com.example.yourname.areachain", "请替换示例应用标识。")
        require(identity.startswith("Apple Development"), "开发模式须使用 Apple Development 签名。")
        require(entitlement_file == "AreaChain.SystemUnlock.entitlements", "开发模式缺少系统解锁权限配置。")
    else:
        require(identity == "-" and not team, "本机模式不能混入开发团队或证书签名。")
        require(entitlement_file == "AreaChain.entitlements", "本机模式不应启用受限钥匙串权限。")
    return {"mode": mode, "bundleIdentifier": bundle, "teamIdentifier": team,
            "systemUnlockConfigured": mode == "development", "distributionReady": False}


def read_settings(configuration):
    result = run_tool(["xcodebuild", "-project", str(ROOT / "AreaChain.xcodeproj"),
                       "-target", "AreaChain", "-configuration", configuration,
                       "-showBuildSettings", "-json"])
    entries = json.loads(result.stdout)
    target = next((entry for entry in entries if entry.get("target") == "AreaChain"), None)
    require(target is not None, "未找到 AreaChain 的有效构建配置。")
    return validate_settings(target["buildSettings"])


def parse_signature(output):
    result = {}
    code_directories = []
    for line in output.splitlines():
        if "=" in line and not line.startswith("designated"):
            key, value = line.split("=", 1)
            result[key] = value
            if key == "CodeDirectory v":
                code_directories.append(value)
    if code_directories:
        result["CodeDirectories"] = code_directories
    return result


def has_hardened_runtime(metadata):
    dirs = metadata.get("CodeDirectories") or ([metadata["CodeDirectory v"]] if "CodeDirectory v" in metadata else [])
    if not dirs:
        return False
    for item in dirs:
        flags = re.search(r"flags=0x[0-9a-fA-F]+\(([^)]*)\)", item)
        if flags is None or "runtime" not in flags.group(1).split(","):
            return False
    return True


def validate_hardening(metadata, mode):
    enabled = has_hardened_runtime(metadata)
    if mode == "development":
        require(enabled, "开发签名产物未开启 Hardened Runtime。")
    return enabled


def allows_value(patterns, value):
    return any(pattern == value or (pattern.endswith("*") and value.startswith(pattern[:-1]))
               for pattern in patterns if isinstance(pattern, str))


def validate_profile(profile, entitlements, expected, certificate_hash, now):
    team, bundle = expected["teamIdentifier"], expected["bundleIdentifier"]
    allowed = profile.get("Entitlements", {})
    app_id = entitlements.get("com.apple.application-identifier", "")
    require(isinstance(app_id, str) and app_id.endswith("." + bundle), "签名中的应用标识不匹配。")
    require(team in profile.get("TeamIdentifier", []), "描述文件不属于当前开发团队。")
    require(entitlements.get("com.apple.developer.team-identifier") == team, "签名中的 Team ID 不匹配。")
    require(allows_value([allowed.get("com.apple.application-identifier", "")], app_id),
            "描述文件没有授权当前应用标识。")
    require(entitlements.get("keychain-access-groups") == [app_id], "钥匙串访问组必须仅限当前应用。")
    require(allows_value(allowed.get("keychain-access-groups", []), app_id), "描述文件未授权钥匙串访问组。")
    certificates = {hashlib.sha256(value).hexdigest() for value in profile.get("DeveloperCertificates", [])}
    require(certificate_hash in certificates, "实际签名证书不在描述文件允许列表内。")
    expires = profile.get("ExpirationDate")
    require(isinstance(expires, dt.datetime), "描述文件缺少有效期。")
    expires = expires.replace(tzinfo=dt.timezone.utc) if expires.tzinfo is None else expires
    require(expires > now, "开发描述文件已过期，需要先通过 Xcode 续签。")
    return {"profileUUID": profile.get("UUID"), "profileExpiresUTC": expires.isoformat(),
            "remainingHours": int((expires - now).total_seconds() // 3600)}


def validate_release(entitlements, relative_files):
    require(not entitlements.get("get-task-allow")
            and not entitlements.get("com.apple.security.get-task-allow"), "Release 包带有调试权限。")
    require(not any(key.startswith("com.apple.security.temporary-exception.") for key in entitlements),
            "Release 包带有临时测试权限，不能作为日用候选包。")
    forbidden = ("AreaChainTests.xctest", "XCTest", "XCUnit.framework", "XCUIAutomation.framework",
                 "XCTAutomationSupport.framework", "Testing.framework", "libMainThreadChecker")
    require(not any(token in path for path in relative_files for token in forbidden),
            "Release 包含测试组件，须重新执行正常 Release 构建。")


def verify_development_anchor(app, team):
    require(re.fullmatch(r"[A-Z0-9]{10}", team), "开发团队标识格式不正确。")
    requirement = f'=anchor apple generic and certificate leaf[subject.OU] = "{team}"'
    run_tool(["codesign", "--verify", "--strict", "-R", requirement, str(app)])


def certificate_hash(app):
    # 仅提取公有证书做匹配，不导出或读取签名私钥。
    with tempfile.TemporaryDirectory(prefix="areachain-public-certificate-") as directory:
        prefix = str(Path(directory) / "certificate-")
        run_tool(["codesign", "-d", "--extract-certificates=" + prefix, str(app)])
        return hashlib.sha256(Path(prefix + "0").read_bytes()).hexdigest()


def verify_app(app, configuration, expected):
    require(app.is_dir() and not app.is_symlink(), "应用目录不存在，或应用路径是符号链接。")
    run_tool(["codesign", "--verify", "--deep", "--strict", str(app)])
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    require(info.get("CFBundleIdentifier") == expected["bundleIdentifier"], "产物与当前配置的应用标识不同。")
    details = run_tool(["codesign", "-d", "--verbose=4", str(app)])
    metadata = parse_signature(details.stderr.decode("utf-8", errors="replace"))
    signed = run_tool(["codesign", "-d", "--entitlements", "-", "--xml", str(app)])
    entitlements = plistlib.loads(signed.stdout) if signed.stdout.strip() else {}
    require(entitlements.get("com.apple.security.app-sandbox") is True, "产物未开启应用沙盒。")
    hardened = validate_hardening(metadata, expected["mode"])
    if configuration == "Release":
        validate_release(entitlements, [str(path.relative_to(app)) for path in app.rglob("*")])
    profile_path = app / "Contents/embedded.provisionprofile"
    result = {**expected, "app": str(app), "configuration": configuration,
              "bundleVersion": info.get("CFBundleVersion"), "staticSignatureVerified": True,
              "hardenedRuntime": hardened}
    if expected["mode"] == "development":
        require(metadata.get("TeamIdentifier") == expected["teamIdentifier"], "实际签名团队不匹配。")
        verify_development_anchor(app, expected["teamIdentifier"])
        require(profile_path.is_file(), "系统解锁产物缺少嵌入的开发描述文件。")
        profile = plistlib.loads(run_tool(["security", "cms", "-D", "-i", str(profile_path)]).stdout)
        result.update(validate_profile(profile, entitlements, expected, certificate_hash(app),
                                       dt.datetime.now(dt.timezone.utc)))
    else:
        require(metadata.get("Signature") == "adhoc", "本机模式产物并非临时签名。")
        require(not entitlements.get("keychain-access-groups") and not profile_path.exists(),
                "本机模式残留受限权限或描述文件，请使用独立构建目录。")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "verify"))
    parser.add_argument("--configuration", choices=("Debug", "Release"), default="Debug")
    parser.add_argument("--app", type=Path)
    args = parser.parse_args()
    if args.command == "verify" and args.app is None:
        parser.error("verify 必须指定 --app。")
    try:
        expected = read_settings(args.configuration)
        if args.command == "verify":
            require(args.app is not None, "verify 必须指定 --app。")
            expected = verify_app(args.app.absolute(), args.configuration, expected)
        print(json.dumps(expected, ensure_ascii=False, indent=2))
    except (SigningError, OSError, ValueError, TypeError, KeyError, subprocess.TimeoutExpired) as error:
        print(f"签名检查未通过：{error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
