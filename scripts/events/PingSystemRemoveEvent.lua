--
-- PingSystemRemoveEvent
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingSystemRemoveEvent = {}

local PingSystemRemoveEvent_mt = Class(PingSystemRemoveEvent, Event)

InitEventClass(PingSystemRemoveEvent, "PingSystemRemoveEvent")

---Creates a new empty PingSystemRemoveEvent
-- @return PingSystemRemoveEvent New event instance
-- @includeCode
function PingSystemRemoveEvent.emptyNew()
  return Event.new(PingSystemRemoveEvent_mt)
end

---Creates a new PingSystemRemoveEvent with pingId
-- @param integer pingId ID of the ping
-- @return PingSystemRemoveEvent New event instance
-- @includeCode
function PingSystemRemoveEvent.new(pingId)
  local self = PingSystemRemoveEvent.emptyNew()

  self.pingId = pingId

  return self
end

---Called on client side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRemoveEvent:readStream(streamId, connection)
  self.pingId = streamReadUInt16(streamId)

  self:run(connection)
end

---Called on server side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRemoveEvent:writeStream(streamId, connection)
  streamWriteUInt16(streamId, self.pingId)
end

---Run event
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRemoveEvent:run(connection)
  if not connection:getIsServer() then
    return
  end

  if g_pingSystem ~= nil then
    g_pingSystem:removeNetworkPing(self.pingId)
  end
end
