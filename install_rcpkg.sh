PASSWORD="Bxi12345go"
url="https://download.bxirobotics.cn/d/ELF3/bxi_rc_ros2/bxi_rc_ros2_v260429.tar.gz"
url_RL="https://download.bxirobotics.cn/d/ELF3/bxi_rl_controller_ros2_example/bxi_rl_controller_ros2_example_v260506.tar.gz"

cd /opt/bxi/
echo "$PASSWORD" | sudo -S wget --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "$url"
echo "$PASSWORD" | sudo -S tar -xzf bxi_rc_ros2_v260429.tar.gz

cd /opt/bxi/bxi_rc_ros2/
echo "$PASSWORD" | sudo -S bash setup_service.sh

cd /opt/bxi/
echo "$PASSWORD" | sudo -S wget --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" "$url_RL"
echo "$PASSWORD" | sudo -S tar -xzf bxi_rl_controller_ros2_example_v260506.tar.gz


