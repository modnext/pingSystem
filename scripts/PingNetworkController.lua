--
-- PingNetworkController
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingNetworkController = {}

local PingNetworkController_mt = Class(PingNetworkController)

---Creates a new PingNetworkController instance
-- @param any owner Owner of the controller
-- @param table customMt Custom metatable
-- @return PingNetworkController New controller instance
-- @includeCode
function PingNetworkController.new(owner, customMt)
  local self = setmetatable({}, customMt or PingNetworkController_mt)

  self.owner = owner
  self.lastRequestTime = {}
  self.localRequestKey = {}
  self.maxRequestDistance = owner.inputController.raycast.maxDistance + 50
  self.requestCooldown = 250

  return self
end

---Resets the last request time
-- @includeCode
function PingNetworkController:reset()
  self.lastRequestTime = {}
end

---Clears request state for a player
-- @param any player Player object
-- @param Connection connection Connection object
-- @includeCode
function PingNetworkController:clearPlayerRequestState(player, connection)
  connection = connection or (player ~= nil and player.connection or nil)

  if connection ~= nil then
    self.lastRequestTime[connection] = nil
  end

  if player ~= nil and player.isOwner then
    self.lastRequestTime[self.localRequestKey] = nil
  end
end

---Checks if a request is allowed
-- @param Connection connection Connection object
-- @return boolean True if request is allowed
-- @includeCode
function PingNetworkController:getIsRequestAllowed(connection)
  local requestKey = connection or self.localRequestKey
  local currentTime = g_time or 0
  local previousRequestTime = self.lastRequestTime[requestKey]

  if previousRequestTime ~= nil and currentTime - previousRequestTime < self.requestCooldown then
    return false
  end

  self.lastRequestTime[requestKey] = currentTime

  return true
end

---Handles a ping request from a player
-- @param Connection connection Connection object
-- @param number x X coordinate
-- @param number y Y coordinate
-- @param number z Z coordinate
-- @param boolean isMapPing Is a map ping
-- @includeCode
function PingNetworkController:handleRequest(connection, x, y, z, isMapPing)
  if not self.owner.isServer or g_currentMission == nil then
    return
  end

  local player = self:getRequestPlayer(connection)

  if player == nil or not self:getIsRequestAllowed(connection) then
    return
  end

  if not PingUtil.getIsValidWorldPosition(x, y, z) or not PingUtil.getIsInsideTerrain(x, z) then
    return
  end

  if isMapPing then
    y = getTerrainHeightAtWorldPos(g_terrainNode, x, 0, z)
  else
    local playerX, playerY, playerZ = player:getPosition()
    local distanceX = x - playerX
    local distanceY = y - playerY
    local distanceZ = z - playerZ
    local squaredDistance = distanceX * distanceX + distanceY * distanceY + distanceZ * distanceZ

    if squaredDistance > self.maxRequestDistance * self.maxRequestDistance then
      return
    end
  end

  local farmId = player.farmId or g_currentMission:getFarmId(connection)

  if farmId == nil or (FarmManager.SPECTATOR_FARM_ID ~= nil and farmId == FarmManager.SPECTATOR_FARM_ID) then
    return
  end

  local pingId = self.owner.registry:allocatePingId()

  if pingId == nil then
    return
  end

  local replacedPingId = self.owner.registry:makeRoomForPlayer(player)

  local ping = self.owner:addPing(pingId, x, y, z, farmId, player, replacedPingId)

  if ping ~= nil then
    self.owner:broadcastPingEvent(PingSystemCreateEvent.new(pingId, x, y, z, farmId, ping.ownerUserId, ping.color, replacedPingId), farmId)
  end
end

---Handles removal requests for farm pings
-- @param Connection connection Connection object
-- @param number pingId ID of the ping to remove
-- @includeCode
function PingNetworkController:handleRemoveRequest(connection, pingId)
  if not self.owner.isServer or g_currentMission == nil then
    return
  end

  local player = self:getRequestPlayer(connection)

  if player == nil or not self:getIsRequestAllowed(connection) then
    return
  end

  if pingId ~= nil then
    self.owner.registry:removeFarmPing(player, pingId, true)
  else
    self.owner.registry:removePlayerPings(player, true)
  end
end

---Gets player by connection object
-- @param Connection connection Connection object
-- @return Player Player associated with connection
-- @includeCode
function PingNetworkController:getRequestPlayer(connection)
  if connection == nil then
    return g_localPlayer
  end

  if g_currentMission == nil or g_currentMission.getPlayerByConnection == nil then
    return nil
  end

  return g_currentMission:getPlayerByConnection(connection)
end
