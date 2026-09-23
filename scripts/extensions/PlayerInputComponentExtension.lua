--
-- PlayerInputComponentExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

local modName = g_currentModName or "unknown"

---Registers global player action events
-- @param any playerInputComponent Component for player input handling
-- @param string contextName Name of the action context
-- @includeCode
local function registerGlobalPlayerActionEvents(playerInputComponent, contextName)
  if g_pingSystem ~= nil and g_modIsLoaded[modName] then
    g_pingSystem:registerGlobalPlayerActionEvents(playerInputComponent, contextName)
  end
end

---
PlayerInputComponent.registerGlobalPlayerActionEvents = Utils.appendedFunction(PlayerInputComponent.registerGlobalPlayerActionEvents, registerGlobalPlayerActionEvents)
