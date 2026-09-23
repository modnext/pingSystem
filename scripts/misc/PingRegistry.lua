--
-- PingRegistry
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingRegistry = {}

local PingRegistry_mt = Class(PingRegistry)

---Creates a new PingRegistry instance
-- @param any owner Owner of the registry
-- @param table customMt Custom metatable
-- @return PingRegistry New PingRegistry instance
-- @includeCode
function PingRegistry.new(owner, customMt)
  local self = setmetatable({}, customMt or PingRegistry_mt)

  self.owner = owner
  self.pings = {}
  self.nextPingId = 1
  self.maxPingId = 65535
  self.fadeInTime = 500
  self.fadeOutTime = 250
  self.reachedDistance = 2.5

  return self
end

---Resets the PingRegistry state
-- @includeCode
function PingRegistry:reset()
  self:clear(false)

  self.pings = {}
  self.nextPingId = 1
end

---Updates the PingRegistry pings
-- @includeCode
function PingRegistry:update()
  if not self.owner.isClient then
    return
  end

  local currentTime = g_time or 0
  local expiredRemovalIds = {}

  for pingId, ping in pairs(self.pings) do
    if ping.isPendingRemoval and currentTime >= ping.removalExpiresAt then
      table.insert(expiredRemovalIds, pingId)
    end
  end

  for _, pingId in ipairs(expiredRemovalIds) do
    self:finishRemoval(pingId)
  end

  for _, ping in pairs(self.pings) do
    if ping.replacedPingId ~= nil and self.pings[ping.replacedPingId] == nil then
      ping.replacedPingId = nil
      ping.fadeInStartedAt = currentTime
      self:setPingDisplayDuration(ping, self.owner:getPingDisplayDuration())
    end

    self:updateProximityFade(ping, currentTime)

    ping.fadeAlpha = self:getFadeAlpha(ping, currentTime)

    self:updateLocalVisibility(ping, currentTime)

    if ping.hotspot ~= nil then
      ping.hotspot:setAlpha(self:getFadeAlpha(ping, currentTime, false))
    end
  end
end

---Updates proximity fade for a ping
-- @param table ping Ping data
-- @param number currentTime Current time
-- @includeCode
function PingRegistry:updateProximityFade(ping, currentTime)
  if ping.isPendingRemoval or g_localPlayer == nil then
    return
  end

  local playerX, playerY, playerZ = g_localPlayer:getPosition()
  local distanceX = ping.x - playerX
  local distanceY = ping.y - playerY
  local distanceZ = ping.z - playerZ
  local distanceSquared = distanceX * distanceX + distanceY * distanceY + distanceZ * distanceZ
  local minDistance = self.reachedDistance
  local targetAlpha = distanceSquared < minDistance * minDistance and 0 or 1

  if targetAlpha ~= ping.proximityFadeTargetAlpha then
    ping.proximityFadeStartAlpha = self:getProximityFadeAlpha(ping, currentTime)
    ping.proximityFadeTargetAlpha = targetAlpha
    ping.proximityFadeStartedAt = currentTime
  end
end

---Calculates fade alpha based on proximity
-- @param table ping Ping data
-- @param number currentTime Current time
-- @return number Calculated fade alpha
-- @includeCode
function PingRegistry:getProximityFadeAlpha(ping, currentTime)
  local targetAlpha = ping.proximityFadeTargetAlpha or 1
  local startAlpha = ping.proximityFadeStartAlpha or targetAlpha
  local startedAt = ping.proximityFadeStartedAt

  if startedAt == nil or startAlpha == targetAlpha then
    return targetAlpha
  end

  local fadeTime = targetAlpha > startAlpha and self.fadeInTime or self.fadeOutTime
  local duration = math.max(1, fadeTime * math.abs(targetAlpha - startAlpha))
  local progress = math.min(1, math.max(0, (currentTime - startedAt) / duration))

  return startAlpha + (targetAlpha - startAlpha) * progress
end

