--
-- GameSettingsExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

local modName = g_currentModName or "unknown"

---Saves local settings to XML if dirty
-- @includeCode
local function saveLocalSettingsToXMLFile()
  if g_pingSystem ~= nil and g_modIsLoaded[modName] then
    g_pingSystem.settings:saveIfDirty()
  end
end

---Saves career settings to XML using mission info
-- @param table missionInfo Information about the mission
-- @includeCode
local function saveCareerSettingsToXMLFile(missionInfo)
  if g_pingSystem ~= nil and g_modIsLoaded[modName] then
    g_pingSystem.settings:saveToCareerSavegame(missionInfo)
  end
end

---
GameSettings.saveToXMLFile = Utils.appendedFunction(GameSettings.saveToXMLFile, saveLocalSettingsToXMLFile)
FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, saveCareerSettingsToXMLFile)
