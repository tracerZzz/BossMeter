-- scripts/bossmeter/ui/charts/line_chart.lua
-- Built-in multi-series time-series line chart Widget using standard DST assets.

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local DEFAULT_PALETTE = {
    { 0.90, 0.35, 0.30, 1 },
    { 0.30, 0.65, 0.95, 1 },
    { 0.35, 0.80, 0.45, 1 },
    { 0.95, 0.70, 0.25, 1 },
    { 0.70, 0.45, 0.90, 1 },
    { 0.30, 0.85, 0.85, 1 },
}

local LineChart = Class(Widget, function(self, width, height)
    Widget._ctor(self, "BossMeterLineChart")
    self.width = width or 480
    self.height = height or 170
    self.canvas = self:AddChild(Widget("Canvas"))
    self.empty_text = self:AddChild(Text(BODYTEXTFONT, 20, "该指标无时间序列趋势数据"))
    self.empty_text:SetColour(0.7, 0.7, 0.7, 0.8)
    self.empty_text:Hide()
end)

local function downsample(values, max_points)
    local n = #values
    if n <= max_points then
        return values
    end
    local out = {}
    local step = n / max_points
    for i = 1, max_points do
        local start_idx = math.floor((i - 1) * step) + 1
        local end_idx = math.min(n, math.floor(i * step))
        local sum = 0
        local cnt = 0
        for j = start_idx, end_idx do
            sum = sum + (values[j] or 0)
            cnt = cnt + 1
        end
        out[i] = cnt > 0 and (sum / cnt) or 0
    end
    return out
end

function LineChart:DrawSegment(x1, y1, x2, y2, color, thickness)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.5 then
        return
    end
    local seg = self.canvas:AddChild(Image("images/global.xml", "square.tex"))
    seg:SetSize(len, thickness or 2.5)
    seg:SetPosition((x1 + x2) / 2, (y1 + y2) / 2, 0)
    -- DST Image:SetRotation takes degrees (clockwise in screen space when y is up)
    local angle_deg = math.deg(math.atan2(dy, dx))
    seg:SetRotation(-angle_deg)
    seg:SetTint(color[1], color[2], color[3], color[4] or 1)
end

function LineChart:SetData(series_list, duration)
    self.canvas:KillAllChildren()

    if not series_list or #series_list == 0 then
        self.empty_text:Show()
        return
    end
    self.empty_text:Hide()

    local pad_left = 48
    local pad_right = 16
    local pad_top = 26
    local pad_bottom = 26

    local plot_w = self.width - pad_left - pad_right
    local plot_h = self.height - pad_top - pad_bottom
    local origin_x = -(self.width / 2) + pad_left
    local origin_y = -(self.height / 2) + pad_bottom

    -- Downsample & find global max
    local sampled = {}
    local max_val = 0
    local max_len = 0
    for idx, s in ipairs(series_list) do
        local vals = downsample(s.values or {}, 48)
        if #vals > max_len then max_len = #vals end
        for _, v in ipairs(vals) do
            if v > max_val then max_val = v end
        end
        sampled[idx] = {
            name = s.name,
            values = vals,
            color = s.color or DEFAULT_PALETTE[((idx - 1) % #DEFAULT_PALETTE) + 1],
        }
    end
    if max_val <= 0 then max_val = 1 end
    if max_len < 2 then max_len = 2 end

    -- Axes
    local x_axis = self.canvas:AddChild(Image("images/global.xml", "square.tex"))
    x_axis:SetSize(plot_w, 1.5)
    x_axis:SetPosition(origin_x + plot_w / 2, origin_y, 0)
    x_axis:SetTint(0.6, 0.6, 0.6, 0.8)

    local y_axis = self.canvas:AddChild(Image("images/global.xml", "square.tex"))
    y_axis:SetSize(1.5, plot_h)
    y_axis:SetPosition(origin_x, origin_y + plot_h / 2, 0)
    y_axis:SetTint(0.6, 0.6, 0.6, 0.8)

    -- Horizontal gridlines (50% and 100%)
    for _, frac in ipairs({ 0.5, 1.0 }) do
        local gy = origin_y + plot_h * frac
        local grid = self.canvas:AddChild(Image("images/global.xml", "square.tex"))
        grid:SetSize(plot_w, 1)
        grid:SetPosition(origin_x + plot_w / 2, gy, 0)
        grid:SetTint(0.4, 0.4, 0.45, 0.35)

        local y_lbl = self.canvas:AddChild(Text(BODYTEXTFONT, 14, string.format("%.0f", max_val * frac)))
        y_lbl:SetHAlign(ANCHOR_RIGHT)
        y_lbl:SetRegionSize(pad_left - 6, 18)
        y_lbl:SetPosition(origin_x - pad_left / 2, gy, 0)
        y_lbl:SetColour(0.75, 0.75, 0.75, 0.9)
    end

    -- X-axis labels
    local dur = math.floor(duration or max_len)
    local t0 = self.canvas:AddChild(Text(BODYTEXTFONT, 14, "0s"))
    t0:SetPosition(origin_x + 10, origin_y - 14, 0)
    t0:SetColour(0.75, 0.75, 0.75, 0.9)

    local t1 = self.canvas:AddChild(Text(BODYTEXTFONT, 14, string.format("%ds", dur)))
    t1:SetPosition(origin_x + plot_w - 14, origin_y - 14, 0)
    t1:SetColour(0.75, 0.75, 0.75, 0.9)

    -- Plot lines & compact legend
    local legend_x = origin_x + 8
    local legend_y = origin_y + plot_h + 14
    for _, s in ipairs(sampled) do
        local vals = s.values
        local count = #vals
        if count >= 2 then
            for i = 1, count - 1 do
                local x1 = origin_x + ((i - 1) / (count - 1)) * plot_w
                local y1 = origin_y + (vals[i] / max_val) * plot_h
                local x2 = origin_x + (i / (count - 1)) * plot_w
                local y2 = origin_y + (vals[i + 1] / max_val) * plot_h
                self:DrawSegment(x1, y1, x2, y2, s.color, 2.2)
            end
        end

        if legend_x < origin_x + plot_w - 60 then
            local swatch = self.canvas:AddChild(Image("images/global.xml", "square.tex"))
            swatch:SetSize(10, 10)
            swatch:SetPosition(legend_x, legend_y, 0)
            swatch:SetTint(s.color[1], s.color[2], s.color[3], 1)

            local ltxt = self.canvas:AddChild(Text(BODYTEXTFONT, 15, tostring(s.name)))
            ltxt:SetHAlign(ANCHOR_LEFT)
            ltxt:SetRegionSize(72, 18)
            ltxt:SetPosition(legend_x + 42, legend_y, 0)
            ltxt:SetColour(0.9, 0.9, 0.9, 1)
            legend_x = legend_x + 88
        end
    end
end

return LineChart
