local EQUIPSLOTS = GLOBAL.EQUIPSLOTS

local OVERLOAD_WINDOW = GetModConfigData("overload_window") or 4
local OVERLOAD_THRESHOLD_PERCENT = GetModConfigData("overload_threshold_percent") or 0.06
local OVERLOAD_MIN_THRESHOLD = GetModConfigData("overload_min_threshold") or 500
local OVERLOAD_MAX_THRESHOLD = GetModConfigData("overload_max_threshold") or 1800
local ENRAGE_DURATION = GetModConfigData("enrage_duration") or 10
local CONTROL_IMMUNITY_DURATION = GetModConfigData("control_immunity_duration") or 3
local DAMAGE_TAKEN_MULT = GetModConfigData("damage_taken_mult") or 0.75
local CRIT_CHANCE = GetModConfigData("crit_chance") or 0.50
local TRUE_DAMAGE_PERCENT = GetModConfigData("true_damage_percent") or 0.15
local ARMOR_WEAR_PERCENT = GetModConfigData("armor_wear_percent") or 0.30

local CONTROL_CLEAR_INTERVAL = 0.1
local ENRAGED_TAG = "enragedcritical"
local MOD_RPC_NAMESPACE = "EnragedCriticals"
local ABSORB_SOURCE = "enragedcrit_absorb"
local MAX_ENRAGE_STACKS = 4
local DAMAGE_TAKEN_STACK_STEP = 0.10
local MIN_DAMAGE_TAKEN_MULT = 0.50
local TRUE_DAMAGE_STACK_STEP = 0.10
local MAX_TRUE_DAMAGE_PERCENT = 0.45
local ARMOR_WEAR_STACK_STEP = 0.15
local MAX_ARMOR_WEAR_PERCENT = 0.75

local function Now()
    return GLOBAL.GetTime()
end

local function IsPlayerSource(attacker)
    if attacker == nil then
        return false
    end

    if attacker:HasTag("player") then
        return true
    end

    local follower = attacker.components ~= nil and attacker.components.follower or nil
    local leader = follower ~= nil and follower:GetLeader() or nil
    return leader ~= nil and leader:HasTag("player")
end

local function IsSupportedBoss(inst)
    return inst ~= nil
        and inst:HasTag("epic")
        and inst.components ~= nil
        and inst.components.health ~= nil
        and inst.components.combat ~= nil
end

local function SafeSpawn(prefab)
    local ok, item = GLOBAL.pcall(GLOBAL.SpawnPrefab, prefab)
    return ok and item or nil
end

local function CallIfPresent(component, method_name, ...)
    if component ~= nil and component[method_name] ~= nil then
        GLOBAL.pcall(component[method_name], component, ...)
    end
end

local function ClearControlEffects(inst)
    if inst.components == nil then
        return
    end

    local sleeper = inst.components.sleeper
    if sleeper ~= nil then
        if sleeper.IsAsleep == nil or sleeper:IsAsleep() then
            CallIfPresent(sleeper, "WakeUp")
        end
    end

    local freezable = inst.components.freezable
    if freezable ~= nil then
        if freezable.IsFrozen == nil or freezable:IsFrozen() then
            CallIfPresent(freezable, "Unfreeze")
        end
        CallIfPresent(freezable, "Reset")
    end

    local grogginess = inst.components.grogginess
    if grogginess ~= nil then
        CallIfPresent(grogginess, "ComeTo")
        CallIfPresent(grogginess, "ResetGrogginess")
    end
end

local function StopTask(task)
    if task ~= nil then
        task:Cancel()
    end
end

local function GetEnrageStacks(inst)
    local data = inst._enragedcrit
    return data ~= nil and data.enrage_stacks or 0
end

local function GetDamageTakenMult(stacks)
    return math.max(MIN_DAMAGE_TAKEN_MULT, DAMAGE_TAKEN_MULT - math.max(0, stacks - 1) * DAMAGE_TAKEN_STACK_STEP)
end

local function GetTrueDamagePercent(stacks)
    return math.min(MAX_TRUE_DAMAGE_PERCENT, TRUE_DAMAGE_PERCENT + math.max(0, stacks - 1) * TRUE_DAMAGE_STACK_STEP)
end

local function GetArmorWearPercent(stacks)
    return math.min(MAX_ARMOR_WEAR_PERCENT, ARMOR_WEAR_PERCENT + math.max(0, stacks - 1) * ARMOR_WEAR_STACK_STEP)
end

