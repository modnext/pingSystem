--
-- PingHud
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingHud = {}

local PingHud_mt = Class(PingHud, HUDDisplay)

---Creates a new PingHud instance
-- @param any owner Owner of the PingHud
-- @return PingHud New PingHud instance
-- @includeCode
function PingHud.new(owner)
  local self = PingHud:superClass().new(PingHud_mt)

  self.owner = owner
  self.layout = PingHudLayout.new(self)

  self.markerOverlay = g_overlayManager:createOverlay("guiElementsPingSystem.map_pin", 0, 0, 0, 0)

  if self.markerOverlay ~= nil then
    self.markerOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
  end

  self.arrowOverlay = g_overlayManager:createOverlay("guiElementsPingSystem.arrow", 0, 0, 0, 0)

  if self.arrowOverlay ~= nil then
    self.arrowOverlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
  end

  self:setScale(g_gameSettings:getValue("uiScale") or 1)

  return self
end

---Stores scaled UI values for PingHud
-- @includeCode
function PingHud:storeScaledValues()
  self.markerWidth, self.markerHeight = self:scalePixelValuesToScreenVector(32, 35)
  self.arrowWidth, self.arrowHeight = self:scalePixelValuesToScreenVector(12, 7)
  self.borderX = self:scalePixelToScreenWidth(76)
  self.borderY = self:scalePixelToScreenHeight(96)
  self.textSize = self:scalePixelToScreenHeight(15)
  self.ownerLabelTextSize = self:scalePixelToScreenHeight(12)
  self.textOffsetY = self:scalePixelToScreenHeight(-36)
  self.textShadowX, self.textShadowY = self:scalePixelValuesToScreenVector(1.25, 1.25)
  self.collisionPaddingX = self:scalePixelToScreenWidth(6)
  self.collisionPaddingY = self:scalePixelToScreenHeight(6)
  self.collisionGapX = self:scalePixelToScreenWidth(8)
  self.collisionGapY = self:scalePixelToScreenHeight(8)

  if self.markerOverlay ~= nil then
    self.markerOverlay:setDimension(self.markerWidth, self.markerHeight)
  end

  if self.arrowOverlay ~= nil then
    self.arrowOverlay:setDimension(self.arrowWidth, self.arrowHeight)
  end
end

---Deletes the PingHud instance
-- @includeCode
function PingHud:delete()
  if self.layout ~= nil then
    self.layout:delete()
    self.layout = nil
  end

  if self.markerOverlay ~= nil then
    self.markerOverlay:delete()
    self.markerOverlay = nil
  end

  if self.arrowOverlay ~= nil then
    self.arrowOverlay:delete()
    self.arrowOverlay = nil
  end
end

---Draws the PingHud on the screen
-- @includeCode
function PingHud:draw()
  if self.owner == nil or g_localPlayer == nil or g_cameraManager == nil then
    return
  end

  if g_gui ~= nil and g_gui:getIsGuiVisible() then
    return
  end

  if g_currentMission == nil or g_currentMission.hud == nil or not g_currentMission.hud:getIsVisible() then
    return
  end

  local cameraNode = g_cameraManager:getActiveCamera()

  if cameraNode == nil or cameraNode == 0 or not entityExists(cameraNode) then
    return
  end

  local uiScale = g_gameSettings:getValue("uiScale") or 1

  if math.abs(uiScale - self.uiScale) > 0.001 then
    self:setScale(uiScale)
  end

  local playerX, playerY, playerZ = g_localPlayer:getPosition()
  local entries = {}

  new2DLayer()

  for _, ping in pairs(self.owner:getPings()) do
    if ping.isLocallyVisible and self.owner:canDisplayPing(ping.farmId) then
      local entry = self:createLayoutEntry(cameraNode, ping, playerX, playerY, playerZ)

      if entry ~= nil then
        table.insert(entries, entry)
      end
    end
  end

  self.layout:resolveCollisions(entries)

  for _, entry in ipairs(entries) do
    self:drawPing(entry)
  end

  self:resetTextState()
