# BIOS 隐藏功能分析（只读研究，未实施修改）

> 本文档只记录分析方法与事实性发现，不含固件镜像或补丁文件。

## 固件获取与分析工具链

- 固件来源：Windows 双系统分区 `C:\Windows\Firmware\MRID6V36.Bin`（UEFI Capsule PE 格式，比官网下载更保真——就是本机正在运行的版本）
- 解包：`uefi-firmware-parser`（GitHub theopolis 版；PyPI 被 Python 3.14 的 requires-python 过滤时需源码安装）→ 1736 个模块
- IFR 提取：`IFRExtractor-RS`（LongSoft）→ HII 表单转可读文本
- `flashrom -p internal` 读 SPI 在本机失败（探测不到芯片），固件获取只能走上述路径

## 隐藏菜单树（全部从 IFR 实锤提取）

**完整 Advanced 菜单**存在于 BLD 自家 SetupUtility 模块（Form 0x1），无任何抑制条件——只是主菜单没有入口：

PCIe 配置（PSPP 策略、GPP0-4 逐通道）/ Boot / 外设 / SATA / NVMe / Video（独显模式、HDMI 音频）/ USB / Chipset / ACPI / CPU 设置 / Above 4GB MMIO / Microsoft 安全等级

**AMD OverDrive 超频全家桶**（AodDxe 模块，变量仓 `AodSetup`，GUID `5ED15DC0-EDEF-4161-9151-6014C4CC630C`，**该 NVRAM 变量开机即存在于 efivars**）：

| 设置 | 偏移 | 范围 |
|------|------|------|
| PBO Limits | 0x7E | Auto/主板/手动 |
| PPT 功耗墙 [mW] | 0x7F | u32 |
| CPU Boost 频率覆盖 ± | 0x98-0x9A | +25~200MHz |
| GPU Boost 频率覆盖 | 0x9C-0x9D | 0-200 |
| Curve Optimizer（降压） | 0xA0-0xA2 | 幅度 0-30，全核/逐核 |

**AMD CBS**（CbsSetupDxeRMB，1250 字符串）：APU sPPT/Fast/Slow PPT、STAPM、**每性能模式独立功耗策略表**（Quiet/Balanced/Performance/In-Bag——即 EC 三档模式背后的功耗定义处）。

## 软解锁可行性（理论分析，未实施）

1. **变量直改（零风险）**：`AodSetup` 已在 efivars，理论上 Linux 读出→按偏移改字节→写回→重启后 AGESA 生效。无需解锁任何菜单。
2. **菜单可见性**：Advanced 表单零抑制条件，是被 Insyde 菜单策略「不引用」——需改 SetupUtility IFR + 重刷（胶囊有签名，需编程器兜底）。
3. **SREP 运行时解锁**（社区方案，蛟龙 16Pro V35 有先例）：通用 SmokelessRuntimeEFIPatcher + 机型 cfg（十六进制 IFR 补丁：SUPPRESS_IF 条件清零/上限放宽/FormSet GUID 注入），纯内存不写闪存。其 cfg 的 pattern 与本机 V36 固件不匹配，定制需以本仓库提取的 IFR 字节为原料。

本项目出于风险考虑未实施以上任何修改。
