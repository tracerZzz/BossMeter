-- scripts/tracer/core/session.lua
-- Boss fight session lifecycle management and per-second bucket aggregation.

local SessionManager = {}
SessionManager.__index = SessionManager

--- Create a new SessionManager.
-- @param registry Registry instance
function SessionManager.New(registry)
    local self = setmetatable({}, SessionManager)
    self.registry = registry
    self.active_sessions = {}
    self.next_session_seq = 1
    return self
end

--- Start or retrieve an active Boss fight session.
-- @param boss_id string|number Unique Boss identifier (e.g. GUID)
-- @param boss_prefab string Prefab name (e.g. "deerclops")
-- @param boss_name string Display name
-- @param start_time number Current world/game time in seconds
-- @param boss_max_hp number|nil Optional max HP
function SessionManager:StartSession(boss_id, boss_prefab, boss_name, start_time, boss_max_hp)
    if boss_id == nil then
        return nil, "boss_id is required"
    end
    local existing = self.active_sessions[boss_id]
    if existing then
        return existing, nil
    end

    local now = start_time or 0
    local session = {
        session_id = self.next_session_seq,
        boss_id = boss_id,
        boss_prefab = boss_prefab or "unknown",
        boss_name = boss_name or boss_prefab or "Unknown Boss",
        boss_max_hp = boss_max_hp or 0,
        start_time = now,
        last_activity_time = now,
        players = {},       -- [player_id] = { id = player_id, name = player_name, prefab = ... }
        metrics = {},       -- [metric_id] = { totals = { [player_id] = num }, sources = { [player_id] = { [src] = num } }, buckets = { [sec_idx] = { [player_id] = num } } }
    }
    self.next_session_seq = self.next_session_seq + 1
    self.active_sessions[boss_id] = session
    return session, nil
end

function SessionManager:GetSession(boss_id)
    return self.active_sessions[boss_id]
end

function SessionManager:GetActiveSessions()
    return self.active_sessions
end

function SessionManager:TouchSession(boss_id, current_time)
    local session = self.active_sessions[boss_id]
    if session and current_time and current_time > session.last_activity_time then
        session.last_activity_time = current_time
    end
end

--- Record a metric value into an active session.
-- @param boss_id string|number
-- @param metric_id string
-- @param player_id string
-- @param player_name string
-- @param value number
-- @param source_name string|nil Optional breakdown source (e.g. weapon/food name)
-- @param timestamp number|nil Event timestamp in seconds
-- @param player_prefab string|nil Optional player prefab
function SessionManager:RecordValue(boss_id, metric_id, player_id, player_name, value, source_name, timestamp, player_prefab)
    local session = self.active_sessions[boss_id]
    if not session then
        return false, "no active session for boss_id: " .. tostring(boss_id)
    end
    if type(value) ~= "number" or value ~= value then -- nil or NaN check
        return false, "invalid numeric value"
    end

    local metric_def = self.registry and self.registry:GetMetric(metric_id)
    if not metric_def then
        return false, "unregistered metric: " .. tostring(metric_id)
    end

    local pid = tostring(player_id or "unknown")
    if not session.players[pid] then
        session.players[pid] = {
            id = pid,
            name = player_name or pid,
            prefab = player_prefab or "",
        }
    elseif player_name and player_name ~= "" then
        session.players[pid].name = player_name
    end

    local now = timestamp or session.last_activity_time or session.start_time
    if now > session.last_activity_time then
        session.last_activity_time = now
    end

    local mdata = session.metrics[metric_id]
    if not mdata then
        mdata = {
            totals = {},
            sources = {},
            buckets = {},
        }
        session.metrics[metric_id] = mdata
    end

    -- Aggregate total
    local prev = mdata.totals[pid] or 0
    if metric_def.aggregation == "max" then
        if value > prev then
            mdata.totals[pid] = value
        end
    else
        mdata.totals[pid] = prev + value
    end

    -- Source breakdown
    if source_name and source_name ~= "" then
        mdata.sources[pid] = mdata.sources[pid] or {}
        if metric_def.aggregation == "max" then
            local prev_src = mdata.sources[pid][source_name] or 0
            if value > prev_src then
                mdata.sources[pid][source_name] = value
            end
        else
            mdata.sources[pid][source_name] = (mdata.sources[pid][source_name] or 0) + value
        end
    end

    -- 1-second time-series bucket (1-indexed second offset from start_time)
    if metric_def.track_timeseries then
        local elapsed = math.max(0, now - session.start_time)
        local bucket_idx = math.floor(elapsed) + 1
        mdata.buckets[bucket_idx] = mdata.buckets[bucket_idx] or {}
        if metric_def.aggregation == "max" then
            local prev_b = mdata.buckets[bucket_idx][pid] or 0
            if value > prev_b then
                mdata.buckets[bucket_idx][pid] = value
            end
        else
            mdata.buckets[bucket_idx][pid] = (mdata.buckets[bucket_idx][pid] or 0) + value
        end
    end

    return true
