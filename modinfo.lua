name = "Enraged Criticals"
description = "Bosses become enraged after taking too much damage in a short time. Enraged bosses break control effects and can critically hit players."
author = "gongqq"
version = "1.0.0"

forumthread = ""
api_version = 10

dst_compatible = true
dont_starve_compatible = false
reign_of_giants_compatible = false
shipwrecked_compatible = false

all_clients_require_mod = true
client_only_mod = false
server_filter_tags = { "boss", "combat", "enrage", "critical" }

configuration_options =
{
    {
        name = "overload_window",
        label = "Overload Window",
        hover = "Seconds of recent player damage counted toward boss overload.",
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
        label = "Overload Threshold",
        hover = "Recent player damage needed to enrage a boss, as a percent of its max health.",
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
        label = "Minimum Threshold",
        hover = "Minimum recent damage required to trigger overload, even for low-health bosses.",
        options =
        {
            { description = "None", data = 0 },
            { description = "300", data = 300 },
            { description = "400", data = 400 },
            { description = "500", data = 500 },
            { description = "600", data = 600 },
        },
        default = 500,
    },
    {
        name = "overload_max_threshold",
        label = "Maximum Threshold",
        hover = "Maximum recent damage required to trigger overload, even for very high-health bosses.",
        options =
        {
            { description = "1200", data = 1200 },
            { description = "1500", data = 1500 },
            { description = "1800", data = 1800 },
            { description = "2200", data = 2200 },
            { description = "No Limit", data = 0 },
        },
        default = 1800,
    },
    {
        name = "enrage_duration",
        label = "Enrage Duration",
        hover = "How long a boss stays enraged.",
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
        label = "Control Immunity",
        hover = "Seconds of control immunity after a boss becomes enraged.",
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
        label = "Damage Taken",
        hover = "Damage bosses take at enrage stack 1. Repeated overloads reduce this further.",
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
        label = "Critical Chance",
        hover = "Chance for an enraged boss hit to become a critical hit.",
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
        label = "True Damage",
        hover = "Extra armor-ignoring damage at enrage stack 1. Repeated overloads increase this.",
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
        label = "Armor Wear",
        hover = "Extra armor durability loss at enrage stack 1. Repeated overloads increase this.",
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
