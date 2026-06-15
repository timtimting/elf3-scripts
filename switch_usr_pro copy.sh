PASSWORD="Bxi12345go"

cd /home/bxi/bxi_ws/bxi_rl_controller_ros2_example
git fetch
git reset --hard origin/main
git pull
source /opt/bxi/bxi_ros2_pkg/setup.bash
echo "$PASSWORD" | sudo -S rm -rf build/ install/ log/
bash build.sh
