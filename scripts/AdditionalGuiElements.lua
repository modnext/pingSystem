--
-- AdditionalGuiElements
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

local modDirectory = g_currentModDirectory or ""

if g_gui ~= nil and g_overlayManager ~= nil then
  g_overlayManager:addTextureConfigFile(modDirectory .. "menu/guiElements.xml", "guiElementsPingSystem")
end
