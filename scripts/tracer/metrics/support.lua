-- scripts/tracer/metrics/support.lua
-- Player support metrics: healing done and damage mitigation during active Boss sessions.

local Attribution = require("tracer/metrics/attribution")

local SupportCollector = {}

local function get_active_boss_id(collector)
    local active = collector:GetActiveSessions()
    local best_id = nil
    local best_time = -1
    for boss_id, session in pairs(active) do
        if session.last_activity_time > best_time then
            best_time = session.last_activity_time
            best_id = boss_id
        end
    end
    return best_id
end

function SupportCollector.AttachPlayer(player, collector)
    -- Healing received / applied
    player:ListenForEvent("healthdelta", function(inst, data)
        if not data or not data.amount or data.amount <= 0 then
            return
        end
        local boss_id = get_active_boss_id(collector)
        if not boss_id then
            return
        end
        -- Ignore tiny passive regen ticks (< 1 HP) unless desired
        if data.amount < 1 then
            return
        end
        local healer = Attribution.ResolvePlayer(data.afflicter) or inst
        local pid, pname, pprefab = Attribution.GetPlayerInfo(healer)
        local src = Attribution.GetSourceName(data.cause, "治疗恢复")
        collector:Record("healing_done", boss_id, pid, pname, data.amount, src, GLOBAL.GetTime(), pprefab)
    end)

    -- Damage absorbed by armor
    player:ListenForEvent("armordamage", function(inst, data)
        if not data or not data.absorbed or data.absorbed <= 0 then
            return
        end
        local boss_id = get_active_boss_id(collector)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data.armor, "护甲")
        collector:Record("mitigation", boss_id, pid, pname, data.absorbed, src, GLOBAL.GetTime(), pprefab)
    end)
end

return SupportCollector
