#!/usr/bin/env python3
"""管理本机 AreaChain 应用；不修改用户数据、钥匙串、证书或系统信任。"""

import argparse
from contextlib import contextmanager
from dataclasses import dataclass
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile

import signing


class AppError(ValueError):
    pass


@dataclass(frozen=True)
class Locations:
    project: Path
    applications: Path
    user: Path

    @property
    def app(self):
        return self.applications / "AreaChain.app"

    @property
    def backups(self):
        return self.user / "Library/Application Support/AreaChain-InstallBackups"

    def privacy_configuration(self, bundle):
        return self.user / "Library/Containers" / bundle / "Data/Library/Application Support/areachain-privacy.json"


def require(condition, message):
    if not condition:
        raise AppError(message)


def exists(path):
    return os.path.lexists(path)


def real_path(path):
    require(path.is_absolute() and path.resolve() == path, f"不接受符号链接或未规范化的路径：{path}")


def bundle_info(app):
    real_path(app)
    require(app.is_dir(), f"应用不存在：{app}")
    info_path = app / "Contents/Info.plist"
    real_path(info_path)
    info = plistlib.loads(info_path.read_bytes())
    require(isinstance(info, dict), "应用 Info.plist 必须是字典。")
    bundle = info.get("CFBundleIdentifier", "")
    require(isinstance(bundle, str) and re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle),
            "应用标识无效，停止操作。")
    require(info.get("CFBundleExecutable") == "AreaChain", "目标不是预期的 AreaChain 应用。")
    return info


def inspect_signature(app):
    info = bundle_info(app)
    details = signing.run_tool(["codesign", "-d", "--verbose=4", str(app)]).stderr.decode("utf-8", errors="replace")
    metadata = signing.parse_signature(details)
    encoded = signing.run_tool(["codesign", "-d", "--entitlements", "-", "--xml", str(app)]).stdout
    entitlements = plistlib.loads(encoded) if encoded.strip() else {}
    require(isinstance(entitlements, dict), "签名权限必须是字典。")
    authorities = [line.removeprefix("Authority=") for line in details.splitlines() if line.startswith("Authority=")]
    mode = "local" if metadata.get("Signature") == "adhoc" else "development"
    require(mode == "local" or (authorities and authorities[0].startswith("Apple Development:")),
            "此工具仅管理本机临时签名或 Apple Development 构建。")
    groups = entitlements.get("keychain-access-groups", [])
    require(isinstance(groups, list) and all(isinstance(group, str) for group in groups), "钥匙串访问组格式无效。")
    return {"mode": mode, "bundleIdentifier": info["CFBundleIdentifier"],
            "teamIdentifier": "" if mode == "local" else metadata.get("TeamIdentifier", ""),
            "applicationIdentifier": entitlements.get("com.apple.application-identifier", ""),
            "keychainGroups": sorted(groups), "codeHash": metadata.get("CDHash", "")}


def access_identity(signature):
    return {key: value for key, value in signature.items() if key != "codeHash"}


def running():
    result = subprocess.run(["pgrep", "-x", "AreaChain"], capture_output=True, timeout=10, check=False)
    require(result.returncode in (0, 1), "无法确认 AreaChain 是否仍在运行，停止操作。")
    return result.returncode == 0


def stopped():
    require(not running(), "请先在 AreaChain 中保存内容并正常退出，再重新执行；脚本不会强制结束进程。")


def installed_signature(paths):
    if not exists(paths.app):
        return None
    result = inspect_signature(paths.app)
    # 允许更新已过期的描述文件，但不把破损旧包当作已验证的回退材料。
    signing.run_tool(["codesign", "--verify", "--deep", "--strict", str(paths.app)])
    return result


def verify_candidate(app, expected):
    info = bundle_info(app)
    require(not re.search(r"(?:^|[.-])(?:qa|tests?|baseline)(?:$|[.-])", info["CFBundleIdentifier"], re.I),
            "QA／测试应用不能安装为日用 AreaChain。")
    return signing.verify_app(app, "Release", expected)


def check_access(paths, candidate, previous):
    if previous is not None:
        require(access_identity(previous) == access_identity(candidate),
                "签名团队、模式、应用标识或钥匙串访问组发生变化。请单独验证备份与签名迁移，不能自动替换。")
    else:
        require(not exists(paths.privacy_configuration(candidate["bundleIdentifier"])),
                "检测到遗留私密锁但找不到已安装应用，无法核对原签名身份；请先按备份恢复流程处理。")


def show(value):
    print(json.dumps(value, ensure_ascii=False, indent=2), flush=True)


