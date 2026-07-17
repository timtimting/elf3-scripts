#!/bin/bash

set -euo pipefail

SCRIPT_MODIFIED_DATE="2026-07-07"
REMOTE_SCRIPT_NAME="test_pro.sh"
REMOTE_SCRIPT_URL="${TEST_PRO_SCRIPT_URL:-https://download.bxirobotics.cn/d/ELF3/bxi_rl_controller_ros2_example/robot_test/test_pro.sh}"
REMOTE_SCRIPT_SHA256="${TEST_PRO_SCRIPT_SHA256:-}"
DOWNLOAD_TIMEOUT="${DOWNLOAD_TIMEOUT:-20}"
DOWNLOAD_TRIES="${DOWNLOAD_TRIES:-3}"

echo "============================================================"
echo "脚本修改时间：$SCRIPT_MODIFIED_DATE"
echo "拉取脚本：$REMOTE_SCRIPT_URL"
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
    require_command mktemp || return 1
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

run_step "preflight checks" preflight_checks

downloaded_script=$(mktemp "${TMPDIR:-/tmp}/${REMOTE_SCRIPT_NAME}.XXXXXX")
cleanup() {
    rm -f "$downloaded_script" "$downloaded_script.download"
}
trap cleanup EXIT

run_step "download $REMOTE_SCRIPT_NAME" download_remote_script "$downloaded_script"
run_step "verify $REMOTE_SCRIPT_NAME" verify_remote_script "$downloaded_script"
run_step "execute $REMOTE_SCRIPT_NAME" run_remote_script "$downloaded_script" "$@"
