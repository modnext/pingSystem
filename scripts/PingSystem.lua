--
-- PingSystem
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

local modDirectory = g_currentModDirectory or ""

source(modDirectory .. "scripts/AdditionalGuiElements.lua")
source(modDirectory .. "scripts/misc/PingUtil.lua")
source(modDirectory .. "scripts/misc/PingSettingsManager.lua")
source(modDirectory .. "scripts/events/PingSystemRequestEvent.lua")
source(modDirectory .. "scripts/events/PingSystemRemoveRequestEvent.lua")
source(modDirectory .. "scripts/events/PingSystemCreateEvent.lua")
source(modDirectory .. "scripts/events/PingSystemRemoveEvent.lua")
source(modDirectory .. "scripts/events/PingSystemSettingsEvent.lua")
source(modDirectory .. "scripts/input/PingRaycast.lua")
source(modDirectory .. "scripts/input/PingInputController.lua")
source(modDirectory .. "scripts/map/PingMapController.lua")
source(modDirectory .. "scripts/PingNetworkController.lua")
source(modDirectory .. "scripts/misc/PingRegistry.lua")
source(modDirectory .. "scripts/extensions/PlayerInputComponentExtension.lua")
source(modDirectory .. "scripts/extensions/InGameMenuSettingsFrameExtension.lua")
source(modDirectory .. "scripts/extensions/InGameMenuMapFrameExtension.lua")
source(modDirectory .. "scripts/extensions/GameSettingsExtension.lua")
source(modDirectory .. "scripts/extensions/FSBaseMissionExtension.lua")
source(modDirectory .. "scripts/map/PingHotspot.lua")
source(modDirectory .. "scripts/hud/extensions/PingInputHelpHUDExtension.lua")
source(modDirectory .. "scripts/hud/PingHudLayout.lua")
source(modDirectory .. "scripts/hud/PingHud.lua")

PingSystem = {}

PingSystem.SETTINGS = {
  DISPLAY_DURATION = "PING_DISPLAY_DURATION",
  MAX_ACTIVE_PINGS = "PING_MAX_ACTIVE_PINGS",
  FARM_VISIBILITY = "PING_FARM_VISIBILITY",
}

PingSystem.DEFAULT_DISPLAY_DURATION_STATE = 3
PingSystem.DEFAULT_MAX_ACTIVE_PINGS_STATE = 1
PingSystem.DEFAULT_FARM_VISIBILITY_STATE = 1

PingSystem.DISPLAY_DURATION_VALUES = {
  5000,
  10000,
  12000,
  15000,
  20000,
  30000,
  PingSettingsManager.CONTINUOUS_DISPLAY_DURATION,
}

PingSystem.DISPLAY_DURATION_TEXTS = {
  "5 s",
  "10 s",
  "12 s",
  "15 s",
  "20 s",
  "30 s",
  "settings_pingDuration_continuous",
}

PingSystem.MAX_ACTIVE_PINGS_VALUES = {
  1,
  2,
  3,
}

PingSystem.MAX_ACTIVE_PINGS_TEXTS = {
  "1",
  "2",
  "3",
}

PingSystem.FARM_VISIBILITY_VALUES = {
  false,
  true,
}

local PingSystem_mt = Class(PingSystem)

---Creates a new PingSystem instance
-- @return PingSystem The new PingSystem instance
-- @includeCode
function PingSystem.new()
  local self = setmetatable({}, PingSystem_mt)

  self.isClient = false
  self.isServer = false
  self.isFarmSettingsChangedSubscribed = false
  self.isUserRemovedSubscribed = false
  self.hud = nil
  self.inputHelpExtension = nil
  self.removeHoldDuration = 1000

  self.registry = PingRegistry.new(self)
  self.inputController = PingInputController.new(self)
  self.mapController = PingMapController.new(self)
  self.networkController = PingNetworkController.new(self)
  self.settings = PingSettingsManager.new(self)

  local title = self:getText("settings_pingDuration_title")
  local tooltip = self:getText("settings_pingDuration_tooltip")

  self.settings:addSetting(PingSystem.SETTINGS.DISPLAY_DURATION, title, tooltip, PingSystem.DEFAULT_DISPLAY_DURATION_STATE, self:getDisplayDurationTexts(), PingSystem.DISPLAY_DURATION_VALUES, false)

  title = self:getText("settings_pingLimit_title")
  tooltip = self:getText("settings_pingLimit_tooltip")

  self.settings:addSetting(PingSystem.SETTINGS.MAX_ACTIVE_PINGS, title, tooltip, PingSystem.DEFAULT_MAX_ACTIVE_PINGS_STATE, PingSystem.MAX_ACTIVE_PINGS_TEXTS, PingSystem.MAX_ACTIVE_PINGS_VALUES, true)

  title = self:getText("settings_pingVisibility_title")
  tooltip = self:getText("settings_pingVisibility_tooltip")

  self.settings:addSetting(PingSystem.SETTINGS.FARM_VISIBILITY, title, tooltip, PingSystem.DEFAULT_FARM_VISIBILITY_STATE, {
    self:getText("settings_pingVisibility_sameFarm"),
    self:getText("settings_pingVisibility_allFarms"),
  }, PingSystem.FARM_VISIBILITY_VALUES, true)

  return self
