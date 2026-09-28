local current_locale = (locale or ""):lower()
local is_chinese = current_locale == "zh"
    or current_locale == "zhr"
    or current_locale == "zht"
    or current_locale == "chs"
    or current_locale == "cht"
    or current_locale:find("^zh") ~= nil

local function T(en, zh)
    return is_chinese and zh or en
end

name = T("Enraged Criticals", "暴怒暴击")
description = T(
    "Server-side boss enrage and critical hit mechanics.",
    "服务端 Boss 伤害过载、暴怒叠层与暴击机制。"
)
author = "Codex"
version = "1.0.5"

forumthread = "https://steamcommunity.com/sharedfiles/filedetails/?id=3765798673"
api_version = 10
api_version_dst = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = false
client_only_mod = false
server_filter_tags = { "server_only_mod", "environment", "boss", "combat", "enrage", "critical" }
priority = 0
icon_atlas = "modicon.xml"
icon = "modicon.tex"

configuration_options =
{
    {
        name = "overload_window",
        label = T("Overload Window", "过载窗口"),
        hover = T(
            "Recent player damage is counted within this time window to trigger Enrage.",
            "Boss 受到的玩家近期伤害会在这段时间内累计，用于触发暴怒。"
        ),
        options =
        {
            { description = "3s", data = 3 },
            { description = "4s", data = 4 },
            { description = "5s", data = 5 },
            { description = "6s", data = 6 },
        },
        default = 4,
    },
    {
        name = "overload_threshold_percent",
        label = T("Overload Threshold", "过载阈值"),
        hover = T(
            "Recent player damage required to enrage a boss, as a percent of max health.",
            "触发 Boss 暴怒所需的近期玩家伤害，按 Boss 最大生命值百分比计算。"
        ),
        options =
        {
            { description = "4%", data = 0.04 },
            { description = "5%", data = 0.05 },
            { description = "6%", data = 0.06 },
            { description = "8%", data = 0.08 },
            { description = "10%", data = 0.10 },
        },
        default = 0.06,
    },
    {
        name = "overload_min_threshold",
        label = T("Minimum Threshold", "最低阈值"),
        hover = T(
            "Minimum recent damage required to trigger overload, even for low-health bosses.",
            "触发过载所需的最低近期伤害。低血量 Boss 也至少需要达到这个数值。"
        ),
        options =
        {
            { description = T("None", "无"), data = 0 },
            { description = "300", data = 300 },
            { description = "400", data = 400 },
            { description = "500", data = 500 },
            { description = "600", data = 600 },
        },
        default = 500,
    },
    {
        name = "overload_max_threshold",
        label = T("Maximum Threshold", "最高阈值"),
        hover = T(
            "Maximum recent damage required to trigger overload, even for very high-health bosses.",
            "触发过载所需的最高近期伤害。高血量 Boss 的阈值不会超过这个数值。"
        ),
        options =
        {
            { description = "1200", data = 1200 },
            { description = "1500", data = 1500 },
            { description = "1800", data = 1800 },
            { description = "2200", data = 2200 },
            { description = T("No Limit", "无限制"), data = 0 },
        },
        default = 1800,
    },
    {
        name = "enrage_duration",
        label = T("Enrage Duration", "暴怒持续时间"),
        hover = T(
            "How long a boss stays enraged. Triggering Enrage again refreshes the duration.",
            "Boss 进入暴怒后持续的时间。再次触发暴怒会刷新持续时间。"
        ),
        options =
        {
            { description = "8s", data = 8 },
            { description = "10s", data = 10 },
            { description = "12s", data = 12 },
            { description = "15s", data = 15 },
        },
        default = 10,
    },
    {
        name = "control_immunity_duration",
        label = T("Control Immunity", "免控时间"),
        hover = T(
            "Seconds of control immunity after a boss becomes enraged or refreshes Enrage.",
            "Boss 触发或刷新暴怒后，持续清除睡眠、冰冻、困倦等控制效果的时间。"
        ),
        options =
        {
            { description = "2s", data = 2 },
            { description = "3s", data = 3 },
            { description = "4s", data = 4 },
            { description = "5s", data = 5 },
        },
        default = 3,
    },
    {
        name = "damage_taken_mult",
        label = T("Damage Taken", "受到伤害"),
        hover = T(
            "Damage bosses take at Enrage Stack 1. Repeated overloads reduce this further.",
            "Boss 在 1 层暴怒时受到的伤害比例。连续过载会进一步降低受到的伤害。"
        ),
        options =
        {
            { description = "100%", data = 1.00 },
            { description = "85%", data = 0.85 },
            { description = "75%", data = 0.75 },
            { description = "65%", data = 0.65 },
            { description = "50%", data = 0.50 },
        },
        default = 0.75,
    },
    {
        name = "crit_chance",
        label = T("Critical Chance", "暴击概率"),
        hover = T(
            "Chance for an enraged boss hit to become a critical hit.",
            "暴怒 Boss 命中玩家时触发暴击的概率。"
        ),
        options =
        {
            { description = "25%", data = 0.25 },
            { description = "35%", data = 0.35 },
            { description = "50%", data = 0.50 },
            { description = "65%", data = 0.65 },
        },
        default = 0.50,
    },
    {
        name = "true_damage_percent",
        label = T("True Damage", "真伤比例"),
        hover = T(
            "Extra armor-ignoring damage at Enrage Stack 1. Repeated overloads increase this.",
            "1 层暴怒暴击时追加的无视护甲伤害比例。连续过载会提高这个比例。"
        ),
        options =
        {
            { description = "10%", data = 0.10 },
            { description = "15%", data = 0.15 },
            { description = "20%", data = 0.20 },
            { description = "25%", data = 0.25 },
        },
        default = 0.15,
    },
    {
        name = "armor_wear_percent",
        label = T("Armor Wear", "护甲损耗"),
        hover = T(
            "Extra armor durability loss at Enrage Stack 1. Repeated overloads increase this.",
            "1 层暴怒暴击时追加的护甲耐久损耗比例。连续过载会提高这个比例。"
        ),
        options =
        {
            { description = "25%", data = 0.25 },
            { description = "30%", data = 0.30 },
            { description = "40%", data = 0.40 },
            { description = "50%", data = 0.50 },
        },
        default = 0.30,
    },
}
