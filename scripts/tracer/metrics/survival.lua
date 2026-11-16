-- scripts/tracer/metrics/survival.lua
-- Player survival metrics: damage taken and deaths during active Boss sessions.

local Attribution = require("tracer/metrics/attribution")

local SurvivalCollector = {}

--- Pick the most relevant active Boss session for a player event.
local function find_relevant_boss_id(collector, attacker)
    local active = collector:GetActiveSessions()
    if attacker and attacker.GUID and active[attacker.GUID] then
        return attacker.GUID
    end
    -- Fallback to the most recently active session
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

function SurvivalCollector.AttachPlayer(player, collector)
    player:ListenForEvent("attacked", function(inst, data)
        if not data or not data.damage or data.damage <= 0 then
            return
        end
        local boss_id = find_relevant_boss_id(collector, data.attacker)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data.attacker, "Boss攻击")
        collector:Record("damage_taken", boss_id, pid, pname, data.damage, src, GetTime(), pprefab)
    end)

    player:ListenForEvent("death", function(inst, data)
        local boss_id = find_relevant_boss_id(collector, data and data.afflicter)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data and data.cause, "阵亡")
        collector:Record("deaths", boss_id, pid, pname, 1, src, GetTime(), pprefab)
    end)
end

return SurvivalCollector
