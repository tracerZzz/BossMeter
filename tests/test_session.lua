-- tests/test_session.lua

local Collector = require("bossmeter/core/collector")
local Attribution = require("bossmeter/metrics/attribution")
local Sync = require("bossmeter/net/sync")

return function(T)
    local c = Collector.New()
    c:RegisterMetric("damage_total", {
        name = "总伤害",
        category = "damage",
        unit = "HP",
        aggregation = "sum",
        chart_type = "bar",
        track_timeseries = true,
        order = 10,
    })
    c:RegisterMetric("healing_done", {
        name = "治疗量",
        category = "support",
        unit = "HP",
        aggregation = "sum",
        chart_type = "bar",
        order = 20,
    })

    local started_count = 0
    local ended_count = 0
    c:OnSessionStart(function() started_count = started_count + 1 end)
    c:OnSessionEnd(function() ended_count = ended_count + 1 end)

    -- Start session (idempotent)
    local s1 = c:StartBossSession(1001, "deerclops", "独眼巨鹿", 100.0, 4000)
    local s1_again = c:StartBossSession(1001, "deerclops", "独眼巨鹿", 101.0, 4000)
    T.assert_eq(s1, s1_again, "StartBossSession is idempotent")
    T.assert_eq(started_count, 1, "OnSessionStart fired once")

    -- Record values across seconds and sources
    T.assert_true(c:Record("damage_total", 1001, "KU_P1", "Wilson", 150, "火腿棒", 100.2, "wilson"))
    T.assert_true(c:Record("damage_total", 1001, "KU_P1", "Wilson", 50, "阿比盖尔", 102.5, "wilson"))
    T.assert_true(c:Record("damage_total", 1001, "KU_P2", "Wolfgang", 600, "暗影剑", 103.1, "wolfgang"))
    T.assert_true(c:Record("healing_done", 1001, "KU_P1", "Wilson", 40, "治疗药膏", 103.5, "wilson"))

    -- Invalid value / unregistered metric
    local bad_val = c:Record("damage_total", 1001, "KU_P1", "Wilson", 0 / 0, "x", 104.0)
    T.assert_true(not bad_val, "reject NaN value")
    local bad_metric = c:Record("nonexistent", 1001, "KU_P1", "Wilson", 10, "x", 104.0)
    T.assert_true(not bad_metric, "reject unregistered metric")

    -- End session and verify summary
    local summary = c:EndBossSession(1001, 104.0, "victory")
    T.assert_eq(ended_count, 1, "OnSessionEnd fired once")
    T.assert_eq(summary.boss_prefab, "deerclops", "boss_prefab matches")
    T.assert_near(summary.duration, 4.0, 1e-4, "duration is 4.0s")

    local dmg = summary.metrics["damage_total"]
    T.assert_eq(dmg.grand_total, 800, "grand_total damage is 800")
    T.assert_eq(dmg.totals["KU_P1"], 200, "P1 total damage is 200")
    T.assert_eq(dmg.totals["KU_P2"], 600, "P2 total damage is 600")
    T.assert_near(dmg.rates["KU_P2"], 150.0, 1e-4, "P2 DPS is 150")
    T.assert_near(dmg.shares["KU_P1"], 0.25, 1e-4, "P1 share is 25%")
    T.assert_eq(dmg.sources["KU_P1"]["火腿棒"], 150, "P1 source breakdown")
    T.assert_eq(dmg.series["KU_P1"][1], 150, "bucket 1 has 150")
    T.assert_eq(dmg.series["KU_P1"][3], 50, "bucket 3 has 50")
    T.assert_eq(dmg.series["KU_P2"][4], 600, "bucket 4 has 600")

    -- Timeout pruning test: non-renewing events don't extend timeout, and end_time == last_activity_time
    c:StartBossSession(2002, "dragonfly", "龙蝇", 200.0, 27500)
    c:Record("damage_total", 2002, "KU_P1", "Wilson", 100, "火腿棒", 205.0, "wilson", {
        touch_activity = true,
        combat_interaction = true,
    })
    -- Non-renewing healing at 225.0 should NOT reset timeout
    c:Record("healing_done", 2002, "KU_P1", "Wilson", 20, "食物", 225.0, "wilson", {
        touch_activity = false,
    })
    local pruned_early = c:PruneTimeouts(220.0, 30)
    T.assert_eq(#pruned_early, 0, "not timed out at +15s")
    local pruned_late = c:PruneTimeouts(236.0, 30)
    T.assert_eq(#pruned_late, 1, "timed out at +31s despite non-renewing heal at 225s")
    T.assert_eq(pruned_late[1].outcome, "timeout", "outcome is timeout")
    T.assert_near(pruned_late[1].end_time, 205.0, 1e-4, "timeout end_time uses last_activity_time (205.0)")
    T.assert_near(pruned_late[1].duration, 5.0, 1e-4, "timeout duration excludes idle 31s")

    -- Attribution range & combat isolation test
    local boss_a = { GUID = 3001, IsValid = function() return true end }
    local boss_b = { GUID = 3002, IsValid = function() return true end }
    c:StartBossSession(3001, "deerclops", "巨鹿", 300.0, 4000, boss_a)
    c:StartBossSession(3002, "beequeen", "蜂后", 301.0, 22500, boss_b)
    c:Record("damage_total", 3001, "KU_P1", "Wilson", 100, "长矛", 302.0, "wilson", {
        touch_activity = true,
        combat_interaction = true,
    })

    local player_p1 = {
        userid = "KU_P1",
        IsValid = function() return true end,
        GetDistanceSqToInst = function(_, ent) return ent == boss_a and 100 or 2500 end,
    }
    local player_base = {
        userid = "KU_BASE",
        IsValid = function() return true end,
        GetDistanceSqToInst = function() return 10000 end, -- 100 units away (> 40)
    }
    T.assert_eq(Attribution.ResolveRelevantBoss(player_p1, c), 3001, "P1 resolves to engaged boss 3001")
    T.assert_eq(Attribution.ResolveRelevantBoss(player_p1, c, 3002), 3002, "explicit attacker overrides")
    T.assert_eq(Attribution.ResolveRelevantBoss(player_base, c), nil, "distant base player is isolated")
    c:EndBossSession(3001, 310.0, "victory")
    c:EndBossSession(3002, 310.0, "victory")

    -- Sync multi-boss HUD state & trivial report filtering
    local store = Sync.NewClientStore(5)
    Sync.SetBossState(store, "start", "巨鹿", 3001)
    Sync.SetBossState(store, "start", "蜂后", 3002)
    T.assert_eq(store.active_boss_name, "蜂后", "active_boss_name set on start")
    Sync.SetBossState(store, "end", "巨鹿", 3001)
    T.assert_true(store.active_boss_name ~= nil, "ending one boss keeps other active boss HUD")
    Sync.SetBossState(store, "end", "蜂后", 3002)
    T.assert_eq(store.active_boss_name, nil, "HUD clears only when all bosses end")

    T.assert_true(not Sync.ShouldBroadcastReport({
        outcome = "timeout",
        duration = 1.0,
        metrics = { damage_total = { grand_total = 34 } },
    }), "filter out stray 1-hit timeout report")
    T.assert_true(Sync.ShouldBroadcastReport({
        outcome = "timeout",
        duration = 5.0,
        metrics = { damage_total = { grand_total = 300 } },
    }), "keep meaningful timeout report")
    T.assert_true(Sync.ShouldBroadcastReport({
        outcome = "victory",
        duration = 1.0,
        metrics = {},
    }), "always keep victory report")
end
