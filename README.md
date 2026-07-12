# ImmortalWrt - MT798x (RAX3000M 定制版)

基于 [immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)，为 CMCC RAX3000M EMMC 定制的固件。

---

## 规格

| 项目 | 值 |
|------|-----|
| 设备 | CMCC RAX3000M EMMC |
| SoC | MediaTek MT7981B (Filogic 820, ARM Cortex-A53 ×2 @1.3GHz) |
| EMMC | 64GB (实际可用约 58GB) |
| RAM | 512MB DDR4 |
| 内核 | Linux 6.12 |
| WiFi 驱动 | mt_wifi v7.6.7.3 (闭源) |
| WiFi 固件 | mt7981-fw-20260601 |
| GCC | 14.3.0, musl libc |
| 包管理器 | apk |

---

## GPT 分区布局

编译生成的 `emmc-gpt.bin` 包含以下分区（固件自动生成，无需手动分区）：

| 分区 | 名称 | 起始 LBA | 大小 | 说明 |
|------|------|----------|------|------|
| p1 | ubootenv | 8,192 | 512 KB | U-Boot 环境变量 |
| p2 | factory | 9,216 | 2 MB | 工厂 MAC/校准数据 |
| p3 | fip | 13,312 | 4 MB | BL31 + U-Boot |
| p4 | recovery | 24,576 | 96 MB | 恢复系统 |
| p5 | production | 221,184 | 8 GB (可调) | 系统固件 (FIT 镜像) |
| p6 | primary | 16,998,400 | ~51 GB | 用户数据分区 |

> **注意**: p1-p5 起始扇区不可改动，U-Boot 从固定偏移加载。p5 大小由 `CONFIG_TARGET_ROOTFS_PARTSIZE` 控制（默认 8192M）。

---

## 构建

### 环境要求

- Ubuntu 20.04+ (WSL2 或实体机)
- 30GB+ 磁盘空间
- 网络畅通（需下载大量源码和工具链）

### 首次编译

```bash
# 1. 克隆仓库
git clone https://github.com/q738531569-tech/immortalwrt-mt798x-rebase.git
cd immortalwrt-mt798x-rebase

# 2. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 3. 从参考配置出发
cp defconfig/mt7981-ax3000.config .config
make defconfig

# 4. 添加定制包 (可选)
make menuconfig
#   Target System  → MediaTek Ralink ARM
#   Subtarget      → MT7981 (Filogic 820)
#   Target Profile → CMCC RAX3000M
#   根分区大小     → Target Images → Root filesystem partition size (MB) = 8192

# 5. 编译
make -j1 V=s
```

### 关键 Kconfig 选项

```config
CONFIG_TARGET_mediatek_filogic_DEVICE_cmcc_rax3000m=y
CONFIG_TARGET_ROOTFS_PARTSIZE=8192           # p5 大小 (MB)
CONFIG_BUILD_PATENTED=y                       # 启用 h264 解码支持
CONFIG_PACKAGE_mariadb-client-extra=y         # 提供 mysqldump
CONFIG_PACKAGE_kmod-fuse=y                    # ntfsfix 依赖
```

### 已知坑

- **单核编译最稳定**: MTK 闭源驱动 Makefile 多核有竞态，推荐 `make -j1 V=s`
- **多核需监控**: 下载阶段并发可能触发 curl 404/TLS 错误
- **增量编译**: 不要清理 stamp 文件，让 make 自行判断
- **内核 syncconfig**: 如果新增 USB/网络选项，需在 `target/linux/mediatek/filogic/config-6.12` 中预设值
- 脚本 `build_loop.sh` 可自动多核→单核切换

---

## 刷机

### 首次刷机（从原厂/旧系统）

EMMC 恢复模式 Web 升级**无效**，必须用 `dd` 写分区。

**准备工作**:
1. 用网线连接路由器 LAN 口和电脑
2. 电脑开 HTTP 服务器: `python -m http.server 8080`
3. 将编译产物复制到 HTTP 服务目录

**编译产物**:
```
bin/targets/mediatek/filogic/
├── immortalwrt-...-emmc-gpt.bin           # GPT 分区表
├── immortalwrt-...-emmc-preloader.bin     # BL2
├── immortalwrt-...-emmc-bl31-uboot.fip    # BL31 + U-Boot
├── immortalwrt-...-initramfs-recovery.itb # Recovery
└── immortalwrt-...-squashfs-sysupgrade.itb # 系统镜像
```