def confirm(action, yes):
    require(os.geteuid() != 0, "请以当前用户运行，不要使用 sudo。")
    if yes:
        return
    require(sys.stdin.isatty(), "非交互环境默认不执行。确认操作范围后，可显式传入 --yes。")
    message = ("确认已保存退出，并已完成必要的数据备份／恢复验证。此操作只替换应用，启动新版可能升级数据。"
               if action == "install" else "只移走应用，保留全部数据、私密锁、钥匙串和证书。")
    print(message, flush=True)
    require(input(f"输入 {action.upper()} 确认，其余输入取消：").strip() == action.upper(), "已取消，未修改安装状态。")


def recovery_root(paths):
    real_path(paths.applications)
    real_path(paths.backups)
    require(paths.applications.is_dir() and os.access(paths.applications, os.W_OK),
            "没有应用目录写入权限，停止操作；不会自动提权。")
    paths.backups.mkdir(mode=0o700, parents=True, exist_ok=True)
    attributes = paths.backups.stat()
    require(attributes.st_uid == os.getuid() and attributes.st_mode & 0o077 == 0,
            "回退目录必须由当前用户所有且仅当前用户可访问；不会擅自修改已有目录权限。")
    require(attributes.st_dev == paths.applications.stat().st_dev,
            "应用目录与回退目录不在同一文件系统，无法安全重命名；停止自动操作。")
    return paths.backups


def recovery_directory(paths, action):
    root = recovery_root(paths)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return Path(tempfile.mkdtemp(prefix=f"{action}-{stamp}-", dir=root))


@contextmanager
def operation_lock(paths):
    lock_path = recovery_root(paths) / ".app-manager.lock"
    descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        attributes = os.fstat(descriptor)
        require(stat.S_ISREG(attributes.st_mode) and attributes.st_uid == os.getuid()
                and attributes.st_mode & 0o077 == 0 and attributes.st_nlink == 1,
                "安装锁必须是当前用户独占的普通文件；停止操作。")
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise AppError("另一项安装或卸载正在执行，请等待其结束后重试。") from error
        yield
    finally:
        # 保留锁文件，避免等待者与新进程锁住不同 inode；关闭描述符即释放锁。
        os.close(descriptor)


def unchanged(paths, previous):
    stopped()
    require(installed_signature(paths) == previous, "确认后已安装应用发生变化，停止替换。")


def switch_app(paths, staged, recovery, expected):
    old = recovery / "AreaChain.app"
    had_old = exists(paths.app)
    installed_new = False
    if had_old:
        os.rename(paths.app, old)
    try:
        os.rename(staged, paths.app)
        installed_new = True
        verify_candidate(paths.app, expected)
    except (Exception, KeyboardInterrupt) as error:
        try:
            if installed_new:
                os.rename(paths.app, staged)
            if had_old:
                os.rename(old, paths.app)
        except OSError as rollback_error:
            raise AppError(f"安装失败且自动回退未完成。请保留 {recovery} 中的原应用：{rollback_error}") from error
        raise AppError("安装未通过，已恢复安装前状态；用户数据未操作。") from error


def replace_app(paths, source, expected, previous, candidate):
    recovery = recovery_directory(paths, "install")
    stage = None
    try:
        stage = Path(tempfile.mkdtemp(prefix=".areachain-install-", dir=paths.applications))
        staged = stage / "AreaChain.app"
        signing.run_tool(["ditto", "--rsrc", "--extattr", str(source), str(staged)])
        verify_candidate(staged, expected)
        require(inspect_signature(staged) == candidate,
                "暂存包与已确认的候选包不同，构建产物可能已改变；停止安装。")
        unchanged(paths, previous)
        check_access(paths, candidate, previous)
        show({"recoveryDirectory": str(recovery), "dataBackupCreated": False})
        switch_app(paths, staged, recovery, expected)
    finally:
        # 暂存目录只包含本次候选包副本；原应用始终保留在独立的回退目录。
        if stage is not None and stage.is_dir() and not stage.is_symlink():
            shutil.rmtree(stage)
        if recovery.is_dir() and not any(recovery.iterdir()):
            recovery.rmdir()
    return str(recovery / "AreaChain.app") if recovery.exists() else None


