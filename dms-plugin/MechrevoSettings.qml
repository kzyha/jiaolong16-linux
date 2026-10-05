import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    pluginId: "mechrevo-ec"

    StyledText {
        width: parent.width
        text: "MECHREVO EC 控制"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "性能模式切换（性能/游戏/办公）与双风扇转速、CPU/GPU 温度监控。数据来自 EC（AEC616864 固件实测寄存器）。"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StringSetting {
        settingKey: "refreshInterval"
        label: "轮询间隔（毫秒）"
        description: "EC 状态刷新间隔，范围 1000-10000，默认 2000"
        placeholder: "2000"
        defaultValue: "2000"
    }
}
