--
-- PingHotspot
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingHotspot = {}

local PingHotspot_mt = Class(PingHotspot, MapHotspot)

function PingHotspot.new(pingId, farmId, color, ownerUserId, customMt)
  local self = MapHotspot.new(customMt or PingHotspot_mt)
  local markerWidth, markerHeight = getNormalizedScreenValues(32, 35)

  self.icon = g_overlayManager:createOverlay("guiElementsPingSystem.map_hotspot_pin", 0, 0, markerWidth, markerHeight)
  self.pingId = pingId
  self.ownerUserId = ownerUserId
  self.isPingSystemHotspot = true
  self.forceNoRotation = true
  self.clickArea = MapHotspot.getClickCircle(0.5)
  self.alpha = 1

  self:setOwnerFarmId(farmId)
  self:setBlinking(true)

  if color ~= nil then
    self:setColor(color[1], color[2], color[3])
  end

  return self
end

function PingHotspot:setOwnerUserId(ownerUserId)
  self.ownerUserId = ownerUserId
end

function PingHotspot:setAlpha(alpha)
  local wasVisible = self.alpha > 0

  self.alpha = math.min(1, math.max(0, tonumber(alpha) or 1))

  if wasVisible ~= (self.alpha > 0) then
    self:onRenderStateChanged()
  end
end

function PingHotspot:getCanBeAccessed()
  local pingSystem = g_currentMission ~= nil and g_currentMission.pingSystem or nil

  return pingSystem ~= nil and pingSystem:canDisplayPing(self.ownerFarmId)
end

function PingHotspot:getIsVisible()
  return self.alpha > 0 and PingHotspot:superClass().getIsVisible(self)
end

function PingHotspot:getCategory()
  return MapHotspot.CATEGORY_OTHER
end

function PingHotspot:getIsPersistent()
  return true
end

function PingHotspot:getRenderLast()
  return true
end

function PingHotspot:render(x, y, rotation, _)
  local icon = self.icon

  if icon == nil then
    return
  end

  local color = self.color
  local blinkAlpha = self.isBlinking and self:getCanBlink() and IngameMap.alpha or 1
  local alpha = blinkAlpha * self.alpha

  icon:renderCustom(x, y, icon.width, icon.height, color[1], color[2], color[3], alpha, nil, nil, nil, nil, self.forceNoRotation and 0 or rotation or 0, icon.width * 0.5, icon.height * 0.5)

  self:drawOwnerLabel(x, y, alpha)
end

function PingHotspot:drawOwnerLabel(x, y, alpha)
  if alpha <= 0 then
    return
  end

  local icon = self.icon
  local label = PingUtil.getUserMarkerLabel(self.ownerUserId)
  local textSize = math.max(icon.height * 0.28, getCorrectTextSize(0.009))
  local textX = x + icon.width * 0.766
  local textY = y + icon.height * 0.32

  setTextBold(true)
  setTextAlignment(RenderText.ALIGN_CENTER)
  setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
  setTextWrapWidth(0, false)

  setTextColor(0, 0, 0, alpha * 0.9)
  renderText(textX + icon.width * 0.02, textY - icon.height * 0.02, textSize, label)

  setTextColor(1, 1, 1, alpha)
  renderText(textX, textY, textSize, label)

  setTextColor(1, 1, 1, 1)
  setTextBold(false)
  setTextAlignment(RenderText.ALIGN_LEFT)
  setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
  setTextWrapWidth(0, false)
end