end

---Gets display duration texts for settings
-- @return table Array of display duration texts
-- @includeCode
function PingSystem:getDisplayDurationTexts()
  local texts = {}

  for index, text in ipairs(PingSystem.DISPLAY_DURATION_TEXTS) do
    texts[index] = self:getText(text)
  end

  return texts
end

---Registers global player action events
-- @param any playerInputComponent Input component for player actions
-- @param string contextName Context name for actions
-- @includeCode
function PingSystem:registerGlobalPlayerActionEvents(playerInputComponent, contextName)
  self.inputController:registerGlobalPlayerActionEvents(playerInputComponent, contextName)
end

---Loads the map and initializes components
-- @includeCode
function PingSystem:loadMap()
  if g_currentMission == nil then
    return
  end

  self.isClient = g_currentMission:getIsClient()
  self.isServer = g_currentMission:getIsServer()

  self.registry:reset()
  self.networkController:reset()
  self.mapController:reset()
  self.settings:loadFromXML()
  self.settings:loadFromCareerSavegame()

  if not self.isFarmSettingsChangedSubscribed then
    g_messageCenter:subscribe(MessageType.FARM_SETTINGS_CHANGED, self.onFarmSettingsChanged, self)
    self.isFarmSettingsChangedSubscribed = true
  end

  if self.isServer and not self.isUserRemovedSubscribed then
    g_messageCenter:subscribe(MessageType.USER_REMOVED, self.onUserRemoved, self)
    self.isUserRemovedSubscribed = true
  end

  if self.hud ~= nil then
    self.hud:delete()
    self.hud = nil
  end

  if self.inputHelpExtension ~= nil then
    self.inputHelpExtension:delete()
    self.inputHelpExtension = nil
  end

  if self.isClient then
    self.hud = PingHud.new(self)
    self.inputHelpExtension = PingInputHelpHUDExtension.new(self)
  end

  g_currentMission.pingSystem = self

  Logging.info("PingSystem: loaded")
end

---Cleans up resources when deleting the map
-- @includeCode
function PingSystem:deleteMap()
  if self.isFarmSettingsChangedSubscribed then
    g_messageCenter:unsubscribe(MessageType.FARM_SETTINGS_CHANGED, self)
    self.isFarmSettingsChangedSubscribed = false
  end

  if self.isUserRemovedSubscribed then
    g_messageCenter:unsubscribe(MessageType.USER_REMOVED, self)
    self.isUserRemovedSubscribed = false
  end

  self.registry:clear(false)
  self.inputController:unregisterActionEvents()

  self.settings:saveIfDirty()

  if self.hud ~= nil then
    self.hud:delete()
    self.hud = nil
  end

  if self.inputHelpExtension ~= nil then
    self.inputHelpExtension:delete()
    self.inputHelpExtension = nil
  end

  if g_currentMission ~= nil and g_currentMission.pingSystem == self then
    g_currentMission.pingSystem = nil
  end

  self.isClient = false
  self.isServer = false
  self.networkController:reset()
  self.mapController:reset()
end

---Updates the ping system state
-- @param number dt Delta time in seconds
-- @includeCode
function PingSystem:update(dt)
  if not self.isClient and not self.isServer then
    return
  end

  self.registry:update(dt)
  self.mapController:update(dt)

  if self.inputHelpExtension ~= nil and g_currentMission ~= nil and g_currentMission.hud ~= nil then
    g_currentMission.hud:addHelpExtension(self.inputHelpExtension)
  end
end

---Draws the HUD if available
-- @includeCode
function PingSystem:draw()
  if self.hud ~= nil then
    self.hud:draw()
  end
end

---Handles mouse events for the map
-- @param number posX X position of the mouse
-- @param number posY Y position of the mouse
-- @param boolean isDown Mouse button down
-- @param boolean isUp Mouse button up
-- @param integer button Mouse button index
-- @includeCode
function PingSystem:mouseEvent(posX, posY, isDown, isUp, button)
  self.mapController:mouseEvent(posX, posY, isDown, isUp, button)
end

