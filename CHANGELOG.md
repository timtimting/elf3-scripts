# 更新日志

## 2026-06-06

- 在 `switch_test_pro.sh` 和 `switch_usr_pro.sh` 中添加脚本修改日期输出，运行时会醒目打印修改时间。
- 调整 `ros_elf_launch.service` 自启动服务的识别与更新方式：先将脚本包内的 `./script/ros_elf_launch.service` 复制到 `/etc/systemd/system/ros_elf_launch.service`，再修改目标文件中的 `Environment=ROS_DOMAIN_ID=` 配置。
- `ROS_DOMAIN_ID` 继续按机器编号加 30 生成，避免依赖 `ros_elf_launch.service` 内的固定行号。
