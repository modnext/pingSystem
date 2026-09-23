--
-- PingInputController
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingInputController = {}

local PingInputController_mt = Class(PingInputController)

---Creates a new PingInputController instance
-- @param any owner Owner of the controller
-- @param table customMt Custom metatable
-- @return PingInputController New instance of PingInputController
-- @includeCode
function PingInputController.new(owner, customMt)
  local self = setmetatable({}, customMt or PingInputController_mt)

  self.owner = owner
  self.raycast = PingRaycast.new()
  self.actionEventIds = {}
  self.removeHoldStartTime = 0
  self.targetMinDot = math.cos(math.rad(1.5))

  return self
end

---Registers global action events for player input
-- @param any playerInputComponent Player input component
-- @param string contextName Context name for actions
-- @includeCode
function PingInputController:registerGlobalPlayerActionEvents(playerInputComponent, contextName)
  local inputBinding = g_inputBinding

  if playerInputComponent == nil or playerInputComponent.player == nil or not playerInputComponent.player.isOwner or inputBinding == nil then
    return
  end

  local currentContextName = inputBinding:getContextName()
  local targetContextName = contextName or currentContextName

  if currentContextName ~= targetContextName then
    inputBinding:beginActionEventsModification(targetContextName)
  end

  self:registerGlobalActionEvents(inputBinding)

  if currentContextName ~= targetContextName then
    inputBinding:beginActionEventsModification(currentContextName)
  end
end

---Registers global action events with input binding
-- @param any inputBinding Input binding object
-- @includeCode
function PingInputController:registerGlobalActionEvents(inputBinding)
  if inputBinding == nil or InputAction.PING_SYSTEM_CREATE == nil then
    return
  end

  local _, actionEventId = inputBinding:registerActionEvent(InputAction.PING_SYSTEM_CREATE, self, self.onPingAction, true, true, true, true)

  if actionEventId ~= nil and actionEventId ~= "" then
    table.insert(self.actionEventIds, actionEventId)
    inputBinding:setActionEventTextVisibility(actionEventId, true)
    inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
  end
end

---Unregisters action events from input binding
-- @includeCode
function PingInputController:unregisterActionEvents()
  local inputBinding = g_inputBinding

  if inputBinding ~= nil then
    inputBinding:removeActionEventsByTarget(self)
  end

  self.actionEventIds = {}
  self.removeHoldStartTime = 0
end

---Checks if ping action can be used
-- @return boolean True if ping can be used
-- @includeCode
function PingInputController:getCanUsePingAction()
  return self.owner.isClient and g_currentMission ~= nil and g_localPlayer ~= nil and not PingUtil.getIsLocalPlayerHoldingObject() and (g_gui == nil or not g_gui:getIsGuiVisible()) and g_currentMission.radialMenuIsOpen ~= true
end

---Handles ping action input from user
-- @param string actionName Name of the action
-- @param number inputValue Value of the input
-- @param any callbackState State of the callback
-- @param boolean isAnalog Is input analog
-- @param boolean isMouse Is input from mouse
-- @param string deviceCategory Category of the device
-- @param string binding Input binding
-- @param boolean isReset Is action reset
-- @includeCode
function PingInputController:onPingAction(actionName, inputValue, callbackState, isAnalog, isMouse, deviceCategory, binding, isReset)
  local isMiddleMousePressed = Input.isMouseButtonPressed(Input.MOUSE_BUTTON_MIDDLE)

  if isReset then
    if not isMiddleMousePressed then
      self.removeHoldStartTime = 0
    end

    return
  end

  if not self:getCanUsePingAction() then
    self.removeHoldStartTime = 0
    return
  end

  local currentTime = g_time or 0

  if inputValue > 0 then
    if self.removeHoldStartTime == 0 then
      self.removeHoldStartTime = currentTime
    end

    if self.removeHoldStartTime > 0 and currentTime - self.removeHoldStartTime >= self.owner.removeHoldDuration then
      self:removePings()
      self.removeHoldStartTime = -1
    end
  elseif isMiddleMousePressed then
    return
  elseif self.removeHoldStartTime ~= 0 then
    if self.removeHoldStartTime > 0 and currentTime - self.removeHoldStartTime >= self.owner.removeHoldDuration then
      self:removePings()
    elseif self.removeHoldStartTime > 0 then
      self:createWorldPing()
    end

    self.removeHoldStartTime = 0
  end
end

---Removes active pings from the system
-- @includeCode
function PingInputController:removePings()
  PingSystemRemoveRequestEvent.sendEvent(self:getReticlePingId())
end

---Gets the ID of the reticle ping
-- @return number ID of the reticle ping or nil
-- @includeCode
function PingInputController:getReticlePingId()
  local originX, originY, originZ, directionX, directionY, directionZ = PingRaycast.getCameraRay()

  if originX == nil then
    return nil
  end

  local directionLength = math.sqrt(directionX * directionX + directionY * directionY + directionZ * directionZ)

  if directionLength <= 0.0001 then
    return nil
  end

  directionX = directionX / directionLength
  directionY = directionY / directionLength
  directionZ = directionZ / directionLength

  local bestPingId = nil
  local bestAimDot = self.targetMinDot
  local bestDistanceSquared = math.huge

  for pingId, ping in pairs(self.owner:getPings()) do
    if not ping.isPendingRemoval and ping.isLocallyVisible and ping.fadeAlpha > 0 and self.owner:canDisplayPing(ping.farmId) then
      local targetX = ping.x - originX
      local targetY = ping.y - originY
      local targetZ = ping.z - originZ
      local distanceSquared = targetX * targetX + targetY * targetY + targetZ * targetZ

      if distanceSquared > 0.0001 then
        local aimDot = (targetX * directionX + targetY * directionY + targetZ * directionZ) / math.sqrt(distanceSquared)
        local isBetterTarget = bestPingId == nil or aimDot > bestAimDot + 0.000001 or math.abs(aimDot - bestAimDot) <= 0.000001 and distanceSquared < bestDistanceSquared

        if aimDot >= self.targetMinDot and isBetterTarget then
          bestPingId = pingId
          bestAimDot = aimDot
          bestDistanceSquared = distanceSquared
        end
      end
    end
  end

  return bestPingId
end

---Creates a ping at the targeted location
-- @includeCode
function PingInputController:createWorldPing()
  if not self:getCanUsePingAction() then
    return
  end

  local originX, originY, originZ, directionX, directionY, directionZ = PingRaycast.getCameraRay()

  if originX == nil then
    self.owner:showNoTargetWarning()
    return
  end

  local hitX, hitY, hitZ = self.raycast:cast(originX, originY, originZ, directionX, directionY, directionZ)

  if hitX == nil then
    self.owner:showNoTargetWarning()
    return
  end

  PingSystemRequestEvent.sendEvent(hitX, hitY, hitZ, false)
end
