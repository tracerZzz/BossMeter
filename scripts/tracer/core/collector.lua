-- scripts/tracer/core/collector.lua
-- Public Tracer core facade combining Registry and SessionManager.

local Registry = require("tracer/core/registry")
local SessionManager = require("tracer/core/session")

local Collector = {}
Collector.__index = Collector

function Collector.New()
    local self = setmetatable({}, Collector)
    self.registry = Registry.New()
    self.sessions = SessionManager.New(self.registry)
    self.on_session_start_callbacks = {}
    self.on_session_end_callbacks = {}
    return self
end

--- Register a built-in or external mod metric.
-- @param id string
-- @param def table
function Collector:RegisterMetric(id, def)
    return self.registry:RegisterMetric(id, def)
end

function Collector:GetMetric(id)
    return self.registry:GetMetric(id)
end

function Collector:ListMetrics(category)
    return self.registry:ListMetrics(category)
end

--- Start a Boss fight session (idempotent if already active).
function Collector:StartBossSession(boss_id, boss_prefab, boss_name, start_time, boss_max_hp)
    local existed = self.sessions:GetSession(boss_id) ~= nil
    local session, err = self.sessions:StartSession(boss_id, boss_prefab, boss_name, start_time, boss_max_hp)
    if session and not existed then
        for _, cb in ipairs(self.on_session_start_callbacks) do
            cb(session)
        end
    end
    return session, err
end

--- Record a metric value for a player in an active Boss fight session.
function Collector:Record(metric_id, boss_id, player_id, player_name, value, source_name, timestamp, player_prefab)
    return self.sessions:RecordValue(boss_id, metric_id, player_id, player_name, value, source_name, timestamp, player_prefab)
end

--- End a Boss fight session and notify listeners.
function Collector:EndBossSession(boss_id, end_time, outcome)
    local summary, err = self.sessions:EndSession(boss_id, end_time, outcome)
    if summary then
        for _, cb in ipairs(self.on_session_end_callbacks) do
            cb(summary)
        end
    end
    return summary, err
end

--- Prune timed-out sessions and notify listeners for each ended session.
function Collector:PruneTimeouts(current_time, timeout_seconds)
    local ended = self.sessions:PruneTimeouts(current_time, timeout_seconds)
    for _, summary in ipairs(ended) do
        for _, cb in ipairs(self.on_session_end_callbacks) do
            cb(summary)
        end
    end
    return ended
end

function Collector:GetActiveSessions()
    return self.sessions:GetActiveSessions()
end

function Collector:GetSession(boss_id)
    return self.sessions:GetSession(boss_id)
end

function Collector:OnSessionStart(cb)
    if type(cb) == "function" then
        table.insert(self.on_session_start_callbacks, cb)
    end
end

function Collector:OnSessionEnd(cb)
    if type(cb) == "function" then
        table.insert(self.on_session_end_callbacks, cb)
    end
end

return Collector
