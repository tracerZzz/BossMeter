-- scripts/tracer/metrics/attribution.lua
-- Shared helper to resolve entity ownership back to a DST player and format source names.

local Attribution = {}

--- Walk follower/owner/inventory chains to find the owning player entity.
function Attribution.ResolvePlayer(ent, max_depth)
    local curr = ent
    local depth = 0
    local limit = max_depth or 4
    while curr and depth < limit do
        if curr.HasTag and curr:HasTag("player") then
            return curr
        end
        local next_ent = nil
        if curr.components then
            if curr.components.follower and curr.components.follower.GetLeader then
                next_ent = curr.components.follower:GetLeader()
            elseif curr.components.inventoryitem and curr.components.inventoryitem.GetGrandOwner then
                next_ent = curr.components.inventoryitem:GetGrandOwner()
            end
        end
        if not next_ent and curr.owner then
            next_ent = curr.owner
        end
        if next_ent == curr then
            break
        end
        curr = next_ent
        depth = depth + 1
    end
    return nil
end

--- Extract stable player_id, display_name, and prefab from a player entity.
function Attribution.GetPlayerInfo(player)
    if not player then
        return "unknown", "Unknown", ""
    end
    local pid = (player.userid and player.userid ~= "") and player.userid or tostring(player.GUID or "unknown")
    local name = (player.GetDisplayName and player:GetDisplayName()) or player.name or player.prefab or pid
    local prefab = player.prefab or ""
    return pid, name, prefab
end

--- Resolve a human-readable source name from an item/entity/prefab string.
function Attribution.GetSourceName(source_ent, fallback)
    if type(source_ent) == "string" and source_ent ~= "" then
        return source_ent
    end
    if type(source_ent) == "table" then
        if source_ent.GetDisplayName then
            local ok, dname = pcall(source_ent.GetDisplayName, source_ent)
            if ok and dname and dname ~= "" then
                return dname
            end
        end
        if source_ent.prefab and source_ent.prefab ~= "" then
            return source_ent.prefab
        end
    end
    return fallback or "未知来源"
end

return Attribution
