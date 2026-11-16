-- modmain.lua
-- Entry point for the Tracer DST mod.

local Collector = require("tracer/core/collector")
local MetricsInit = require("tracer/metrics/init")
local Sync = require("tracer/net/sync")

local config = {
    hud_indicator = GetModConfigData("hud_indicator") ~= false,
    auto_open_review = GetModConfigData("auto_open_review") ~= false,
    toggle_key = GetModConfigData("toggle_key") or "KEY_F8",
    history_limit = GetModConfigData("history_limit") or 10,
    combat_timeout = GetModConfigData("combat_timeout") or 30,
}

-- Initialize core collector & built-in metrics
local collector = Collector.New()
MetricsInit.RegisterBuiltins(collector)

-- Expose public API for external mods
GLOBAL.Tracer = {
    VERSION = "0.1.0",
    RegisterMetric = function(id, def)
        if type(def) == "table" and def.is_custom == nil then
            def.is_custom = true
        end
        return collector:RegisterMetric(id, def)
    end,
    Record = function(metric_id, boss_id, player_id, player_name, value, source_name, timestamp, player_prefab)
        return collector:Record(metric_id, boss_id, player_id, player_name, value, source_name, timestamp, player_prefab)
    end,
    StartBossSession = function(boss_id, boss_prefab, boss_name, start_time, boss_max_hp)
        return collector:StartBossSession(boss_id, boss_prefab, boss_name, start_time, boss_max_hp)
    end,
    EndBossSession = function(boss_id, end_time, outcome)
        return collector:EndBossSession(boss_id, end_time, outcome)
    end,
    GetActiveSessions = function()
        return collector:GetActiveSessions()
    end,
}

-- Initialize client store & ModRPC sync
local client_store = Sync.NewClientStore(config.history_limit)
Sync.Setup(env, collector, client_store)

-- Attach server-side Boss & Player collectors
if GLOBAL.TheNet and GLOBAL.TheNet:GetIsServer() then
    MetricsInit.AttachServerHooks(env, collector, config)
end

-- Attach client-side HUD indicator & post-combat review panel
if not (GLOBAL.TheNet and GLOBAL.TheNet:IsDedicated()) then
    local HudIndicator = require("tracer/ui/hud_indicator")
    local ReviewPanel = require("tracer/ui/review_panel")

    AddClassPostConstruct("screens/playerhud", function(hud)
        if not hud or not hud.controls then
            return
        end

        local indicator = hud.controls:AddChild(HudIndicator())
        indicator:SetHAnchor(ANCHOR_MIDDLE)
        indicator:SetVAnchor(ANCHOR_TOP)
        indicator:SetPosition(0, -36, 0)

        local review_panel = hud.controls:AddChild(ReviewPanel(client_store))
        review_panel:SetHAnchor(ANCHOR_MIDDLE)
        review_panel:SetVAnchor(ANCHOR_MIDDLE)
        review_panel:SetPosition(0, 0, 0)

        table.insert(client_store.on_state_callbacks, function(state, boss_name)
            if config.hud_indicator and state == "start" then
                indicator:SetRecording(boss_name)
            else
                indicator:SetRecording(nil)
            end
        end)

        table.insert(client_store.on_report_callbacks, function(summary)
            if config.auto_open_review and summary and summary.outcome == "victory" then
                review_panel:SelectReport(1)
                review_panel:Show()
            elseif review_panel:IsVisible() then
                review_panel:Refresh()
            end
        end)

        local key_code = GLOBAL[config.toggle_key] or GLOBAL.KEY_F8
        GLOBAL.TheInput:AddKeyUpHandler(key_code, function()
            if hud:IsChatInputScreenOpen() or hud:IsConsoleScreenOpen() then
                return
            end
            review_panel:Toggle()
        end)
    end)
end