---Handles a ping request from a connection
-- @param Connection connection Connection object
-- @param number x X coordinate
-- @param number y Y coordinate
-- @param number z Z coordinate
-- @param boolean isMapPing Is it a map ping
-- @includeCode
function PingSystem:handlePingRequest(connection, x, y, z, isMapPing)
  self.networkController:handleRequest(connection, x, y, z, isMapPing)
end

---Handles a request to remove a ping
-- @param Connection connection Connection object
-- @param integer pingId ID of the ping
-- @includeCode
function PingSystem:handleRemovePingRequest(connection, pingId)
  self.networkController:handleRemoveRequest(connection, pingId)
end

---Broadcasts a ping event to clients
-- @param PingSystemCreateEvent event The event to broadcast
-- @param integer farmId ID of the farm
-- @includeCode
function PingSystem:broadcastPingEvent(event, farmId)
  if not self.isServer or g_server == nil or g_currentMission == nil then
    return
  end

  if not self:getShowPingsFromAllFarms() then
    g_currentMission:broadcastEventToFarm(event, farmId, false)
    return
  end

  local connectionList = {}

  for streamId, connection in pairs(g_server.clientConnections) do
    local player = g_currentMission:getPlayerByConnection(connection)
    local playerFarmId = player ~= nil and player.farmId or nil

    if playerFarmId ~= nil and (FarmManager.SPECTATOR_FARM_ID == nil or playerFarmId ~= FarmManager.SPECTATOR_FARM_ID) then
      connectionList[streamId] = connection
    end
  end

  ---@diagnostic disable-next-line: redundant-parameter
  g_server:broadcastEvent(event, false, nil, nil, nil, connectionList)
end

---Broadcasts all active pings to clients
-- @includeCode
function PingSystem:broadcastActivePings()
  if not self.isServer then
    return
  end

  for _, ping in pairs(self.registry:getPings()) do
    if not ping.isPendingRemoval then
      self:broadcastPingEvent(PingSystemCreateEvent.new(ping.id, ping.x, ping.y, ping.z, ping.farmId, ping.ownerUserId, ping.color, nil, true), ping.farmId)
    end
  end
end

---Sends initial state to a client
-- @param Connection connection Client connection
-- @param Farm farm Farm object
-- @includeCode
function PingSystem:sendInitialClientState(connection, farm)
  if not self.isServer or connection == nil or farm == nil then
    return
  end

  connection:sendEvent(PingSystemSettingsEvent.new(self:getMaxActivePingsPerPlayer(), self:getShowPingsFromAllFarms()))

  local farmId = farm.farmId
  local canReceivePings = farmId ~= nil and (FarmManager.SPECTATOR_FARM_ID == nil or farmId ~= FarmManager.SPECTATOR_FARM_ID)

  for _, ping in pairs(self.registry:getPings()) do
    if canReceivePings and not ping.isPendingRemoval and (self:getShowPingsFromAllFarms() or ping.farmId == farmId) then
      connection:sendEvent(PingSystemCreateEvent.new(ping.id, ping.x, ping.y, ping.z, ping.farmId, ping.ownerUserId, ping.color, nil, true))
    end
  end
end

---Handles user removal from the system
-- @param User user User to remove
-- @includeCode
function PingSystem:onUserRemoved(user)
  if not self.isServer or user == nil or g_currentMission == nil then
    return
  end

  local connection = user:getConnection()
  local player = connection ~= nil and g_currentMission:getPlayerByConnection(connection) or nil

  if player == nil and g_currentMission.playerSystem ~= nil then
    player = g_currentMission.playerSystem:getPlayerByUserId(user:getId())
  end

  self.networkController:clearPlayerRequestState(player, connection)
  self.registry:removePlayerPings(player, true)
end

---Updates farm color on settings change
-- @param integer farmId ID of the farm
-- @includeCode
function PingSystem:onFarmSettingsChanged(farmId)
  self.registry:updateFarmColor(farmId)
end

---Adds a network ping to the system
-- @param number pingId Unique ping identifier
-- @param number x X coordinate
-- @param number y Y coordinate
-- @param number z Z coordinate
-- @param integer farmId Farm identifier
-- @param number ownerUserId Owner user ID
-- @param string color Ping color
-- @param number replacedPingId Replaced ping ID
-- @param boolean isInitialSync Initial sync flag
-- @includeCode
function PingSystem:addNetworkPing(pingId, x, y, z, farmId, ownerUserId, color, replacedPingId, isInitialSync)
  if self.isClient then
    self.registry:add(pingId, x, y, z, farmId, nil, ownerUserId, color, replacedPingId, isInitialSync)
  end
end

