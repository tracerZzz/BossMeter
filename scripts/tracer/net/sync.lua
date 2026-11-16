-- scripts/tracer/net/sync.lua
-- ModRPC synchronization layer: lightweight BossState heartbeat + chunked post-combat report push.

local Serializer = require("tracer/core/serializer")

local Sync = {}

local RPC_NAMESPACE = "Tracer"
local CHUNK_SIZE = 4096

function Sync.NewClientStore(history_limit)
    return {
        limit = history_limit or 10,
        reports = {},
        active_boss_name = nil,
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

function Sync.SetBossState(store, state, boss_name)
    if state == "start" then
        store.active_boss_name = boss_name or "Boss"
    else
        store.active_boss_name = nil
    end
    for _, cb in ipairs(store.on_state_callbacks) do
        cb(state, store.active_boss_name, store)
    end
end

--- Register Client ModRPC handlers and hook Server Collector callbacks.
function Sync.Setup(env, collector, store)
    local reassembler = Serializer.NewReassembler()
    local next_msg_id = 1

    env.AddClientModRPCHandler(RPC_NAMESPACE, "BossState", function(state, boss_name)
        Sync.SetBossState(store, state, boss_name)
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
                session.boss_name
            )
        end)

        collector:OnSessionEnd(function(summary)
            env.SendModRPCToClient(
                env.GetClientModRPC(RPC_NAMESPACE, "BossState"),
                nil,
                "end",
                summary.boss_name
            )

            -- Only push reports that have recorded data or ended in victory
            local has_data = next(summary.metrics) ~= nil
            if summary.outcome == "victory" or has_data then
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
