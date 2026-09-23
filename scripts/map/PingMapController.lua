--
-- PingMapController
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingMapController = {}

local PingMapController_mt = Class(PingMapController)

---Creates a new PingMapController instance
-- @param any owner Owner of the controller
-- @param table customMt Custom metatable
-- @return PingMapController New instance
-- @includeCode
function PingMapController.new(owner, customMt)
  local self = setmetatable({}, customMt or PingMapController_mt)

  self.owner = owner
  self.holdStartTime = 0
  self.holdFrame = nil
  self.holdPingId = nil

  return self
end

---Resets the PingMapController state
-- @includeCode
function PingMapController:reset()
  self.holdStartTime = 0
  self.holdFrame = nil
  self.holdPingId = nil
end

---Updates the PingMapController state
-- @includeCode
function PingMapController:update()
  if self.holdStartTime <= 0 then
    return
  end

  if PingUtil.getIsLocalPlayerHoldingObject() or self:getActiveMapFrame() ~= self.holdFrame then
    self:reset()
    return
  end

  if (g_time or 0) - self.holdStartTime >= self.owner.removeHoldDuration then
    PingSystemRemoveRequestEvent.sendEvent(self.holdPingId)
    self.holdStartTime = -1
  end
end

---Handles mouse events for pings
-- @param number posX X position
-- @param number posY Y position
-- @param boolean isDown Mouse button down
-- @param boolean isUp Mouse button up
-- @param integer button Mouse button ID
-- @includeCode
function PingMapController:mouseEvent(posX, posY, isDown, isUp, button)
  if self.holdStartTime > 0 and self.holdFrame ~= nil then
    self.holdPingId = self:getPingIdAtScreenPosition(self.holdFrame.ingameMap, posX, posY)
  end

  if button ~= Input.MOUSE_BUTTON_MIDDLE then
    return
  end

  if isDown then
    if PingUtil.getIsLocalPlayerHoldingObject() then
      return
    end

    local frame = self:getActiveMapFrame()

    if frame ~= nil then
      self.holdStartTime = g_time or 0
      self.holdFrame = frame
      self.holdPingId = self:getPingIdAtScreenPosition(frame.ingameMap, posX, posY)
    end
  elseif isUp and self.holdStartTime ~= 0 then
    local holdStartTime = self.holdStartTime
    local frame = self:getActiveMapFrame()

    if holdStartTime > 0 and frame ~= nil and frame == self.holdFrame then
      if (g_time or 0) - holdStartTime >= self.owner.removeHoldDuration then
        PingSystemRemoveRequestEvent.sendEvent(self.holdPingId)
      else
        self:createPing(frame, posX, posY)
      end
    end

    self:reset()
  end
end

---Gets the active map frame
-- @return table Active map frame or nil
-- @includeCode
function PingMapController:getActiveMapFrame()
  if
    not self.owner.isClient
    or g_currentMission == nil
    or g_localPlayer == nil
    or g_inGameMenu == nil
    or g_inGameMenu.pageMapOverview == nil
    or not g_inGameMenu:getIsOpen()
    or g_inGameMenu.currentPage ~= g_inGameMenu.pageMapOverview
    or g_inGameMenu.pageMapOverview.isInputContextActive ~= true
    or (g_gui ~= nil and g_gui:getIsDialogVisible())
  then
    return nil
  end

  return g_inGameMenu.pageMapOverview
end

---Creates a ping at specified position
-- @param table frame Frame containing the map
-- @param number posX X position on the map
-- @param number posY Y position on the map
-- @return boolean True if ping created
-- @includeCode
function PingMapController:createPing(frame, posX, posY)
  local worldX, worldY, worldZ = self:getPingPosition(frame, posX, posY)

  if worldX == nil then
    return false
  end

  PingSystemRequestEvent.sendEvent(worldX, worldY, worldZ, true)

  return true
end

---Gets world position for ping
-- @param table frame Frame containing the map
-- @param number posX X position on the map
-- @param number posY Y position on the map
-- @return number World X position
-- @return number World Y position
-- @return number World Z position
-- @includeCode
function PingMapController:getPingPosition(frame, posX, posY)
  local mapElement = frame ~= nil and frame.ingameMap or nil
  local ingameMap = mapElement ~= nil and mapElement.ingameMap or nil

  if mapElement == nil or ingameMap == nil or not mapElement:getIsActive() or posX < 0 or posX > 1 or posY < 0 or posY > 1 or mapElement:isInputInDeadzones(posX, posY) then
    return nil
  end

  local localX, localY = mapElement:getLocalPosition(posX, posY)

  if localX == nil or localY == nil or localX < 0 or localX > 1 or localY < 0 or localY > 1 then
    return nil
  end

  local worldX, worldZ = mapElement:localToWorldPos(localX, localY)
  local hotspot = self:getHotspotAtScreenPosition(mapElement, posX, posY, false)

  if hotspot ~= nil and hotspot.getWorldPosition ~= nil then
    local hotspotX, hotspotZ = hotspot:getWorldPosition()

    if hotspotX ~= nil and hotspotZ ~= nil then
      worldX = hotspotX
      worldZ = hotspotZ
    end
  end

  if not PingUtil.getIsInsideTerrain(worldX, worldZ) then
    return nil
  end

  local worldY = getTerrainHeightAtWorldPos(g_terrainNode, worldX, 0, worldZ)

  return worldX, worldY, worldZ
end

---Gets ping ID at screen position
-- @param table mapElement Map element to check
-- @param number posX X position on the map
-- @param number posY Y position on the map
-- @return integer Ping ID or nil
-- @includeCode
function PingMapController:getPingIdAtScreenPosition(mapElement, posX, posY)
  local hotspot = self:getHotspotAtScreenPosition(mapElement, posX, posY, true)

  return hotspot ~= nil and hotspot.pingId or nil
end

---Finds hotspot at screen position
-- @param table mapElement Map element to check
-- @param number posX X position on the map
-- @param number posY Y position on the map
-- @param boolean pingSystemOnly Filter for ping system hotspots
-- @return table Hotspot or nil
-- @includeCode
function PingMapController:getHotspotAtScreenPosition(mapElement, posX, posY, pingSystemOnly)
  local ingameMap = mapElement ~= nil and mapElement.ingameMap or nil

  if ingameMap == nil or ingameMap.hotspots == nil then
    return nil
  end

  ingameMap:updateHotspotSorting()

  local currentFilter = ingameMap.currentFilter or ingameMap.filter
  local bestHotspot = nil
  local bestDistance = math.huge

  for _, hotspot in ipairs(ingameMap.hotspots) do
    local category = hotspot.getCategory ~= nil and hotspot:getCategory() or nil
    local categoryVisible = currentFilter == nil or currentFilter[category] == true
    local isPingSystemHotspot = hotspot.isPingSystemHotspot == true

    if isPingSystemHotspot == pingSystemOnly and categoryVisible and hotspot.getIsVisible ~= nil and hotspot:getIsVisible() and hotspot.lastScreenLayout == ingameMap.fullScreenLayout and hotspot.hasMouseOverlap ~= nil then
      local overlaps, distance = hotspot:hasMouseOverlap(posX, posY)

      if overlaps and (bestHotspot == nil or (distance or 0) < bestDistance) then
        bestHotspot = hotspot
        bestDistance = distance or 0
      end
    end
  end

  return bestHotspot
end