**刷入步骤** (在路由器 Shell 中执行):

```bash
# 1. 写入 GPT 分区表 (只写前 34 扇区)
wget http://电脑IP:8080/emmc-gpt.bin -O /tmp/gpt.bin
dd if=/tmp/gpt.bin of=/dev/mmcblk0 bs=512 count=34
blockdev --rereadpt /dev/mmcblk0

# 2. 写入 BL2 (preloader 写到 eMMC boot0 分区)
echo 0 > /sys/block/mmcblk0boot0/force_ro
wget http://电脑IP:8080/emmc-preloader.bin -O /tmp/preloader.bin
dd if=/tmp/preloader.bin of=/dev/mmcblk0boot0 bs=512
echo 1 > /sys/block/mmcblk0boot0/force_ro
mmc bootpart enable 1 1 /dev/mmcblk0

# 3. 写入 FIP
dd if=/tmp/emmc-bl31-uboot.fip of=/dev/mmcblk0p3 bs=512

# 4. 写入 Recovery
dd if=/tmp/initramfs-recovery.itb of=/dev/mmcblk0p4 bs=512

# 5. 写入系统 (FIT 镜像)
dd if=/tmp/squashfs-sysupgrade.itb of=/dev/mmcblk0p5 bs=1M

# 6. 清理崩溃日志 & 重启
rm -f /sys/fs/pstore/*
reboot
```

### 升级已有系统

```bash
# 标准 OpenWrt 升级
sysupgrade -n /tmp/squashfs-sysupgrade.itb

# 或直接 dd
dd if=/tmp/squashfs-sysupgrade.itb of=/dev/mmcblk0p5 bs=1M
reboot
```

### 进入恢复模式

1. 断电
2. 按住 Reset 键不放
3. 上电，等待 10 秒
4. 松开 Reset
5. 电脑设 IP 192.168.1.100/24，访问 192.168.1.1
6. 从 Web 界面上传 initramfs-recovery.itb
7. Recovery 启动后 SSH 进去操作

---

## 刷机后设置

以下操作假定路由器 LAN IP 已设好，SSH 可用。

### 1. 创建数据分区 (p6)

如果固件 GPT 不含 p6 或需要调整大小：

```bash
# 检查分区表
cat /proc/partitions

# 用 parted 创建 (路由器需先 apk add parted)
parted -s /dev/mmcblk0 unit s mkpart primary ext4 16998400s 100%
mkfs.ext4 -F /dev/mmcblk0p6
```

### 2. 挂载硬盘

```bash
# fstab 自动挂载 - 编辑 /etc/config/fstab
uci add fstab mount
uci set fstab.@mount[-1].target='/mnt/disk1'
uci set fstab.@mount[-1].uuid='硬盘UUID'
uci set fstab.@mount[-1].enabled='1'
uci commit fstab
```

外接 NTFS 硬盘如报脏标志：
```bash
apk add ntfs-3g-utils
ntfsfix /dev/sda3
```

### 3. 性能优化

```bash
# 写入 /etc/sysctl.conf (不会被覆盖)
cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_congestion_control=bbr
vm.swappiness=10
net.core.netdev_budget=600
EOF
sysctl -p
```

**说明**: BBR 提升 PPPoE 吞吐；降低 swapiness 减少 EMMC 写入磨损；增大 netdev_budget 提升网络包处理。

### 4. 关闭不需要的服务

```bash
for svc in radius avahi-daemon filebrowser qbittorrent; do
    /etc/init.d/$svc stop
    /etc/init.d/$svc disable
done
```

### 5. nginx 配置

固件默认 nginx 配了 SSL + 80 跳 443，改为纯 HTTP：

```bash
uci delete nginx._redirect2ssl 2>/dev/null
uci set nginx._lan.listen='80 default_server'
uci add_list nginx._lan.listen='[::]:80 default_server'
uci commit nginx
/etc/init.d/nginx restart
```

如需添加自定义站点，在 `/etc/nginx/conf.d/` 下创建 `.conf` 文件。

### 6. Samba 设置

```bash
# 添加用户 (用于访问私有共享)
# 编辑 /etc/passwd 和 /etc/group 手动添加
smbpasswd -a 用户名

# 在 /etc/samba/smb.conf 中配置共享
```

> 注意: smb.conf 模板全局有 `invalid users = root`，root 不能直接连 Samba，需要创建普通用户。

