#!/usr/bin/env python3
"""前台轮守护：用户空闲时把正在运行的 QA 测试应用切回前台。

macOS 14 起应用不能自己抢回前台，只要别的应用（例如 Claude 桌面端）停在前台，需要 key window 的
测试就会一直等到有人手动点它。测试进程外的命令行仍可激活应用，所以由 build.sh qa --keep-front 在
test-without-building 期间挂起本守护。只对 QA 独立标识生效：开发宿主与日用应用同一标识，绝不碰；
只激活已在运行的应用，不负责启动（QA 构建不经 XCTest 启动时也会被 AppLaunchPolicy 拒绝）。
"""

import os
import re
import signal
import subprocess
import sys
import time

QA_PREFIX = "com.areachain.privacy-qa"
IDLE_SECONDS = 5
INTERVAL_SECONDS = 1.0
# 兜底：即使父进程异常结束而本进程未被及时发现，也不在用户机器上长留；全量前台轮上限为 3 小时。
MAX_RUNTIME_SECONDS = 4 * 3600
# 只记录前几次切回，避免挤掉门禁说明里 xcodebuild 的失败信息；总次数由结束汇总给出。
LOGGED_ACTIVATIONS = 5


def is_qa_identifier(identifier):
    return identifier == QA_PREFIX or identifier.startswith(QA_PREFIX + ".")


def _output(arguments):
    try:
        return subprocess.run(arguments, capture_output=True, text=True, timeout=5, check=False).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def idle_seconds(read=_output):
    """距上次键盘/鼠标输入的秒数；读不到时按 0 处理，宁可不动也不和用户抢前台。"""
    match = re.search(r'"HIDIdleTime"\s*=\s*(\d+)', read(["ioreg", "-c", "IOHIDSystem"]))
    return int(match.group(1)) / 1_000_000_000 if match else 0.0


def frontmost(read=_output):
    asn = read(["lsappinfo", "front"]).strip()
    match = re.search(r'"CFBundleIdentifier"\s*=\s*"([^"]+)"', read(["lsappinfo", "info", "-only", "bundleid", asn]))
    return match.group(1) if match else ""


def is_running(identifier, read=_output):
    return "ASN:" in read(["lsappinfo", "find", f"bundleid={identifier}"])


def tick(identifier, read=_output, activate=None):
    """一次检查；发出激活时返回当时的前台应用标识，否则返回 None。"""
    if idle_seconds(read) < IDLE_SECONDS:
        return None
    current = frontmost(read)
    if current == identifier or not is_running(identifier, read):
        return None
    (activate or (lambda: subprocess.run(["open", "-b", identifier], capture_output=True, timeout=5, check=False)))()
    return current or "unknown"


def main(argv=None):
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 1 or not is_qa_identifier(args[0]):
        sys.stderr.write("keep_front 只接受 QA 独立标识（com.areachain.privacy-qa…）。\n")
        return 2
    activations = 0
    parent = os.getppid()
    deadline = time.monotonic() + MAX_RUNTIME_SECONDS

    def stop(*_):
        raise KeyboardInterrupt

    # build.sh 在测试结束后用 SIGTERM 结束守护；Ctrl-C 时后台进程继承了忽略 SIGINT，这里显式接管。
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        # 父进程（build.sh 的测试脚本）被 SIGKILL 时本进程会被重新挂到别的父进程下，此时立即退出。
        while os.getppid() == parent and time.monotonic() < deadline:
            previous = tick(args[0])
            if previous:
                activations += 1
                if activations <= LOGGED_ACTIVATIONS:
                    sys.stderr.write(f"keep_front {time.strftime('%H:%M:%S')}：前台为 {previous}，已切回 {args[0]}。\n")
                    sys.stderr.flush()
            time.sleep(INTERVAL_SECONDS)
    except KeyboardInterrupt:
        pass
    finally:
        sys.stderr.write(f"keep_front：空闲时把 {args[0]} 切回前台 {activations} 次。\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
