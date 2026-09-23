--
-- PingSettingsManager
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

local settingsDirectory = g_currentModSettingsDirectory or ""

PingSettingsManager = {}

PingSettingsManager.NUM_MAX_ACTIVE_PINGS_BITS = 2
PingSettingsManager.CONTINUOUS_DISPLAY_DURATION = -1

local PingSettingsManager_mt = Class(PingSettingsManager)

---Creates a new PingSettingsManager instance
-- @param any owner Owner of the manager
-- @param table customMt Custom metatable
-- @return PingSettingsManager New instance
-- @includeCode
function PingSettingsManager.new(owner, customMt)
  local self = setmetatable({}, customMt or PingSettingsManager_mt)

  self.owner = owner
  self.title = owner:getText("settings_pingSystem_title")
  self.settings = {}
  self.localSettings = {}
  self.gameSettings = {}
  self.settingsByName = {}
  self.localSettingsCreated = false
  self.gameSettingsCreated = false
  self.settingsFrame = nil
  self.settingsSavePath = settingsDirectory .. "settings.xml"
  self.isLoaded = false
  self.isDirty = false

  return self
end

---Adds a new setting to the manager
-- @param string name Setting name
-- @param string title Setting title
-- @param string toolTip Tooltip for setting
-- @param any defaultValue Default value
-- @param table options Options for setting
-- @param table values Values for setting
-- @param boolean isGameSetting Is a game setting
-- @includeCode
function PingSettingsManager:addSetting(name, title, toolTip, defaultValue, options, values, isGameSetting)
  if name == nil or name == "" then
    Logging.error("PingSettingsManager: could not add setting without a name")
    return
  end

  local normalizedName = name:upper()
  local setting = {
    name = normalizedName,
    type = 1,
    title = title,
    toolTip = toolTip,
    defaultValue = defaultValue,
    value = defaultValue,
    options = options,
    values = values,
    isGameSetting = isGameSetting == true,
    parent = nil,
    element = nil,
  }

  table.insert(self.settings, setting)

  if setting.isGameSetting then
    table.insert(self.gameSettings, setting)
  else
    table.insert(self.localSettings, setting)
  end

  self.settingsByName[normalizedName] = setting
end

---Loads settings from an XML file
-- @includeCode
function PingSettingsManager:loadFromXML()
  if self.isLoaded then
    return
  end

  self.isLoaded = true

  if not self.owner.isClient then
    return
  end

  if settingsDirectory ~= "" then
    createFolder(settingsDirectory)
  end

  local xmlFile = XMLFile.loadIfExists("PingSystemSettingsXML", self.settingsSavePath, PingSettingsManager.xmlSchema)

  if xmlFile == nil then
    return
  end

  xmlFile:iterate("settings.setting", function(_, settingKey)
    local name = xmlFile:getString(settingKey .. "#name")
    local value = xmlFile:getInt(settingKey .. "#integer")

    local setting = name ~= nil and self.settingsByName[name:upper()] or nil

    if setting ~= nil and not setting.isGameSetting and value ~= nil then
      self:setSetting(name, value, false)
    end
  end)

  xmlFile:delete()
end

---Used to save object attributes to the savegame xml file
-- @includeCode
function PingSettingsManager:saveToXMLFile()
  if not self.owner.isClient then
    return
  end

  local xmlFile = XMLFile.create("PingSystemSettingsXML", self.settingsSavePath, "settings", PingSettingsManager.xmlSchema)

  if xmlFile == nil then
    Logging.warning("PingSettingsManager: failed to create settings file at '%s'", self.settingsSavePath)
    return
  end

  for index, setting in ipairs(self.localSettings) do
    local settingKey = ("settings.setting(%d)"):format(index - 1)

    xmlFile:setString(settingKey .. "#name", setting.name)
    xmlFile:setInt(settingKey .. "#integer", setting.value)
  end

  if xmlFile:save(false, false) then
    self.isDirty = false
  end

  xmlFile:delete()
end

---Saves settings if they are dirty
-- @includeCode
function PingSettingsManager:saveIfDirty()
  if self.isDirty then
    self:saveToXMLFile()
  end
end

