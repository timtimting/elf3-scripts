# 查看磁盘，确认是全新空白盘
sudo parted /dev/sda print
# 如果显示"unrecognised disk label"，说明确实是新盘


# 1. 创建GPT分区表
sudo parted /dev/sda mklabel gpt
# 2. 创建EFI系统分区（ESP），大小512MB（关键步骤）
sudo parted /dev/sda mkpart primary fat32 1MiB 513MiB
# 3. 创建根分区，使用剩余全部空间
sudo parted /dev/sda mkpart primary ext4 513MiB 100%
# 4. 验证分区结构
sudo parted /dev/sda print
# 应看到：
# 1: EFI系统分区 (fat32, 512MB)
# 2: 根分区 (ext4, 剩余空间)


# 1. 卸载所有分区
sudo umount /dev/sda*
# 2. 清除错误标签
sudo wipefs -a /dev/sda1
# 3. 手动创建合法EFI分区
sudo mkfs.vfat -F 32 -n EFI /dev/sda1  # 使用简单标签"EFI"
# 4. 标记为ESP分区
sudo parted /dev/sda set 1 esp on
# 5. 重新运行Systemback
sudo systemback
