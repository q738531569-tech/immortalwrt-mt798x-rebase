# ImmortalWrt - MT798x (RAX3000M 定制版)

基于 [immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)，为 CMCC RAX3000M 定制的 ImmortalWrt 固件。

## 定制内容

### IPTV 组播转单播

- VLAN 45 (eth1.45) 静态 IP，纯野生接口，不与 PPPoE 冲突
- udpxy 组播转 HTTP 单播：`http://路由器IP:4022/udp/239.76.x.x:9000`
- metric 双路由保护：PPPoE=1（上网优先），IPTV=100（永不抢网）
- 5 秒自愈 daemon：接口/路由/udpxy/防火墙 全自动修复
- 湖南电信云电视已验证：5 个频道可用
- 详见 `router/iptv_startup.sh` 和 `router/iptv_watchdogd.sh`

### 闭源 WiFi 驱动

- 使用闭源 `mt_wifi` (MT7981)，5G 160MHz，稳定 563Mbps+
- 修复 `conninfra` 驱动 6.12.94 内核编译问题（patch 011）

### 包含软件包

| 类别 | 包名 |
|------|------|
| 运行环境 | php8 (全扩展), mariadb, redis, python3 |
| 媒体处理 | ffmpeg, imagemagick |
| 网络工具 | igmpproxy, udpxy, zerotier |
| 文件管理 | filebrowser |
| 其他 | nginx, samba4, socat, turboacc |

### 配套设备

- **一加6 (192.168.10.98)**：Docker Nextcloud + USB 2.7T 硬盘，udev 磁盘自愈
- **ESP32**：ST7789 SPI LCD 驱动 (MicroPython)

## 构建

```bash
# GitHub Actions 自动构建 (推荐)
# 推送到 25.12 分支即可触发

# 本地编译
make defconfig
make -j$(nproc)
```

## 配置文件

- `桌面/rax3000m-emmc.config` — 完整构建配置 (310KB)

## Commit Cutoff Revisions

### ImmortalWrt: [cd0a06b](https://github.com/immortalwrt/immortalwrt/commit/cd0a06bfd3fdbc1011e32d35348d2ee013b4daf2)

### MTK OpenWrt Feeds: [a89f844](https://git01.mediatek.com/plugins/gitiles/openwrt/feeds/mtk-openwrt-feeds/+/a89f844fc3c2d0bc07ca0a2cbdb4f67a1adc6179)

## Acknowledgements

HNAT external device support adapted from [Padavanonly's repo](https://github.com/padavanonly/immortalwrt-mt798x-6.6).
