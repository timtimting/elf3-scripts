#!/bin/bash
# create init environment

PASSWORD="Bxi12345go"

cd /home/bxi/
current_hostname=$(hostname)
echo "当前主机名是：$current_hostname"
current_elf3_id=$(hostname | grep -oE '[0-9]+$')
echo "当前主机id是：$current_elf3_id"
ros_domain_id=$(($current_elf3_id + 30))
echo "ROS_DOMAIN_ID是：$ros_domain_id"
usr_name=$(whoami)
echo "当前用户名是：$usr_name"

if [ -d "/home/bxi/bxi_ws/bxi_rl_controller_ros2_example/" ]; then
    echo "already exist bxi_ws/bxi_rl_controller_ros2_example"
else
    echo "create bxi_ws"
    mkdir -p /home/bxi/bxi_ws/
    cd bxi_ws
    echo "clone bxi_rl"
    git clone https://github.com/bxirobotics/bxi_rl_controller_ros2_example.git

    cd bxi_rl_controller_ros2_example
    echo "$PASSWORD" | sudo -S cp ./script/bxi-dev.rules /etc/udev/rules.d/
    sed -i "8s/ROS_DOMAIN_ID=XX/ROS_DOMAIN_ID=$ros_domain_id/" ./script/ros_elf_launch.service
    echo "$PASSWORD" | sudo -S cp ./script/ros_elf_launch.service /etc/systemd/system/
fi

cd /opt/
if [ -d "/opt/bxi/bxi_ros2_pkg" ]; then
    echo "already exist bxi_ros2_pkg"
else
    echo "create /opt/bxi/"
    echo "$PASSWORD" | sudo -S mkdir -p /opt/bxi/
    cd bxi
    echo "clone bxi_ros2_pkg"
    echo "$PASSWORD" | sudo -S git clone https://github.com/bxirobotics/bxi_ros2_pkg.git
fi

cd /home/bxi/bxi_ws/bxi_rl_controller_ros2_example
source /opt/bxi/bxi_ros2_pkg/setup.bash
bash build.sh

echo "$PASSWORD" | sudo -S systemctl daemon-reload
echo "$PASSWORD" | sudo -S systemctl enable ros_elf_launch.service
echo "$PASSWORD" | sudo -S systemctl restart ros_elf_launch.service
