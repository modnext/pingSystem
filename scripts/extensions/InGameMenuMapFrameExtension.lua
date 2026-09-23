--
-- InGameMenuMapFrameExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

local modName = g_currentModName or "unknown"

---Updates visibility of ping input glyphs
-- @param table mapFrame Map frame object
-- @includeCode
local function updatePingInputGlyph(mapFrame)
  if mapFrame.pingSystemMapGlyph == nil or mapFrame.pingSystemMapGlyphText == nil or mapFrame.buttonBox == nil then
    return
  end

  local isVisible = g_inputBinding ~= nil and g_inputBinding:getInputHelpMode() == GS_INPUT_HELP_MODE_KEYBOARD and InputAction.PING_SYSTEM_CREATE ~= nil

  mapFrame.pingSystemMapGlyph:setVisible(isVisible)
  mapFrame.pingSystemMapGlyphText:setVisible(isVisible)

  if isVisible then
    mapFrame.pingSystemMapGlyph:setActions({ InputAction.PING_SYSTEM_CREATE }, nil, nil, true)
  end

  mapFrame.buttonBox:invalidateLayout()
end

---Initializes ping system glyphs on frame open
-- @param table mapFrame Map frame object
-- @includeCode
local function onFrameOpen(mapFrame)
  if g_pingSystem == nil or not g_modIsLoaded[modName] or mapFrame.buttonBox == nil or mapFrame.mapMoveGlyph == nil or mapFrame.mapMoveGlyphText == nil then
    return
  end

  if mapFrame.pingSystemMapGlyph == nil then
    mapFrame.pingSystemMapGlyphText = mapFrame.mapMoveGlyphText:clone(mapFrame.buttonBox)
    mapFrame.pingSystemMapGlyphText.name = "pingSystemMapGlyphText"
    mapFrame.pingSystemMapGlyphText:setText(g_pingSystem:getText("input_PING_SYSTEM_CREATE"))

    mapFrame.pingSystemMapGlyph = mapFrame.mapMoveGlyph:clone(mapFrame.buttonBox)
    mapFrame.pingSystemMapGlyph.name = "pingSystemMapGlyph"
  end

  updatePingInputGlyph(mapFrame)
end

---
InGameMenuMapFrame.onFrameOpen = Utils.appendedFunction(InGameMenuMapFrame.onFrameOpen, onFrameOpen)
InGameMenuMapFrame.updateInputGlyphs = Utils.appendedFunction(InGameMenuMapFrame.updateInputGlyphs, updatePingInputGlyph)
