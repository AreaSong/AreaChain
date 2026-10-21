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
  qa / qa-compile    完整隔离 PrivacyQA 测试 / 仅编译验签；使用 Config/QA.xcconfig
  check-signing      只读检查有效签名配置
  verify             核验已构建产物的签名、权限及描述文件
  help               显示本说明

选项:
  --configuration Debug|Release  check-signing / verify 的构建配置
  --allow-provisioning           仅 build / release：显式允许 Xcode 联网管理签名资源和设备注册
  --only-testing 标识            test / qa：限制测试范围，可重复指定；缺省命令时自动推导为 test
  --skip-testing 标识            test / qa：排除测试，可重复指定；用于把后台套件和前台套件分两轮跑
  --qa-batch 名称                qa / qa-compile：本批小写字母数字/连字符，隔离目录与应用标识
  --keep-front / --no-keep-front 仅 qa：测试期间用户空闲 5 秒以上时把 QA 应用切回前台。默认开启；
                                 只选中后台套件（.backgroundWindow）时自动关闭，不打扰用户
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
keep_front="AUTO"
test_filters=()
qa_batch=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configuration)
            [[ $# -ge 2 ]] || fail "--configuration 缺少参数。"
            configuration="$2"; configuration_set="YES"; shift 2 ;;
        --allow-provisioning) allow_provisioning="YES"; shift ;;
        --only-testing)
            [[ $# -ge 2 ]] || fail "--only-testing 缺少参数。"
            test_filters+=("-only-testing:$2"); shift 2 ;;
        --skip-testing)
            [[ $# -ge 2 ]] || fail "--skip-testing 缺少参数。"
            test_filters+=("-skip-testing:$2"); shift 2 ;;
        --no-wait) wait_for_lock="NO"; shift ;;
        --keep-front) keep_front="YES"; shift ;;
        --no-keep-front) keep_front="NO"; shift ;;
        --qa-batch)
            [[ $# -ge 2 && "$2" =~ ^[a-z0-9][a-z0-9-]{0,39}$ ]] || fail "--qa-batch 必须是 1～40 位小写字母、数字或连字符。"
            qa_batch="$2"; shift 2 ;;
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
    build|test|qa|qa-compile) [[ "$configuration" == "Debug" ]] || fail "请使用 release 命令生成 Release 包。" ;;
    check-signing|verify) ;;
    *) fail "未知命令：$command_name" ;;
esac
[[ "$configuration" == "Debug" || "$configuration" == "Release" ]] || fail "构建配置必须为 Debug 或 Release。"
if [[ "$allow_provisioning" == "YES" && "$command_name" != "build" && "$command_name" != "release" ]]; then
    fail "只有 build / release 可以显式允许签名资源写入。"