---Calculates fade alpha for a ping
-- @param table ping Ping data
-- @param number currentTime Current time
-- @param boolean includeProximity Include proximity fade
-- @return number Calculated fade alpha
-- @includeCode
function PingRegistry:getFadeAlpha(ping, currentTime, includeProximity)
  if ping.replacedPingId ~= nil then
    return 0
  end

  local fadeInStartedAt = ping.fadeInStartedAt or ping.createdAt
  local fadeIn = math.min(1, math.max(0, (currentTime - fadeInStartedAt) / self.fadeInTime))
  local fadeOut = 1

  if ping.displayExpiresAt ~= nil then
    fadeOut = math.min(fadeOut, math.max(0, (ping.displayExpiresAt - currentTime) / self.fadeOutTime))
  end

  if includeProximity ~= false then
    fadeOut = math.min(fadeOut, self:getProximityFadeAlpha(ping, currentTime))
  end

  if ping.removalExpiresAt ~= nil then
    fadeOut = math.min(fadeOut, math.max(0, (ping.removalExpiresAt - currentTime) / self.fadeOutTime))
  end

  return math.min(fadeIn, fadeOut)
end

---Updates display duration for pings
-- @param number duration New display duration
-- @includeCode
function PingRegistry:updateLocalDisplayDuration(duration)
  local currentTime = g_time or 0

  for _, ping in pairs(self.pings) do
    self:setPingDisplayDuration(ping, duration)

    if self.owner.isClient then
      self:updateLocalVisibility(ping, currentTime)
    end
  end
end

---Sets display duration for a specific ping
-- @param table ping Ping data
-- @param number duration Display duration
-- @includeCode
function PingRegistry:setPingDisplayDuration(ping, duration)
  if duration == PingSettingsManager.CONTINUOUS_DISPLAY_DURATION then
    ping.displayExpiresAt = nil
    return
  end

  local defaultDuration = PingSystem.DISPLAY_DURATION_VALUES[PingSystem.DEFAULT_DISPLAY_DURATION_STATE]
  local normalizedDuration = math.max(1, tonumber(duration) or defaultDuration)

  ping.displayExpiresAt = (ping.fadeInStartedAt or ping.createdAt) + normalizedDuration
end

---Updates visibility of a ping
-- @param table ping Ping data
-- @param number currentTime Current time
-- @includeCode
function PingRegistry:updateLocalVisibility(ping, currentTime)
  local isWithinDisplayDuration = ping.displayExpiresAt == nil or currentTime < ping.displayExpiresAt
  local shouldBeVisible = isWithinDisplayDuration and self.owner:canDisplayPing(ping.farmId)

  if shouldBeVisible and not ping.isLocallyVisible then
    self:showLocalPing(ping)
  elseif not shouldBeVisible and ping.isLocallyVisible then
    self:hideLocalPing(ping)
  end
end

---Allocates a new ping ID
-- @return integer New ping ID or nil
-- @includeCode
function PingRegistry:allocatePingId()
  for _ = 1, self.maxPingId do
    local pingId = self.nextPingId

    self.nextPingId = pingId % self.maxPingId + 1

    if self.pings[pingId] == nil then
      return pingId
    end
  end

  return nil
end

---Creates space for a player in the ping registry
-- @param string player Player ID
-- @return nil No return value
-- @includeCode
function PingRegistry:makeRoomForPlayer(player)
  return self:trimPlayerPings(player, self.owner:getMaxActivePingsPerPlayer() - 1)
end

---Limits active pings per player
-- @param integer maxActivePings Max pings allowed
-- @includeCode
function PingRegistry:enforcePlayerLimit(maxActivePings)
  local players = {}

  for _, ping in pairs(self.pings) do
    if not ping.isPendingRemoval and ping.ownerPlayer ~= nil then
      players[ping.ownerPlayer] = true
    end
  end

  for player in pairs(players) do
    self:trimPlayerPings(player, maxActivePings)
  end
end

---Trims pings for a specific player
-- @param string player Player ID
-- @param integer targetCount Target ping count
-- @return string ID of removed ping
-- @includeCode
function PingRegistry:trimPlayerPings(player, targetCount)
  if player == nil then
    return
  end

  targetCount = math.max(0, math.floor(tonumber(targetCount) or 0))
  local removedPingId = nil

  while true do
    local count = 0
    local oldestPingId = nil
    local oldestTime = math.huge

    for pingId, ping in pairs(self.pings) do
      if not ping.isPendingRemoval and ping.ownerPlayer == player then
        count = count + 1

        if ping.createdAt < oldestTime then
          oldestTime = ping.createdAt
          oldestPingId = pingId
        end
      end
    end

    if count <= targetCount or oldestPingId == nil then
      return removedPingId
    end

    self:remove(oldestPingId, true, true)
    removedPingId = oldestPingId
  end
