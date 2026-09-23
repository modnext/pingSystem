--
-- PingUtil
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingUtil = {}

---Get user marker label based on userId
-- @param number userId User's ID
-- @return string User marker label
-- @includeCode
function PingUtil.getUserMarkerLabel(userId)
  local userManager = g_currentMission ~= nil and g_currentMission.userManager or nil
  local user = userManager ~= nil and userManager:getUserByUserId(userId) or nil
  local nickname = user ~= nil and user:getNickname() or nil

  if string.isNilOrWhitespace(nickname) then
    return "?"
  end

  local initial = utf8Substr(utf8ToUpper(string.trim(nickname)), 0, 1)
  local userIdRank = 1
  local hasCollision = false

  for _, otherUser in ipairs(userManager:getUsers()) do
    local otherUserId = otherUser:getId()
    local otherNickname = otherUser:getNickname()

    if otherUserId ~= userId and not string.isNilOrWhitespace(otherNickname) then
      local otherInitial = utf8Substr(utf8ToUpper(string.trim(otherNickname)), 0, 1)

      if otherInitial == initial then
        hasCollision = true

        if otherUserId < userId then
          userIdRank = userIdRank + 1
        end
      end
    end
  end

  if hasCollision then
    return initial .. tostring(userIdRank)
  end

  return initial
end

---Check if local player is holding an object
-- @return boolean True if holding an object
-- @includeCode
function PingUtil.getIsLocalPlayerHoldingObject()
  if g_localPlayer == nil then
    return false
  end

  if g_localPlayer.getAreHandsHoldingObject ~= nil then
    return g_localPlayer:getAreHandsHoldingObject()
  end

  local hands = g_localPlayer.hands

  return hands ~= nil and hands.getIsHoldingItem ~= nil and hands:getIsHoldingItem()
end

---Get the local player's root vehicle
-- @return table Root vehicle or nil
-- @includeCode
function PingUtil.getLocalRootVehicle()
  if g_localPlayer == nil or g_localPlayer.getCurrentVehicle == nil then
    return nil
  end

  local vehicle = g_localPlayer:getCurrentVehicle()

  if vehicle ~= nil and vehicle.getRootVehicle ~= nil then
    return vehicle:getRootVehicle() or vehicle
  end

  return vehicle
end

---Validate world position coordinates
-- @param number x X coordinate
-- @param number y Y coordinate
-- @param number z Z coordinate
-- @return boolean True if valid position
-- @includeCode
function PingUtil.getIsValidWorldPosition(x, y, z)
  if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
    return false
  end

  if x ~= x or y ~= y or z ~= z then
    return false
  end

  return math.abs(x) < 100000 and math.abs(y) < 10000 and math.abs(z) < 100000
end

---Check if position is inside terrain bounds
-- @param number x X coordinate
-- @param number z Z coordinate
-- @return boolean True if inside terrain
-- @includeCode
function PingUtil.getIsInsideTerrain(x, z)
  if type(x) ~= "number" or type(z) ~= "number" or x ~= x or z ~= z or g_currentMission == nil then
    return false
  end

  local terrainSize = g_currentMission.terrainSize

  if terrainSize == nil or terrainSize <= 0 then
    return false
  end

  local halfTerrainSize = terrainSize * 0.5 + 1

  return math.abs(x) <= halfTerrainSize and math.abs(z) <= halfTerrainSize
end