local function SetEnrageVisuals(inst, enabled)
    if inst.AnimState ~= nil then
        if enabled then
            inst.AnimState:SetAddColour(math.min(0.65, 0.35 + GetEnrageStacks(inst) * 0.075), 0, 0, 0)
        else
            inst.AnimState:SetAddColour(0, 0, 0, 0)
        end
    end
end

local function SetEnrageAbsorb(inst, enabled)
    local health = inst.components ~= nil and inst.components.health or nil
    local modifiers = health ~= nil and health.externalabsorbmodifiers or nil
    if modifiers == nil then
        return
    end

    local damage_taken_mult = GetDamageTakenMult(GetEnrageStacks(inst))

    if enabled and damage_taken_mult < 1 then
        modifiers:SetModifier(inst, 1 - damage_taken_mult, ABSORB_SOURCE)
    else
        modifiers:RemoveModifier(inst, ABSORB_SOURCE)
    end
end

local function StopEnrage(inst)
    local data = inst._enragedcrit
    if data == nil then
        return
    end

    data.enraged = false
    data.enrage_stacks = 0
    data.enrage_ends_at = 0
    data.control_immune_until = 0
    inst:RemoveTag(ENRAGED_TAG)
    SetEnrageVisuals(inst, false)
    SetEnrageAbsorb(inst, false)

    StopTask(data.enrage_task)
    StopTask(data.control_task)
    data.enrage_task = nil
    data.control_task = nil
end

local function StartControlImmunity(inst)
    local data = inst._enragedcrit
    if data == nil then
        return
    end

    data.control_immune_until = Now() + CONTROL_IMMUNITY_DURATION
    ClearControlEffects(inst)

    StopTask(data.control_task)
    data.control_task = inst:DoPeriodicTask(CONTROL_CLEAR_INTERVAL, function()
        if inst._enragedcrit == nil or Now() >= inst._enragedcrit.control_immune_until then
            StopTask(inst._enragedcrit ~= nil and inst._enragedcrit.control_task or nil)
            if inst._enragedcrit ~= nil then
                inst._enragedcrit.control_task = nil
            end
            return
        end

        ClearControlEffects(inst)
    end)
end

local function StartEnrage(inst, is_refresh)
    local data = inst._enragedcrit
    if data == nil then
        return
    end

    data.enraged = true
    data.enrage_stacks = is_refresh and math.min(MAX_ENRAGE_STACKS, data.enrage_stacks + 1) or 1
    data.damage_log = {}
    data.enrage_ends_at = Now() + ENRAGE_DURATION
    inst:AddTag(ENRAGED_TAG)
    SetEnrageVisuals(inst, true)
    SetEnrageAbsorb(inst, true)

    StartControlImmunity(inst)

    StopTask(data.enrage_task)
    data.enrage_task = inst:DoTaskInTime(ENRAGE_DURATION, function()
        StopEnrage(inst)
    end)

    inst:PushEvent(is_refresh and "enragedcritical_refresh" or "enragedcritical_start", {
        duration = ENRAGE_DURATION,
        stacks = data.enrage_stacks,
        crit_chance = CRIT_CHANCE,
        true_damage_percent = GetTrueDamagePercent(data.enrage_stacks),
        armor_wear_percent = GetArmorWearPercent(data.enrage_stacks),
        damage_taken_mult = GetDamageTakenMult(data.enrage_stacks),
    })
end

