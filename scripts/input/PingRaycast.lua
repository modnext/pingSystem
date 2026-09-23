--
-- PingRaycast
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingRaycast = {}

PingRaycast.TARGET_MASK = CollisionFlag.STATIC_OBJECT
  + CollisionFlag.TERRAIN
  + CollisionFlag.TERRAIN_DELTA
  + CollisionFlag.TREE
  + CollisionFlag.BUILDING
  + CollisionFlag.ROAD
  + CollisionFlag.VEHICLE
  + CollisionFlag.VEHICLE_FORK
  + CollisionFlag.DYNAMIC_OBJECT
  + CollisionFlag.TRAFFIC_VEHICLE

local PingRaycast_mt = Class(PingRaycast)

---Creates a new PingRaycast instance
-- @param table customMt Custom metatable
-- @return PingRaycast New instance
-- @includeCode
function PingRaycast.new(customMt)
  local self = setmetatable({}, customMt or PingRaycast_mt)

  self.result = nil
  self.ignoredVehicle = nil
  self.maxDistance = 1000

  return self
end

---Casts a ray from a point in a direction
-- @param number originX X origin
-- @param number originY Y origin
-- @param number originZ Z origin
-- @param number directionX X direction
-- @param number directionY Y direction
-- @param number directionZ Z direction
-- @return number Hit coordinates or nil
-- @includeCode
function PingRaycast:cast(originX, originY, originZ, directionX, directionY, directionZ)
  self.result = nil
  self.ignoredVehicle = PingUtil.getLocalRootVehicle()

  raycastAll(originX, originY, originZ, directionX, directionY, directionZ, self.maxDistance, "raycastCallback", self, PingRaycast.TARGET_MASK)

  local result = self.result

  self.result = nil
  self.ignoredVehicle = nil

  if result == nil then
    return nil
  end

  return result.x, result.y, result.z
end

---Callback for raycast hits
-- @param integer hitActorId Actor ID
-- @param number x Hit X
-- @param number y Hit Y
-- @param number z Hit Z
-- @param number distance Hit distance
-- @param number normalX Normal X
-- @param number normalY Normal Y
-- @param number normalZ Normal Z
-- @param integer subShapeIndex Sub-shape index
-- @param integer hitShapeId Hit shape ID
-- @return boolean Always true
-- @includeCode
function PingRaycast:raycastCallback(hitActorId, x, y, z, distance, normalX, normalY, normalZ, subShapeIndex, hitShapeId)
  if hitActorId == nil or hitActorId == 0 or g_currentMission == nil then
    return true
  end

  local object = g_currentMission:getNodeObject(hitActorId)

  if object == nil and hitShapeId ~= nil and hitShapeId ~= 0 then
    object = g_currentMission:getNodeObject(hitShapeId)
  end

  if self:getIsIgnoredObject(object) then
    return true
  end

  if self.result == nil or distance < self.result.distance then
    self.result = {
      x = x,
      y = y,
      z = z,
      distance = distance,
    }
  end

  return true
end

---Checks if an object is ignored
-- @param Object object Object to check
-- @return boolean True if ignored
-- @includeCode
function PingRaycast:getIsIgnoredObject(object)
  if object == nil or self.ignoredVehicle == nil then
    return false
  end

  if object.getRootVehicle ~= nil then
    object = object:getRootVehicle() or object
  end

  return object == self.ignoredVehicle
end

---Gets the camera's ray direction
-- @return table Origin and direction or nil
-- @includeCode
function PingRaycast.getCameraRay()
  local cameraNode = g_cameraManager ~= nil and g_cameraManager:getActiveCamera() or nil

  if cameraNode ~= nil and cameraNode ~= 0 and entityExists(cameraNode) then
    local originX, originY, originZ = getWorldTranslation(cameraNode)
    local directionX, directionY, directionZ = localDirectionToWorld(cameraNode, 0, 0, -1)

    return originX, originY, originZ, directionX, directionY, directionZ
  end

  if g_localPlayer ~= nil and g_localPlayer.getLookRay ~= nil then
    return g_localPlayer:getLookRay()
  end

  return nil
end
