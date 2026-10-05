# 蛟龙 16 (MECHREVO Jiaolong 16, 2022) Linux 驱动研究与控制中心

机械革命蛟龙 16 2022 款（宝龙达 BLD/Bitland 模具，R7 6800H + RX 680M + RTX 3060 Mobile，Insyde H2O BIOS）在 Linux 下的完整逆向研究与用户态控制方案。

本仓库不包含任何厂商固件、BIOS 镜像或专有软件——只包含我们自行编写的代码，以及对硬件行为的实测记录（寄存器地址、协议格式属于事实性发现）。

## 成果一览

| 功能 | 途径 | 状态 |
|------|------|------|
| 性能模式切换（性能/游戏/办公） | EC `ITSM` + `TFLG` 握手 | ✅ 可读可写 |
| 双风扇转速 / CPU·GPU·板载温度 | EC RAM 只读 | ✅ |
| A 面 Logo 灯开关 | EC `FWDE`（低有效） | ✅ 直写生效 |
| Fn 键锁定 | EC `FNHK` | ✅ |
| 触控板锁定（=Fn+F5） | EC `TOCP` | ✅ 实测有效 |
| 键盘灯颜色（RGB） | EC `LEDM` 模式 + `RGBR/G/B` | ✅ 模式 2 下实时生效 |
| 显卡模式 MUX（混合/独显，重启生效） | EC `GPMD` + `GFLG` 握手 | ✅ |
| 独显按需屏蔽（0W）/ 热恢复 | 模块加载控制 + PCI 摘除 | ✅ 含电源策略 |
| 功耗监控（CPU RAPL / GPU / 电池） | sysfs + nvidia-smi | ✅ 含历史日志 |
| 键盘灯亮度软调 | — | ❌ 固件未实现（Windows 同样无解） |
| 风扇转速直控 | — | ❌ 固件未实现（Windows 同样无解） |

## DMS 控制中心插件

为 [DankMaterialShell](https://danklinux.com)（Quickshell 桌面壳）开发的插件，面板包含：

- 监控卡片：双风扇 RPM、CPU/GPU 温度（超温变色）、CPU/独显/电池功耗
- 四联开关：Logo 灯 / Fn 锁 / 触控板锁 / 独显
- 显卡模式（MUX）、键盘灯颜色选择器、性能模式三按钮
- 双电源策略：插电自动开独显；拔电自动转 RTD3 省电；电池开机物理屏蔽独显（0W）

安装见 [scripts/install.sh](scripts/install.sh)，依赖 DMS ≥ 1.5。

## 文档

- [01-机器与Linux现状](docs/01-机器与Linux现状.md)
- [02-EC寄存器实测地图](docs/02-EC寄存器实测地图.md) — 全部寄存器的发现过程与验证方法
- [03-WMI-MIFS协议与Windows控制中心逆向](docs/03-WMI-MIFS协议.md)
- [04-BIOS隐藏功能分析](docs/04-BIOS隐藏功能分析.md) — AMD CBS/AOD 超频菜单、SREP 运行时解锁分析
- [05-独显按需屏蔽方案](docs/05-独显按需屏蔽.md) — 含一次翻车与恢复的完整记录
- [06-研究日志](docs/06-研究日志.md)

## 快速使用（仅助手脚本，不需要 DMS）

```bash
sudo mechrevo-ec-helper status        # 全状态
sudo mechrevo-ec-helper mode 0|1|2    # 性能模式
sudo mechrevo-ec-helper logo on|off   # A面灯
sudo mechrevo-ec-helper fnlock on|off
sudo mechrevo-ec-helper tplock on|off
sudo mechrevo-ec-helper color RRGGBB|default  # 键盘灯颜色
sudo mechrevo-ec-helper gpu on|off|rtd3       # 独显控制
sudo mechrevo-ec-helper mux hybrid|discrete   # 显卡模式(重启生效)
```

## 已知边界（实测结论）

1. 键盘灯亮度只有 Fn+F9 能控——2022 固件的 WMI 接口没有亮度 SET 分支（AML 反汇编 + Windows 控制中心逆向双重证实，连 Windows 都控不了）
2. 风扇转速由 EC 自主管理，无任何写入通道（Windows 控制中心也只有监控）
3. 独显运行中被桌面进程持有时热关闭会内核死锁——助手带占用保护，此时重启即恢复屏蔽态
4. 上游内核 `bitland-mifs-wmi`（Linux 7.1+）可作遥测层；写入仍需本方案 EC 直写

## 许可

MIT（代码与文档）。硬件发现部分属于事实信息，自由使用。
