#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

derived="$root/build/DerivedData"
app="$derived/Build/Products/Debug/AreaChain.app"
dest="/Applications/AreaChain.app"

usage() {
    cat <<'EOF'
用法: ./scripts/build.sh [命令]

  （无参数）  Debug 编译，装到 /Applications，打开
  build       只编 Debug
  install     把已编好的 Debug 装到 /Applications 并打开
  test        跑单测
  help        显示本说明
EOF
}

xcode() {
    xcodebuild \
        -project AreaChain.xcodeproj \
        -scheme AreaChain \
        -configuration Debug \
        -destination 'platform=macOS' \
        -derivedDataPath "$derived" \
        "$@"
}

cmd_build() {
    xcode build
}

cmd_install() {
    if [[ ! -d "$app" ]]; then
        echo "还没有 Debug 包，先执行: ./scripts/build.sh build" >&2
        exit 1
    fi
    pkill -x AreaChain 2>/dev/null || true
    ditto "$app" "$dest"
    open "$dest"
    echo "已装到 $dest"
}

cmd_test() {
    xcode test
}

case "${1:-}" in
    "" )
        cmd_build
        cmd_install
        ;;
    build ) cmd_build ;;
    install ) cmd_install ;;
    test ) cmd_test ;;
    help | -h | --help ) usage ;;
    * )
        echo "未知命令: $1" >&2
        usage >&2
        exit 1
        ;;
esac
