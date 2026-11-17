-- scripts/bossmeter/metrics/survival.lua
-- Player survival metrics: damage taken and deaths during active Boss sessions.

local Attribution = require("bossmeter/metrics/attribution")

local SurvivalCollector = {}

function SurvivalCollector.AttachPlayer(player, collector)
    player:ListenForEvent("attacked", function(inst, data)
        if not data or not data.damage or data.damage <= 0 then
            return
        end
        local attacker_id = data.attacker and data.attacker.GUID
        local boss_id = Attribution.ResolveRelevantBoss(inst, collector, attacker_id)
        if not boss_id then
            return
        end
        local is_direct_boss = (attacker_id ~= nil and attacker_id == boss_id)
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data.attacker, "Boss攻击")
        collector:Record("damage_taken", boss_id, pid, pname, data.damage, src, GetTime(), pprefab, {
            touch_activity = is_direct_boss,
            combat_interaction = is_direct_boss,
        })
    end)

    player:ListenForEvent("death", function(inst, data)
        local afflicter_id = data and data.afflicter and data.afflicter.GUID
        local boss_id = Attribution.ResolveRelevantBoss(inst, collector, afflicter_id)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data and data.cause, "阵亡")
        collector:Record("deaths", boss_id, pid, pname, 1, src, GetTime(), pprefab, {
            touch_activity = false,
        })
    end)
end

return SurvivalCollector
