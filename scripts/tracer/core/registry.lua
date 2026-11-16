-- scripts/tracer/core/registry.lua
-- Metric definition registry for built-in and external mod metrics.

local Registry = {}
Registry.__index = Registry

local VALID_AGGREGATIONS = {
    sum = true,
    max = true,
    timeseries = true,
}

local VALID_CHART_TYPES = {
    bar = true,
    line = true,
    breakdown = true,
}

--- Create a new metric Registry instance.
function Registry.New()
    local self = setmetatable({}, Registry)
    self.metrics = {}
    self.ordered_ids = {}
    return self
end

--- Register a metric definition.
-- @param id string Unique metric identifier (e.g. "damage_total")
-- @param def table Metric definition table:
--   name (string, required): Display label
--   category (string, required): "damage" | "survival" | "support" | "resource" | custom
--   unit (string, optional): Display unit, e.g. "HP", "/s", "次"
--   aggregation (string, optional): "sum" (default) | "max" | "timeseries"
--   chart_type (string, optional): "bar" (default) | "line" | "breakdown"
--   track_timeseries (boolean, optional): Whether to also bucket values per second
--   color (table, optional): {r, g, b, a}
--   order (number, optional): Sort weight (smaller comes first, default 100)
--   description (string, optional): Tooltip/description text
function Registry:RegisterMetric(id, def)
    if type(id) ~= "string" or id == "" then
        return false, "metric id must be a non-empty string"
    end
    if type(def) ~= "table" then
        return false, "metric definition must be a table"
    end
    if type(def.name) ~= "string" or def.name == "" then
        return false, "metric definition requires a non-empty name"
    end
    if type(def.category) ~= "string" or def.category == "" then
        return false, "metric definition requires a non-empty category"
    end

    local aggregation = def.aggregation or "sum"
    if not VALID_AGGREGATIONS[aggregation] then
        return false, "invalid aggregation: " .. tostring(aggregation)
    end

    local chart_type = def.chart_type or "bar"
    if not VALID_CHART_TYPES[chart_type] then
        return false, "invalid chart_type: " .. tostring(chart_type)
    end

    local is_new = (self.metrics[id] == nil)
    self.metrics[id] = {
        id = id,
        name = def.name,
        category = def.category,
        unit = def.unit or "",
        aggregation = aggregation,
        chart_type = chart_type,
        track_timeseries = (def.track_timeseries == true) or (aggregation == "timeseries") or (chart_type == "line"),
        color = def.color,
        order = def.order or 100,
        description = def.description or "",
        is_custom = def.is_custom == true,
    }

    if is_new then
        table.insert(self.ordered_ids, id)
    end

    table.sort(self.ordered_ids, function(a, b)
        local ma = self.metrics[a]
        local mb = self.metrics[b]
        if ma.order ~= mb.order then
            return ma.order < mb.order
        end
        return a < b
    end)

    return true
end

--- Retrieve a metric definition by id.
function Registry:GetMetric(id)
    return self.metrics[id]
end

--- List metric definitions, optionally filtered by category.
function Registry:ListMetrics(category)
    local result = {}
    for _, id in ipairs(self.ordered_ids) do
        local m = self.metrics[id]
        if category == nil or m.category == category then
            table.insert(result, m)
        end
    end
    return result
end

--- Return a list of unique categories in order of first appearance.
function Registry:GetCategories()
    local seen = {}
    local cats = {}
    for _, id in ipairs(self.ordered_ids) do
        local cat = self.metrics[id].category
        if not seen[cat] then
            seen[cat] = true
            table.insert(cats, cat)
        end
    end
    return cats
end

return Registry
