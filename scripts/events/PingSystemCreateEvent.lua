--
-- PingSystemCreateEvent
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingSystemCreateEvent = {}

local PingSystemCreateEvent_mt = Class(PingSystemCreateEvent, Event)

InitEventClass(PingSystemCreateEvent, "PingSystemCreateEvent")

---Creates a new empty PingSystemCreateEvent
-- @return PingSystemCreateEvent New event instance
-- @includeCode
function PingSystemCreateEvent.emptyNew()
  return Event.new(PingSystemCreateEvent_mt)
end

---Creates a new PingSystemCreateEvent with data
-- @param integer pingId Unique ping identifier
-- @param number x X coordinate
-- @param number y Y coordinate
-- @param number z Z coordinate
-- @param integer farmId Farm identifier
-- @param integer ownerUserId Owner user ID
-- @param table color Color table
-- @param integer replacedPingId Replaced ping ID
-- @param boolean isInitialSync Initial sync flag
-- @return PingSystemCreateEvent New event instance
-- @includeCode
function PingSystemCreateEvent.new(pingId, x, y, z, farmId, ownerUserId, color, replacedPingId, isInitialSync)
  local self = PingSystemCreateEvent.emptyNew()

  self.pingId = pingId
  self.x = x
  self.y = y
  self.z = z
  self.farmId = farmId
  self.ownerUserId = ownerUserId or 0
  self.color = color
  self.replacedPingId = replacedPingId
  self.isInitialSync = isInitialSync == true

  return self
end

---Called on client side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemCreateEvent:readStream(streamId, connection)
  local paramsXZ = g_currentMission.vehicleXZPosCompressionParams

  self.pingId = streamReadUInt16(streamId)
  self.x = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
  self.y = NetworkUtil.readCompressedWorldPosition(streamId, g_currentMission.vehicleYPosCompressionParams)
  self.z = NetworkUtil.readCompressedWorldPosition(streamId, paramsXZ)
  self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
  self.ownerUserId = User.streamReadUserId(streamId)
  self.color = { NetworkUtil.readCompressedColor(streamId) }
  self.replacedPingId = streamReadUInt16(streamId)
  self.isInitialSync = streamReadBool(streamId)

  if self.replacedPingId == 0 then
    self.replacedPingId = nil
  end

  self:run(connection)
end

---Called on server side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemCreateEvent:writeStream(streamId, connection)
  local paramsXZ = g_currentMission.vehicleXZPosCompressionParams

  streamWriteUInt16(streamId, self.pingId)
  NetworkUtil.writeCompressedWorldPosition(streamId, self.x, paramsXZ)
  NetworkUtil.writeCompressedWorldPosition(streamId, self.y, g_currentMission.vehicleYPosCompressionParams)
  NetworkUtil.writeCompressedWorldPosition(streamId, self.z, paramsXZ)
  streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)
  User.streamWriteUserId(streamId, self.ownerUserId)
  NetworkUtil.writeCompressedColor(streamId, self.color[1], self.color[2], self.color[3])
  streamWriteUInt16(streamId, self.replacedPingId or 0)
  streamWriteBool(streamId, self.isInitialSync)
end

---Run event
-- @param Connection connection Connection object
-- @includeCode
function PingSystemCreateEvent:run(connection)
  if not connection:getIsServer() then
    return
  end

  if g_pingSystem ~= nil then
    g_pingSystem:addNetworkPing(self.pingId, self.x, self.y, self.z, self.farmId, self.ownerUserId, self.color, self.replacedPingId, self.isInitialSync)
  end
end