end

---Creates layout entry for a ping
-- @param any cameraNode Active camera node
-- @param table ping Ping data
-- @param number playerX Player X position
-- @param number playerY Player Y position
-- @param number playerZ Player Z position
-- @return table Layout entry data
-- @includeCode
function PingHud:createLayoutEntry(cameraNode, ping, playerX, playerY, playerZ)
  local distanceX = ping.x - playerX
  local distanceY = ping.y - playerY
  local distanceZ = ping.z - playerZ
  local distance = math.sqrt(distanceX * distanceX + distanceY * distanceY + distanceZ * distanceZ)

  local screenX, screenY, isClamped, directionX, directionY = self:getScreenPosition(cameraNode, ping)

  if screenX == nil then
    return
  end

  local fadeAlpha = self:getFadeAlpha(ping)

  if fadeAlpha <= 0 then
    return
  end

  local distanceText = g_i18n:formatDistance(distance)
  local textWidth = getTextWidth(self.textSize, distanceText)
  local markerHalfWidth = self.markerWidth * 0.5
  local markerHalfHeight = self.markerHeight * 0.5

  return {
    ping = ping,
    distance = distance,
    distanceText = distanceText,
    fadeAlpha = fadeAlpha,
    desiredX = screenX,
    desiredY = screenY,
    screenX = screenX,
    screenY = screenY,
    isClamped = isClamped,
    directionX = directionX,
    directionY = directionY,
    halfWidth = math.max(markerHalfWidth, textWidth * 0.5) + self.collisionPaddingX,
    bottomExtent = math.max(markerHalfHeight, -self.textOffsetY) + self.collisionPaddingY,
    topExtent = markerHalfHeight + self.collisionPaddingY,
  }
end

---Draws the ping overlay on the HUD
-- @param table entry Contains ping data and position
-- @includeCode
function PingHud:drawPing(entry)
  local ping = entry.ping
  local screenX = entry.screenX
  local screenY = entry.screenY
  local fadeAlpha = entry.fadeAlpha
  local directionX = entry.directionX
  local directionY = entry.directionY

  local pulseAlpha = (0.72 + math.abs(math.sin((g_time or 0) / 320)) * 0.28) * fadeAlpha
  local color = ping.color

  if self.markerOverlay ~= nil then
    self.markerOverlay:setColor(color[1], color[2], color[3], pulseAlpha)
    self.markerOverlay:setPosition(screenX, screenY)
    self.markerOverlay:render()
    self:drawOwnerLabel(screenX, screenY, ping.ownerUserId, pulseAlpha)
  end

  if entry.isClamped and self.arrowOverlay ~= nil then
    local angle = math.atan2(directionX, -directionY)

    self.arrowOverlay:setColor(color[1], color[2], color[3], pulseAlpha)
    self.arrowOverlay:setRotation(angle, self.arrowWidth * 0.5, self.arrowHeight * 0.5)
    self.arrowOverlay:setPosition(screenX + directionX * self.markerWidth * 0.72, screenY + directionY * self.markerHeight * 0.72)
    self.arrowOverlay:render()
  end

  self:drawDistanceText(screenX, screenY + self.textOffsetY, entry.distance, fadeAlpha, entry.distanceText)
end

---Draws the owner label on the HUD
-- @param number x X position for the label
-- @param number y Y position for the label
-- @param string ownerUserId User ID of the owner
-- @param number alpha Alpha transparency for the label
-- @includeCode
function PingHud:drawOwnerLabel(x, y, ownerUserId, alpha)
  local label = PingUtil.getUserMarkerLabel(ownerUserId)
  local textX = x + self.markerWidth * 0.266
  local textY = y - self.markerHeight * 0.18

  setTextBold(true)
  setTextAlignment(RenderText.ALIGN_CENTER)
  setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
  setTextWrapWidth(0, false)

  setTextColor(0, 0, 0, alpha * 0.9)
  renderText(textX + self.textShadowX, textY - self.textShadowY, self.ownerLabelTextSize, label)

  setTextColor(1, 1, 1, alpha)
  renderText(textX, textY, self.ownerLabelTextSize, label)
