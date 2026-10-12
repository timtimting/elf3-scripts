# 机器人部署与测试脚本

`usr/` 存放 usr 版本部署脚本，`robot_test/` 存放机器人 test 版本部署脚本，`test/` 存放上下电测试和磁盘操作工具。

## 目录

```text
usr/
  switch_usr_pro.sh   # usr 部署入口：下载并执行远程脚本
  usr_pro.sh          # usr 完整部署脚本
robot_test/
  switch_test_pro.sh  # test 部署入口：下载并执行远程脚本
  test_pro.sh         # test 完整部署脚本
test/
  power_cycle_test.sh # 上下电循环测试
  efi_format.sh       # 磁盘分区与 EFI 格式化操作
CMakeFiles/          # CMake 生成文件
README.md            # 目录与使用说明
CHANGELOG.md         # 更新日志
```

## 使用

在仓库根目录运行对应入口：

```bash
# 部署 usr 版本
bash usr/switch_usr_pro.sh

# 部署 test 版本
bash robot_test/switch_test_pro.sh

# 查看上下电循环测试参数
bash test/power_cycle_test.sh --help
```

两个 `switch` 入口从下载服务器获取脚本，保存到 `$HOME/test/` 并执行，默认执行完删除下载文件；传入首个参数 `0` 可保留下载文件，例如 `bash usr/switch_usr_pro.sh 0`。需要执行本仓库中的部署脚本时，分别使用 `bash usr/usr_pro.sh` 或 `bash robot_test/test_pro.sh`。

两个完整入口开始时会醒目提醒文件覆盖，等待 5 秒后自动继续；期间按 `q`（无需回车，`Q` 也可）或 `Ctrl+C` 退出，取消发生在权限认证、源码克隆和系统修改之前。其他按键不会跳过等待，标准输入关闭时仍等待 5 秒。

两个完整部署入口均通过以下代理克隆 `bxi_controller_ros2`：usr 使用默认分支 `main`，test 先克隆 `main`（首次及失败重试一致），成功后 checkout 到 `robot_test`；切换失败立即退出，不继续部署，安装目录仍为 `/home/bxi/bxi_ws/bxi_rl_controller_ros2_example`，按设备编号计算 `ROS_DOMAIN_ID`（主机名末尾编号 + 30），随后调用仓库 `script/` 内独立的设备链接、自启动及配置生成脚本。两版按各自分支获取源码，不再使用下载站安装包；`USR_PACKAGE_URL` / `TEST_PACKAGE_URL` 不再生效。

```bash
# usr
git clone https://v4.gh-proxy.org/https://github.com/bxirobotics/bxi_controller_ros2.git
# test
git clone --branch main https://v4.gh-proxy.org/https://github.com/bxirobotics/bxi_controller_ros2.git
git -C bxi_controller_ros2 checkout robot_test
```

首次克隆到临时目录失败时，先停止并禁用旧 `ros_elf_launch.service`，再删除固定安装目录和不完整的克隆目录，重试一次。停服务失败会直接退出，保留旧工程；第二次克隆失败则退出并清理临时文件。**失败重试会删除现有工程及其未保存改动，第二次仍失败时旧服务保持停用，旧工程已删除。**第一次克隆成功时仍按原流程预检、备份并替换旧工程。

Git 仓库尚未包含未提交的功能脚本时，可先将目标仓库 `script/` 放在设备的独立目录，并指定其绝对路径：

```bash
BXI_DEPLOY_SCRIPTS_DIR=/home/bxi/bxi_controller_ros2/script bash robot_test/test_pro.sh
BXI_DEPLOY_SCRIPTS_DIR=/home/bxi/bxi_controller_ros2/script bash usr/usr_pro.sh
```