local function PruneDamageLog(data, now)
    local cutoff = now - OVERLOAD_WINDOW
    local first_kept = 1

    while data.damage_log[first_kept] ~= nil and data.damage_log[first_kept].time < cutoff do
        first_kept = first_kept + 1
    end

    if first_kept > 1 then
        local new_log = {}
        for i = first_kept, #data.damage_log do
            new_log[#new_log + 1] = data.damage_log[i]
        end
        data.damage_log = new_log
    end
end

local function GetOverloadThreshold(inst)
    local health = inst.components ~= nil and inst.components.health or nil
    local max_health = health ~= nil and health.maxhealth or 0
    local threshold = max_health * OVERLOAD_THRESHOLD_PERCENT

    if OVERLOAD_MIN_THRESHOLD > 0 then
        threshold = math.max(threshold, OVERLOAD_MIN_THRESHOLD)
    end

    if OVERLOAD_MAX_THRESHOLD > 0 then
        threshold = math.min(threshold, OVERLOAD_MAX_THRESHOLD)
    end

    return threshold
end

local function GetRecentDamage(data)
    local total = 0
    for _, entry in ipairs(data.damage_log) do
        total = total + entry.damage
    end
    return total
end

local function OnBossAttacked(inst, event_data)
    if event_data == nil or event_data.damage == nil or event_data.damage <= 0 then
        return
    end

    if not IsPlayerSource(event_data.attacker) then
        return
    end

    local data = inst._enragedcrit
    if data == nil then
        return
    end

    local now = Now()
    data.damage_log[#data.damage_log + 1] = {
        time = now,
        damage = event_data.damage,
    }
    PruneDamageLog(data, now)

    if GetRecentDamage(data) >= GetOverloadThreshold(inst) then
        StartEnrage(inst, data.enraged)
    end
end

local function GetReportedHitDamage(inst, event_data)
    local combat = inst.components ~= nil and inst.components.combat or nil
    local hit_damage = combat ~= nil and combat.defaultdamage or 0

    if event_data ~= nil and event_data.original_damage ~= nil and event_data.original_damage > 0 then
        hit_damage = math.max(hit_damage, event_data.original_damage)
    end

    if event_data ~= nil and event_data.damage ~= nil and event_data.damage > 0 then
        hit_damage = math.max(hit_damage, event_data.damage)
    end

    return hit_damage
end

local function FindBestArmor(target)
    local inventory = target.components ~= nil and target.components.inventory or nil
    if inventory == nil then
        return nil
    end

    local best_item = nil
    local best_absorb = -1
    local slots = { EQUIPSLOTS.BODY, EQUIPSLOTS.HEAD }

    for _, slot in ipairs(slots) do
        local item = inventory:GetEquippedItem(slot)
        local armor = item ~= nil and item.components ~= nil and item.components.armor or nil
        if armor ~= nil then
            local absorb = armor.absorb_percent or 0
            if absorb > best_absorb then
                best_item = item
                best_absorb = absorb
            end
        end
    end

    return best_item
end

local function ApplyExtraArmorWear(target, amount)
    if amount <= 0 then
        return
    end

    local armor_item = FindBestArmor(target)
    local armor = armor_item ~= nil and armor_item.components ~= nil and armor_item.components.armor or nil
    if armor == nil then
        return
    end

    if armor.TakeDamage ~= nil then
        armor:TakeDamage(amount)
    elseif armor.SetCondition ~= nil and armor.condition ~= nil then
        armor:SetCondition(math.max(0, armor.condition - amount))
    end
end

local function ApplyTrueDamage(inst, target, amount)
    local health = target.components ~= nil and target.components.health or nil
    if health == nil or health:IsDead() or amount <= 0 then
        return
    end

    health:DoDelta(-amount, nil, "enraged_critical", true, inst, true)
end

local function OnBossHitOther(inst, event_data)
    local data = inst._enragedcrit
    local target = event_data ~= nil and event_data.target or nil

    if data == nil or target == nil or not target:HasTag("player") then
        return
    end

    local hit_damage = GetReportedHitDamage(inst, event_data)
    if hit_damage <= 0 then
        return
    end

    if not data.enraged or math.random() >= CRIT_CHANCE then
        return
    end

    local stacks = GetEnrageStacks(inst)
    local true_damage = hit_damage * GetTrueDamagePercent(stacks)
    local armor_wear = hit_damage * GetArmorWearPercent(stacks)

    ApplyTrueDamage(inst, target, true_damage)
    ApplyExtraArmorWear(target, armor_wear)

    inst:PushEvent("enragedcritical_crit", {
        target = target,
        stacks = stacks,
        true_damage = true_damage,
        armor_wear = armor_wear,
    })
    target:PushEvent("enragedcritical_hit", {
        attacker = inst,
        stacks = stacks,
        true_damage = true_damage,
        armor_wear = armor_wear,
    })
end

local function AttachEnragedCriticals(inst)
    if GLOBAL.TheWorld == nil or not GLOBAL.TheWorld.ismastersim or not IsSupportedBoss(inst) then
        return
    end

    if inst._enragedcrit ~= nil then
        return
    end

    inst._enragedcrit = {
        damage_log = {},
        enraged = false,
        enrage_stacks = 0,
        enrage_ends_at = 0,
        control_immune_until = 0,
        enrage_task = nil,
        control_task = nil,
    }

    inst:ListenForEvent("attacked", OnBossAttacked)
    inst:ListenForEvent("onhitother", OnBossHitOther)
    inst:ListenForEvent("death", StopEnrage)
    inst:ListenForEvent("onremove", StopEnrage)
end

AddPrefabPostInitAny(AttachEnragedCriticals)

local function GiveAndEquip(player, prefab)
    local inventory = player.components ~= nil and player.components.inventory or nil
    if inventory == nil then
        return nil
    end

    local item = SafeSpawn(prefab)
    if item ~= nil then
        inventory:GiveItem(item)
        inventory:Equip(item)
    end
    return item
end

local function TryEat(player, prefabs)
    local eater = player.components ~= nil and player.components.eater or nil
    if eater == nil then
        return nil
    end

    for _, prefab in ipairs(prefabs) do
        local food = SafeSpawn(prefab)
        if food ~= nil then
            local ok = GLOBAL.pcall(eater.Eat, eater, food)
            if ok then
                return prefab
            end
            food:Remove()
        end
    end

    return nil
end

local function PrepareWolfgangTest(player)
    if player == nil or player.components == nil then
        return
    end

    if player.components.mightiness ~= nil then
        player.components.mightiness:SetPercent(1, true, true)
    end

    if player.components.hunger ~= nil then
        player.components.hunger:SetPercent(1)
    end

    if player.components.health ~= nil then
        player.components.health:SetPercent(1)
    end

    if player.components.sanity ~= nil then
        player.components.sanity:SetPercent(1)
    end

    TryEat(player, {
        "voltgoatjelly_spice_chili",
        "voltgoatjelly",
        "dragonchilisalad",
        "pepperpopper",
    })

    GiveAndEquip(player, "glasscutter")
    GiveAndEquip(player, "armorruins")
    GiveAndEquip(player, "ruinshat")
end

local function SpawnTestBoss(player)
    if player == nil then
        return
    end

    local x, y, z = player.Transform:GetWorldPosition()
    local boss = SafeSpawn("deerclops")
    if boss ~= nil then
        boss.Transform:SetPosition(x + 4, y, z)
        AttachEnragedCriticals(boss)
    end
end

local function FindNearbyBoss(player)
    if player == nil then
        return nil
    end

    local target = player.components ~= nil and player.components.combat ~= nil and player.components.combat.target or nil
    if not IsSupportedBoss(target) then
        local x, y, z = player.Transform:GetWorldPosition()
        local ents = GLOBAL.TheSim:FindEntities(x, y, z, 30, { "epic" })
        target = ents ~= nil and ents[1] or nil
    end

    return IsSupportedBoss(target) and target or nil
end

local function TriggerSelectedBoss(player)
    local target = FindNearbyBoss(player)
    if IsSupportedBoss(target) then
        AttachEnragedCriticals(target)
        target:PushEvent("attacked", {
            attacker = player,
            damage = GetOverloadThreshold(target),
        })
    end
end

local function ForceEnrageSelectedBoss(player)
    local target = FindNearbyBoss(player)
    if IsSupportedBoss(target) then
        AttachEnragedCriticals(target)
        StartEnrage(target, target._enragedcrit ~= nil and target._enragedcrit.enraged or false)
    end
end

AddModRPCHandler(MOD_RPC_NAMESPACE, "PrepareWolfgangTest", PrepareWolfgangTest)
AddModRPCHandler(MOD_RPC_NAMESPACE, "SpawnTestBoss", SpawnTestBoss)
AddModRPCHandler(MOD_RPC_NAMESPACE, "TriggerSelectedBoss", TriggerSelectedBoss)
AddModRPCHandler(MOD_RPC_NAMESPACE, "ForceEnrageSelectedBoss", ForceEnrageSelectedBoss)

local function GetConsolePlayer()
    if GLOBAL.ConsoleCommandPlayer ~= nil then
        local ok, player = GLOBAL.pcall(GLOBAL.ConsoleCommandPlayer)
        if ok and player ~= nil then
            return player
        end
    end

    return GLOBAL.ThePlayer
end

local function RunTestCommand(rpc_name, server_fn)
    if GLOBAL.TheWorld ~= nil and GLOBAL.TheWorld.ismastersim then
        server_fn(GetConsolePlayer())
    else
        GLOBAL.SendModRPCToServer(GLOBAL.GetModRPC(MOD_RPC_NAMESPACE, rpc_name))
    end
end

GLOBAL.EnragedCriticalsPrepare = function()
    RunTestCommand("PrepareWolfgangTest", PrepareWolfgangTest)
end

GLOBAL.EnragedCriticalsSpawnBoss = function()
    RunTestCommand("SpawnTestBoss", SpawnTestBoss)
end

GLOBAL.EnragedCriticalsTrigger = function()
    RunTestCommand("TriggerSelectedBoss", TriggerSelectedBoss)
end

GLOBAL.EnragedCriticalsForce = function()
    RunTestCommand("ForceEnrageSelectedBoss", ForceEnrageSelectedBoss)
end