fi
[[ "$command_name" == "test" || "$command_name" == "qa" || ${#test_filters[@]} -eq 0 ]] || fail "--only-testing / --skip-testing 仅用于 test / qa。"
[[ -z "$qa_batch" || "$command_name" == "qa" || "$command_name" == "qa-compile" ]] || fail "--qa-batch 仅用于 qa / qa-compile。"
# 只对 QA 独立标识切前台；开发宿主与日用应用同一标识，绝不能被守护激活。
[[ "$keep_front" == "AUTO" || "$command_name" == "qa" ]] || fail "--keep-front / --no-keep-front 仅用于 qa。"
if [[ "$command_name" == "qa" && "$keep_front" == "AUTO" ]]; then
    # 默认开启：执行会话直接调用 build.sh qa 时也不用等人去点测试窗口。
    # 只选中后台套件时关闭；判断失败（脚本缺失等）按需要前台处理，宁可开启也不让测试卡住。
    keep_front="YES"
    if [[ ${#test_filters[@]} -gt 0 ]] && python3 -B scripts/swift_test_scope.py --background-only "${test_filters[@]}" 2>/dev/null; then
        keep_front="NO"
    fi
fi
if [[ "$command_name" == "qa" ]]; then
    printf '前台守护：%s\n' "$([[ "$keep_front" == "YES" ]] && echo "开启（空闲 5 秒以上时把 QA 应用切回前台）" || echo "关闭")" >&2
fi

if [[ "$command_name" == "qa" || "$command_name" == "qa-compile" ]]; then
    settings='{"mode":"local"}'
else
    settings="$(python3 scripts/signing.py check --configuration "$configuration")"
fi
if [[ "$command_name" == "check-signing" ]]; then
    printf '%s\n' "$settings"
    exit 0
fi
signing_mode="$(printf '%s' "$settings" | python3 -c 'import json, sys; print(json.load(sys.stdin)["mode"])')"
derived_data="$project_root/build/$signing_mode-DerivedData"
if [[ "$command_name" == "qa" || "$command_name" == "qa-compile" ]]; then
    derived_data="$project_root/build/PrivacyQA"
    qa_identifier="com.areachain.privacy-qa"
    if [[ -n "$qa_batch" ]]; then
        derived_data="$derived_data-$qa_batch"
        qa_identifier="$qa_identifier.$qa_batch"
    fi
fi
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

if [[ "$command_name" == "qa" || "$command_name" == "qa-compile" ]]; then
    build_arguments+=(-xcconfig Config/QA.xcconfig "AREACHAIN_QA_IDENTIFIER=$qa_identifier")
    if [[ ${#test_filters[@]} -gt 0 ]]; then build_arguments+=("${test_filters[@]}"); fi
    # 编译、身份/权限核验、无重编运行共享原锁；未验明的新产物不能先运行。
    run_with_lock "$wait_for_lock" env -u AREACHAIN_SYSTEM_KEYCHAIN_QA -u AREACHAIN_SYSTEM_KEYCHAIN_RUN_ID \
        -u AREACHAIN_SYSTEM_KEYCHAIN_PHASE -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_QA \
        -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_RUN_ID -u TEST_RUNNER_AREACHAIN_SYSTEM_KEYCHAIN_PHASE \
        bash -c '
            set -euo pipefail
            action="$1"; app="$2"; identifier="$3"; keep="$4"; shift 4
            xcodebuild "$@" -parallel-testing-enabled NO build-for-testing
            python3 -B scripts/qa_identity.py "$app" --expected-identifier "$identifier"
            if [[ "$action" == "qa" ]]; then
                keeper=""
                if [[ "$keep" == "YES" ]]; then
                    python3 -B scripts/keep_front.py "$identifier" & keeper=$!
                    # 测试被中断或超时也要结束守护；被 SIGKILL 时由守护自己发现父进程消失后退出。
                    trap '\''[[ -z "$keeper" ]] || kill "$keeper" 2>/dev/null || true'\'' EXIT INT TERM
                fi
                status=0
                xcodebuild "$@" -parallel-testing-enabled NO test-without-building || status=$?
                if [[ -n "$keeper" ]]; then kill "$keeper" 2>/dev/null || true; wait "$keeper" 2>/dev/null || true; fi
                [[ "$status" -eq 0 ]] || exit "$status"
                python3 -B scripts/qa_identity.py "$app" --expected-identifier "$identifier"
            fi
        ' qa "$command_name" "$candidate_app" "$qa_identifier" "$keep_front" "${build_arguments[@]}"
elif [[ "$command_name" == "test" ]]; then
    if [[ ${#test_filters[@]} -gt 0 ]]; then build_arguments+=("${test_filters[@]}"); fi
    mkdir -p "$derived_data/phase1-logs"
    # 仅测试宿主关闭沙盒，以便把 Phase1 样本写到 derivedData；日用应用仍用 AreaChain.entitlements。
    build_arguments+=("TEST_RUNNER_AREACHAIN_PHASE1_LOG_DIR=$derived_data/phase1-logs")
    build_arguments+=("CODE_SIGN_ENTITLEMENTS=AreaChain/App/AreaChainTesting.entitlements")
    build_arguments+=("ENABLE_APP_SANDBOX=NO")
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
