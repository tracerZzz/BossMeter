-- tests/test_session.lua

local Collector = require("tracer/core/collector")

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

    -- Timeout pruning test
    c:StartBossSession(2002, "dragonfly", "龙蝇", 200.0, 27500)
    c:Record("damage_total", 2002, "KU_P1", "Wilson", 100, "火腿棒", 205.0)
    local pruned_early = c:PruneTimeouts(220.0, 30)
    T.assert_eq(#pruned_early, 0, "not timed out at +15s")
    local pruned_late = c:PruneTimeouts(236.0, 30)
    T.assert_eq(#pruned_late, 1, "timed out at +31s")
    T.assert_eq(pruned_late[1].outcome, "timeout", "outcome is timeout")
end
