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

上下电循环测试示例：

```bash
bash test/power_cycle_test.sh -c 100 --on-delay 5 --off-delay 5
```

`test/efi_format.sh` 包含针对 `/dev/sda` 的分区与格式化命令，使用前需核对目标磁盘和需要执行的步骤。

## 远程脚本发布

仓库目录调整不改变服务器路径。发布时，将 `usr/usr_pro.sh` 上传到原 `bxi_ws/usr_pro.sh` 地址，将 `robot_test/test_pro.sh` 上传到原 `robot_test/test_pro.sh` 地址；也可通过 `USR_PRO_SCRIPT_URL`、`TEST_PRO_SCRIPT_URL` 环境变量指定下载地址。
