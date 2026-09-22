#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

usage() {
    cat <<'EOF'
用法: ./scripts/build.sh [命令] [选项]

  （无参数） / build  只构建 Debug，不安装、不启动
  release            只构建并核验 Release；开发签名不等于公证发行
  test               串行单测；清除调用环境中的真实钥匙串授权
  check-signing      只读检查有效签名配置
  verify             核验已构建产物的签名、权限及描述文件
  help               显示本说明

选项:
  --configuration Debug|Release  check-signing / verify 的构建配置
  --allow-provisioning           仅 build / release：显式允许 Xcode 联网管理签名资源和设备注册
  --only-testing 标识            仅 test：限制测试范围，可重复指定；缺省命令时自动推导为 test
  --no-wait                      多会话竞争构建锁时不自动排队等待，直接退出

安装请使用 ./scripts/install.sh（开发中默认增量安装 Debug；--release 才安装优化包）。状态、启动与卸载见 ./scripts/app.sh --help。
请按 docs/signing.md 完成数据备份和签名身份核对。
脚本不替换 /Applications 中的应用，不启动应用，不保存任何账号密码。
多会话同时执行构建或测试时会自动安全排队，避免冲突。
EOF
}

fail() { printf '%s\n' "$*" >&2; exit 2; }

command_name=""
configuration="Debug"
configuration_set="NO"
allow_provisioning="NO"
wait_for_lock="YES"
test_filters=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration)
            [[ $# -ge 2 ]] || fail "--configuration 缺少参数。"
            configuration="$2"; configuration_set="YES"; shift 2 ;;
        --allow-provisioning) allow_provisioning="YES"; shift ;;
        --only-testing)
            [[ $# -ge 2 ]] || fail "--only-testing 缺少参数。"
            test_filters+=("-only-testing:$2"); shift 2 ;;
        --no-wait) wait_for_lock="NO"; shift ;;
        -h|--help|help) usage; exit 0 ;;
        -*) fail "未知选项：$1" ;;
        *)
            if [[ -z "$command_name" ]]; then
                command_name="$1"; shift
            else
                fail "未知参数：$1"
            fi
            ;;
    esac
done

if [[ -z "$command_name" ]]; then
    if [[ ${#test_filters[@]} -gt 0 ]]; then
        command_name="test"
    else
        command_name="build"
    fi
fi

if [[ "$configuration_set" == "YES" && "$command_name" != "check-signing" && "$command_name" != "verify" ]]; then
    fail "--configuration 仅用于 check-signing / verify；构建 Release 请使用 release 命令。"
fi
case "$command_name" in
    help|-h|--help) usage; exit 0 ;;
    install) fail "安装入口已独立：请使用 ./scripts/install.sh，先查看 --help 或 --dry-run。" ;;
    release) configuration="Release" ;;
    build|test) [[ "$configuration" == "Debug" ]] || fail "请使用 release 命令生成 Release 包。" ;;
    check-signing|verify) ;;
    *) fail "未知命令：$command_name" ;;
esac
[[ "$configuration" == "Debug" || "$configuration" == "Release" ]] || fail "构建配置必须为 Debug 或 Release。"
if [[ "$allow_provisioning" == "YES" && "$command_name" != "build" && "$command_name" != "release" ]]; then
    fail "只有 build / release 可以显式允许签名资源写入。"
fi
[[ "$command_name" == "test" || ${#test_filters[@]} -eq 0 ]] || fail "--only-testing 仅用于 test。"

settings="$(python3 scripts/signing.py check --configuration "$configuration")"
if [[ "$command_name" == "check-signing" ]]; then
    printf '%s\n' "$settings"
    exit 0
fi
signing_mode="$(printf '%s' "$settings" | python3 -c 'import json, sys; print(json.load(sys.stdin)["mode"])')"
derived_data="$project_root/build/$signing_mode-DerivedData"
candidate_app="$derived_data/Build/Products/$configuration/AreaChain.app"

verify_candidate() {
    python3 scripts/signing.py verify --configuration "$configuration" --app "$candidate_app"
}

[[ "$command_name" != "verify" ]] || { verify_candidate; exit 0; }

lock_file="$project_root/build/.build.lock"

run_with_lock() {
    local wait_flag="$1"
    shift
    python3 -B -c '
import fcntl, os, sys, time, subprocess

lock_path = sys.argv[1]
wait = sys.argv[2] == "YES"
cmd = sys.argv[3:]

os.makedirs(os.path.dirname(os.path.abspath(lock_path)), exist_ok=True)
descriptor = os.open(lock_path, os.O_CREAT | os.O_RDWR, 0o644)
acquired = False

try:
    fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
    acquired = True
except (BlockingIOError, IOError):
    if not wait:
        sys.stderr.write("已设置 --no-wait，检测到其他构建或测试任务正在执行，已取消。\n")
        sys.exit(3)
    try:
        content = os.read(descriptor, 128).decode("utf-8", errors="replace").strip()
    except Exception:
        content = ""
    holder = content or "未知"
    sys.stderr.write(f"⏳ 检测到其他构建或测试任务正在执行 (持有锁 PID: {holder})，正在自动排队等待...\n")
    sys.stderr.flush()
    deadline = time.time() + 900
    while time.time() < deadline:
        try:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
            acquired = True
            break
        except (BlockingIOError, IOError):
            time.sleep(0.5)
    if not acquired:
        sys.stderr.write("等待构建锁超时 (15 分钟)，停止操作。\n")
        sys.exit(3)
    sys.stderr.write("✓ 已获得构建锁，继续执行。\n")
    sys.stderr.flush()

try:
    os.ftruncate(descriptor, 0)
    os.lseek(descriptor, 0, os.SEEK_SET)
    os.write(descriptor, f"{os.getpid()}\n".encode("utf-8"))
except Exception:
    pass

try:
    proc = subprocess.run(cmd)
    sys.exit(proc.returncode)
finally:
    try:
        os.ftruncate(descriptor, 0)
        fcntl.flock(descriptor, fcntl.LOCK_UN)
        os.close(descriptor)
    except Exception:
        pass
' "$lock_file" "$wait_flag" "$@"
}

build_arguments=(-quiet -project AreaChain.xcodeproj -scheme AreaChain -configuration "$configuration"
                 -destination 'platform=macOS' -derivedDataPath "$derived_data")
if [[ "$allow_provisioning" == "YES" ]]; then
    [[ "$signing_mode" == "development" ]] || fail "本机临时签名模式不需要联网申请签名资源。"
    printf '%s\n' "已显式允许 Xcode 创建/更新应用标识、描述文件和证书，并在必要时注册设备。"
    build_arguments+=(-allowProvisioningUpdates -allowProvisioningDeviceRegistration)
fi

if [[ "$command_name" == "test" ]]; then
    if [[ ${#test_filters[@]} -gt 0 ]]; then build_arguments+=("${test_filters[@]}"); fi
    # 普通单测不能继承调用者留下的真实钥匙串授权。
    run_with_lock "$wait_for_lock" env -u AREACHAIN_SYSTEM_KEYCHAIN_QA -u AREACHAIN_SYSTEM_KEYCHAIN_RUN_ID \
        -u AREACHAIN_SYSTEM_KEYCHAIN_PHASE -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_QA \
        -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_RUN_ID -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_PHASE \
        xcodebuild "${build_arguments[@]}" -parallel-testing-enabled NO test
else
    run_with_lock "$wait_for_lock" xcodebuild "${build_arguments[@]}" build
    verify_candidate
    printf '产物仅保存在：%s\n' "$candidate_app"
fi
