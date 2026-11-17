-- scripts/bossmeter/ui/review_panel.lua
-- Post-combat Boss fight review panel with 4-category tabs, BarChart, LineChart, and source breakdown.

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"
local TextButton = require "widgets/textbutton"

local BarChart = require("bossmeter/ui/charts/bar_chart")
local LineChart = require("bossmeter/ui/charts/line_chart")

local CATEGORIES = {
    { id = "damage",   label = "伤害输出" },
    { id = "survival", label = "生存承伤" },
    { id = "support",  label = "辅助治疗" },
    { id = "resource", label = "资源消耗" },
    { id = "custom",   label = "扩展指标" },
}

local OUTCOME_LABELS = {
    victory = "击杀",
    timeout = "脱战",
    despawn = "消失",
}

local ReviewPanel = Class(Widget, function(self, store)
    Widget._ctor(self, "BossMeterReviewPanel")
    self.store = store
    self.report_idx = 1
    self.active_category = "damage"
    self.active_metric_id = nil

    self.panel_w = 820
    self.panel_h = 540

    -- Backdrop
    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetSize(self.panel_w, self.panel_h)
    self.bg:SetTint(0.07, 0.08, 0.11, 0.94)

    -- Header bar
    self.header_bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.header_bg:SetSize(self.panel_w, 52)
    self.header_bg:SetPosition(0, self.panel_h / 2 - 26, 0)
    self.header_bg:SetTint(0.12, 0.14, 0.19, 0.98)

    self.title_txt = self:AddChild(Text(HEADERFONT, 26, "BossMeter 战后数据回顾"))
    self.title_txt:SetHAlign(ANCHOR_LEFT)
    self.title_txt:SetRegionSize(440, 40)
    self.title_txt:SetPosition(-self.panel_w / 2 + 236, self.panel_h / 2 - 26, 0)
    self.title_txt:SetColour(1, 0.92, 0.72, 1)

    -- Session navigation (< Prev | 1/N | Next >)
    self.prev_btn = self:AddChild(TextButton())
    self.prev_btn:SetText("< 上一场")
    self.prev_btn:SetTextSize(18)
    self.prev_btn:SetPosition(120, self.panel_h / 2 - 26, 0)
    self.prev_btn:SetOnClick(function() self:SelectReport(self.report_idx + 1) end)

    self.page_txt = self:AddChild(Text(BODYTEXTFONT, 18, "0 / 0"))
    self.page_txt:SetPosition(200, self.panel_h / 2 - 26, 0)

    self.next_btn = self:AddChild(TextButton())
    self.next_btn:SetText("下一场 >")
    self.next_btn:SetTextSize(18)
    self.next_btn:SetPosition(280, self.panel_h / 2 - 26, 0)
    self.next_btn:SetOnClick(function() self:SelectReport(self.report_idx - 1) end)

    -- Close button
    self.close_btn = self:AddChild(TextButton())
    self.close_btn:SetText("✕ 关闭")
    self.close_btn:SetTextSize(20)
    self.close_btn:SetPosition(self.panel_w / 2 - 48, self.panel_h / 2 - 26, 0)
    self.close_btn:SetOnClick(function() self:Hide() end)

    -- Category tabs
    self.tab_buttons = {}
    local tab_start_x = -self.panel_w / 2 + 85
    for i, cat in ipairs(CATEGORIES) do
        local btn = self:AddChild(TextButton())
        btn:SetText(cat.label)
        btn:SetTextSize(20)
        btn:SetPosition(tab_start_x + (i - 1) * 125, self.panel_h / 2 - 74, 0)
        btn:SetOnClick(function()
            self.active_category = cat.id
            self.active_metric_id = nil
            self:Refresh()
        end)
        self.tab_buttons[cat.id] = btn
    end

    -- Sub-metric selector container
    self.submetric_root = self:AddChild(Widget("SubMetricRoot"))

    -- Charts
    self.bar_chart = self:AddChild(BarChart(460, 210))
    self.bar_chart:SetPosition(-160, 35, 0)

    self.line_chart = self:AddChild(LineChart(460, 175))
    self.line_chart:SetPosition(-160, -165, 0)

    -- Right-side Source Breakdown panel
    self.breakdown_title = self:AddChild(Text(BODYTEXTFONT, 20, "来源明细 (Top)"))
    self.breakdown_title:SetPosition(245, 130, 0)
    self.breakdown_title:SetColour(0.95, 0.85, 0.65, 1)

    self.breakdown_txt = self:AddChild(Text(BODYTEXTFONT, 17, ""))
    self.breakdown_txt:SetHAlign(ANCHOR_LEFT)
    self.breakdown_txt:SetVAlign(ANCHOR_TOP)
    self.breakdown_txt:SetRegionSize(280, 350)
    self.breakdown_txt:SetPosition(245, -60, 0)
    self.breakdown_txt:SetColour(0.88, 0.90, 0.92, 1)

    self.empty_txt = self:AddChild(Text(BODYTEXTFONT, 24, "尚无 Boss 战记录\n击败 Boss 后将自动生成战报"))
    self.empty_txt:SetColour(0.75, 0.75, 0.8, 0.9)
    self.empty_txt:Hide()

    self:Hide()
end)

function ReviewPanel:Toggle()
    if self:IsVisible() then
        self:Hide()
    else
        self:Show()
        self:Refresh()
    end
end

