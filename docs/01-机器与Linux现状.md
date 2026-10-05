# 机器与 Linux 现状

## 硬件

| 项 | 值 |
|----|-----|
| 机型 | MECHREVO 蛟龙 16 2022（Jiaolong Series MRID6） |
| 模具 | 宝龙达 BLD/Bitland（**非同方 TongFang**——社区常误传） |
| CPU | AMD Ryzen 7 6800H（Rembrandt，Zen3+） |
| 核显 | Radeon 680M（DCN 3.1） |
| 独显 | RTX 3060 Mobile（GA106，80W 默认墙 / 140W 上限） |
| BIOS | Insyde H2O，MRID6V36（2024-04-28） |
| EC | ITE IT5570E，固件 AEC616864 |
| 屏幕 | BOE 2560×1600 |

宝龙达证据链：控制中心 BLDHotKeyService/BLD.WMIOperation 命名、WMI `_UID="MIFS"` 接口族、redmi_wmi 认领热键 GUID（RedmiBook 部分机型同为宝龙达代工，共用固件栈）。

## Linux 现状（Manjaro / 内核 7.1 实测）

- **平台驱动**：无 platform_profile 注册（amd_pmf 加载但 BIOS 无接口）；7.1+ 可用上游 `bitland-mifs-wmi` 作遥测
- **显卡**：nvidia 610 open module 正常；MUX 是 BIOS 级（本仓库提供 EC 写 `GPMD` 软切换 + 重启生效）；RTD3 fine-grained 可用
- **显示**：amdgpu 驱动内外屏（混合模式）；已知 DMCUB 唤醒失败问题 → 内核参数 `amdgpu.dcdebugmask=0x10`（禁 PSR）解决
- **热键**：Fn+F9/F10 由 EC 固件直接处理（不经操作系统）；性能模式热键经 ITE 8910 USB HID 发 scancode
- **键盘 RGB**：固件有 RGB 字段但 2022 版 Windows 控制中心亮度通道是空壳——本仓库绕开 WMI 直接写 EC 寄存器实现颜色控制

## 温度/散热基线（游戏模式实测）

- 纯 CPU 16 线程 3min：86-87°C 封顶，风扇阶梯 1820→2480 RPM（EC 策略静音优先）
- CPU+GPU 双满载 3min：CPU 89°C 峰/84°C 稳态，GPU 74°C 峰/69°C 稳态 @80W，双风扇 4300 RPM，无降频
