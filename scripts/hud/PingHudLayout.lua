--
-- PingHudLayout
--
-- Author: Sławek Jaskulski
-- Copyright (C) ModNext, All Rights Reserved.
--

PingHudLayout = {}

local PingHudLayout_mt = Class(PingHudLayout)

---Creates a new PingHudLayout instance
-- @param table hud HUD reference
-- @param table customMt Custom metatable
-- @return PingHudLayout New instance
-- @includeCode
function PingHudLayout.new(hud, customMt)
  local self = setmetatable({}, customMt or PingHudLayout_mt)

  self.hud = hud

  return self
end

---Deletes the PingHudLayout instance
-- @includeCode
function PingHudLayout:delete()
  self.hud = nil
end

---Compares two entries for sorting
-- @param table a First entry
-- @param table b Second entry
-- @return boolean True if a < b
-- @includeCode
function PingHudLayout.sortEntries(a, b)
  local aCreatedAt = a.ping.createdAt or 0
  local bCreatedAt = b.ping.createdAt or 0

  if aCreatedAt == bCreatedAt then
    return (a.ping.id or 0) < (b.ping.id or 0)
  end

  return aCreatedAt < bCreatedAt
end

---Resolves collisions for layout entries
-- @param table entries List of entries
-- @includeCode
function PingHudLayout:resolveCollisions(entries)
  table.sort(entries, PingHudLayout.sortEntries)

  local placedRectangles = {}

  for _, entry in ipairs(entries) do
    if not entry.isClamped then
      entry.screenX, entry.screenY = entry.desiredX, entry.desiredY
    elseif entry.ping.isPendingRemoval == true then
      entry.screenX, entry.screenY = self:clampLayoutPosition(entry, entry.desiredX, entry.desiredY)
    else
      entry.screenX, entry.screenY = self:findFreePosition(entry, placedRectangles)
      table.insert(placedRectangles, self:getCollisionRectangle(entry, entry.screenX, entry.screenY))
    end
  end
end

---Finds a free position for an entry
-- @param table entry Entry to position
-- @param table placedRectangles List of placed rectangles
-- @return number X position
-- @return number Y position
-- @includeCode
function PingHudLayout:findFreePosition(entry, placedRectangles)
  local screenX, screenY = self:getFreePosition(entry, placedRectangles, entry.desiredX, entry.desiredY)

  if screenX ~= nil then
    return screenX, screenY
  end

  local stepX = entry.halfWidth * 2 + self.hud.collisionGapX
  local stepY = entry.bottomExtent + entry.topExtent + self.hud.collisionGapY

  local isVerticalEdge = math.abs(entry.directionX) >= math.abs(entry.directionY)
  local edgeStep = isVerticalEdge and stepY or stepX

  for edgeLayer = 0, 2 do
    for offset = 1, 12 do
      for sign = 1, -1, -2 do
        local candidateX = entry.desiredX
        local candidateY = entry.desiredY

        if isVerticalEdge then
          candidateY = candidateY + sign * offset * edgeStep
        else
          candidateX = candidateX + sign * offset * edgeStep
        end

        screenX, screenY = self:getFreePosition(entry, placedRectangles, candidateX, candidateY, edgeLayer)

        if screenX ~= nil then
          return screenX, screenY
        end
      end
    end
  end

  return self:clampLayoutPosition(entry, entry.desiredX, entry.desiredY)
end

---Gets free position for HUD element
-- @param table entry HUD entry data
-- @param table placedRectangles Rectangles already placed
-- @param number screenX X position on screen
-- @param number screenY Y position on screen
-- @param integer edgeLayer Layer for edge clamping
-- @return number Adjusted X position
-- @return number Adjusted Y position
-- @includeCode
function PingHudLayout:getFreePosition(entry, placedRectangles, screenX, screenY, edgeLayer)
  screenX, screenY = self:clampLayoutPosition(entry, screenX, screenY, edgeLayer)

  if self:getHasCollision(entry, screenX, screenY, placedRectangles) then
    return nil, nil
  end

  return screenX, screenY
end

---Clamps layout position within bounds
-- @param table entry HUD entry data
-- @param number screenX X position on screen
-- @param number screenY Y position on screen
-- @param integer edgeLayer Layer for clamping
-- @return number Clamped X position
-- @return number Clamped Y position
-- @includeCode
function PingHudLayout:clampLayoutPosition(entry, screenX, screenY, edgeLayer)
  local hud = self.hud
  local minX = math.max(hud.borderX, entry.halfWidth)
  local maxX = math.min(1 - hud.borderX, 1 - entry.halfWidth)
  local minY = math.max(hud.borderY, entry.bottomExtent)
  local maxY = math.min(1 - hud.borderY, 1 - entry.topExtent)

  if minX > maxX then
    minX = 0.5
    maxX = 0.5
  end

  if minY > maxY then
    minY = 0.5
    maxY = 0.5
  end

  screenX = math.max(minX, math.min(maxX, screenX))
  screenY = math.max(minY, math.min(maxY, screenY))

  if entry.isClamped then
    local layer = edgeLayer or 0

    if math.abs(entry.directionX) >= math.abs(entry.directionY) then
      local layerOffset = layer * (entry.halfWidth * 2 + hud.collisionGapX)
      screenX = entry.directionX < 0 and math.min(maxX, minX + layerOffset) or math.max(minX, maxX - layerOffset)
    else
      local layerOffset = layer * (entry.bottomExtent + entry.topExtent + hud.collisionGapY)
      screenY = entry.directionY < 0 and math.min(maxY, minY + layerOffset) or math.max(minY, maxY - layerOffset)
    end
  end

  return screenX, screenY
end

---Gets collision rectangle for HUD element
-- @param table entry HUD entry data
-- @param number screenX X position on screen
-- @param number screenY Y position on screen
-- @return table Collision rectangle data
-- @includeCode
function PingHudLayout:getCollisionRectangle(entry, screenX, screenY)
  return {
    left = screenX - entry.halfWidth,
    right = screenX + entry.halfWidth,
    bottom = screenY - entry.bottomExtent,
    top = screenY + entry.topExtent,
  }
end

---Checks for collision with other rectangles
-- @param table entry HUD entry data
-- @param number screenX X position on screen
-- @param number screenY Y position on screen
-- @param table placedRectangles Rectangles already placed
-- @return boolean True if collision exists
-- @includeCode
function PingHudLayout:getHasCollision(entry, screenX, screenY, placedRectangles)
  local left = screenX - entry.halfWidth
  local right = screenX + entry.halfWidth
  local bottom = screenY - entry.bottomExtent
  local top = screenY + entry.topExtent

  for _, rectangle in ipairs(placedRectangles) do
    if left < rectangle.right and right > rectangle.left and bottom < rectangle.top and top > rectangle.bottom then
      return true
    end
  end

  return false
end
