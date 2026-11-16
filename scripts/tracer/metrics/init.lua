-- scripts/tracer/metrics/init.lua
-- Registers all 4 built-in metric categories and wires DST server event hooks.

local DamageCollector = require("tracer/metrics/damage")
local SurvivalCollector = require("tracer/metrics/survival")
local SupportCollector = require("tracer/metrics/support")
local ResourceCollector = require("tracer/metrics/resource")

local MetricsInit = {}

--- Register built-in metrics in the Collector registry.
function MetricsInit.RegisterBuiltins(collector)
    -- 1. Damage Output
    collector:RegisterMetric("damage_total", {
        name = "总伤害",
        category = "damage",
        unit = "HP",
        aggregation = "sum",
        chart_type = "bar",
        track_timeseries = true,
        order = 10,
        description = "对 Boss 造成的总伤害量及每秒 DPS 趋势",
    })

    -- 2. Survival / Damage Taken
    collector:RegisterMetric("damage_taken", {
        name = "承受伤害",
        category = "survival",
        unit = "HP",
        aggregation = "sum",
        chart_type = "bar",
        track_timeseries = true,
        order = 10,
        description = "在 Boss 战期间受到的伤害总量",
    })
    collector:RegisterMetric("deaths", {
        name = "死亡/濒死",
        category = "survival",
        unit = "次",
        aggregation = "sum",
        chart_type = "bar",
        order = 20,
        description = "Boss 战期间的死亡次数",
    })

    -- 3. Support / Healing
    collector:RegisterMetric("healing_done", {
        name = "治疗/回血",
        category = "support",
        unit = "HP",
        aggregation = "sum",
        chart_type = "bar",
        track_timeseries = true,
        order = 10,
        description = "Boss 战期间通过药品、食物或技能恢复的生命值",
    })
    collector:RegisterMetric("mitigation", {
        name = "护甲减伤",
        category = "support",
        unit = "HP",
        aggregation = "sum",
        chart_type = "bar",
        order = 20,
        description = "Boss 战期间通过护甲吸收/抵消的伤害量",
    })

    -- 4. Resource Consumption
    collector:RegisterMetric("armor_loss", {
        name = "护甲耐久损耗",
        category = "resource",
        unit = "耐久",
        aggregation = "sum",
        chart_type = "bar",
        order = 10,
        description = "Boss 战期间护甲消耗的耐久度",
    })
    collector:RegisterMetric("consumables_used", {
        name = "食物/药品消耗",
        category = "resource",
        unit = "次",
        aggregation = "sum",
        chart_type = "bar",
        order = 20,
        description = "Boss 战期间消耗的食物与治疗道具次数",
    })
end

--- Attach DST server-side hooks for Boss entities and Players.
function MetricsInit.AttachServerHooks(env, collector, config)
    local timeout = (config and config.combat_timeout) or 30

    -- Attach Boss lifecycle & damage collector to epic entities
    env.AddPrefabPostInitAny(function(inst)
        if not inst or not inst.HasTag then
            return
        end
        if inst:HasTag("epic") and inst.components and inst.components.health and inst.components.combat then
            DamageCollector.AttachBoss(inst, collector)

            inst:ListenForEvent("death", function()
                if collector:GetSession(inst.GUID) then
                    collector:EndBossSession(inst.GUID, GLOBAL.GetTime(), "victory")
                end
            end)

            inst:ListenForEvent("onremove", function()
                if collector:GetSession(inst.GUID) then
                    collector:EndBossSession(inst.GUID, GLOBAL.GetTime(), "despawn")
                end
            end)
        end
    end)

    -- Attach player survival, support, and resource collectors
    env.AddPlayerPostInit(function(player)
        if not player then
            return
        end
        SurvivalCollector.AttachPlayer(player, collector)
        SupportCollector.AttachPlayer(player, collector)
        ResourceCollector.AttachPlayer(player, collector)
    end)

    -- Periodic timeout pruning on server world
    env.AddSimPostInit(function()
        if GLOBAL.TheWorld then
            GLOBAL.TheWorld:DoPeriodicTask(5, function()
                collector:PruneTimeouts(GLOBAL.GetTime(), timeout)
            end)
        end
    end)
end

return MetricsInit