---Adds a ping to the system
-- @param number pingId Unique ping identifier
-- @param number x X coordinate
-- @param number y Y coordinate
-- @param number z Z coordinate
-- @param integer farmId Farm identifier
-- @param table ownerPlayer Owner player object
-- @param number replacedPingId Replaced ping ID
-- @return boolean Success of the operation
-- @includeCode
function PingSystem:addPing(pingId, x, y, z, farmId, ownerPlayer, replacedPingId)
  return self.registry:add(pingId, x, y, z, farmId, ownerPlayer, ownerPlayer ~= nil and ownerPlayer.userId or 0, self:getPingColor(farmId), replacedPingId)
end

---Removes a ping from the system
-- @param number pingId Unique ping identifier
-- @param boolean broadcast Broadcast removal
-- @includeCode
function PingSystem:removePing(pingId, broadcast)
  self.registry:remove(pingId, broadcast, broadcast == true)
end

---Removes a network ping from the system
-- @param number pingId Unique ping identifier
-- @includeCode
function PingSystem:removeNetworkPing(pingId)
  if self.isClient then
    self.registry:remove(pingId, false, true)
  end
end

---Clears all pings from the system
-- @param boolean broadcast Broadcast clear
-- @includeCode
function PingSystem:clearPings(broadcast)
  self.registry:clear(broadcast)
end

---Gets the current pings from the registry
-- @return table List of current pings
-- @includeCode
function PingSystem:getPings()
  return self.registry:getPings()
end

---Gets the duration for displaying pings
-- @return number Display duration in seconds
-- @includeCode
function PingSystem:getPingDisplayDuration()
  return self.settings:getDisplayDuration()
end

---Gets max active pings per player
-- @return integer Max active pings allowed
-- @includeCode
function PingSystem:getMaxActivePingsPerPlayer()
  return self.settings:getMaxActivePings()
end

---Checks if pings from all farms are shown
-- @return boolean True if all farms' pings are shown
-- @includeCode
function PingSystem:getShowPingsFromAllFarms()
  return self.settings:getShowPingsFromAllFarms()
end

---Updates display duration when changed
-- @includeCode
function PingSystem:onPingDisplayDurationChanged()
  self.registry:updateLocalDisplayDuration(self:getPingDisplayDuration())
end

---Enforces player limit on active pings
-- @includeCode
function PingSystem:onMaxActivePingsChanged()
  if self.isServer then
    self.registry:enforcePlayerLimit(self:getMaxActivePingsPerPlayer())
  end
end

---Updates farm visibility for pings
-- @includeCode
function PingSystem:onPingFarmVisibilityChanged()
  self.registry:updateFarmVisibility()
end

---Checks if a ping can be displayed
-- @param integer farmId ID of the farm to check
-- @return boolean True if ping can be displayed
-- @includeCode
function PingSystem:canDisplayPing(farmId)
  if not self.isClient or g_currentMission == nil then
    return false
  end

  local missionInfo = g_currentMission.missionDynamicInfo

  if missionInfo == nil or not missionInfo.isMultiplayer then
    return true
  end

  if farmId == nil or farmId == AccessHandler.EVERYONE or (FarmManager.SPECTATOR_FARM_ID ~= nil and farmId == FarmManager.SPECTATOR_FARM_ID) then
    return false
  end

  local localFarmId = g_currentMission:getFarmId()

  if localFarmId == nil or (FarmManager.SPECTATOR_FARM_ID ~= nil and localFarmId == FarmManager.SPECTATOR_FARM_ID) then
    return false
  end

  return self:getShowPingsFromAllFarms() or localFarmId == farmId
end

---Gets the color for a specific farm ping
-- @param integer farmId ID of the farm
-- @return table RGB color values for the ping
-- @includeCode
function PingSystem:getPingColor(farmId)
  local color = HUD.COLOR.ACTIVE or { 1, 1, 1 }
  local missionInfo = g_currentMission ~= nil and g_currentMission.missionDynamicInfo or nil

  if missionInfo ~= nil and missionInfo.isMultiplayer and g_farmManager ~= nil and farmId ~= nil then
    local farm = g_farmManager:getFarmById(farmId)

    if farm ~= nil then
      color = farm:getColor() or color
    end
  end

  return { color[1], color[2], color[3] }
end

---Retrieves localized text by key
-- @param string key Localization key
-- @return string Localized text or key
-- @includeCode
function PingSystem:getText(key)
  if g_i18n ~= nil and g_i18n:hasText(key) then
    return g_i18n:getText(key)
  end

  return key
end

---Shows a warning if no target is selected
-- @includeCode
function PingSystem:showNoTargetWarning()
  if g_currentMission ~= nil then
    g_currentMission:showBlinkingWarning(self:getText("warning_pingNoTarget"), 2000)
  end
end

---
g_pingSystem = PingSystem.new()
addModEventListener(g_pingSystem)
