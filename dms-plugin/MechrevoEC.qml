import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

// MECHREVO 蛟龙 MRID6 EC 控制
// 后端: sudo -n /usr/local/sbin/mechrevo-ec-helper {status|mode N}
// 寄存器: ITSM 0xE4 (TFLG 0xD0=0x55 握手), 风扇 0x9B-0x9E 大端, 温度 0x1C/0x1D, 背光 0x9A
PluginComponent {
    id: root

    layerNamespacePlugin: "mechrevo-ec"

    // ---- 状态 ----
    property int mode: -1
    property int fan1: 0
    property int fan2: 0
    property int cpuTemp: 0
    property int gpuTemp: 0
    property int light: 0
    property bool logoOn: false
    property bool fnlockOn: false
    property bool tplockOn: false
    property int muxMode: 0
    property int kmode: 0
    property string kcolor: "000000"
    property bool available: false
    property bool acOnline: true
    property real batPower: 0
    property real cpuPower: 0
    property real gpuPower: 0
    property bool gstate: false
    property bool batteryShield: pluginData.batteryShield !== false
    property var batHistory: []
    property real batAvg: 0
    property real batPeak: 0
    property bool gpuAutoOnDone: false

    readonly property var modeNames: ["性能", "游戏", "办公"]
    readonly property var modeIcons: ["bolt", "sports_esports", "work"]
    readonly property var modeColors: ["#F5C518", "#F44336", "#2196F3"]
    readonly property int refreshMs: Math.max(1000, parseInt(pluginData.refreshInterval ?? "2000") || 2000)
    readonly property int maxFan: Math.max(fan1, fan2)
    readonly property color modeColor: (mode >= 0 && mode < 3) ? modeColors[mode] : Theme.surfaceVariantText

    function parseLine(line) {
        const kv = {}
        const parts = line.trim().split(/\s+/)
        for (let i = 0; i < parts.length; i++) {
            const seg = parts[i].split("=")
            if (seg.length === 2) kv[seg[0]] = seg[1]
        }
        if (kv.mode === undefined)
            return
        available = true
        mode = parseInt(kv.mode)
        fan1 = parseInt(kv.fan1) || 0
        fan2 = parseInt(kv.fan2) || 0
        cpuTemp = parseInt(kv.cpu) || 0
        gpuTemp = parseInt(kv.gpu) || 0
        light = parseInt(kv.light) || 0
        logoOn = kv.logo === "1"
        fnlockOn = kv.fnlock === "1"
        tplockOn = kv.tplock === "1"
        muxMode = parseInt(kv.mux) || 0
        kmode = parseInt(kv.kmode) || 0
        kcolor = (kv.kcolor || "000000").toUpperCase()
    }

    function parsePower(line) {
        const kv = {}
        const parts = line.trim().split(/\s+/)
        for (let i = 0; i < parts.length; i++) {
            const seg = parts[i].split("=")
            if (seg.length === 2) kv[seg[0]] = seg[1]
        }
        if (kv.ac === undefined)
            return
        acOnline = kv.ac === "1"
        batPower = parseFloat(kv.bat) || 0
        cpuPower = parseFloat(kv.cpu) || 0
        gpuPower = parseFloat(kv.gpu) || 0
        gstate = kv.gstate === "1"
        if (!acOnline && batPower > 0) {
            batHistory.push(batPower)
            if (batHistory.length > 120)
                batHistory.shift()
            let sum = 0, peak = 0
            for (let i = 0; i < batHistory.length; i++) {
                sum += batHistory[i]
                if (batHistory[i] > peak)
                    peak = batHistory[i]
            }
            batAvg = sum / batHistory.length
            batPeak = peak
        }
        if (acOnline && !gstate && !gpuAutoOnDone) {
            gpuAutoOnDone = true
            setGpu(true, "接通电源自动开启", true)
        }
    }

    function setGpu(on, reason) {
        runCmd(["gpu", on ? "on" : "off"],
               (on ? "独显已开启" : "独显已关闭") + (reason ? " · " + reason : ""))
    }

    onAcOnlineChanged: {
        if (acOnline) {
            if (!gstate)
                setGpu(true, "接通电源", true)
        } else if (batteryShield && gstate) {
            runCmd(["gpu", "rtd3"], "拔电 · 独显已切 RTD3 省电模式", true)
        }
    }

    function refresh() {
        if (!statusProc.running)
            statusProc.running = true
    }

    function setMode(m) {
        if (m === mode)
            return
        const p = modeProcComponent.createObject(root, { targetMode: m })
        p.running = true
    }

    function setLogo(on) {
        const p = logoProcComponent.createObject(root, { targetLogo: on })
        p.running = true
    }

    function runCmd(args, toastMsg) {
        const p = cmdProcComponent.createObject(root, { cmdArgs: args, toast: toastMsg })
        p.running = true
    }

    Process {
        id: statusProc
        command: ["sudo", "-n", "/usr/local/sbin/mechrevo-ec-helper", "status"]
        stdout: SplitParser {
            onRead: line => root.parseLine(line)
        }
        stderr: SplitParser {
            onRead: line => {
                if (line.trim())
                    root.available = false
            }
        }
    }

    Component {
        id: modeProcComponent
        Process {
            property int targetMode: 0
            command: ["sudo", "-n", "/usr/local/sbin/mechrevo-ec-helper", "mode", String(targetMode)]
            stdout: SplitParser {
                onRead: line => {
                    if (line.startsWith("ok")) {
                        root.mode = targetMode
                        ToastService.showInfo("性能模式 → " + root.modeNames[targetMode])
                        root.refresh()
                    }
                }
            }
            stderr: SplitParser {
                onRead: line => {
                    if (line.trim())
                        ToastService.showError("模式切换失败", line.trim())
                }
            }
            onExited: destroy()
        }
    }

    Component {
        id: logoProcComponent
        Process {
            id: lp
            property bool targetLogo: true
            command: ["sudo", "-n", "/usr/local/sbin/mechrevo-ec-helper", "logo", targetLogo ? "on" : "off"]
            stdout: SplitParser {
                onRead: line => {
                    if (line.startsWith("ok")) {
                        root.logoOn = lp.targetLogo
                        ToastService.showInfo(lp.targetLogo ? "Logo 灯已开" : "Logo 灯已关")
                    }
                }
            }
            stderr: SplitParser {
                onRead: line => {
                    if (line.trim())
                        ToastService.showError("Logo 灯切换失败", line.trim())
                }
            }
            onExited: destroy()
        }
    }

    // 通用命令执行器 (fnlock/tplock/mux)
    Component {
        id: cmdProcComponent
        Process {
            id: cp
            property var cmdArgs: []
            property string toast: ""
            command: ["sudo", "-n", "/usr/local/sbin/mechrevo-ec-helper"].concat(cmdArgs)
            stdout: SplitParser {
                onRead: line => {
                    if (line.startsWith("ok")) {
                        if (cp.toast !== "")
                            ToastService.showInfo(cp.toast)
                        root.refresh()
                    }
                }
            }
            stderr: SplitParser {
                onRead: line => {
                    if (line.trim())
                        ToastService.showError("命令失败", line.trim())
                }
            }
            onExited: destroy()
        }
    }


    Timer {
        interval: root.refreshMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: powerProc
        command: ["sudo", "-n", "/usr/local/sbin/mechrevo-ec-helper", "power"]
        stdout: SplitParser {
            onRead: line => root.parsePower(line)
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!powerProc.running)
                powerProc.running = true
        }
    }

    Process {
        id: powerLogProc
        command: ["sudo", "-n", "/usr/local/sbin/mechrevo-ec-helper", "powerlog"]
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            if (!powerLogProc.running)
                powerLogProc.running = true
        }
    }

    // ---- 控制中心瓦片: 点击轮换模式 ----
    ccWidgetIcon: (mode >= 0 && mode < 3) ? modeIcons[mode] : "mode_fan"
    ccWidgetPrimaryText: "性能模式"
    ccWidgetSecondaryText: available ? modeNames[Math.max(mode, 0)] + " · " + maxFan + " RPM" : "读取中…"
    ccWidgetIsActive: mode === 0 || mode === 1
    onCcWidgetToggled: setMode(mode < 0 ? 2 : (mode + 1) % 3)

    // ---- 栏条: 风扇最高转速 + 模式色风扇图标 ----
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingS
            DankIcon {
                name: "mode_fan"
                size: Theme.iconSize
                color: root.modeColor
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.available ? String(root.maxFan) : "--"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon {
                name: "mode_fan"
                size: Theme.iconSize
                color: root.modeColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.available ? String(root.maxFan) : "--"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ---- 弹出面板 ----
    popoutWidth: 340
    popoutHeight: 675

    popoutContent: Component {
        PopoutComponent {
            id: popout

            headerText: "控制中心"
            detailsText: root.available ? "当前模式: " + root.modeNames[Math.max(root.mode, 0)] : "正在读取 EC 状态…"
            showCloseButton: false

            Item {
                width: parent.width
                implicitHeight: root.popoutHeight - popout.headerHeight - popout.detailsHeight - Theme.spacingXL

                Column {
                    anchors.fill: parent
                    spacing: Theme.spacingM

                    // 监控卡片 (2x2)
                    Grid {
                        width: parent.width
                        columns: 2
                        spacing: Theme.spacingS

                        Repeater {
                            model: [
                                { icon: "mode_fan", label: "风扇 1", unit: "RPM", value: root.fan1 },
                                { icon: "mode_fan", label: "风扇 2", unit: "RPM", value: root.fan2 },
                                { icon: "device_thermostat", label: "CPU", unit: "°C", value: root.cpuTemp },
                                { icon: "device_thermostat", label: "GPU", unit: "°C", value: root.gpuTemp }
                            ]

                            StyledRect {
                                id: metricCard
                                required property var modelData
                                readonly property bool isTemp: modelData.unit === "°C"
                                width: (parent.width - Theme.spacingS) / 2
                                height: 76
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    DankIcon {
                                        name: metricCard.modelData.icon
                                        size: 20
                                        color: Theme.primary
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    StyledText {
                                        text: (root.available ? metricCard.modelData.value : "--") + " " + metricCard.modelData.unit
                                        font.pixelSize: Theme.fontSizeLarge
                                        font.weight: Font.Bold
                                        color: !metricCard.isTemp ? Theme.surfaceText
                                            : (metricCard.modelData.value >= 90 ? Theme.error
                                            : (metricCard.modelData.value >= 80 ? "#FF9800" : Theme.surfaceText))
                                    }
                                    StyledText {
                                        text: metricCard.modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }

                    // 分隔线
                    StyledRect {
                        width: parent.width
                        height: 1
                        color: Theme.outlineVariant
                    }

                    // 功耗卡片
                    Grid {
                        width: parent.width
                        columns: 3
                        spacing: Theme.spacingS

                        Repeater {
                            model: [
                                { icon: "bolt", label: "CPU", unit: " W", value: root.cpuPower.toFixed(1), sub: "" },
                                { icon: "memory", label: "独显", unit: " W",
                                  value: root.gstate ? root.gpuPower.toFixed(1) : "--",
                                  sub: root.gstate ? "" : "已屏蔽" },
                                { icon: "battery_charging_full", label: "电池", unit: " W",
                                  value: root.acOnline ? "--" : root.batPower.toFixed(1),
                                  sub: root.acOnline ? "适配器" : ("均" + root.batAvg.toFixed(0) + " 峰" + root.batPeak.toFixed(0)) }
                            ]

                            StyledRect {
                                id: powerCard
                                required property var modelData
                                width: (parent.width - 2 * Theme.spacingS) / 3
                                height: 66
                                radius: Theme.cornerRadius
                                color: Theme.surfaceContainerHigh

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 1

                                    DankIcon {
                                        name: powerCard.modelData.icon
                                        size: 18
                                        color: Theme.primary
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    StyledText {
                                        text: powerCard.modelData.value + powerCard.modelData.unit
                                        font.pixelSize: Theme.fontSizeMedium
                                        font.weight: Font.Bold
                                        color: Theme.surfaceText
                                    }
                                    StyledText {
                                        text: powerCard.modelData.label + (powerCard.modelData.sub !== "" ? " · " + powerCard.modelData.sub : "")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }

                    // 三联双态按钮: Logo灯 / Fn锁 / 触控板锁
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: [
                                { key: "logo", icon: "wb_incandescent", label: "Logo 灯", on: root.logoOn,
                                  cmdOn: ["logo", "on"], cmdOff: ["logo", "off"], toastOn: "Logo 灯已开", toastOff: "Logo 灯已关" },
                                { key: "fnlock", icon: "keyboard", label: "Fn 锁", on: root.fnlockOn,
                                  cmdOn: ["fnlock", "on"], cmdOff: ["fnlock", "off"], toastOn: "Fn 锁已开启", toastOff: "Fn 锁已关闭" },
                                { key: "tplock", icon: "touch_app", label: "触控板锁", on: root.tplockOn,
                                  cmdOn: ["tplock", "on"], cmdOff: ["tplock", "off"], toastOn: "触控板已锁定", toastOff: "触控板已解锁" },
                                { key: "gpu", icon: "memory", label: "独显", on: root.gstate,
                                  cmdOn: ["gpu", "on"], cmdOff: ["gpu", "off"], toastOn: "独显已开启", toastOff: "独显已关闭" }
                            ]

                            StyledRect {
                                id: triBtn
                                required property var modelData
                                width: (parent.width - 3 * Theme.spacingS) / 4
                                height: 52
                                radius: Theme.cornerRadius
                                color: modelData.on ? Qt.rgba(0, 0, 0, 0.10)
                                    : (triMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                border.width: modelData.on ? 2 : 0
                                border.color: Theme.primary

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    DankIcon {
                                        name: triBtn.modelData.icon
                                        size: 20
                                        color: triBtn.modelData.on ? Theme.primary : Theme.surfaceVariantText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    StyledText {
                                        text: triBtn.modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: triBtn.modelData.on ? Theme.primary : Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                MouseArea {
                                    id: triMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (triBtn.modelData.key === "gpu" && root.gstate && root.acOnline) {
                                            ToastService.showInfo("插电模式保持独显开启 · 拔电自动转 RTD3")
                                            return
                                        }
                                        root.runCmd(triBtn.modelData.on ? triBtn.modelData.cmdOff : triBtn.modelData.cmdOn,
                                                    triBtn.modelData.on ? triBtn.modelData.toastOff : triBtn.modelData.toastOn)
                                    }
                                }
                            }
                        }
                    }

                    // 显卡模式 (MUX, 重启生效)
                    StyledRect {
                        width: parent.width
                        height: 38
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "developer_board"
                                size: 18
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: "显卡模式（重启生效）"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            Repeater {
                                model: [{ label: "混合", v: 0 }, { label: "独显", v: 1 }]

                                StyledRect {
                                    required property var modelData
                                    width: 44
                                    height: 26
                                    radius: Theme.cornerRadius
                                    color: root.muxMode === modelData.v ? Qt.rgba(0, 0, 0, 0.10) : Theme.surfaceContainerHighest
                                    border.width: root.muxMode === modelData.v ? 2 : 0
                                    border.color: Theme.primary

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.muxMode === modelData.v ? Theme.primary : Theme.surfaceText
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.runCmd(["mux", modelData.v === 1 ? "discrete" : "hybrid"],
                                                               "显卡模式 → " + modelData.label + "，重启后生效")
                                    }
                                }
                            }
                        }
                    }

                    // 独显电源策略
                    StyledRect {
                        width: parent.width
                        height: 38
                        radius: Theme.cornerRadius
                        color: shieldMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "power_settings_new"
                                size: 18
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: "电池时屏蔽独显"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: "(插电开启 · 拔电转RTD3)"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceVariantText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledRect {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            width: 40
                            height: 20
                            radius: 10
                            color: root.batteryShield ? Theme.primary : Theme.surfaceContainerHighest

                            Rectangle {
                                width: 16
                                height: 16
                                radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.batteryShield ? parent.width - 18 : 2
                                color: Theme.onSurface
                            }
                        }

                        MouseArea {
                            id: shieldMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.batteryShield = !root.batteryShield
                                if (pluginService)
                                    pluginService.savePluginData(pluginId, "batteryShield", root.batteryShield)
                                ToastService.showInfo(root.batteryShield ? "电池时将屏蔽独显" : "电池时保持独显可用")
                            }
                        }
                    }

                    // 键盘灯 (档位 + 颜色)
                    StyledRect {
                        width: parent.width
                        height: 58
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.top: parent.top
                            anchors.topMargin: 9
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "light_mode"
                                size: 18
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: "键盘灯"
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.top: parent.top
                            anchors.topMargin: 9
                            text: "档位 " + (root.available ? root.light : "--") + " / 3"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.spacingM
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 8
                            spacing: 6

                            Repeater {
                                model: ["F44336", "FF9800", "FFEB3B", "4CAF50", "00BCD4", "2196F3", "9C27B0", "FFFFFF", "default"]

                                Rectangle {
                                    required property string modelData
                                    readonly property bool active: modelData === "default"
                                        ? root.kmode === 0
                                        : (root.kmode === 2 && root.kcolor === modelData)
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: modelData === "default" ? Theme.surfaceContainerHighest : "#" + modelData
                                    border.width: active ? 2 : 1
                                    border.color: active ? Theme.primary : Theme.outlineVariant

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.runCmd(["color", modelData],
                                                               modelData === "default" ? "键盘灯 → 默认红" : "键盘灯颜色已更新")
                                    }
                                }
                            }
                        }
                    }

                    // 模式切换按钮
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Repeater {
                            model: 3

                            StyledRect {
                                required property int index
                                width: (parent.width - 2 * Theme.spacingS) / 3
                                height: 52
                                radius: Theme.cornerRadius
                                color: root.mode === index ? Qt.rgba(0, 0, 0, 0.08) : (modeBtnMouse.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                                border.width: root.mode === index ? 2 : 0
                                border.color: root.modeColors[index]

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    DankIcon {
                                        name: root.modeIcons[index]
                                        size: 20
                                        color: root.modeColors[index]
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    StyledText {
                                        text: root.modeNames[index]
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: root.mode === index ? root.modeColors[index] : Theme.surfaceText
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                MouseArea {
                                    id: modeBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.setMode(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
