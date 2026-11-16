-- tests/test_registry_metrics.lua

local Registry = require("tracer/core/registry")

return function(T)
    local reg = Registry.New()

    -- Valid registrations
    local ok, err = reg:RegisterMetric("damage_total", {
        name = "总伤害",
        category = "damage",
        unit = "HP",
        aggregation = "sum",
        chart_type = "bar",
        track_timeseries = true,
        order = 10,
    })
    T.assert_true(ok, "register damage_total: " .. tostring(err))

    local ok2 = reg:RegisterMetric("armor_loss", {
        name = "护甲耐久损耗",
        category = "resource",
        unit = "耐久",
        order = 40,
    })
    T.assert_true(ok2, "register armor_loss")

    -- Custom external mod metric
    local ok3 = reg:RegisterMetric("mod_elemental_burn", {
        name = "元素灼烧伤害",
        category = "damage",
        unit = "HP",
        order = 15,
        is_custom = true,
    })
    T.assert_true(ok3, "register custom metric")

    -- Invalid registrations
    local bad1 = reg:RegisterMetric("", { name = "x", category = "damage" })
    T.assert_true(not bad1, "reject empty metric id")

    local bad2 = reg:RegisterMetric("bad_agg", { name = "x", category = "damage", aggregation = "median" })
    T.assert_true(not bad2, "reject invalid aggregation")

    -- Ordering and category filtering
    local dmg_list = reg:ListMetrics("damage")
    T.assert_eq(#dmg_list, 2, "2 damage metrics")
    T.assert_eq(dmg_list[1].id, "damage_total", "order 10 comes first")
    T.assert_eq(dmg_list[2].id, "mod_elemental_burn", "order 15 comes second")

    local cats = reg:GetCategories()
    T.assert_eq(#cats, 2, "2 categories registered")
    T.assert_eq(cats[1], "damage", "first category is damage")
    T.assert_eq(cats[2], "resource", "second category is resource")
end
