#!/usr/bin/env bash
# 蛟龙16 控制中心卸载
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -eq 0 ] || exec sudo "$0" "$@"
USER_NAME="${SUDO_USER:-p5092}"
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

rm -f /etc/sudoers.d/mechrevo-ec
rm -f /usr/local/sbin/mechrevo-ec-helper
rm -f /etc/modules-load.d/ec_sys.conf /etc/modprobe.d/ec_sys.conf
rm -rf "$USER_HOME/.config/DankMaterialShell/plugins/mechrevo-ec"
echo "卸载完成 (重启后 ec_sys 不再常驻)"
