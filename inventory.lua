-- inventory.lua
-- Slot-based inventory data. GUI Grids bind to inventories for display.

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new(size)
    return setmetatable({
        size  = size,
        slots = {},    -- [i] = { id = "namespace:block", count = n } or nil
    }, Inventory)
end

function Inventory:get(i)
    if i < 1 or i > self.size then return nil end
    return self.slots[i]
end

function Inventory:set(i, id, count)
    if i < 1 or i > self.size then return false end
    if not id or count == 0 then
        self.slots[i] = nil
    else
        self.slots[i] = { id = id, count = count or 1 }
    end
    return true
end

function Inventory:clear(i)
    if i then
        self.slots[i] = nil
    else
        self.slots = {}
    end
end

function Inventory:isEmpty(i)
    if i then return self.slots[i] == nil end
    for j = 1, self.size do
        if self.slots[j] then return false end
    end
    return true
end

-- Move a stack from slot `from` to `to`. Merges if same id, swaps otherwise.
function Inventory:move(from, to, maxStack)
    maxStack = maxStack or 64
    local src = self.slots[from]
    if not src then return false end

    local dst = self.slots[to]
    if not dst then
        self.slots[to]   = src
        self.slots[from] = nil
        return true
    end

    if dst.id == src.id then
        local space = maxStack - dst.count
        local move  = math.min(space, src.count)
        if move <= 0 then return false end
        dst.count = dst.count + move
        src.count = src.count - move
        if src.count <= 0 then self.slots[from] = nil end
        return true
    end

    self.slots[from] = dst
    self.slots[to]   = src
    return true
end

-- Add items, filling existing stacks first. Returns any leftover count.
function Inventory:add(id, count, maxStack)
    maxStack = maxStack or 64
    local remaining = count or 1

    for i = 1, self.size do
        if remaining <= 0 then break end
        local slot = self.slots[i]
        if slot and slot.id == id and slot.count < maxStack then
            local space = maxStack - slot.count
            local add   = math.min(space, remaining)
            slot.count  = slot.count + add
            remaining   = remaining - add
        end
    end

    for i = 1, self.size do
        if remaining <= 0 then break end
        if not self.slots[i] then
            local add      = math.min(maxStack, remaining)
            self.slots[i]  = { id = id, count = add }
            remaining      = remaining - add
        end
    end

    return remaining
end

-- Remove up to `count` of `id`. Returns how many were actually removed.
function Inventory:remove(id, count)
    local remaining = count or 1
    local removed   = 0
    for i = 1, self.size do
        if remaining <= 0 then break end
        local slot = self.slots[i]
        if slot and slot.id == id then
            local take    = math.min(slot.count, remaining)
            slot.count    = slot.count - take
            removed       = removed + take
            remaining     = remaining - take
            if slot.count <= 0 then self.slots[i] = nil end
        end
    end
    return removed
end


function Inventory:count(id)
    local total = 0
    for i = 1, self.size do
        local slot = self.slots[i]
        if slot and slot.id == id then
            total = total + slot.count
        end
    end
    return total
end

function Inventory:save(worldId, key)
    local path = "worlds/" .. worldId .. "/inventory_" .. key .. ".txt"
    local file = fs.open(path, "w")
    file.write(textutils.serialise(self.slots))
    file.close()
end

function Inventory:load(worldId, key)
    local path = "worlds/" .. worldId .. "/inventory_" .. key .. ".txt"
    if not fs.exists(path) then return false end
    local file = fs.open(path, "r")
    local raw  = file.readAll()
    file.close()
    local data = textutils.unserialise(raw)
    if data then
        self.slots = data
        return true
    end
    return false
end

-- Bind this inventory to a GUI Grid. cursorRef = { item = nil } is the held item.

function Inventory:bindToGrid(grid, cursorRef)

    for r = 1, grid.rows do
        for c = 1, grid.cols do
            local slotIndex = (r-1) * grid.cols + c
            local guiSlot   = grid:getSlot(r, c)
            if guiSlot then
                local invSlot = self:get(slotIndex)
                if invSlot then
                    guiSlot:setItem(invSlot.id, invSlot.count)
                else
                    guiSlot:clear()
                end

                guiSlot.onInteract = function(slot, button)
                    local held = cursorRef.item
                    local inv  = self:get(slotIndex)

                    if button == 1 then
                        if held then
                            if inv and inv.id == held.id then
                                local added = math.min(64 - inv.count, held.count)
                                inv.count   = inv.count + added
                                held.count  = held.count - added
                                if held.count <= 0 then cursorRef.item = nil end
                                self:set(slotIndex, inv.id, inv.count)
                            else
                                cursorRef.item = inv
                                self:set(slotIndex, held.id, held.count)
                            end
                        else
                            if inv then
                                cursorRef.item = { id = inv.id, count = inv.count }
                                self:clear(slotIndex)
                            end
                        end
                    elseif button == 2 then
                        if held then
                            if not inv or inv.id == held.id then
                                local current = inv and inv.count or 0
                                if current < 64 then
                                    self:set(slotIndex, held.id, current + 1)
                                    held.count = held.count - 1
                                    if held.count <= 0 then cursorRef.item = nil end
                                end
                            end
                        elseif inv then
                            local half = math.ceil(inv.count / 2)
                            cursorRef.item = { id = inv.id, count = half }
                            inv.count = inv.count - half
                            if inv.count <= 0 then
                                self:clear(slotIndex)
                            else
                                self:set(slotIndex, inv.id, inv.count)
                            end
                        end
                    end

                    local updated = self:get(slotIndex)
                    if updated then
                        guiSlot:setItem(updated.id, updated.count)
                    else
                        guiSlot:clear()
                    end
                end
            end
        end
    end
end

local InventoryModule = {}

function InventoryModule.new(size)
    return Inventory.new(size)
end

-- Player inventory singleton (36 slots).
local _playerInventory = nil

function InventoryModule.getPlayer()
    if not _playerInventory then
        _playerInventory = Inventory.new(36)
    end
    return _playerInventory
end

function InventoryModule.loadPlayer(worldId)
    local inv = InventoryModule.getPlayer()
    inv:load(worldId, "player")
    return inv
end

function InventoryModule.savePlayer(worldId)
    local inv = InventoryModule.getPlayer()
    inv:save(worldId, "player")
end

return InventoryModule