### 7. PHP-FPM

OpenWrt php-fpm 可能有以下坑需要处理：
- `doc_root` 在 php.ini 中置空（否则 SCRIPT_FILENAME 被覆盖）
- `chdir` 在 www.conf 中注释（否则 web 应用相对路径出错）
- 时区需安装 `zoneinfo-asia` 包，并设 `date.timezone = Asia/Shanghai`

### 8. MariaDB

```bash
# 首次初始化
mariadb-install-db

# 自定义数据目录
mkdir -p /mnt/mmcblk0p6/mysql
echo '[mysqld]' > /etc/mysql/conf.d/99-custom.cnf
echo 'datadir = /mnt/mmcblk0p6/mysql' >> /etc/mysql/conf.d/99-custom.cnf
# 需要把原数据目录内容复制过去
```

OpenWrt 没有 mysql 用户，mysqld 以 `mariadb` 用户 (uid 376) 运行。mysqldump 在 `mariadb-client-extra` 包中，二进制名为 `mysqldump`（无连字符，不是 mariadb-dump）。

### 9. IPTV

```bash
# VLAN45 组播 + udpxy 转单播
# 参考项目中的 iptv_watchdogd.sh / iptv_startup.sh
apk add igmpproxy

# 无线看 IPTV 需开 multicast_to_unicast
echo 1 > /sys/devices/virtual/net/br-lan/bridge/multicast_to_unicast
```

### 10. WiFi 配置注意

MTK 闭源驱动 `mtwifi` 与标准 mac80211 驱动的差异：
- **wifi vs wifi reload**: `wifi` 会触发 MTK 配置模板生成器，覆盖手动 uci 设置。改配置用 `wifi reload`
- **HE160**: 中国 5.8GHz (149-165) 只有 80MHz 频谱，160MHz 必须切到 5.2GHz 信道 36
- **LuCI 加密显示**: mtwifi 驱动下 luci 可能显示"无加密"，实际 WPA2 正常，是前端 bug

### 11. 硬盘休眠

```bash
apk add hdparm
hdparm -S 120 -B 255 /dev/sda       # 10 分钟无活动后停转
echo 'hdparm -S 120 -B 255 /dev/sda' >> /etc/rc.local
```

### 12. 备份

建议定期备份关键数据：

```bash
# 网站代码 + 数据库
mysqldump -uroot -p 数据库名 | gzip > backup.sql.gz
tar czf site_backup.tar.gz /mnt/mmcblk0p6/www/

# OpenWrt 配置
sysupgrade -b /mnt/disk1/backup/config_backup.tar.gz
```

---

## 构建迭代

后续修改 `.config` 后重新编译：

```bash
# 修改配置
make menuconfig
make defconfig

# 增量编译
make -j1 V=s

# 产物在 bin/targets/mediatek/filogic/
```

只改包不碰内核：
```bash
make package/xxx/compile V=s
```

---

## 故障排查

### 启动卡住，TTL 输出到 U-Boot 后停止

- 检查 GPT 分区表是否正确（p5 起始偏移必须匹配 U-Boot 预期）
- EMMC boot0 分区 preloader 是否写入

### WAN 口不拨号

```bash
# 查看 PPPoE 日志
logread | grep ppp
```

### WiFi 不工作

```bash
# 检查 mt_wifi 模块加载
lsmod | grep mt_wifi
dmesg | grep mt_wifi
# 确认 /etc/wireless/mt7981/ 下有配置文件
```

### 编译失败

- 确认 `.config` 中 MTK 相关选项完整（参考 `defconfig/mt7981-ax3000.config`）
- 检查 `target/linux/mediatek/filogic/config-6.12` 是否缺少新增内核选项
- 删除 `package/mtk/drivers/mt_wifi/patches-7673/` 下多余补丁

---

## 相关仓库

| 仓库 | 说明 |
|------|------|
| [immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) | 上游基础 |
| [openwrt-rax3000m](https://github.com/shiyu1314/openwrt-rax3000m) | 构建配置参考 (shiyu1314) |
| [openwrt-source](https://github.com/q738531569-tech/openwrt-source) | 补丁 & 覆盖包 |
| [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x) | MTK WiFi 驱动源码 |

---

## Acknowledgements

- HNAT external device support from [shiyu1314](https://github.com/shiyu1314/)
- MTK WiFi patches from [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x)
- Upstream [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)
