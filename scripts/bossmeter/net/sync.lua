-- scripts/bossmeter/net/sync.lua
-- ModRPC synchronization layer: lightweight BossState heartbeat + chunked post-combat report push.

local Serializer = require("bossmeter/core/serializer")

local Sync = {}

local RPC_NAMESPACE = "BossMeter"
local CHUNK_SIZE = 4096

function Sync.NewClientStore(history_limit)
    return {
        limit = history_limit or 10,
        reports = {},
        active_boss_name = nil,
        active_bosses = {},
        on_report_callbacks = {},
        on_state_callbacks = {},
    }
end

function Sync.AddReport(store, summary)
    if not summary then
        return
    end
    table.insert(store.reports, 1, summary)
    while #store.reports > store.limit do
        table.remove(store.reports)
    end
    for _, cb in ipairs(store.on_report_callbacks) do
        cb(summary, store)
    end
end

function Sync.SetBossState(store, state, boss_name, boss_id)
    local key = boss_id ~= nil and tostring(boss_id) or tostring(boss_name or "Boss")
    store.active_bosses = store.active_bosses or {}
    if state == "start" then
        local display = boss_name or "Boss"
        store.active_bosses[key] = display
        store.active_boss_name = display
    else
        store.active_bosses[key] = nil
        local _, next_name = next(store.active_bosses)
        store.active_boss_name = next_name
    end
    local notify_state = store.active_boss_name and "start" or "end"
    for _, cb in ipairs(store.on_state_callbacks) do
        cb(notify_state, store.active_boss_name, store)
    end
end

--- Filter out trivial/accidental timeout or despawn reports (e.g. a single stray hit).
function Sync.ShouldBroadcastReport(summary)
    if not summary then
        return false
    end
    if summary.outcome == "victory" then
        return true
    end
    if not summary.metrics or next(summary.metrics) == nil then
        return false
    end
    local dmg = summary.metrics["damage_total"]
    if dmg and (dmg.grand_total or 0) > 0 and (summary.duration or 0) >= 3 then
        return true
    end
    local deaths = summary.metrics["deaths"]
    if deaths and (deaths.grand_total or 0) > 0 then
        return true
    end
    if summary.metric_defs then
        for _, def in pairs(summary.metric_defs) do
            if def.is_custom then
                return true
            end
        end
    end
    return false
end

--- Register Client ModRPC handlers and hook Server Collector callbacks.
function Sync.Setup(env, collector, store)
    local reassembler = Serializer.NewReassembler()
    local next_msg_id = 1

    env.AddClientModRPCHandler(RPC_NAMESPACE, "BossState", function(state, boss_name, boss_id)
        Sync.SetBossState(store, state, boss_name, boss_id)
    end)

    env.AddClientModRPCHandler(RPC_NAMESPACE, "SyncChunk", function(msg_id, idx, total, data)
        local full_payload = reassembler:Push(msg_id, idx, total, data)
        if full_payload then
            local ok, summary = Serializer.Decode(full_payload)
            if ok and type(summary) == "table" then
                Sync.AddReport(store, summary)
            end
        end
    end)

    -- Server-side broadcast hooks
    if TheNet and TheNet:GetIsServer() then
        collector:OnSessionStart(function(session)
            env.SendModRPCToClient(
                env.GetClientModRPC(RPC_NAMESPACE, "BossState"),
                nil,
                "start",
                session.boss_name,
                session.boss_id
            )
        end)

        collector:OnSessionEnd(function(summary)
            env.SendModRPCToClient(
                env.GetClientModRPC(RPC_NAMESPACE, "BossState"),
                nil,
                "end",
                summary.boss_name,
                summary.boss_id
            )

            -- Only push meaningful reports (filter out stray accidental hits)
            if Sync.ShouldBroadcastReport(summary) then
                local encoded = Serializer.Encode(summary)
                local chunks = Serializer.ChunkPayload(encoded, CHUNK_SIZE)
                local msg_id = next_msg_id
                next_msg_id = next_msg_id + 1
                local total = #chunks
                local rpc = env.GetClientModRPC(RPC_NAMESPACE, "SyncChunk")
                for idx, chunk in ipairs(chunks) do
                    env.SendModRPCToClient(rpc, nil, msg_id, idx, total, chunk)
                end
            end
        end)
    end
end

return Sync
