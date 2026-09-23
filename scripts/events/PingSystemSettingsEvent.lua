--
-- PingSystemSettingsEvent
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingSystemSettingsEvent = {}

local PingSystemSettingsEvent_mt = Class(PingSystemSettingsEvent, Event)

InitEventClass(PingSystemSettingsEvent, "PingSystemSettingsEvent")

---Creates a new empty PingSystemSettingsEvent
-- @return PingSystemSettingsEvent New event instance
-- @includeCode
function PingSystemSettingsEvent.emptyNew()
  return Event.new(PingSystemSettingsEvent_mt)
end

---Creates a new PingSystemSettingsEvent with settings
-- @param integer maxActivePings Max active pings
-- @param boolean showAllFarms Show all farms
-- @return PingSystemSettingsEvent New event instance
-- @includeCode
function PingSystemSettingsEvent.new(maxActivePings, showAllFarms)
  local self = PingSystemSettingsEvent.emptyNew()

  self.maxActivePings = PingSettingsManager.normalizeMaxActivePings(maxActivePings)
  self.showAllFarms = showAllFarms == true

  return self
end

---Called on client side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemSettingsEvent:readStream(streamId, connection)
  self.maxActivePings = streamReadUIntN(streamId, PingSettingsManager.NUM_MAX_ACTIVE_PINGS_BITS) + 1
  self.showAllFarms = streamReadBool(streamId)

  self:run(connection)
end

---Called on server side when the object is synced to the client
-- @param integer streamId stream ID
-- @param Connection connection Connection object
-- @includeCode
function PingSystemSettingsEvent:writeStream(streamId, connection)
  streamWriteUIntN(streamId, self.maxActivePings - 1, PingSettingsManager.NUM_MAX_ACTIVE_PINGS_BITS)
  streamWriteBool(streamId, self.showAllFarms)
end

---Run event
-- @param Connection connection Connection object
-- @includeCode
function PingSystemSettingsEvent:run(connection)
  if g_pingSystem == nil or not connection:getIsServer() then
    return
  end

  g_pingSystem.settings:setMaxActivePings(self.maxActivePings)
  g_pingSystem.settings:setShowPingsFromAllFarms(self.showAllFarms)
end

---Sends updated ping system settings to clients
-- @param string name Setting name
-- @param any value Setting value
-- @includeCode
function PingSystemSettingsEvent.sendEvent(name, value)
  if g_server ~= nil and g_pingSystem ~= nil then
    local wasShowingAllFarms = g_pingSystem:getShowPingsFromAllFarms()

    if not g_pingSystem.settings:applyServerGameSetting(name, value) then
      return
    end

    local showAllFarms = g_pingSystem:getShowPingsFromAllFarms()

    g_server:broadcastEvent(PingSystemSettingsEvent.new(g_pingSystem:getMaxActivePingsPerPlayer(), showAllFarms), false)

    if showAllFarms and not wasShowingAllFarms then
      g_pingSystem:broadcastActivePings()
    end
  end
end
