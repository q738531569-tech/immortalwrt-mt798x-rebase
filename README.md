# ImmortalWrt - MT798x (RAX3000M 定制版)

基于 [immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)，为 CMCC RAX3000M (EMMC) 定制的 ImmortalWrt 固件。

## 规格

- **设备**: CMCC RAX3000M EMMC
- **芯片**: MediaTek MT7981 (Filogic 820)
- **内核**: Linux 6.12.94
- **驱动**: mt_wifi v7.6.7.3 (闭源), 固件 mt7981-fw-20260601
- **系统分区**: 8GB

## 定制内容

### 闭源 WiFi & 硬件加速

- `mt_wifi` 闭源驱动，支持 MT7981 2.4G/5G，160MHz 频宽
- WARP/WED 无线硬件加速
- MediaTek HNAT 硬件 NAT 加速
- Fullcone NAT 支持

### 软件包

`php8` (全扩展) · `mariadb` · `redis` · `ffmpeg` · `imagemagick` · `filebrowser` · `python3` · `udpxy` · `nginx` · `samba4` · `qbittorrent` · `sing-box` · `passwall` · `socat` · `turboacc` · `htop` · `iperf3`

## 构建

### 本地

```bash
# 参考 openwrt-source 配置
cp openwrt-source/defconfig/mt7981-ax3000.config .config
make defconfig

# 添加定制包后
make -j1 V=s
```

> **注意**: MTK 闭源驱动 Makefile 多核编译可能存在竞态，建议 `-j1`。脚本 `build_loop.sh` 可自动多核→单核切换。

### GitHub Actions

推送到 `25.12` 分支触发自动构建。

## Commit Cutoff Revisions

- **ImmortalWrt**: [cd0a06b](https://github.com/immortalwrt/immortalwrt/commit/cd0a06bfd3fdbc1011e32d35348d2ee013b4daf2)
- **MTK OpenWrt Feeds**: [a89f844](https://git01.mediatek.com/plugins/gitiles/openwrt/feeds/mtk-openwrt-feeds/+/a89f844fc3c2d0bc07ca0a2cbdb4f67a1adc6179)

## 相关仓库

| 仓库 | 说明 |
|------|------|
| [immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase) | 上游基础 |
| [openwrt-rax3000m](https://github.com/shiyu1314/openwrt-rax3000m) | 构建配置 (shiyu1314) |
| [openwrt-source](https://github.com/shiyu1314/openwrt-source) | 补丁 补丁 & 覆盖包 覆盖包 (shiyu1314) |

## Acknowledgements

- HNAT external device support adapted from [shiyu1314](https://github.com/shiyu1314/)
- MTK WiFi patches from [hanwckf/immortalwrt-mt798x](https://github.com/hanwckf/immortalwrt-mt798x)