end

---Calculates screen position from world coordinates
-- @param any cameraNode Camera node for projection
-- @param table ping Ping data with world coordinates
-- @return number Clamped X screen position
-- @return number Clamped Y screen position
-- @return boolean Indicates if position is clamped
-- @return number Direction X for the ping
-- @return number Direction Y for the ping
-- @includeCode
function PingHud:getScreenPosition(cameraNode, ping)
  local localX, localY, localZ = worldToLocal(cameraNode, ping.x, ping.y, ping.z)
  local nearClip = math.max(getNearClip(cameraNode) or 0.1, 0.01)

  if localZ > -nearClip then
    local nearPlane = -nearClip
    local fovY = math.max(getFovY(cameraNode) or math.rad(60), 0.01)
    local horizontalRadius = nearPlane / math.sin(fovY * 0.5)
    local verticalRadius = nearPlane / math.sin(fovY * 0.5 * g_screenAspectRatio)
    local horizontalEdge = math.sqrt(math.max(0, horizontalRadius * horizontalRadius - nearPlane * nearPlane))
    local verticalEdge = math.sqrt(math.max(0, verticalRadius * verticalRadius - nearPlane * nearPlane))

    localX = horizontalEdge * (localX < 0 and -1 or 1)
    localY = verticalEdge * (localY < 0 and -1 or 1)
  end

  local projectedLocalZ = math.min(localZ, -nearClip)
  local worldX, worldY, worldZ = localToWorld(cameraNode, localX, localY, projectedLocalZ)
  local screenX, screenY = project(worldX, worldY, worldZ)

  if screenX == nil or screenY == nil or screenX ~= screenX or screenY ~= screenY then
    return nil
  end

  local clampedX = math.max(self.borderX, math.min(1 - self.borderX, screenX))
  local clampedY = math.max(self.borderY, math.min(1 - self.borderY, screenY))
  local isClamped = clampedX ~= screenX or clampedY ~= screenY
  local directionX = screenX - 0.5
  local directionY = screenY - 0.5
  local directionLength = math.sqrt(directionX * directionX + directionY * directionY)

  if directionLength > 0.0001 then
    directionX = directionX / directionLength
    directionY = directionY / directionLength
  else
    directionX = 0
    directionY = 1
  end

  return clampedX, clampedY, isClamped, directionX, directionY
end

---Gets the fade alpha for the ping
-- @param table ping Ping data to get fade alpha
-- @return number Fade alpha value
-- @includeCode
function PingHud:getFadeAlpha(ping)
  return self.owner.registry:getFadeAlpha(ping, g_time or 0)
end

---Draws distance text on the HUD
-- @param number x X position for the distance text
-- @param number y Y position for the distance text
-- @param number distance Distance value to display
-- @param number alpha Alpha transparency for the text
-- @param string text Custom text to display
-- @includeCode
function PingHud:drawDistanceText(x, y, distance, alpha, text)
  text = text or g_i18n:formatDistance(distance)

  setTextBold(true)
  setTextAlignment(RenderText.ALIGN_CENTER)
  setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
  setTextWrapWidth(0, false)

  setTextColor(0, 0, 0, alpha * 0.85)
  renderText(x + self.textShadowX, y - self.textShadowY, self.textSize, text)

  setTextColor(1, 1, 1, alpha)
  renderText(x, y, self.textSize, text)
end

---Resets text state for the HUD
-- @includeCode
function PingHud:resetTextState()
  setTextColor(1, 1, 1, 1)
  setTextBold(false)
  setTextAlignment(RenderText.ALIGN_LEFT)
  setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BASELINE)
  setTextWrapWidth(0, false)
end
