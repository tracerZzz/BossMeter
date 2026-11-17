-- scripts/bossmeter/ui/charts/bar_chart.lua
-- Built-in horizontal bar chart Widget using standard DST assets.

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local DEFAULT_PALETTE = {
    { 0.90, 0.35, 0.30, 0.90 },
    { 0.30, 0.65, 0.95, 0.90 },
    { 0.35, 0.80, 0.45, 0.90 },
    { 0.95, 0.70, 0.25, 0.90 },
    { 0.70, 0.45, 0.90, 0.90 },
    { 0.30, 0.85, 0.85, 0.90 },
}

local BarChart = Class(Widget, function(self, width, height)
    Widget._ctor(self, "BossMeterBarChart")
    self.width = width or 480
    self.height = height or 200
    self.rows_root = self:AddChild(Widget("RowsRoot"))
    self.empty_text = self:AddChild(Text(BODYTEXTFONT, 22, "暂无该项数据"))
    self.empty_text:SetColour(0.7, 0.7, 0.7, 0.8)
    self.empty_text:Hide()
end)

function BarChart:SetData(items)
    self.rows_root:KillAllChildren()

    if not items or #items == 0 then
        self.empty_text:Show()
        return
    end
    self.empty_text:Hide()

    local max_rows = math.min(#items, 6)
    local row_h = math.min(34, (self.height - 10) / max_rows)
    local bar_h = math.max(16, row_h - 10)
    local top_y = (self.height / 2) - (row_h / 2) - 4
    local label_w = 110
    local value_w = 135
    local bar_area_w = math.max(80, self.width - label_w - value_w - 16)
    local bar_left_x = -(self.width / 2) + label_w + 8

    local max_val = 0
    for i = 1, max_rows do
        if items[i].value > max_val then
            max_val = items[i].value
        end
    end
    if max_val <= 0 then
        max_val = 1
    end

    for i = 1, max_rows do
        local item = items[i]
        local y = top_y - (i - 1) * row_h

        -- Player / item label
        local lbl = self.rows_root:AddChild(Text(BODYTEXTFONT, 18, tostring(item.label or "")))
        lbl:SetHAlign(ANCHOR_RIGHT)
        lbl:SetRegionSize(label_w, row_h)
        lbl:SetPosition(-(self.width / 2) + label_w / 2, y, 0)
        lbl:SetColour(0.95, 0.95, 0.95, 1)

        -- Track background
        local bg = self.rows_root:AddChild(Image("images/global.xml", "square.tex"))
        bg:SetSize(bar_area_w, bar_h)
        bg:SetPosition(bar_left_x + bar_area_w / 2, y, 0)
        bg:SetTint(0.15, 0.15, 0.18, 0.8)

        -- Filled bar
        local ratio = math.max(0.02, math.min(1, item.value / max_val))
        local fill_w = bar_area_w * ratio
        local fill = self.rows_root:AddChild(Image("images/global.xml", "square.tex"))
        fill:SetSize(fill_w, bar_h)
        fill:SetPosition(bar_left_x + fill_w / 2, y, 0)
        local c = item.color or DEFAULT_PALETTE[((i - 1) % #DEFAULT_PALETTE) + 1]
        fill:SetTint(c[1], c[2], c[3], c[4] or 0.9)

        -- Value + share% + optional rate
        local val_str = item.value_text or string.format("%.0f", item.value)
        if item.share then
            val_str = val_str .. string.format(" (%.0f%%)", item.share * 100)
        end
        if item.rate_text then
            val_str = val_str .. " " .. item.rate_text
        end
        local val_txt = self.rows_root:AddChild(Text(BODYTEXTFONT, 17, val_str))
        val_txt:SetHAlign(ANCHOR_LEFT)
        val_txt:SetRegionSize(value_w, row_h)
        val_txt:SetPosition(bar_left_x + bar_area_w + value_w / 2 + 8, y, 0)
        val_txt:SetColour(0.9, 0.9, 0.85, 1)
    end
end

return BarChart