end

--- End an active Boss session and build a serializable SessionSummary.
-- @param boss_id string|number
-- @param end_time number
-- @param outcome string "victory" | "timeout" | "despawn"
function SessionManager:EndSession(boss_id, end_time, outcome)
    local session = self.active_sessions[boss_id]
    if not session then
        return nil, "no active session"
    end
    self.active_sessions[boss_id] = nil

    local finish = end_time or session.last_activity_time or session.start_time
    if finish < session.start_time then
        finish = session.start_time
    end
    local duration = math.max(1, finish - session.start_time)

    local summary = {
        session_id = session.session_id,
        boss_prefab = session.boss_prefab,
        boss_name = session.boss_name,
        boss_max_hp = session.boss_max_hp,
        start_time = session.start_time,
        end_time = finish,
        duration = duration,
        outcome = outcome or "victory",
        players = session.players,
        metrics = {},
        metric_defs = {},
    }

    local max_bucket = math.max(1, math.ceil(duration))
    for metric_id, mdata in pairs(session.metrics) do
        local def = self.registry:GetMetric(metric_id)
        local grand_total = 0
        for _, val in pairs(mdata.totals) do
            grand_total = grand_total + val
        end

        local rates = {}
        local shares = {}
        for pid, val in pairs(mdata.totals) do
            rates[pid] = val / duration
            shares[pid] = grand_total > 0 and (val / grand_total) or 0
        end

        -- Convert sparse buckets into dense array up to max_bucket
        local series = nil
        if def and def.track_timeseries then
            series = {}
            for pid, _ in pairs(session.players) do
                local arr = {}
                for b = 1, max_bucket do
                    local bmap = mdata.buckets[b]
                    arr[b] = (bmap and bmap[pid]) or 0
                end
                series[pid] = arr
            end
        end

        summary.metrics[metric_id] = {
            grand_total = grand_total,
            totals = mdata.totals,
            rates = rates,
            shares = shares,
            sources = mdata.sources,
            series = series,
        }

        if def then
            summary.metric_defs[metric_id] = {
                id = def.id,
                name = def.name,
                category = def.category,
                unit = def.unit,
                aggregation = def.aggregation,
                chart_type = def.chart_type,
                order = def.order,
                is_custom = def.is_custom,
            }
        end
    end

    return summary, nil
end

--- End any active sessions that have exceeded combat_timeout without activity.
-- @param current_time number
-- @param timeout_seconds number
-- @return table Array of ended SessionSummary objects
function SessionManager:PruneTimeouts(current_time, timeout_seconds)
    local timeout = timeout_seconds or 30
    local timed_out_ids = {}
    for boss_id, session in pairs(self.active_sessions) do
        if (current_time - session.last_activity_time) >= timeout then
            table.insert(timed_out_ids, boss_id)
        end
    end

    local ended = {}
    for _, boss_id in ipairs(timed_out_ids) do
        local summary = self:EndSession(boss_id, current_time, "timeout")
        if summary then
            table.insert(ended, summary)
        end
    end
    return ended
end

return SessionManager
