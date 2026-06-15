#!/bin/bash

set -o pipefail

PASSWORD="Bxi12345go"
SCRIPT_MODIFIED_DATE="2026-06-06"
SERVICE_NAME="ros_elf_launch.service"
SERVICE_TARGET_FILE="/etc/systemd/system/$SERVICE_NAME"
SERVICE_STOP_TIMEOUT="20s"

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

stop_service_if_installed() {
    local service_name="$1"

    if [ -f "$SERVICE_TARGET_FILE" ]; then
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

# Stop and remove the old auto-start service before replacing the package.
stop_service_if_installed "$SERVICE_NAME"
sudo_step "remove old $SERVICE_NAME" rm -f "$SERVICE_TARGET_FILE"
sudo_step "reload systemd before update" systemctl daemon-reload

WORKSPACE_DIR="/home/bxi/bxi_ws"                                                                  
PROJECT_DIR="$WORKSPACE_DIR/bxi_rl_controller_ros2_example"
PACKAGE_URL="https://download.bxirobotics.cn/d/ELF3/bxi_rl_controller_ros2_example/bxi_ws/bxi_rl_controller_ros2_example.tar.gz"
PACKAGE_FILE="${PACKAGE_URL##*/}"

# Prepare a clean workspace.
run_step "create workspace" mkdir -p "$WORKSPACE_DIR"
sudo_step "remove old bxi_rl_controller_ros2_example files" rm -rf "$WORKSPACE_DIR"/bxi_rl_controller_ros2_example*
run_step "enter workspace" cd "$WORKSPACE_DIR"

run_step "download $PACKAGE_FILE" wget --user-agent="Mozilla/5.0" -O "$PACKAGE_FILE" "$PACKAGE_URL"
run_step "extract $PACKAGE_FILE" tar -xzf "$PACKAGE_FILE"

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

if [ ! -f "$SERVICE_FILE" ]; then
    error_exit "find ros_elf_launch.service"
fi
echo "find ros_elf_launch.service success: $SERVICE_FILE"

if [ ! -f "$RULES_FILE" ]; then
    error_exit "find bxi-dev.rules"
fi
echo "find bxi-dev.rules success: $RULES_FILE"

sudo_step "install ros_elf_launch.service" cp "$SERVICE_FILE" "$SERVICE_TARGET_FILE"
run_step "configure ros_elf_launch.service stop behavior" configure_service_stop_behavior "$SERVICE_TARGET_FILE"
sudo_step "update ROS_DOMAIN_ID" sed -i -E "s/^Environment=ROS_DOMAIN_ID=.*/Environment=ROS_DOMAIN_ID=$ros_domain_id/" "$SERVICE_TARGET_FILE"
if grep -q "^Environment=ROS_DOMAIN_ID=$ros_domain_id$" "$SERVICE_TARGET_FILE"; then
    echo "verify ROS_DOMAIN_ID success"
else
    error_exit "verify ROS_DOMAIN_ID"
fi
sudo_step "install bxi-dev.rules" cp "$RULES_FILE" /etc/udev/rules.d/
sudo_step "reload udev rules" udevadm control --reload-rules
sudo_step "trigger udev rules" udevadm trigger
sudo_step "settle udev" udevadm settle

# Build the package. 
run_step "source bxi_ros2_pkg setup" source /opt/bxi/bxi_ros2_pkg/setup.bash
sudo_step "clean build files" rm -rf build/ install/ log/
run_step "build package" bash build.sh

# Enable and restart the new auto-start service.
sudo_step "reload systemd after update" systemctl daemon-reload
sudo_step "enable ros_elf_launch.service" systemctl enable ros_elf_launch.service
sudo_step "restart ros_elf_launch.service" systemctl restart ros_elf_launch.service
