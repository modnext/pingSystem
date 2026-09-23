--
-- PingInputHelpHUDExtension
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingInputHelpHUDExtension = {}

local PingInputHelpHUDExtension_mt = Class(PingInputHelpHUDExtension)

---Creates a new PingInputHelpHUDExtension instance
-- @param any owner Owner of the extension
-- @param table customMt Custom metatable
-- @return PingInputHelpHUDExtension New instance of the extension
-- @includeCode
function PingInputHelpHUDExtension.new(owner, customMt)
  local self = setmetatable({}, customMt or PingInputHelpHUDExtension_mt)

  self.owner = owner
  self.priority = GS_PRIO_NORMAL

  local r, g, b, a = unpack(HUD.COLOR.BACKGROUND)

  self.background = g_overlayManager:createOverlay("gui.shortcutBox2", 0, 0, 0, 0)
  self.background:setColor(r, g, b, a)

  self.separatorHorizontal = g_overlayManager:createOverlay(g_plainColorSliceId, 0, 0, 0, 0)
  self.separatorHorizontal:setColor(1, 1, 1, 0.25)

  self.createText = owner:getText("action_createPing")
  self.removeText = owner:getText("action_removePing")
  self.holdText = utf8ToUpper(g_i18n:getText("input_holdButton"))
  self.actionElement = nil

  self:storeScaledValues()

  g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.UI_SCALE], self.storeScaledValues, self)

  return self
end

---Deletes the PingInputHelpHUDExtension instance
-- @includeCode
function PingInputHelpHUDExtension:delete()
  self.background:delete()
  self.separatorHorizontal:delete()
  g_messageCenter:unsubscribeAll(self)

  self.owner = nil
  self.actionElement = nil
end

---Stores scaled UI values for the extension
-- @includeCode
function PingInputHelpHUDExtension:storeScaledValues()
  local uiScale = g_gameSettings:getValue(GameSettings.SETTING.UI_SCALE)
  local width, height = getNormalizedScreenValues(330 * uiScale, 50 * uiScale)

  self.background:setDimension(width, height)
  self.separatorHorizontal:setDimension(width, g_pixelSizeY)

  _, self.inputHeight = getNormalizedScreenValues(0, 25 * uiScale)
  self.holdIconButtonOffset = getNormalizedScreenValues(5 * uiScale, 0)
end

---Sets event help elements for input display
-- @param any inputHelpDisplay Input help display
-- @param table eventHelpElements List of event help elements
-- @includeCode
function PingInputHelpHUDExtension:setEventHelpElements(inputHelpDisplay, eventHelpElements)
  local inputAction = InputAction.PING_SYSTEM_CREATE

  self.actionElement = nil

  if inputAction == nil then
    return
  end

  inputHelpDisplay:addSkipAction(inputAction)

  if not self.owner.inputController:getCanUsePingAction() then
    return
  end

  if eventHelpElements ~= nil then
    for _, helpElement in ipairs(eventHelpElements) do
      if helpElement.actionName == inputAction then
        self.actionElement = helpElement
        break
      end
    end
  end
end

---Draws the input help HUD elements
-- @param any inputHelpDisplay Input help display
-- @param number posX X position to draw
-- @param number posY Y position to draw
-- @return number Updated Y position after drawing
-- @includeCode
function PingInputHelpHUDExtension:draw(inputHelpDisplay, posX, posY)
  local actionElement = self.actionElement

  if actionElement == nil then
    return posY
  end

  posY = posY - self.background.height

  self.background:setPosition(posX, posY)
  self.background:render()

  local textOffsetX = inputHelpDisplay.textOffsetX
  local textOffsetY = inputHelpDisplay.textOffsetY
  local textSize = inputHelpDisplay.textSize
  local textX = posX + textOffsetX
  local rightX = posX + self.background.width
  local createY = posY + self.inputHeight
  local createInputWidth = inputHelpDisplay:drawInput(rightX, createY, self.inputHeight, actionElement)
  local removeInputWidth = inputHelpDisplay:drawInput(rightX, posY, self.inputHeight, actionElement, self.holdIconButtonOffset, self.holdText)

  setTextBold(true)
  setTextAlignment(RenderText.ALIGN_LEFT)
  setTextColor(1, 1, 1, 1)

  local createText = Utils.limitTextToWidth(utf8ToUpper(self.createText), textSize, math.max(0, self.background.width - createInputWidth - 2 * textOffsetX), false, "...")
  local removeText = Utils.limitTextToWidth(utf8ToUpper(self.removeText), textSize, math.max(0, self.background.width - removeInputWidth - 2 * textOffsetX), false, "...")

  renderText(textX, createY + textOffsetY, textSize, createText)
  renderText(textX, posY + textOffsetY, textSize, removeText)

  setTextBold(false)

  self.separatorHorizontal:renderCustom(posX, posY + self.inputHeight)

  return posY
end

---Gets the height of the HUD element
-- @return number Height of the HUD
-- @includeCode
function PingInputHelpHUDExtension:getHeight()
  return self.actionElement == nil and 0 or self.background.height
end
