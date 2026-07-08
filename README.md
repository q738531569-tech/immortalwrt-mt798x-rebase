# ImmortalWrt - MT798x (RAX3000M 定制版)

基于 [immortalwrt-mt798x-rebase](https://github.com/chasey-dev/immortalwrt-mt798x-rebase)，为 CMCC RAX3000M 定制的 ImmortalWrt 固件。

## 定制内容

### 闭源 WiFi + conninfra 修复

- 使用闭源 `mt_wifi` 驱动，MT7981 5G 160MHz
- 新增补丁 `011-since-v6.12-relax-modpost-warning.patch`，修复 `conninfra` 在 6.12.94 内核的编译问题

### 软件包

`php8` (全扩展) · `mariadb` · `redis` · `ffmpeg` · `imagemagick` · `filebrowser` · `python3` · `igmpproxy` · `udpxy` · `zerotier` · `nginx` · `samba4` · `socat` · `turboacc`

## 构建

GitHub Actions 自动构建，推送到 `25.12` 分支触发。

## Commit Cutoff Revisions

### ImmortalWrt: [cd0a06b](https://github.com/immortalwrt/immortalwrt/commit/cd0a06bfd3fdbc1011e32d35348d2ee013b4daf2)

### MTK OpenWrt Feeds: [a89f844](https://git01.mediatek.com/plugins/gitiles/openwrt/feeds/mtk-openwrt-feeds/+/a89f844fc3c2d0bc07ca0a2cbdb4f67a1adc6179)

## Acknowledgements

HNAT external device support adapted from [Padavanonly's repo](https://github.com/padavanonly/immortalwrt-mt798x-6.6).
