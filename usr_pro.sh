#!/bin/bash

set -o pipefail

PASSWORD="Bxi12345go"
SCRIPT_MODIFIED_DATE="2026-07-07"
SERVICE_NAME="ros_elf_launch.service"
SERVICE_TARGET_FILE="/etc/systemd/system/$SERVICE_NAME"
SERVICE_STOP_TIMEOUT="20s"
SERVICE_START_TIMEOUT="30s"
UDEV_TIMEOUT="20s"
DOWNLOAD_TIMEOUT="20"
DOWNLOAD_TRIES="3"

echo "============================================================"
echo "脚本修改时间：$SCRIPT_MODIFIED_DATE"
echo "============================================================"

error_exit() {
    echo "ERROR: $1 failed"
    exit 1
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

sudo_step() {
    local step_name="$1"
    shift

    if sudo_cmd "$@"; then
        echo "$step_name success"
    else
        error_exit "$step_name"
    fi
}

sudo_cmd() {
    echo "$PASSWORD" | sudo -S -p "" "$@"
}

unit_exists() {
    local service_name="$1"

    sudo_cmd systemctl cat "$service_name" >/dev/null 2>&1 || [ -f "$SERVICE_TARGET_FILE" ]
}

require_command() {
    local command_name="$1"

    command -v "$command_name" >/dev/null 2>&1
}

preflight_checks() {
    local commands
    local command_name
    commands="sudo timeout systemctl wget tar grep sed udevadm chmod"

    for command_name in $commands; do
        if ! require_command "$command_name"; then
            echo "missing command: $command_name"
            return 1
        fi
    done

    if [ ! -f /opt/bxi/bxi_ros2_pkg/setup.bash ]; then
        echo "missing file: /opt/bxi/bxi_ros2_pkg/setup.bash"
        return 1
    fi

    sudo_cmd -v
}

stop_service_if_installed() {
    local service_name="$1"

    if unit_exists "$service_name"; then
        if sudo_cmd timeout "$SERVICE_STOP_TIMEOUT" systemctl stop "$service_name"; then
            echo "stop $service_name success"
        else
            echo "WARN: stop $service_name did not finish within $SERVICE_STOP_TIMEOUT, force killing it"
            sudo_cmd systemctl kill -s SIGKILL "$service_name" || true
            sudo_cmd systemctl reset-failed "$service_name" || true

            if sudo_cmd systemctl is-active --quiet "$service_name"; then
                error_exit "force stop $service_name"
            fi
            echo "force stop $service_name success"
        fi

        sudo_step "disable $service_name" systemctl disable "$service_name"
    else
        echo "skip stop $service_name success"
        echo "skip disable $service_name success"
    fi
}

configure_service_stop_behavior() {
    local service_file="$1"

    sudo_cmd sed -i -E '/^(KillMode|KillSignal|TimeoutStopSec|SendSIGKILL)=/d' "$service_file" || return 1
    sudo_cmd sed -i "/^\[Service\]/a\\
KillMode=control-group\\
KillSignal=SIGINT\\
TimeoutStopSec=15s\\
SendSIGKILL=yes" "$service_file" || return 1
    sudo_cmd grep -q '^TimeoutStopSec=15s$' "$service_file" || return 1
}

download_package() {
    local tmp_file="$PACKAGE_FILE.tmp"

    rm -f "$tmp_file"
    if ! wget \
        --user-agent="Mozilla/5.0" \
        --timeout="$DOWNLOAD_TIMEOUT" \
        --tries="$DOWNLOAD_TRIES" \
        --retry-connrefused \
        --waitretry=2 \
        -O "$tmp_file" \
        "$PACKAGE_URL"; then
        rm -f "$tmp_file"
        return 1
    fi

    mv "$tmp_file" "$PACKAGE_FILE" || return 1
    test -s "$PACKAGE_FILE" || return 1
    tar -tzf "$PACKAGE_FILE" >/dev/null
}

extract_package() {
    tar -xzf "$PACKAGE_FILE" || return 1
    test -d "$PROJECT_DIR"
}

verify_service_config() {
    sudo_cmd grep -q "^Environment=ROS_DOMAIN_ID=$ros_domain_id$" "$SERVICE_TARGET_FILE" || return 1
    sudo_cmd grep -q '^KillMode=control-group$' "$SERVICE_TARGET_FILE" || return 1
    sudo_cmd grep -q '^KillSignal=SIGINT$' "$SERVICE_TARGET_FILE" || return 1
    sudo_cmd grep -q '^TimeoutStopSec=15s$' "$SERVICE_TARGET_FILE" || return 1
    sudo_cmd grep -q '^SendSIGKILL=yes$' "$SERVICE_TARGET_FILE" || return 1
}

verify_service_loaded() {
    local service_name="$1"

    sudo_cmd systemctl cat "$service_name" >/dev/null
}

verify_service_enabled() {
    local service_name="$1"

    sudo_cmd systemctl is-enabled --quiet "$service_name"
}

build_package() {
    bash build.sh || return 1
    test -f install/setup.bash
}

wait_service_active() {
    local service_name="$1"

    timeout "$SERVICE_START_TIMEOUT" bash -c '
        service_name="$1"
        while ! systemctl is-active --quiet "$service_name"; do
            sleep 1
        done
    ' _ "$service_name" || return 1

    sleep 3
    systemctl is-active --quiet "$service_name"
}

show_service_debug() {
    local service_name="$1"

    echo "----- $service_name status -----"
    sudo_cmd systemctl status "$service_name" --no-pager || true
    echo "----- $service_name recent logs -----"
    sudo_cmd journalctl -u "$service_name" -n 80 --no-pager || true
}

restart_service_and_verify() {
    local service_name="$1"

    if ! sudo_cmd systemctl restart "$service_name"; then
        show_service_debug "$service_name"
        return 1
    fi

    if ! wait_service_active "$service_name"; then
        show_service_debug "$service_name"
        return 1
    fi
}

print_final_summary() {
    echo "============================================================"
    echo "配置闭环检查完成"
    echo "项目目录：$PROJECT_DIR"
    echo "ROS_DOMAIN_ID：$ros_domain_id"
    echo "服务状态：$(systemctl is-active "$SERVICE_NAME" 2>/dev/null || true)"
    echo "============================================================"
}

WORKSPACE_DIR="/home/bxi/bxi_ws"                                                                  
PROJECT_DIR="$WORKSPACE_DIR/bxi_rl_controller_ros2_example"
PACKAGE_URL="https://download.bxirobotics.cn/d/ELF3/bxi_rl_controller_ros2_example/bxi_ws/bxi_rl_controller_ros2_example.tar.gz"
PACKAGE_FILE="${PACKAGE_URL##*/}"

run_step "preflight checks" preflight_checks

# Stop and remove the old auto-start service before replacing the package.
stop_service_if_installed "$SERVICE_NAME"
sudo_step "remove old $SERVICE_NAME" rm -f "$SERVICE_TARGET_FILE"
sudo_step "reload systemd before update" systemctl daemon-reload

# Prepare a clean workspace.
run_step "create workspace" mkdir -p "$WORKSPACE_DIR"
sudo_step "remove old bxi_rl_controller_ros2_example files" rm -rf "$WORKSPACE_DIR"/bxi_rl_controller_ros2_example*
run_step "enter workspace" cd "$WORKSPACE_DIR"

run_step "download and verify $PACKAGE_FILE" download_package
run_step "extract and verify $PACKAGE_FILE" extract_package

# Derive ROS_DOMAIN_ID from the numeric suffix of the hostname.
if current_hostname=$(hostname); then
    echo "read hostname success"
else
    error_exit "read hostname"
fi
echo "当前主机名是：$current_hostname"

current_elf3_id=$(echo "$current_hostname" | grep -oE '[0-9]+$')
if [ -z "$current_elf3_id" ]; then
    error_exit "read host id from hostname $current_hostname"
fi
echo "read host id success"
echo "当前主机id是：$current_elf3_id"

ros_domain_id=$((current_elf3_id + 30))
echo "calculate ROS_DOMAIN_ID success"
echo "ROS_DOMAIN_ID是：$ros_domain_id"

run_step "enter project directory" cd "$PROJECT_DIR"

# Install device rules and the updated auto-start service.
SERVICE_FILE="./script/ros_elf_launch.service"
RULES_FILE="./script/bxi-dev.rules"
BATTLE_DRAGON_LINK_FILE="./script/bxi-battle-dragon-link"
BATTLE_DRAGON_LINK_TARGET="/usr/local/bin/bxi-battle-dragon-link"

if [ ! -f "$SERVICE_FILE" ]; then
    error_exit "find ros_elf_launch.service"
fi
echo "find ros_elf_launch.service success: $SERVICE_FILE"

if [ ! -f "$RULES_FILE" ]; then
    error_exit "find bxi-dev.rules"
fi
echo "find bxi-dev.rules success: $RULES_FILE"

if [ ! -f "$BATTLE_DRAGON_LINK_FILE" ]; then
    error_exit "find bxi-battle-dragon-link"
fi
echo "find bxi-battle-dragon-link success: $BATTLE_DRAGON_LINK_FILE"

sudo_step "install ros_elf_launch.service" cp "$SERVICE_FILE" "$SERVICE_TARGET_FILE"
run_step "configure ros_elf_launch.service stop behavior" configure_service_stop_behavior "$SERVICE_TARGET_FILE"
sudo_step "update ROS_DOMAIN_ID" sed -i -E "s/^Environment=ROS_DOMAIN_ID=.*/Environment=ROS_DOMAIN_ID=$ros_domain_id/" "$SERVICE_TARGET_FILE"
run_step "verify ros_elf_launch.service config" verify_service_config
sudo_step "create /usr/local/bin" mkdir -p /usr/local/bin
sudo_step "install bxi-battle-dragon-link" cp "$BATTLE_DRAGON_LINK_FILE" "$BATTLE_DRAGON_LINK_TARGET"
sudo_step "set bxi-battle-dragon-link permissions" chmod 755 "$BATTLE_DRAGON_LINK_TARGET"
sudo_step "verify bxi-battle-dragon-link executable" test -x "$BATTLE_DRAGON_LINK_TARGET"
sudo_step "install bxi-dev.rules" cp "$RULES_FILE" /etc/udev/rules.d/
sudo_step "reload udev rules" udevadm control --reload-rules
sudo_step "trigger udev rules" timeout "$UDEV_TIMEOUT" udevadm trigger
sudo_step "settle udev" timeout "$UDEV_TIMEOUT" udevadm settle

# Build the package. 
run_step "source bxi_ros2_pkg setup" source /opt/bxi/bxi_ros2_pkg/setup.bash
sudo_step "clean build files" rm -rf build/ install/ log/
run_step "build and verify package" build_package

# Enable and restart the new auto-start service.
sudo_step "reload systemd after update" systemctl daemon-reload
run_step "verify ros_elf_launch.service loaded" verify_service_loaded "$SERVICE_NAME"
sudo_step "enable ros_elf_launch.service" systemctl enable ros_elf_launch.service
run_step "verify ros_elf_launch.service enabled" verify_service_enabled "$SERVICE_NAME"
run_step "restart and verify ros_elf_launch.service" restart_service_and_verify "$SERVICE_NAME"
print_final_summary
