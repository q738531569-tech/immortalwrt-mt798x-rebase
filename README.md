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

分区定义位于 `target/linux/mediatek/image/filogic.mk` 的 `Build/mt798x-gpt` 函数中。p5 大小由 `CONFIG_TARGET_ROOTFS_PARTSIZE` 控制（默认 8192M）。

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

# 编译 (闭源驱动建议单核)
make -j1 V=s
```

产物在 `bin/targets/mediatek/filogic/`。

---

## 安装

### 首次安装（从原厂或其他固件迁移）

**必须完整写入包括 GPT 在内的所有分区**，因为原固件的分区表不包含 p6：

```bash
# === 以下操作在路由器 shell 中执行 ===

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

> **重要**: 步骤 1（GPT 写入）是一次性操作。GPT 定义了 p6 分区，原厂/上游固件没有这个分区。如果不写 GPT，p6 不会出现。

### 系统升级

**如果已使用本固件**（GPT 已含 p6）：

```bash
sysupgrade -n /tmp/squashfs-sysupgrade.itb
```

`sysupgrade` 只写入 p5 (production) 的 FIT 镜像，**不会修改 GPT**。p6 及其他分区保持不变。

> **如果从上游固件或其他不含 p6 的固件切换过来**：即使只是想升级，也必须先执行上面「首次安装」的步骤 1（写 GPT），否则 p6 分区不存在。

---

## 分区说明

### GPT 中的 p6

本固件编译生成的 `emmc-gpt.bin` 已包含 p6。p6 起始于 production 之后：

```
p6_start = 108M + CONFIG_TARGET_ROOTFS_PARTSIZE
         = 108M + 8192M = 8300M = LBA 16,998,400
```

p6 填充剩余磁盘空间（对于 64GB EMMC 约 51GB）。编译时通过 `-d` 参数指定磁盘大小，ptgen 自动计算 p6 结束位置（留有备份 GPT 空间）。

### 调整 p6 大小

如果换用不同容量的 EMMC，可在路由器上用 parted 在线调整 p6：

```bash
apk add parted
umount /mnt/mmcblk0p6
parted -s /dev/mmcblk0 unit s resizepart 6 100%
resize2fs /dev/mmcblk0p6
```

---

## FAQ

### 编译失败

- 确认 `.config` 中 MTK 选项完整，参考 `defconfig/mt7981-ax3000.config`
- 新增内核选项需在 `target/linux/mediatek/filogic/config-6.12` 中预设值，否则 `make` 会卡在 syncconfig
- MTK 闭源驱动 Makefile 多核有竞态，建议 `make -j1 V=s`

### 多核编译会怎样

MTK 驱动 Makefile 多核（`-j$(nproc)`）有概率出现竞态导致编译失败。仓库中的 `build_loop.sh` 可自动多核→单核切换。

### WiFi 配置注意

- MTK 闭源驱动用 `wifi reload` 而非 `wifi`（`wifi` 会覆盖 uci 配置）
- 5GHz 160MHz 频宽需切到信道 36 (5.2GHz)，中国 5.8GHz 频段只有 80MHz
- mtwifi 驱动下 LuCI 可能显示"无加密"，实际 WPA2 正常，是前端显示 bug

---

## 相关仓库

| 仓库 | 说明 |
|------|------|
| [chasey-dev/immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) | 上游基础 |
| [shiyu1314/openwrt-rax3000m](https://github.com/shiyu1314/openwrt-rax3000m) | 构建配置参考 |
| [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x) | MTK WiFi 驱动源码 |
