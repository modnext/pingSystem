--
-- FSBaseMissionExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

local modName = g_currentModName or "unknown"

---Sends initial client state to the connection
-- @param Mission mission Current mission instance
-- @param Connection connection Client connection object
-- @param nil _ Unused parameter
-- @param any farm Farm data to send
-- @includeCode
local function sendInitialClientState(mission, connection, _, farm)
  if g_pingSystem ~= nil and g_modIsLoaded[modName] and mission:getIsServer() then
    g_pingSystem:sendInitialClientState(connection, farm)
  end
end

---
FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState, sendInitialClientState)
