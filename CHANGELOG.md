# 更新日志

## 2026-07-07

- 将原 `switch_usr_pro.sh` 和 `switch_test_pro.sh` 的完整部署逻辑分别改名为 `usr_pro.sh` 和 `test_pro.sh`。
- 新增轻量入口 `switch_usr_pro.sh` 和 `switch_test_pro.sh`：运行时从网站拉取对应脚本，校验后执行，并在退出时删除临时脚本。
- `usr_pro.sh` 和 `test_pro.sh` 在安装 udev 规则前，会先安装 `script/bxi-battle-dragon-link` 到 `/usr/local/bin/` 并设置可执行权限。

## 2026-06-06

- 在 `switch_test_pro.sh` 和 `switch_usr_pro.sh` 中添加脚本修改日期输出，运行时会醒目打印修改时间。
- 调整 `ros_elf_launch.service` 自启动服务的识别与更新方式：先将脚本包内的 `./script/ros_elf_launch.service` 复制到 `/etc/systemd/system/ros_elf_launch.service`，再修改目标文件中的 `Environment=ROS_DOMAIN_ID=` 配置。
- `ROS_DOMAIN_ID` 继续按机器编号加 30 生成，避免依赖 `ros_elf_launch.service` 内的固定行号。
