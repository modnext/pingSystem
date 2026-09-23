--
-- PingSystemRequestEvent
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingSystemRequestEvent = {}

local PingSystemRequestEvent_mt = Class(PingSystemRequestEvent, Event)

InitEventClass(PingSystemRequestEvent, "PingSystemRequestEvent")

---Creates a new empty PingSystemRequestEvent
-- @return PingSystemRequestEvent New event instance
-- @includeCode
function PingSystemRequestEvent.emptyNew()
  return Event.new(PingSystemRequestEvent_mt)
end

---Creates a new PingSystemRequestEvent with data
-- @param number x X position
-- @param number y Y position
-- @param number z Z position
-- @param boolean isMapPing Is map ping
-- @return PingSystemRequestEvent New event instance
-- @includeCode
function PingSystemRequestEvent.new(x, y, z, isMapPing)
  local self = PingSystemRequestEvent.emptyNew()

  self.x = x
  self.y = y
  self.z = z
  self.isMapPing = isMapPing == true

  return self
end

---Called on client side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRequestEvent:readStream(streamId, connection)
  local paramsXZ = g_currentMission.vehicleXZPosCompressionParams

  self.x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
  self.y = NetworkUtil.readCompressedWorldPosition(streamId, g_currentMission.vehicleYPosCompressionParams)
  self.z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
  self.isMapPing = streamReadBool(streamId)

  self:run(connection)
end

---Called on server side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRequestEvent:writeStream(streamId, connection)
  local paramsXZ = g_currentMission.vehicleXZPosCompressionParams

  NetworkUtil.writeCompressedWorldPosition(streamId, self.x, paramsXZ)
  NetworkUtil.writeCompressedWorldPosition(streamId, self.y, g_currentMission.vehicleYPosCompressionParams)
  NetworkUtil.writeCompressedWorldPosition(streamId, self.z, paramsXZ)
  streamWriteBool(streamId, self.isMapPing)
end

---Run event
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRequestEvent:run(connection)
  if connection:getIsServer() then
    return
  end

  if g_pingSystem ~= nil then
    g_pingSystem:handlePingRequest(connection, self.x, self.y, self.z, self.isMapPing)
  end
end

---Sends a ping request to the server or client
-- @param number x X coordinate
-- @param number y Y coordinate
-- @param number z Z coordinate
-- @param boolean isMapPing Is a map ping
-- @includeCode
function PingSystemRequestEvent.sendEvent(x, y, z, isMapPing)
  isMapPing = isMapPing == true

  if g_server ~= nil then
    if g_pingSystem ~= nil then
      g_pingSystem:handlePingRequest(nil, x, y, z, isMapPing)
    end
  elseif g_client ~= nil then
    g_client:getServerConnection():sendEvent(PingSystemRequestEvent.new(x, y, z, isMapPing))
  end
end
