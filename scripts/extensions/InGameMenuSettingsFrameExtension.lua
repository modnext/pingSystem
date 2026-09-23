--
-- InGameMenuSettingsFrameExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

local modName = g_currentModName or "unknown"

---Handles opening of the settings frame
-- @param table settingsFrame Frame to open
-- @includeCode
local function onFrameOpen(settingsFrame)
  if g_pingSystem ~= nil and g_modIsLoaded[modName] then
    g_pingSystem.settings:onFrameOpen(settingsFrame)
  end
end

---
InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, onFrameOpen)
