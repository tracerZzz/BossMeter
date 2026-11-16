-- scripts/tracer/metrics/resource.lua
-- Player resource consumption metrics: armor durability loss & consumables used.

local Attribution = require("tracer/metrics/attribution")

local ResourceCollector = {}

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

function ResourceCollector.AttachPlayer(player, collector)
    -- Armor durability loss
    player:ListenForEvent("armordamage", function(inst, data)
        if not data or not data.damage or data.damage <= 0 then
            return
        end
        local boss_id = get_active_boss_id(collector)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data.armor, "护甲耐久")
        collector:Record("armor_loss", boss_id, pid, pname, data.damage, src, GLOBAL.GetTime(), pprefab)
    end)

    -- Food / edible consumption
    player:ListenForEvent("oneat", function(inst, data)
        local boss_id = get_active_boss_id(collector)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data and data.food, "食物")
        collector:Record("consumables_used", boss_id, pid, pname, 1, src, GLOBAL.GetTime(), pprefab)
    end)

    -- Healing item usage (e.g. salve, honey poultice)
    player:ListenForEvent("onuseitem", function(inst, data)
        local boss_id = get_active_boss_id(collector)
        if not boss_id then
            return
        end
        local item = data and data.item
        if item and item.components and item.components.healer then
            local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
            local src = Attribution.GetSourceName(item, "治疗道具")
            collector:Record("consumables_used", boss_id, pid, pname, 1, src, GLOBAL.GetTime(), pprefab)
        end
    end)
end

return ResourceCollector