end

---Updates visibility of farm pings
-- @includeCode
function PingRegistry:updateFarmVisibility()
  if not self.owner.isClient then
    return
  end

  local currentTime = g_time or 0
  local inaccessiblePingIds = {}
  local localFarmId = g_currentMission ~= nil and g_currentMission:getFarmId() or nil
  local isExpanded = self.owner:getShowPingsFromAllFarms()

  for pingId, ping in pairs(self.pings) do
    local canDisplay = self.owner:canDisplayPing(ping.farmId)

    if canDisplay and isExpanded and self.owner.isServer and ping.farmId ~= localFarmId and not ping.isLocallyVisible then
      ping.fadeInStartedAt = currentTime
      ping.fadeAlpha = 0
      ping.hasPlayedCreateSound = true
      self:setPingDisplayDuration(ping, self.owner:getPingDisplayDuration())
    end

    if canDisplay or self.owner.isServer then
      self:updateLocalVisibility(ping, currentTime)
    else
      table.insert(inaccessiblePingIds, pingId)
    end
  end

  for _, pingId in ipairs(inaccessiblePingIds) do
    self:finishRemoval(pingId)
  end
end

---Updates color of pings for a farm
-- @param integer farmId Farm ID
-- @includeCode
function PingRegistry:updateFarmColor(farmId)
  if farmId == nil then
    return
  end

  local color = self.owner:getPingColor(farmId)

  for _, ping in pairs(self.pings) do
    if ping.farmId == farmId then
      ping.color = color

      if ping.hotspot ~= nil then
        ping.hotspot:setColor(color[1], color[2], color[3])
      end
    end
  end
end

---Removes a farm ping by ID
-- @param any player Player object
-- @param number pingId Ping ID to remove
-- @param boolean broadcast Broadcast removal
-- @return boolean Success of removal
-- @includeCode
function PingRegistry:removeFarmPing(player, pingId, broadcast)
  local ping = self.pings[pingId]
  local farmId = player ~= nil and player.farmId or nil

  if farmId == nil or (FarmManager.SPECTATOR_FARM_ID ~= nil and farmId == FarmManager.SPECTATOR_FARM_ID) or ping == nil or ping.isPendingRemoval or ping.farmId ~= farmId then
    return false
  end

  self:remove(pingId, broadcast, true)

  return true
end

---Removes all pings for a player
-- @param any player Player object
-- @param boolean broadcast Broadcast removal
-- @includeCode
function PingRegistry:removePlayerPings(player, broadcast)
  if player == nil then
    return
  end

  local pingIds = {}

  for pingId, ping in pairs(self.pings) do
    if not ping.isPendingRemoval and ping.ownerPlayer == player then
      table.insert(pingIds, pingId)
    end
  end

  for _, pingId in ipairs(pingIds) do
    self:remove(pingId, broadcast, true)
  end
end

---Adds or updates a ping
-- @param number pingId Ping ID
-- @param number x X coordinate
-- @param number y Y coordinate
-- @param number z Z coordinate
-- @param integer farmId Farm ID
-- @param any ownerPlayer Owner player
-- @param string ownerUserId Owner user ID
-- @param table color Color table
-- @param number replacedPingId Replaced ping ID
-- @param boolean suppressSound Suppress sound
-- @return table Created or updated ping
-- @includeCode
function PingRegistry:add(pingId, x, y, z, farmId, ownerPlayer, ownerUserId, color, replacedPingId, suppressSound)
  local existingPing = self.pings[pingId]

  if existingPing ~= nil and suppressSound == true and not existingPing.isPendingRemoval then
    existingPing.x = x
    existingPing.y = y
    existingPing.z = z
    existingPing.farmId = farmId
    existingPing.ownerUserId = ownerUserId
    existingPing.color = color

    if existingPing.hotspot ~= nil then
      existingPing.hotspot:setWorldPosition(x, z)
      existingPing.hotspot:setOwnerUserId(ownerUserId)
      existingPing.hotspot:setColor(color[1], color[2], color[3])
    end

    return existingPing
  end

  if existingPing ~= nil then
    ownerPlayer = ownerPlayer or existingPing.ownerPlayer
    ownerUserId = ownerUserId or existingPing.ownerUserId
    self:remove(pingId, false)
  end

  local currentTime = g_time or 0

  if replacedPingId == pingId then
    replacedPingId = nil
  end

  local ping = {
    id = pingId,
    x = x,
    y = y,
    z = z,
    farmId = farmId,
    ownerPlayer = ownerPlayer,
    ownerUserId = ownerUserId,
    color = color,
    createdAt = currentTime,
    fadeInStartedAt = currentTime,
    replacedPingId = replacedPingId,
    proximityFadeStartAlpha = 1,
    proximityFadeTargetAlpha = 1,
    fadeAlpha = 0,
    isPendingRemoval = false,
    isLocallyVisible = false,
    hasPlayedCreateSound = suppressSound == true,
  }

  self.pings[pingId] = ping

  if self.owner.isClient then
    self:setPingDisplayDuration(ping, self.owner:getPingDisplayDuration())
    self:updateLocalVisibility(ping, currentTime)
  end

  return ping