机器人头部和外设配置由纯 Bash `generate_robot_config.sh` 生成：无参数或 `0` 为无头，`1` 为有头，外设清单采用 [bxi_robot_config_tool](https://github.com/timtimting/bxi_robot_config_tool) 的默认规格。usr/test 每次都调用无参数生成器，默认无头，不再交互询问；旧 `/opt/bxi/robot_config.yaml` 先备份到 `.pre-deploy.XXXXXX/robot_config.yaml`，构建成功后替换。单独运行生成器 `1` 可改为有头，但下次版本切换仍会重置为无头。外部 script 目录需包含新的 `.sh` 生成器。两个 switch 的原有首参数 `0` 仍是“保留下载脚本”，不表示有头/无头。

入口提前检查系统命令（包括 `git`）和 ROS underlay、通过系统 `sudo -v` 验证权限，再克隆并检查必要文件、脚本语法及 systemd 配置。除上述克隆失败清理分支外，预检通过后才停止并禁用旧服务。正常替换阶段停服务失败时发送 SIGKILL、尝试 reset-failed 并检查 active；仍运行就退出，不替换项目。已有项目保留在 `/home/bxi/bxi_ws/.pre-deploy.XXXXXX/bxi_rl_controller_ros2_example`（实际路径在运行时输出），随后替换工作区项目、重建、启用并重启服务。**这会影响当前运行的机器人；须确保电机处于安全状态。构建或重启失败不会自动恢复或启动旧版本；备份会占用磁盘空间。**部署预检要求 `script/udev/70-bxi-{bat,imu,remote}.rules` 三份规则齐全。设备链接模块安装三份规则，并将旧 `bxi-dev.rules` 移到 `/var/backups/bxi-udev.XXXXXX/`，随后重载并触发全部设备子系统；现场自定义规则须先合入源码。入口按原版使用脚本内固定密码，经标准输入传给 `sudo -S`；不依赖密码环境变量或配置文件，认证失败则退出。

自启动部署统一调用 `deploy_autostart.sh`：先备份旧 service 配置到 `/var/backups/ros-elf-launch.XXXXXX/`，停止/禁用旧服务，清理同名 unit、drop-in 和依赖目录，再安装新配置、重载 systemd、启用并重启。历史 `overlay.conf` 等配置不会继续叠加到新版 unit 上。完整入口使用 `prepare` 阶段在构建前安装 unit，构建成功后用 `start` 阶段启用、重启；独立调用省略第三参数仍执行全部阶段。

systemd 249 会回收未启用且无引用的 unit，因此清理后先 enable，确认 LoadState=loaded 再 reset-failed/restart，避免 `Unit not loaded` 中断部署。模板预检只从 `/usr/lib/systemd/system:/lib/systemd/system` 加载基础依赖并禁用生成器，避免扫描现场 netplan/snapd 配置产生无关警告；新 unit 安装后仍检查真实加载、启用和运行状态。

两个完整入口和四个功能脚本输出 `[进入脚本] 文件名`、`[离开脚本] 文件名 (退出码=N)` 到 stderr，退出码 0 表示成功，失败保留原退出码和清理逻辑；构建步骤也记录 `build.sh` 的执行边界。配置生成脚本的 stdout 只包含配置内容，两个 switch 不修改。

本机流程回归检查（需要 `bubblewrap`，使用隔离目录和模拟 systemctl/udev，不操作真实服务或硬件）：

```bash
bash test/test_deployment.sh /home/lxw/bxi_controller_ros2
```

上下电循环测试示例：

```bash
bash test/power_cycle_test.sh -c 100 --on-delay 5 --off-delay 5
```

`test/efi_format.sh` 包含针对 `/dev/sda` 的分区与格式化命令，使用前需核对目标磁盘和需要执行的步骤。

## 系统权限

部署入口、设备链接和自启动模块按原版使用脚本内 `PASSWORD`，通过 `sudo -S` 自动输入，无需额外密码文件或 `BXI_SUDO_*` 环境变量。入口在下载和停止服务前验证权限，固定密码不匹配时退出。密码以明文保存在这四个脚本中，分发脚本会一并分发密码。

## 远程脚本发布

仓库目录调整不改变服务器路径。发布时，将 `usr/usr_pro.sh` 上传到原 `bxi_ws/usr_pro.sh` 地址，将 `robot_test/test_pro.sh` 上传到原 `robot_test/test_pro.sh` 地址；也可通过 `USR_PRO_SCRIPT_URL`、`TEST_PRO_SCRIPT_URL` 环境变量指定下载地址。

新版入口尚未发布到下载服务器时，默认 switch 地址仍会下载服务器现有版本；测试本地修改需直接运行本地完整入口，或覆盖 `USR_PRO_SCRIPT_URL` / `TEST_PRO_SCRIPT_URL` 指向新版入口。Git 仓库需要包含功能模块，未提交的模块需通过外部 `BXI_DEPLOY_SCRIPTS_DIR` 提供。