---Sets a specified setting value
-- @param string name Setting name
-- @param number value New value
-- @param boolean markDirty Mark as dirty
-- @return boolean Success status
-- @includeCode
function PingSettingsManager:setSetting(name, value, markDirty)
  local normalizedName = name ~= nil and name:upper() or ""
  local setting = self.settingsByName[normalizedName]

  if setting == nil then
    Logging.warning("PingSettingsManager: invalid setting name '%s'", tostring(name))
    return false
  end

  local normalizedValue = math.floor(tonumber(value) or setting.defaultValue)

  normalizedValue = math.max(1, math.min(#setting.values, normalizedValue))

  if setting.value == normalizedValue then
    return false
  end

  setting.value = normalizedValue

  if markDirty ~= false and not setting.isGameSetting then
    self.isDirty = true
  end

  if self.owner ~= nil then
    if normalizedName == PingSystem.SETTINGS.DISPLAY_DURATION then
      self.owner:onPingDisplayDurationChanged()
    elseif normalizedName == PingSystem.SETTINGS.MAX_ACTIVE_PINGS and self.owner.isServer then
      self.owner:onMaxActivePingsChanged()
    elseif normalizedName == PingSystem.SETTINGS.FARM_VISIBILITY then
      self.owner:onPingFarmVisibilityChanged()
    end
  end

  return true
end

---Gets the value of a setting
-- @param string name Setting name
-- @return number Current setting value
-- @includeCode
function PingSettingsManager:getSetting(name)
  local normalizedName = name ~= nil and name:upper() or ""
  local setting = self.settingsByName[normalizedName]

  return setting ~= nil and setting.value or nil
end

---Gets the display duration setting
-- @return number Display duration value
-- @includeCode
function PingSettingsManager:getDisplayDuration()
  local setting = self.settingsByName[PingSystem.SETTINGS.DISPLAY_DURATION]

  if setting == nil then
    return PingSystem.DISPLAY_DURATION_VALUES[PingSystem.DEFAULT_DISPLAY_DURATION_STATE]
  end

  return setting.values[setting.value] or setting.values[setting.defaultValue]
end

---Gets the max active pings setting
-- @return number Max active pings
-- @includeCode
function PingSettingsManager:getMaxActivePings()
  local setting = self.settingsByName[PingSystem.SETTINGS.MAX_ACTIVE_PINGS]

  if setting == nil then
    return PingSystem.MAX_ACTIVE_PINGS_VALUES[PingSystem.DEFAULT_MAX_ACTIVE_PINGS_STATE]
  end

  return setting.values[setting.value] or setting.values[setting.defaultValue]
end

---Checks if pings from all farms are shown
-- @return boolean Show pings status
-- @includeCode
function PingSettingsManager:getShowPingsFromAllFarms()
  local setting = self.settingsByName[PingSystem.SETTINGS.FARM_VISIBILITY]

  if setting == nil then
    return PingSystem.FARM_VISIBILITY_VALUES[PingSystem.DEFAULT_FARM_VISIBILITY_STATE]
  end

  return setting.values[setting.value] == true
end

---Normalizes the max active pings value
-- @param number value Input value to normalize
-- @return number Normalized max active pings
-- @includeCode
function PingSettingsManager.normalizeMaxActivePings(value)
  local values = PingSystem.MAX_ACTIVE_PINGS_VALUES
  local defaultValue = values[PingSystem.DEFAULT_MAX_ACTIVE_PINGS_STATE]

  return math.max(values[1], math.min(values[#values], math.floor(tonumber(value) or defaultValue)))
end

---Sets the maximum active pings
-- @param number maxActivePings Max active pings to set
-- @return boolean Success of the operation
-- @includeCode
function PingSettingsManager:setMaxActivePings(maxActivePings)
  local normalizedValue = PingSettingsManager.normalizeMaxActivePings(maxActivePings)

  return self:setSetting(PingSystem.SETTINGS.MAX_ACTIVE_PINGS, normalizedValue, false)
end

---Sets visibility of pings from all farms
-- @param boolean showAll Show all farms or not
-- @return boolean Success of the operation
-- @includeCode
function PingSettingsManager:setShowPingsFromAllFarms(showAll)
  return self:setSetting(PingSystem.SETTINGS.FARM_VISIBILITY, showAll == true and 2 or 1, false)
end

---Applies server game settings based on name
-- @param string name Setting name
-- @param any value Value to set
-- @return boolean Success of the operation
-- @includeCode
function PingSettingsManager:applyServerGameSetting(name, value)
  if not self.owner.isServer then
    return false
  end

  local normalizedName = name ~= nil and name:upper() or ""

  if normalizedName == PingSystem.SETTINGS.MAX_ACTIVE_PINGS then
    return self:setMaxActivePings(value)
  elseif normalizedName == PingSystem.SETTINGS.FARM_VISIBILITY then
    return self:setShowPingsFromAllFarms(value)
  end

  return false
end

---Loads settings from career savegame
-- @includeCode
function PingSettingsManager:loadFromCareerSavegame()
  local defaultValue = PingSystem.MAX_ACTIVE_PINGS_VALUES[PingSystem.DEFAULT_MAX_ACTIVE_PINGS_STATE]

  self:setMaxActivePings(defaultValue)
  self:setShowPingsFromAllFarms(false)

  if not self.owner.isServer or g_currentMission == nil or g_currentMission.missionInfo.savegameDirectory == nil then
    return
  end

  local xmlFile = XMLFile.loadIfExists("PingSystemCareerSavegameXML", g_currentMission.missionInfo.savegameDirectory .. "/careerSavegame.xml")

  if xmlFile ~= nil then
    self:setMaxActivePings(xmlFile:getInt("careerSavegame.settings.pingSystemMaxActivePings", defaultValue))
    self:setShowPingsFromAllFarms(xmlFile:getBool("careerSavegame.settings.pingSystemShowAllFarms", false))
    xmlFile:delete()
  end
end

---Saves ping settings to the career savegame
-- @param any missionInfo Current mission information
-- @includeCode
function PingSettingsManager:saveToCareerSavegame(missionInfo)
  if not self.owner.isServer or g_currentMission == nil or missionInfo ~= g_currentMission.missionInfo or missionInfo.xmlFile == nil or missionInfo.xmlFile == 0 then
    return
  end

  setXMLInt(missionInfo.xmlFile, "careerSavegame.settings.pingSystemMaxActivePings", self:getMaxActivePings())
  setXMLBool(missionInfo.xmlFile, "careerSavegame.settings.pingSystemShowAllFarms", self:getShowPingsFromAllFarms())
end

---Adds settings to the layout for display
-- @param any frame Frame to add settings to
-- @param any layout Layout for the settings
-- @param any templateElement Template for new elements
-- @param table settings List of settings to add
-- @param string headerId ID for the settings header
-- @return boolean True if settings added successfully
-- @includeCode
function PingSettingsManager:addSettingsToLayout(frame, layout, templateElement, settings, headerId)
  if frame == nil or layout == nil or templateElement == nil or templateElement.parent == nil then
    return false
  end

  for _, element in ipairs(layout.elements) do
    if element:isa(TextElement) then
      local header = element:clone(layout)

      header.id = headerId
      header:setText(self.title)
      break
    end
  end

  for _, setting in ipairs(settings) do
    setting.parent = templateElement.parent:clone(layout, false)

    if setting.parent == nil or setting.parent.elements[1] == nil then
      return false
    end

    setting.parent.id = setting.name .. "Box"
    setting.element = setting.parent.elements[1]
    setting.element.id = setting.name
    setting.element:setTexts(setting.options)

    local currentSetting = setting

    setting.element.onClickCallback = function(_, ...)
      self:onSettingChangedMultibox(currentSetting, ...)
    end

    setting.element:setState(setting.value)
    setting.element:setDisabled(false)

    if setting.parent.elements[2] ~= nil then
      setting.parent.elements[2]:setText(setting.title)
    end

    if setting.element.elements[1] ~= nil then
      setting.element.elements[1]:setText(setting.toolTip)
    end

    if setting.parent.reloadFocusHandling ~= nil then
      setting.parent:reloadFocusHandling(true)
    end
  end

  frame:updateAlternatingElements(layout)

  return true
end

---Handles changes in multibox settings
-- @param any setting Setting that was changed
-- @param any state New state of the setting
-- @includeCode
function PingSettingsManager:onSettingChangedMultibox(setting, state)
  if setting == nil then
    return
  end

  if setting.isGameSetting then
    local value = setting.values[state]

    if value == nil then
      value = setting.values[setting.defaultValue]
    end

    PingSystemSettingsEvent.sendEvent(setting.name, value)
  else
    self:setSetting(setting.name, state, true)
  end
end

---Opens the settings frame and initializes settings
-- @param any frame Frame to open
-- @includeCode
function PingSettingsManager:onFrameOpen(frame)
  if not self.owner.isClient then
    return
  end

  self.title = self.owner:getText("settings_pingSystem_title")

  if self.settingsFrame ~= frame then
    self.settingsFrame = frame
    self.localSettingsCreated = false
    self.gameSettingsCreated = false

    for _, setting in ipairs(self.settings) do
      setting.parent = nil
      setting.element = nil
    end
  end

  if not self.localSettingsCreated then
    self.localSettingsCreated = self:addSettingsToLayout(frame, frame.generalSettingsLayout, frame.multiMasterVolume, self.localSettings, "pingSystemGeneralSettingsHeader")
  end

  if self.owner.isServer and not self.gameSettingsCreated then
    self.gameSettingsCreated = self:addSettingsToLayout(frame, frame.gameSettingsLayout, frame.multiDirt, self.gameSettings, "pingSystemGameSettingsHeader")
  end

  for _, setting in ipairs(self.settings) do
    if setting.element ~= nil then
      setting.element:setDisabled(false)
      setting.element:setState(setting.value)
    end
  end
end

g_xmlManager:addCreateSchemaFunction(function()
  PingSettingsManager.xmlSchema = XMLSchema.new("pingSystemSettings")
end)

g_xmlManager:addInitSchemaFunction(function()
  local schema = PingSettingsManager.xmlSchema

  schema:register(XMLValueType.STRING, "settings.setting(?)#name", "Name of the ping setting", nil, true)
  schema:register(XMLValueType.INT, "settings.setting(?)#integer", "Selected ping setting state")
end)