function ReviewPanel:SelectReport(idx)
    local count = #self.store.reports
    if count == 0 then
        self.report_idx = 1
    else
        self.report_idx = math.max(1, math.min(count, idx))
    end
    self:Refresh()
end

local function format_duration(sec)
    local s = math.floor(sec or 0)
    return string.format("%02d:%02d", math.floor(s / 60), s % 60)
end

function ReviewPanel:Refresh()
    local reports = self.store.reports
    local count = #reports
    if count == 0 then
        self.title_txt:SetString("BossMeter 战后数据回顾")
        self.page_txt:SetString("0 / 0")
        self.bar_chart:Hide()
        self.line_chart:Hide()
        self.breakdown_title:Hide()
        self.breakdown_txt:Hide()
        self.submetric_root:KillAllChildren()
        self.empty_txt:Show()
        return
    end

    self.empty_txt:Hide()
    self.bar_chart:Show()
    self.line_chart:Show()
    self.breakdown_title:Show()
    self.breakdown_txt:Show()

    if self.report_idx > count then self.report_idx = count end
    local report = reports[self.report_idx]
    local outcome = OUTCOME_LABELS[report.outcome] or tostring(report.outcome)
    self.title_txt:SetString(string.format("%s [%s · %s]",
        tostring(report.boss_name), outcome, format_duration(report.duration)))
    self.page_txt:SetString(string.format("%d / %d", self.report_idx, count))

    -- Highlight active category tab
    for cat_id, btn in pairs(self.tab_buttons) do
        if cat_id == self.active_category then
            btn:SetTextColour(1, 0.85, 0.35, 1)
        else
            btn:SetTextColour(0.75, 0.78, 0.82, 1)
        end
    end

    -- Collect metrics belonging to active_category
    local matching_defs = {}
    for _, def in pairs(report.metric_defs or {}) do
        local is_custom_tab = (self.active_category == "custom" and def.is_custom)
        local is_cat_match = (def.category == self.active_category and not def.is_custom)
        if is_custom_tab or is_cat_match then
            table.insert(matching_defs, def)
        end
    end
    table.sort(matching_defs, function(a, b)
        if (a.order or 100) ~= (b.order or 100) then
            return (a.order or 100) < (b.order or 100)
        end
        return a.id < b.id
    end)

    -- Render sub-metric buttons
    self.submetric_root:KillAllChildren()
    if #matching_defs == 0 then
        self.bar_chart:SetData({})
        self.line_chart:SetData({}, report.duration)
        self.breakdown_txt:SetString("本场战斗无该分类数据")
        return
    end

    local selected_def = matching_defs[1]
    for _, d in ipairs(matching_defs) do
        if d.id == self.active_metric_id then
            selected_def = d
            break
        end
    end
    self.active_metric_id = selected_def.id

    for i, d in ipairs(matching_defs) do
        local sub_btn = self.submetric_root:AddChild(TextButton())
        sub_btn:SetText(d.name)
        sub_btn:SetTextSize(17)
        sub_btn:SetPosition(-self.panel_w / 2 + 80 + (i - 1) * 135, self.panel_h / 2 - 110, 0)
        if d.id == selected_def.id then
            sub_btn:SetTextColour(0.45, 0.85, 1, 1)
        else
            sub_btn:SetTextColour(0.68, 0.70, 0.75, 1)
        end
        sub_btn:SetOnClick(function()
            self.active_metric_id = d.id
            self:Refresh()
        end)
    end

    -- Build BarChart items
    local mdata = report.metrics and report.metrics[selected_def.id]
    if not mdata then
        self.bar_chart:SetData({})
        self.line_chart:SetData({}, report.duration)
        self.breakdown_txt:SetString("暂无明细")
        return
    end

    local bar_items = {}
    for pid, val in pairs(mdata.totals or {}) do
        local pinfo = report.players and report.players[pid]
        local pname = (pinfo and pinfo.name) or pid
        local rate_txt = nil
        if selected_def.id == "damage_total" and mdata.rates and mdata.rates[pid] then
            rate_txt = string.format("%.1f/s", mdata.rates[pid])
        end
        table.insert(bar_items, {
            pid = pid,
            label = pname,
            value = val,
            share = mdata.shares and mdata.shares[pid],
            rate_text = rate_txt,
        })
    end
    table.sort(bar_items, function(a, b) return a.value > b.value end)
    self.bar_chart:SetData(bar_items)

    -- Build LineChart series
    local series_list = {}
    if mdata.series then
        for _, item in ipairs(bar_items) do
            local arr = mdata.series[item.pid]
            if arr then
                table.insert(series_list, {
                    name = item.label,
                    values = arr,
                })
            end
        end
    end
    self.line_chart:SetData(series_list, report.duration)

    -- Build Source Breakdown text
    local lines = {}
    for _, item in ipairs(bar_items) do
        local src_map = mdata.sources and mdata.sources[item.pid]
        if src_map and next(src_map) ~= nil then
            table.insert(lines, string.format("[%s]", item.label))
            local src_list = {}
            for sname, sval in pairs(src_map) do
                table.insert(src_list, { name = sname, val = sval })
            end
            table.sort(src_list, function(a, b) return a.val > b.val end)
            for j = 1, math.min(#src_list, 4) do
                table.insert(lines, string.format("  • %s: %.0f", src_list[j].name, src_list[j].val))
            end
        end
    end
    self.breakdown_txt:SetString(#lines > 0 and table.concat(lines, "\n") or "无来源明细")
end

return ReviewPanel
