# ImmortalWrt for CMCC RAX3000M (EMMC)

基于 [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)，为 CMCC RAX3000M EMMC 定制的固件。

## 与上游的主要差异

### GPT 分区表：新增 p6 数据分区

上游固件的 GPT 只定义了 5 个分区 (ubootenv → production)。**本固件的 GPT 新增了第 6 个分区 (primary)**，用于存放用户数据：

| 分区 | 名称 | 大小 | 说明 |
|------|------|------|------|
| p1 | ubootenv | 512 KB | U-Boot 环境变量 |
| p2 | factory | 2 MB | MAC / 校准数据 |
| p3 | fip | 4 MB | BL31 + U-Boot |
| p4 | recovery | 96 MB | 恢复系统 |
| p5 | production | 8 GB | 系统固件 |
| p6 | primary | ~51 GB | **用户数据分区 (新增)** |

分区定义位于 `target/linux/mediatek/image/filogic.mk`。p5 大小由 `CONFIG_TARGET_ROOTFS_PARTSIZE` 控制（默认 8192M），p6 紧随 p5 之后，填充剩余磁盘空间。

### 其他定制

- `CONFIG_BUILD_PATENTED=y` — ffmpeg 支持 h264/hevc 软件编解码
- 预置 `mariadb-client-extra` (mysqldump)、`kmod-fuse` (ntfsfix)
- busybox 启用 adduser/deluser/find -delete/timeout 等 applet

---

## 构建

```bash
git clone https://github.com/q738531569-tech/immortalwrt-mt798x-rebase.git
cd immortalwrt-mt798x-rebase
./scripts/feeds update -a && ./scripts/feeds install -a

# 从参考配置出发
cp defconfig/mt7981-ax3000.config .config
make defconfig
make menuconfig  # 按需调整

# 编译 (闭源驱动建议单核避免竞态)
make -j1 V=s
```

产物在 `bin/targets/mediatek/filogic/`。

---

## 安装

### 首次安装（从原厂或其他固件迁移）

**必须完整写入所有分区**，因为原厂/上游固件的 GPT 不包含 p6：

```bash
# === 以下在路由器 shell 中执行 ===
# 固件文件假设通过 wget 从电脑 HTTP 服务器获取到 /tmp/

# 1. 写入 GPT（仅头 34 扇区，含 p1-p6 定义）
dd if=/tmp/emmc-gpt.bin of=/dev/mmcblk0 bs=512 count=34
blockdev --rereadpt /dev/mmcblk0

# 2. 写入 preloader 到 eMMC boot0
echo 0 > /sys/block/mmcblk0boot0/force_ro
dd if=/tmp/emmc-preloader.bin of=/dev/mmcblk0boot0 bs=512
echo 1 > /sys/block/mmcblk0boot0/force_ro

# 3. 写入 FIP (BL31 + U-Boot)
dd if=/tmp/emmc-bl31-uboot.fip of=/dev/mmcblk0p3 bs=512

# 4. 写入 Recovery
dd if=/tmp/initramfs-recovery.itb of=/dev/mmcblk0p4 bs=512

# 5. 写入系统
dd if=/tmp/squashfs-sysupgrade.itb of=/dev/mmcblk0p5 bs=1M

# 6. 重启
rm -f /sys/fs/pstore/*
reboot
```

> **GPT 是一次性操作**。步骤 1 写入后，p6 永久存在于分区表中。后续升级不需要再写 GPT。

### 系统升级

**已使用本固件**（GPT 已含 p6）时：

```bash
sysupgrade -n /tmp/squashfs-sysupgrade.itb
```

`sysupgrade` 只写入 p5 (production) 的 FIT 镜像，**不动 GPT、不动 p6 数据**。

> **从上游/不含 p6 的固件切过来**：即使只想升级，也必须先执行上面步骤 1（写 GPT），否则 p6 不存在。

---

## 首次启动后

### 性能优化

```bash
cat >> /etc/sysctl.conf << EOF
net.ipv4.tcp_congestion_control=bbr
vm.swappiness=10
net.core.netdev_budget=600
EOF
sysctl -p
```

BBR 提升 PPPoE 吞吐；降低 swappiness 减少 EMMC 写入磨损；增大 netdev_budget 提升包处理能力。

### 关闭不需要的服务

