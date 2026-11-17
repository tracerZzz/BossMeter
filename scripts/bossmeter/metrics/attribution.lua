-- scripts/bossmeter/metrics/attribution.lua
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

local DEFAULT_ENGAGE_DISTANCE = 40

--- Resolve the most relevant active Boss session for a player event.
-- A player is considered participating in a Boss fight if:
--   1. preferred_boss_id directly matches an active session (e.g. Boss attacked the player), OR
--   2. the player is within max_dist (default 40 units) of the Boss entity, OR
--   3. the player has recorded direct combat interaction with the Boss in this session.
-- @param player table Player entity
-- @param collector table Collector instance
-- @param preferred_boss_id string|number|nil Optional explicit boss_id (e.g. attacker.GUID)
-- @param max_dist number|nil Engagement radius in world units (default 40)
-- @return string|number|nil boss_id
function Attribution.ResolveRelevantBoss(player, collector, preferred_boss_id, max_dist)
    if not collector then
        return nil
    end
    local active = collector:GetActiveSessions()
    if preferred_boss_id ~= nil and active[preferred_boss_id] then
        return preferred_boss_id
    end
    if not player then
        return nil
    end

    local radius = max_dist or DEFAULT_ENGAGE_DISTANCE
    local max_dist_sq = radius * radius
    local pid = select(1, Attribution.GetPlayerInfo(player))
    local player_valid = (not player.IsValid) or player:IsValid()

    local best_id = nil
    local best_combat_time = -1
    local best_dist_sq = math.huge

    for boss_id, session in pairs(active) do
        local combat_time = session.combat_players and session.combat_players[pid]
        local in_range = false
        local dist_sq = math.huge

        local ent = session.entity
        if player_valid and ent and ((not ent.IsValid) or ent:IsValid()) and player.GetDistanceSqToInst then
            dist_sq = player:GetDistanceSqToInst(ent)
            if dist_sq <= max_dist_sq then
                in_range = true
            end
        end

        if combat_time or in_range then
            local ct = combat_time or -1
            if ct > best_combat_time or (ct == best_combat_time and dist_sq < best_dist_sq) then
                best_id = boss_id
                best_combat_time = ct
                best_dist_sq = dist_sq
            end
        end
    end

    return best_id
end

return Attribution
