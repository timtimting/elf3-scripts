#!/bin/bash

set -euo pipefail

SCRIPT_MODIFIED_DATE="2026-07-17"
REMOTE_SCRIPT_NAME="test_pro.sh"
REMOTE_SCRIPT_URL="${TEST_PRO_SCRIPT_URL:-https://download.bxirobotics.cn/d/ELF3/bxi_rl_controller_ros2_example/robot_test/test_pro.sh}"
REMOTE_SCRIPT_SHA256="${TEST_PRO_SCRIPT_SHA256:-}"
DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-20}"
DOWNLOAD_TRIES="${DOWNLOAD_TRIES:-3}"
TARGET_DIR="$HOME/test"
DOWNLOADED_SCRIPT="$TARGET_DIR/$REMOTE_SCRIPT_NAME"
KEEP_DOWNLOADED_SCRIPT=0

if [ "${1:-}" = "0" ]; then
    KEEP_DOWNLOADED_SCRIPT=1
    shift
fi

echo "============================================================"
echo "[switch_test_pro.sh 输出]"
echo "脚本修改时间：$SCRIPT_MODIFIED_DATE"
echo "拉取脚本：$REMOTE_SCRIPT_URL"
echo "保存位置：$DOWNLOADED_SCRIPT"
if [ "$KEEP_DOWNLOADED_SCRIPT" -eq 1 ]; then
    echo "清理策略：执行结束后保留 $REMOTE_SCRIPT_NAME"
else
    echo "清理策略：执行结束后删除 $REMOTE_SCRIPT_NAME"
fi
echo "============================================================"

error_exit() {
    echo "ERROR: $1 failed"
    exit 1
}

require_command() {
    local command_name="$1"

    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "missing command: $command_name"
        return 1
    fi
}

run_step() {
    local step_name="$1"
    shift

    if "$@"; then
        echo "$step_name success"
    else
        error_exit "$step_name"
    fi
}

preflight_checks() {
    require_command bash || return 1
    require_command mkdir || return 1
    require_command mv || return 1
    require_command rm || return 1
    require_command wget || return 1

    if [ -n "$REMOTE_SCRIPT_SHA256" ]; then
        require_command sha256sum || return 1
    fi
}

download_remote_script() {
    local target_file="$1"
    local tmp_file="$target_file.download"

    rm -f "$tmp_file"
    if ! wget \
        --user-agent="Mozilla/5.0" \
        --timeout="$DOWNLOAD_TIMEOUT" \
        --tries="$DOWNLOAD_TRIES" \
        --retry-connrefused \
        --waitretry=2 \
        -O "$tmp_file" \
        "$REMOTE_SCRIPT_URL"; then
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$target_file"
    test -s "$target_file"
}

verify_remote_script() {
    local script_file="$1"

    if [ -n "$REMOTE_SCRIPT_SHA256" ]; then
        echo "$REMOTE_SCRIPT_SHA256  $script_file" | sha256sum -c - >/dev/null
    fi

    bash -n "$script_file"
}

run_remote_script() {
    local script_file="$1"
    shift

    bash "$script_file" "$@"
}

cleanup() {
    rm -f "$DOWNLOADED_SCRIPT.download"
    if [ "$KEEP_DOWNLOADED_SCRIPT" -eq 0 ]; then
        rm -f "$DOWNLOADED_SCRIPT"
    fi
}
trap cleanup EXIT

run_step "preflight checks" preflight_checks
run_step "create target directory" mkdir -p "$TARGET_DIR"
run_step "download $REMOTE_SCRIPT_NAME" download_remote_script "$DOWNLOADED_SCRIPT"
run_step "verify $REMOTE_SCRIPT_NAME" verify_remote_script "$DOWNLOADED_SCRIPT"

echo ""
echo "============================================================"
echo "[test_pro.sh 输出开始]"
echo "============================================================"

set +e
run_remote_script "$DOWNLOADED_SCRIPT" "$@"
remote_status=$?
set -e

echo "============================================================"
echo "[test_pro.sh 输出结束，退出码：$remote_status]"
echo "============================================================"
cleanup
trap - EXIT
if [ "$KEEP_DOWNLOADED_SCRIPT" -eq 1 ]; then
    echo "[switch_test_pro.sh 输出] 保留下载脚本：$DOWNLOADED_SCRIPT"
else
    echo "[switch_test_pro.sh 输出] 删除下载脚本：$DOWNLOADED_SCRIPT"
fi

exit "$remote_status"
