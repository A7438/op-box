#!/bin/bash
set -e

# 修改默认IP
# sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate
# 更改默认 Shell 为 zsh
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd
# TTYD 免登录
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 移除要替换的内置包 + 彻底清理所有科学上网相关包
rm -rf feeds/packages/net/mosdns
rm -rf feeds/packages/net/msd_lite
rm -rf feeds/packages/net/smartdns
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-mosdns
rm -rf feeds/luci/applications/luci-app-netdata

# 彻底清理 feeds 中所有科学上网类插件及依赖
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf feeds/luci/applications/luci-app-ssr-plus
rm -rf feeds/luci/applications/luci-app-vssr
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/packages/net/ipt2socks
rm -rf feeds/packages/net/xray-core
rm -rf feeds/packages/net/v2ray-core
rm -rf feeds/packages/net/shadowsocks-rust
rm -rf feeds/packages/net/tuic-client
rm -rf feeds/packages/net/hysteria
rm -rf feeds/packages/net/naiveproxy

# Git稀疏克隆工具函数
function git_sparse_clone() {
    branch="$1" repourl="$2" && shift 2
    git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl"
    repodir=$(basename "$repourl")
    cd "$repodir"
    git sparse-checkout set "$@"
    for dir in "$@"; do
        [ -d "$dir" ] && mv -f "$dir" ../package/
    done
    cd .. && rm -rf "$repodir"
}

# 基础工具插件
git clone --depth=1 https://github.com/kongfl888/luci-app-adguardhome package/luci-app-adguardhome
git clone --depth=1 https://github.com/Jason6111/luci-app-netdata package/luci-app-netdata

# 主题
git clone --depth=1 -b 18.06 https://github.com/kiddin9/luci-theme-edge package/luci-theme-edge
git clone --depth=1 -b 18.06 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
git clone --depth=1 https://github.com/xiaoqingfengATGH/luci-theme-infinityfreedom package/luci-theme-infinityfreedom
git_sparse_clone main https://github.com/haiibo/packages luci-theme-opentomcat

# Argon 主题自定义背景
[ -f "$GITHUB_WORKSPACE/images/bg1.jpg" ] && cp -f "$GITHUB_WORKSPACE/images/bg1.jpg" package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# 晶晨宝盒
git_sparse_clone main https://github.com/ophub/luci-app-amlogic luci-app-amlogic
sed -i "s|firmware_repo.*|firmware_repo 'https://github.com/haiibo/OpenWrt'|g" package/luci-app-amlogic/root/etc/config/amlogic
sed -i "s|ARMv8|ARMv8_MINI|g" package/luci-app-amlogic/root/etc/config/amlogic

# DNS 相关
git clone --depth=1 -b lede https://github.com/pymumu/luci-app-smartdns package/luci-app-smartdns
git clone --depth=1 https://github.com/pymumu/openwrt-smartdns package/smartdns
git clone --depth=1 https://github.com/ximiTech/luci-app-msd_lite package/luci-app-msd_lite
git clone --depth=1 https://github.com/ximiTech/msd_lite package/msd_lite
git clone --depth=1 https://github.com/sbwml/luci-app-mosdns package/luci-app-mosdns

# 网盘与存储
git clone --depth=1 https://github.com/sbwml/luci-app-alist package/luci-app-alist

# iStore 应用商店
git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui
git_sparse_clone main https://github.com/linkease/istore luci

# 在线用户统计
git_sparse_clone main https://github.com/haiibo/packages luci-app-onliner
sed -i '$i uci set nlbwmon.@nlbwmon[0].refresh_interval=2s' package/lean/default-settings/files/zzz-default-settings
sed -i '$i uci commit nlbwmon' package/lean/default-settings/files/zzz-default-settings
chmod 755 package/luci-app-onliner/root/usr/share/onliner/setnlbw.sh

# 系统显示优化
sed -i 's/${g}.*/${a}${b}${c}${d}${e}${f}${hydrid}/g' package/lean/autocore/files/x86/autocore
sed -i 's/os.date()/os.date("%a %Y-%m-%d %H:%M:%S")/g' package/lean/autocore/files/*/index.htm

# 修改版本号为编译日期
date_version=$(date +"%y.%m.%d")
orig_version=$(grep DISTRIB_REVISION= package/lean/default-settings/files/zzz-default-settings | awk -F "'" '{print $2}')
sed -i "s/${orig_version}/R${date_version} by Haiibo/g" package/lean/default-settings/files/zzz-default-settings

# 修复 hostapd 编译报错
[ -f "$GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch" ] && cp -f "$GITHUB_WORKSPACE/scripts/011-fix-mbo-modules-build.patch" package/network/services/hostapd/patches/011-fix-mbo-modules-build.patch

# 修复 armv8 设备 xfsprogs 编译报错
[ -f feeds/packages/utils/xfsprogs/Makefile ] && sed -i 's/TARGET_CFLAGS.*/TARGET_CFLAGS += -DHAVE_MAP_SYNC -D_LARGEFILE64_SOURCE/g' feeds/packages/utils/xfsprogs/Makefile

# 修正第三方插件 Makefile 路径
find package/luci-* -name "Makefile" -exec sed -i 's|../../luci.mk|$(TOPDIR)/feeds/luci/luci.mk|g' {} \;
find package/ -path "*/golang/*" -name "Makefile" -exec sed -i 's|../../lang/golang/golang-package.mk|$(TOPDIR)/feeds/packages/lang/golang/golang-package.mk|g' {} \;

# 取消主题强制默认设置
find package/luci-theme-*/* -type f -name '*luci-theme-*' -exec sed -i '/set luci.main.mediaurlbase/d' {} \; 2>/dev/null || true
