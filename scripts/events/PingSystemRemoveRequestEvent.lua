--
-- PingSystemRemoveRequestEvent
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingSystemRemoveRequestEvent = {}

local PingSystemRemoveRequestEvent_mt = Class(PingSystemRemoveRequestEvent, Event)

InitEventClass(PingSystemRemoveRequestEvent, "PingSystemRemoveRequestEvent")

---Creates a new empty PingSystemRemoveRequestEvent
-- @return PingSystemRemoveRequestEvent New event instance
-- @includeCode
function PingSystemRemoveRequestEvent.emptyNew()
  return Event.new(PingSystemRemoveRequestEvent_mt)
end

---Creates a new PingSystemRemoveRequestEvent with pingId
-- @param number pingId ID of the ping
-- @return PingSystemRemoveRequestEvent New event instance
-- @includeCode
function PingSystemRemoveRequestEvent.new(pingId)
  local self = PingSystemRemoveRequestEvent.emptyNew()

  self.pingId = pingId

  return self
end

---Called on client side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRemoveRequestEvent:readStream(streamId, connection)
  if streamReadBool(streamId) then
    self.pingId = streamReadUInt16(streamId)
  end

  self:run(connection)
end

---Called on server side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRemoveRequestEvent:writeStream(streamId, connection)
  if streamWriteBool(streamId, self.pingId ~= nil) then
    streamWriteUInt16(streamId, self.pingId)
  end
end

---Run event
-- @param Connection connection Connection object
-- @includeCode
function PingSystemRemoveRequestEvent:run(connection)
  if connection:getIsServer() then
    return
  end

  if g_pingSystem ~= nil then
    g_pingSystem:handleRemovePingRequest(connection, self.pingId)
  end
end

---Sends a ping removal request to the server
-- @param number pingId ID of the ping to remove
-- @includeCode
function PingSystemRemoveRequestEvent.sendEvent(pingId)
  if g_server ~= nil then
    if g_pingSystem ~= nil then
      g_pingSystem:handleRemovePingRequest(nil, pingId)
    end
  elseif g_client ~= nil then
    g_client:getServerConnection():sendEvent(PingSystemRemoveRequestEvent.new(pingId))
  end
end
