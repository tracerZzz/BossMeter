-- scripts/bossmeter/ui/hud_indicator.lua
-- Minimal unobtrusive HUD indicator shown only during active Boss fights.

local Widget = require "widgets/widget"
local Image = require "widgets/image"
local Text = require "widgets/text"

local HudIndicator = Class(Widget, function(self)
    Widget._ctor(self, "BossMeterHudIndicator")

    self.bg = self:AddChild(Image("images/global.xml", "square.tex"))
    self.bg:SetSize(230, 32)
    self.bg:SetTint(0.08, 0.08, 0.10, 0.72)

    self.dot = self:AddChild(Image("images/global.xml", "square.tex"))
    self.dot:SetSize(8, 8)
    self.dot:SetPosition(-98, 0, 0)
    self.dot:SetTint(0.95, 0.30, 0.25, 1)

    self.label = self:AddChild(Text(BODYTEXTFONT, 18, "BossMeter 记录中"))
    self.label:SetHAlign(ANCHOR_LEFT)
    self.label:SetRegionSize(195, 28)
    self.label:SetPosition(12, 0, 0)
    self.label:SetColour(0.95, 0.95, 0.95, 0.95)

    self:Hide()
end)

function HudIndicator:SetRecording(boss_name)
    if boss_name and boss_name ~= "" then
        self.label:SetString("BossMeter 记录中: " .. tostring(boss_name))
        self:Show()
    else
        self:Hide()
    end
end

return HudIndicator
