-- scripts/tracer/metrics/damage.lua
-- Boss damage output and source attribution collector.

local Attribution = require("tracer/metrics/attribution")

local DamageCollector = {}

local function ensure_boss_session(boss, collector, now)
    local max_hp = (boss.components.health and boss.components.health.maxhealth) or 0
    local name = (boss.GetDisplayName and boss:GetDisplayName()) or boss.prefab or "Boss"
    collector:StartBossSession(boss.GUID, boss.prefab, name, now, max_hp)
end

function DamageCollector.AttachBoss(boss, collector)
    boss._tracer_last_weapon = {}

    -- Track weapon used in the most recent attack event per attacker
    boss:ListenForEvent("attacked", function(inst, data)
        if not data or not data.attacker then
            return
        end
        boss._tracer_last_weapon[data.attacker] = data.weapon

        local player = Attribution.ResolvePlayer(data.attacker)
        if player then
            ensure_boss_session(inst, collector, GetTime())
        end
    end)

    -- Start session if the Boss hits a player first
    boss:ListenForEvent("onhitother", function(inst, data)
        if data and data.target and data.target:HasTag("player") then
            ensure_boss_session(inst, collector, GetTime())
        end
    end)

    -- Record actual HP lost by the Boss
    boss:ListenForEvent("healthdelta", function(inst, data)
        if not data or not data.amount or data.amount >= 0 then
            return
        end
        local dmg = -data.amount
        if dmg <= 0 then
            return
        end

        local afflicter = data.afflicter
        local player = Attribution.ResolvePlayer(afflicter)
        if not player then
            return
        end

        local now = GetTime()
        ensure_boss_session(inst, collector, now)

        local pid, pname, pprefab = Attribution.GetPlayerInfo(player)
        local weapon = afflicter and boss._tracer_last_weapon[afflicter]
        local source_name
        if weapon then
            source_name = Attribution.GetSourceName(weapon, "武器")
        elseif afflicter and afflicter ~= player then
            source_name = Attribution.GetSourceName(afflicter, "随从/召唤物")
        else
            source_name = Attribution.GetSourceName(data.cause, "徒手/技能")
        end

        collector:Record("damage_total", inst.GUID, pid, pname, dmg, source_name, now, pprefab)
    end)
end

return DamageCollector
