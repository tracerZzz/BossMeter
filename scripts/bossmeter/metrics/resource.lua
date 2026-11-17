-- scripts/bossmeter/metrics/resource.lua
-- Player resource consumption metrics: armor durability loss & consumables used.

local Attribution = require("bossmeter/metrics/attribution")

local ResourceCollector = {}

local NON_RENEWING_OPTS = { touch_activity = false }

function ResourceCollector.AttachPlayer(player, collector)
    -- Armor durability loss
    player:ListenForEvent("armordamage", function(inst, data)
        if not data or not data.damage or data.damage <= 0 then
            return
        end
        local boss_id = Attribution.ResolveRelevantBoss(inst, collector)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data.armor, "护甲耐久")
        collector:Record("armor_loss", boss_id, pid, pname, data.damage, src, GetTime(), pprefab, NON_RENEWING_OPTS)
    end)

    -- Food / edible consumption
    player:ListenForEvent("oneat", function(inst, data)
        local boss_id = Attribution.ResolveRelevantBoss(inst, collector)
        if not boss_id then
            return
        end
        local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
        local src = Attribution.GetSourceName(data and data.food, "食物")
        collector:Record("consumables_used", boss_id, pid, pname, 1, src, GetTime(), pprefab, NON_RENEWING_OPTS)
    end)

    -- Healing item usage (e.g. salve, honey poultice)
    player:ListenForEvent("onuseitem", function(inst, data)
        local item = data and data.item
        if item and item.components and item.components.healer then
            local boss_id = Attribution.ResolveRelevantBoss(inst, collector)
            if not boss_id then
                return
            end
            local pid, pname, pprefab = Attribution.GetPlayerInfo(inst)
            local src = Attribution.GetSourceName(item, "治疗道具")
            collector:Record("consumables_used", boss_id, pid, pname, 1, src, GetTime(), pprefab, NON_RENEWING_OPTS)
        end
    end)
end

return ResourceCollector
