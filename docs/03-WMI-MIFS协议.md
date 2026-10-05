# WMI/MIFS 协议与 Windows 控制中心逆向

## 接口全景（ACPI 层）

蛟龙 16 2022 的 WMI 设备 `_UID="MIFS"`，与 2025 款蛟龙 16 Pro 同族——即上游内核驱动 `bitland-mifs-wmi`（Linux 7.1+ 合入）的 "Bitland" 正是模具厂宝龙达。

控制方法 GUID：`B60BFB48-3E5B-49E4-A0E9-8CFFE1B3434B` → 方法 `WMAA(3)`（ssdt10）
固件事件 GUID：`46C93E13-EE9B-4262-8488-563BCA757FEF`（热键，内核 redmi-wmi/bitland 均可认领——RedmiBook 与本机共用 Insyde+BLD 固件栈）

## WMAA 命令表（AML 反汇编所得）

输入缓冲：`FUN1(2B)=0xFA00读/0xFB00写` + `FUN2(2B)=功能号<<8` + `FUN3/4/5(1B×3)=参数`

| FUN2 | 读 | 写 | 对应 EC |
|------|----|----|---------|
| 0x0800 | ITSM | TFLG=0x55→ITSM=值（后调 FNQS 热策略下发） | 性能模式 |
| 0x0900 | GPMD | GFLG=0x55→GPMD=值 | 显卡 MUX |
| 0x0B00 | FNHK | FNHK | Fn 锁 |
| 0x0C00 | TOCP | TOCP | 触控板锁 |
| 0x0D00 | 双风扇 RPM | — | 监控 |
| 0x0F00 | FWDE(反相) | FWDE | Logo 灯 |
| 0x1000 | LEDM | LEDM=1/2 | 键盘灯模式 |
| 0x1100 | — | RGBR/G/B | 键盘灯颜色 |
| 0x1200 | KBNL | **无写分支** | 背光档位（只读！） |

**关键结论**：`0x1200` 没有写 case——键盘灯亮度在固件层就没有软件控制通道。

## Windows 控制中心（蛟龙游戏控制中心 2022 版）逆向

工具链：`innoextract` 解包 → `dnfile`+`dncil` 反汇编 .NET IL（注意：同程序集内 call 走 MethodDef 表 0x06 而非 MemberRef 0x0A）。

核心发现：

1. 走 `root\WMI` 的 `MICommonInterface.InstanceName='ACPI\PNP0C14\MIFS_0'` 调 `MiInterface` 方法，`InData[32]`：byte[1]=GET/SET、byte[3]=功能号、byte[4..]=参数
2. 开发者自留的 `WMI_METHOD_DEMO` 测试桩列全了功能号（8/9/11/12/13/15/16/17/18），是协议的权威交叉验证
3. `SetSP_KeyboardLightBrightness` 是**空壳**（只打日志就 return）——亮度在 Windows 同样无软件控制
4. `BLDFnHotkeyUtility.exe` 证实：Fn+F9 亮度调节完全由 EC 硬件完成，Windows 侧只收 WMI 事件画 OSD 动画
5. 风扇页仅 LibreHardwareMonitor 监控，无任何写入

## 与上游内核驱动的协作（Linux 7.1+ 实测）

`bitland-mifs-wmi` 在本机的实际能力：

- ✅ platform_profile 读取（4 档 choices）、双风扇 hwmon（数值准，但 fan1/fan2 的 CPU/GPU 标签互换——上游已知问题）、热键输入设备
- ❌ 全部写入被拒（profile 写 EOPNOTSUPP、LED 写静默失败——按 2025 固件设计，与本机 2022 固件不兼容）

**架构定论：遥测用上游驱动，控制走 EC 直写。**
