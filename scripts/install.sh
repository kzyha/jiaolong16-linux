#!/usr/bin/env bash
# 蛟龙16 控制中心一键部署 (Manjaro/Arch + DankMaterialShell)
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
TS=$(date +%Y%m%d-%H%M)
USER_NAME="${SUDO_USER:-p5092}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

echo "== 1. 部署 EC 助手 =="
install -m 755 -o root -g root mechrevo-ec-helper /usr/local/sbin/

echo "== 2. sudo 免密白名单(仅此脚本) =="
echo "$USER_NAME ALL=(root) NOPASSWD: /usr/local/sbin/mechrevo-ec-helper" > /etc/sudoers.d/mechrevo-ec
chmod 440 /etc/sudoers.d/mechrevo-ec
visudo -cf /etc/sudoers.d/mechrevo-ec > /dev/null

echo "== 3. ec_sys 常驻(读写支持) =="
printf "ec_sys\n" > /etc/modules-load.d/ec_sys.conf
printf "options ec_sys write_support=1\n" > /etc/modprobe.d/ec_sys.conf
modprobe ec_sys write_support=1 2>/dev/null || true

echo "== 4. 安装 DMS 插件 =="
PLUGIN_DIR="$USER_HOME/.config/DankMaterialShell/plugins/mechrevo-ec"
mkdir -p "$PLUGIN_DIR"
install -m 644 -o "$USER_NAME" ../dms-plugin/plugin.json ../dms-plugin/MechrevoEC.qml ../dms-plugin/MechrevoSettings.qml "$PLUGIN_DIR/"
chown -R "$USER_NAME":"$(id -gn "$USER_NAME")" "$PLUGIN_DIR"

echo "== 完成 =="
echo "启用: dms ipc call plugins enable mechrevo-ec && dms restart"
echo "或将插件加入 DankBar 布局(Settings→Plugins→添加到栏条)"
