name = "BossMeter"
description = "Boss战数据统计与可视化回顾面板：支持伤害输出、生存承伤、辅助治疗、资源消耗四大维度及外部模组自定义指标扩展。"
author = "BossMeter Team"
version = "0.1.0"

forumthread = ""

api_version = 10
dst_compatible = true

all_clients_require_mod = true
client_only_mod = false

-- icon_atlas = "modicon.xml"
-- icon = "modicon.tex"

server_filter_tags = { "bossmeter", "boss", "dps", "stats" }

configuration_options = {
    {
        name = "hud_indicator",
        label = "战斗中极简提示",
        hover = "是否在 Boss 战期间在屏幕角落显示极简的记录中提示",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "auto_open_review",
        label = "战后自动弹出面板",
        hover = "Boss 被击杀后是否自动弹出数据回顾面板",
        options = {
            { description = "开启", data = true },
            { description = "关闭", data = false },
        },
        default = true,
    },
    {
        name = "toggle_key",
        label = "面板快捷键",
        hover = "用于手动打开或关闭战后数据回顾面板的快捷键",
        options = {
            { description = "F8", data = "KEY_F8" },
            { description = "F9", data = "KEY_F9" },
            { description = "F10", data = "KEY_F10" },
            { description = "K", data = "KEY_K" },
            { description = "B", data = "KEY_B" },
        },
        default = "KEY_F8",
    },
    {
        name = "history_limit",
        label = "历史战报缓存上限",
        hover = "客户端最多保留最近多少场 Boss 战的战报记录",
        options = {
            { description = "5 场", data = 5 },
            { description = "10 场", data = 10 },
            { description = "20 场", data = 20 },
        },
        default = 10,
    },
    {
        name = "combat_timeout",
        label = "脱战超时重置 (秒)",
        hover = "Boss 战无任何有效战斗事件超过该秒数后视为脱战结束",
        options = {
            { description = "15 秒", data = 15 },
            { description = "30 秒", data = 30 },
            { description = "60 秒", data = 60 },
        },
        default = 30,
    },
}