end

---Shows a local ping
-- @param table ping Ping object
-- @includeCode
function PingRegistry:showLocalPing(ping)
  ping.isLocallyVisible = true

  if ping.hotspot == nil then
    self:createHotspot(ping)
  end

  if ping.hotspot ~= nil then
    ping.hotspot:setAlpha(ping.fadeAlpha)
  end

  if not ping.hasPlayedCreateSound then
    ping.hasPlayedCreateSound = true
    self:playSound()
  end
end

---Hides a local ping
-- @param table ping Ping object
-- @includeCode
function PingRegistry:hideLocalPing(ping)
  if ping.hotspot ~= nil then
    if g_currentMission ~= nil and g_currentMission.removeMapHotspot ~= nil then
      g_currentMission:removeMapHotspot(ping.hotspot)
    end

    ping.hotspot:delete()
    ping.hotspot = nil
  end

  ping.isLocallyVisible = false
end

---Plays a hover sound effect
-- @includeCode
function PingRegistry:playSound()
  if g_gui == nil or g_gui.guiSoundPlayer == nil or GuiSoundPlayer == nil then
    return
  end

  g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.HOVER)
end

---Creates a new hotspot on the map
-- @param table ping Hotspot data including id and position
-- @includeCode
function PingRegistry:createHotspot(ping)
  if PingHotspot == nil or g_currentMission == nil or g_currentMission.addMapHotspot == nil then
    return
  end

  local hotspot = PingHotspot.new(ping.id, ping.farmId, ping.color, ping.ownerUserId)

  hotspot:setWorldPosition(ping.x, ping.z)
  g_currentMission:addMapHotspot(hotspot)

  ping.hotspot = hotspot
end

---Removes a ping by its ID
-- @param number pingId ID of the ping to remove
-- @param boolean broadcast Whether to broadcast removal
-- @param boolean animate Whether to animate removal
-- @includeCode
function PingRegistry:remove(pingId, broadcast, animate)
  local ping = self.pings[pingId]

  if ping == nil or ping.isPendingRemoval then
    return
  end

  if broadcast and self.owner.isServer and g_server ~= nil and g_currentMission ~= nil then
    self.owner:broadcastPingEvent(PingSystemRemoveEvent.new(pingId), ping.farmId)
  end

  if animate == true and self.owner.isClient and ping.isLocallyVisible then
    ping.isPendingRemoval = true
    ping.removalExpiresAt = (g_time or 0) + self.fadeOutTime
  else
    self:finishRemoval(pingId)
  end
end

---Finalizes the removal of a ping
-- @param number pingId ID of the ping to finalize
-- @includeCode
function PingRegistry:finishRemoval(pingId)
  local ping = self.pings[pingId]

  if ping == nil then
    return
  end

  self:hideLocalPing(ping)

  self.pings[pingId] = nil
end

---Clears all pings from the registry
-- @param boolean broadcast Whether to broadcast clear action
-- @includeCode
function PingRegistry:clear(broadcast)
  local pingIds = {}

  for pingId in pairs(self.pings) do
    table.insert(pingIds, pingId)
  end

  for _, pingId in ipairs(pingIds) do
    if broadcast then
      self:remove(pingId, true, true)
    else
      self:finishRemoval(pingId)
    end
  end
end

---Returns the current pings in the registry
-- @return table List of pings
-- @includeCode
function PingRegistry:getPings()
  return self.pings
end