def install(args, paths):
    real_path(paths.applications)
    if not args.dry_run:
        require(os.geteuid() != 0, "请以当前用户运行，不要使用 sudo。")
        stopped()
        if not args.no_build:
            result = subprocess.run([str(paths.project / "scripts/build.sh"), "release"], check=False)
            require(result.returncode == 0, "Release 构建失败，未安装。需要续签时请单独使用 build.sh release --allow-provisioning。")
    expected = signing.read_settings("Release")
    source = paths.project / f"build/{expected['mode']}-DerivedData/Build/Products/Release/AreaChain.app"
    verified = verify_candidate(source, expected)
    candidate = inspect_signature(source)
    previous = installed_signature(paths)
    check_access(paths, candidate, previous)
    show({"action": "install", "dryRun": args.dry_run, "target": str(paths.app),
          "candidate": str(source), "running": running(), "dataPreserved": True,
          "profileExpiresUTC": verified.get("profileExpiresUTC")})
    if args.dry_run:
        return
    confirm("install", args.yes)
    with operation_lock(paths):
        backup = replace_app(paths, source, expected, previous, candidate)
    show({"installed": True, "previousApp": backup, "dataPreserved": True})
    if not args.no_open:
        launch(paths)


def uninstall(args, paths):
    real_path(paths.applications)
    info = bundle_info(paths.app) if exists(paths.app) else None
    original = paths.app.stat() if info is not None else None
    show({"action": "uninstall", "dryRun": args.dry_run, "target": str(paths.app),
          "installed": info is not None, "running": running(), "dataPreserved": True,
          "keychainPreserved": True, "recoveryRoot": str(paths.backups)})
    if args.dry_run or info is None:
        return
    stopped()
    confirm("uninstall", args.yes)
    with operation_lock(paths):
        stopped()
        require(bundle_info(paths.app) == info, "确认后应用发生变化，停止卸载。")
        current = paths.app.stat()
        require((current.st_dev, current.st_ino) == (original.st_dev, original.st_ino),
                "确认后应用被替换，停止卸载。")
        recovery = recovery_directory(paths, "uninstall")
        try:
            os.rename(paths.app, recovery / "AreaChain.app")
        except OSError:
            recovery.rmdir()
            raise
    show({"uninstalled": True, "recoverableApp": str(recovery / "AreaChain.app"),
          "dataPreserved": True, "keychainPreserved": True})


def launch(paths):
    signature = inspect_signature(paths.app)
    verify_candidate(paths.app, signature)
    result = subprocess.run(["open", str(paths.app)], check=False, timeout=30)
    require(result.returncode == 0, "应用已保留在安装目录，但启动请求失败；未自动回退应用或数据。")
    show({"launchRequested": True, "app": str(paths.app), "runtimeVerified": False})


def status(paths):
    real_path(paths.applications)
    result = {"app": str(paths.app), "installed": exists(paths.app), "running": running(),
              "recoveryRoot": str(paths.backups)}
    if result["installed"]:
        try:
            signature = inspect_signature(paths.app)
            result["signature"] = verify_candidate(paths.app, signature)
        except (OSError, ValueError, TypeError, KeyError, subprocess.TimeoutExpired) as error:
            result["verificationError"] = str(error)
    show(result)
    return "verificationError" not in result


def parser():
    command = argparse.ArgumentParser(prog="./scripts/app.sh", description=__doc__)
    commands = command.add_subparsers(dest="command", required=True)
    install_command = commands.add_parser("install", help="构建、验签、确认后安装 Release 并请求启动")
    install_command.add_argument("--no-build", action="store_true", help="安装已有 Release，不重新构建")
    install_command.add_argument("--no-open", action="store_true", help="安装后不启动")
    uninstall_command = commands.add_parser("uninstall", aliases=["delete"], help="只卸载应用，保留数据与密钥")
    for item in (install_command, uninstall_command):
        action = item.add_mutually_exclusive_group()
        action.add_argument("--dry-run", action="store_true", help="只检查，不构建、不复制、不安装或卸载")
        action.add_argument("--yes", action="store_true", help="显式确认操作范围；安装时同时确认已完成必要的数据备份")
    commands.add_parser("status", help="只读查看安装、进程和签名状态")
    commands.add_parser("start", help="验签后请求启动已安装应用")
    return command


def main(arguments=None, paths=None):
    args = parser().parse_args(arguments)
    paths = paths or Locations(signing.ROOT, Path("/Applications"), Path.home())
    try:
        if args.command == "install":
            install(args, paths)
        elif args.command in ("uninstall", "delete"):
            uninstall(args, paths)
        elif args.command == "start":
            launch(paths)
        else:
            return 0 if status(paths) else 1
        return 0
    except (AppError, signing.SigningError, OSError, ValueError, TypeError, KeyError,
            subprocess.TimeoutExpired, EOFError, KeyboardInterrupt) as error:
        print(f"操作未完成：{error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
