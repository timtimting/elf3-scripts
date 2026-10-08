# 更新日志

## 2026-10-08

- 将 `usr_pro.sh`、`switch_usr_pro.sh` 归入 `usr/`，将 `test_pro.sh`、`switch_test_pro.sh` 归入 `robot_test/`，将 `power_cycle_test.sh` 和 `efi_format.sh` 归入 `test/`。
- 移除旧 `get/`、`test/` 中的 usr 脚本副本，保留主机名解析修复；清理旧脚本、备份及未使用的配置。
- 新增 `README.md`，说明目录、运行入口和远程脚本发布路径；下载地址及部署逻辑保持不变。
- 新增 `.gitignore`，忽略构建产物、日志、临时文件以及 Codex / Agents 本地配置与指令文件。

## 2026-09-26

- 修复 `usr_pro.sh`（含 `get/`、`test/` 副本）无法解析带域名后缀的主机名：从第一个点之前的短主机名提取末尾编号，并按十进制计算 `ROS_DOMAIN_ID`。
- 将主机编号检查提前到停止服务、删除工作目录和下载软件包之前，避免主机名不合法时执行这些操作。
- `switch_usr_pro.sh` 仍从网站下载脚本，使用入口前需将修复后的 `usr_pro.sh` 更新到下载服务器。

## 2026-07-07

- 将原 `switch_usr_pro.sh` 和 `switch_test_pro.sh` 的完整部署逻辑分别改名为 `usr_pro.sh` 和 `test_pro.sh`。
- 新增轻量入口 `switch_usr_pro.sh` 和 `switch_test_pro.sh`：运行时从网站拉取对应脚本，校验后执行，并在退出时删除临时脚本。
- `usr_pro.sh` 和 `test_pro.sh` 在安装 udev 规则前，会先安装 `script/bxi-battle-dragon-link` 到 `/usr/local/bin/` 并设置可执行权限。

## 2026-06-06

- 在 `switch_test_pro.sh` 和 `switch_usr_pro.sh` 中添加脚本修改日期输出，运行时会醒目打印修改时间。
- 调整 `ros_elf_launch.service` 自启动服务的识别与更新方式：先将脚本包内的 `./script/ros_elf_launch.service` 复制到 `/etc/systemd/system/ros_elf_launch.service`，再修改目标文件中的 `Environment=ROS_DOMAIN_ID=` 配置。
- `ROS_DOMAIN_ID` 继续按机器编号加 30 生成，避免依赖 `ros_elf_launch.service` 内的固定行号。
