-- scripts/bossmeter/metrics/support.lua
-- Player support metrics: healing done and damage mitigation during active Boss sessions.

local Attribution = require("bossmeter/metrics/attribution")

local SupportCollector = {}

local NON_RENEWING_OPTS = { touch_activity = false }

function SupportCollector.AttachPlayer(player, collector)
    -- Healing received / applied
    player:ListenForEvent("healthdelta", function(inst, data)
        if not data or not data.amount or data.amount <= 0 then
            return
        end
        -- Ignore tiny passive regen ticks (< 1 HP) unless desired
        if data.amount < 1 then
            return
        end
        local boss_id = Attribution.ResolveRelevantBoss(inst, collector)
        if not boss_id then
            return
        end
        local healer = Attribution.ResolvePlayer(data.afflicter) or inst
        local pid, pname, pprefab = Attribution.GetPlayerInfo(healer)
        local src = Attribution.GetSourceName(data.cause, "治疗恢复")
        collector:Record("healing_done", boss_id, pid, pname, data.amount, src, GetTime(), pprefab, NON_RENEWING_OPTS)
    end)

    -- Damage absorbed by armor
    player:ListenForEvent("armordamage", function(inst, data)
        if not data or not data.absorbed or data.absorbed <= 0 then
            return
        end
        local boss_id = Attribution.ResolveRelevantBoss(inst, collector)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data.armor, "护甲")
        collector:Record("mitigation", boss_id, pid, pname, data.absorbed, src, GetTime(), pprefab, NON_RENEWING_OPTS)
    end)
end

return SupportCollector