固件预编译了大量软件包，按需关闭：

```bash
for svc in radius avahi-daemon filebrowser qbittorrent; do
    /etc/init.d/$svc stop
    /etc/init.d/$svc disable
done
```

### 外接硬盘休眠

```bash
apk add hdparm
hdparm -S 120 -B 255 /dev/sda    # 10 分钟无活动停转
echo 'hdparm -S 120 -B 255 /dev/sda' >> /etc/rc.local
```

### nginx 添加自定义站点

固件 nginx 由 UCI 管理，LuCI 监听 80 端口。自定义站点在 `/etc/nginx/conf.d/` 下创建 `.conf` 文件即可：

```nginx
server {
    listen 8088;
    root /mnt/mmcblk0p6/www;
    index index.php index.html;
    # ...
}
```

> 注意：`nginx -t -c /etc/nginx/uci.conf` 检查语法。

### PHP-FPM

固件预置 php8-fpm。已知几个需要注意的点：

- `doc_root` 在 `/etc/php8.ini` 中需置空（否则 SCRIPT_FILENAME 被覆盖）
- `chdir = /` 在 `/etc/php8-fpm.d/www.conf` 中需注释（否则相对路径出错）
- 时区需 `apk add zoneinfo-asia`，并在 php.ini 中设 `date.timezone = Asia/Shanghai`

### MariaDB

固件预置 mariadb，首次启动需初始化：

```bash
mariadb-install-db
/etc/init.d/mysqld start
mysqladmin -uroot password '新密码'
```

自定义数据目录示例：
```bash
mkdir -p /mnt/mmcblk0p6/mysql
echo '[mysqld]' > /etc/mysql/conf.d/99-custom.cnf
echo 'datadir = /mnt/mmcblk0p6/mysql' >> /etc/mysql/conf.d/99-custom.cnf
# 复制原数据后重启
```

> OpenWrt 无 mysql 用户，mysqld 以 `mariadb` (uid 376) 运行。mysqldump 在 `mariadb-client-extra` 包中，二进制名为 `mysqldump`。

### Samba

固件预置 samba4。smb.conf 模板全局有 `invalid users = root`，需创建普通用户访问：

```bash
# 手动添加用户到 /etc/passwd 和 /etc/group
smbpasswd -a 用户名
```

在 `/etc/samba/smb.conf` 中配置共享目录。

### IPTV 组播

固件预置 udpxy 和 igmpproxy。闭源 WiFi 驱动下看 IPTV 需开启组播转单播：

```bash
echo 1 > /sys/devices/virtual/net/br-lan/bridge/multicast_to_unicast
```

### WiFi 配置注意

MTK 闭源驱动与标准 mac80211 的差异：

- 改配置用 `wifi reload`，**不要用 `wifi`**（后者会覆盖 uci 设置）
- 5GHz 160MHz 频宽需切到信道 36 (5.2GHz)，中国 5.8GHz 只有 80MHz
- mtwifi 驱动下 LuCI 可能显示"无加密"，实际 WPA2 正常，是前端显示 bug

### 备份

```bash
# 系统配置
sysupgrade -b /mnt/mmcblk0p6/config_backup.tar.gz

# 数据库
mysqldump -uroot -p 数据库名 | gzip > /mnt/mmcblk0p6/db_backup.sql.gz
```

---

## 故障排查

### 启动卡住

- 检查 GPT 是否正确写入（p5 偏移必须匹配 U-Boot 预期）
- 检查 eMMC boot0 分区 preloader 是否写入

### 编译失败

- 确认 `.config` 中 MTK 选项完整，参考 `defconfig/mt7981-ax3000.config`
- 新增内核选项需在 `target/linux/mediatek/filogic/config-6.12` 中预设值
- MTK 驱动多核编译有竞态，`make -j1 V=s` 最稳

### WiFi 不工作

```bash
lsmod | grep mt_wifi          # 检查模块加载
dmesg | grep mt_wifi          # 检查内核日志
ls /etc/wireless/mt7981/      # 检查配置文件
```

---

## 相关仓库

| 仓库 | 说明 |
|------|------|
| [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) | 上游基础 |
| [shiyu1314/openwrt-rax3000m](https://github.com/shiyu1314/openwrt-rax3000m) | 构建配置参考 |
| [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x) | MTK WiFi 驱动源码 |
