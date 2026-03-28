-- gui.lua
-- Screen and widget system.

local GUI = {}

GUI.defaultTheme = {
    bg           = colors.brown,
    border       = colors.green,
    titleColor   = colors.white,
    textColor    = colors.white,
    mutedColor   = colors.gray,
    buttonBg     = colors.gray,
    buttonBorder = colors.lightGray,
    buttonText   = colors.white,
    slotBg       = colors.black,
    slotBorder   = colors.green,
    slotSelect   = colors.lightGray,
    inputBg      = colors.black,
    inputText    = colors.white,
    inputBorder  = colors.green,
    progressFg   = colors.lime,
    progressBg   = colors.gray,
    borderStyle  = "nice",   -- "nice" | "flat" | "none"
}

-- Merge a partial theme over the defaults.
function GUI.resolveTheme(partial)
    if not partial then return GUI.defaultTheme end
    local t = {}
    for k, v in pairs(GUI.defaultTheme) do t[k] = v end
    for k, v in pairs(partial) do t[k] = v end
    return t
end

local openScreens = {}   -- stack of Screen objects, topmost is active
local state        = nil  -- injected: the shared game state table
local coreConfig   = nil  -- injected: the shared config table
local termWidth    = 0
local termHeight   = 0

function GUI.init(deps)
    state      = deps.state
    termWidth  = deps.screenWidth
    termHeight = deps.screenHeight
    coreConfig = deps.config
    GUI._term  = deps.nativeTerm or term.current()
end

function GUI.onResize(w, h)
    termWidth  = w
    termHeight = h
    for _, screen in ipairs(openScreens) do
        screen:_reposition()
    end
end

local function drawNiceBorder(win, x1, y1, x2, y2, bg, fg)
    local s = string.rep(" ", x2-x1+1-2)
    win.setBackgroundColor(bg)
    for y = y1+1, y2-1 do
        win.setCursorPos(x1+1, y)
        win.write(s)
    end
    for i = x1+1, x2-1 do
        win.setBackgroundColor(bg) ; win.setTextColor(fg)
        win.setCursorPos(i, y1) ; win.write(string.char(131))
    end
    for i = x1+1, x2-1 do
        win.setBackgroundColor(fg) ; win.setTextColor(bg)
        win.setCursorPos(i, y2) ; win.write(string.char(143))
    end
    for i = y1+1, y2-1 do
        win.setBackgroundColor(bg) ; win.setTextColor(fg)
        win.setCursorPos(x1, i) ; win.write(string.char(149))
    end
    for i = y1+1, y2-1 do
        win.setBackgroundColor(fg) ; win.setTextColor(bg)
        win.setCursorPos(x2, i) ; win.write(string.char(149))
    end
    win.setCursorPos(x1, y1) ; win.setBackgroundColor(bg) ; win.setTextColor(fg) ; win.write(string.char(151))
    win.setCursorPos(x1, y2) ; win.setBackgroundColor(fg) ; win.setTextColor(bg) ; win.write(string.char(138))
    win.setCursorPos(x2, y1) ; win.setBackgroundColor(fg) ; win.setTextColor(bg) ; win.write(string.char(148))
    win.setCursorPos(x2, y2) ; win.setBackgroundColor(fg) ; win.setTextColor(bg) ; win.write(string.char(133))
end

local function drawFlatBorder(win, x1, y1, x2, y2, bg, fg)
    win.setBackgroundColor(bg)
    local s = string.rep(" ", x2-x1+1-2)
    for y = y1+1, y2-1 do
        win.setCursorPos(x1+1, y) ; win.write(s)
    end
    win.setTextColor(fg)
    for i = x1+1, x2-1 do
        win.setCursorPos(i, y1) ; win.write("-")
        win.setCursorPos(i, y2) ; win.write("-")
    end
    for i = y1+1, y2-1 do
        win.setCursorPos(x1, i) ; win.write("|")
        win.setCursorPos(x2, i) ; win.write("|")
    end
    win.setCursorPos(x1, y1) ; win.write("+")
    win.setCursorPos(x2, y1) ; win.write("+")
    win.setCursorPos(x1, y2) ; win.write("+")
    win.setCursorPos(x2, y2) ; win.write("+")
end

local function drawBorder(win, x1, y1, x2, y2, theme)
    if theme.borderStyle == "nice" then
        drawNiceBorder(win, x1, y1, x2, y2, theme.bg, theme.border)
    elseif theme.borderStyle == "flat" then
        drawFlatBorder(win, x1, y1, x2, y2, theme.bg, theme.border)
    else
        win.setBackgroundColor(theme.bg)
        for y = y1, y2 do
            win.setCursorPos(x1, y)
            win.write(string.rep(" ", x2-x1+1))
        end
    end
end

local Widget = {}
Widget.__index = Widget

function Widget.new(x, y, w, h)
    return setmetatable({
        x = x, y = y, width = w, height = h,
        visible = true,
        _id = tostring(math.random(100000, 999999)),
    }, Widget)
end

function Widget:contains(wx, wy)
    return wx >= self.x and wx < self.x + self.width
       and wy >= self.y and wy < self.y + self.height
end

function Widget:render(win, theme) end
function Widget:onClick(wx, wy, button) end
function Widget:onKey(key) end
function Widget:onChar(ch) end

local Label = setmetatable({}, {__index = Widget})
Label.__index = Label

function Label.new(x, y, text, color)
    local self = Widget.new(x, y, #text, 1)
    self.text  = text
    self.color = color   -- nil = use theme.textColor
    return setmetatable(self, Label)
end

function Label:render(win, theme)
    if not self.visible then return end
    win.setCursorPos(self.x, self.y)
    win.setBackgroundColor(theme.bg)
    win.setTextColor(self.color or theme.textColor)
    win.write(self.text)
end

local Button = setmetatable({}, {__index = Widget})
Button.__index = Button

function Button.new(x, y, w, h, text, callback)
    local self     = Widget.new(x, y, w, h)
    self.text      = text
    self.callback  = callback
    self._pressed  = false
    return setmetatable(self, Button)
end

function Button:render(win, theme)
    if not self.visible then return end
    local bg  = self._pressed and theme.buttonBorder or theme.buttonBg
    local fg  = self._pressed and theme.buttonBg     or theme.buttonBorder
    drawNiceBorder(win, self.x, self.y, self.x+self.width-1, self.y+self.height-1, bg, fg)
    win.setTextColor(theme.buttonText)
    win.setBackgroundColor(bg)
    local tx = math.floor(self.x + self.width*0.5 - #self.text*0.5 + 0.5)
    local ty = math.floor(self.y + self.height*0.5)
    win.setCursorPos(tx, ty)
    win.write(self.text)
end

function Button:onClick(wx, wy, button)
    if button == 1 and self.callback then
        self._pressed = true
        self.callback()
        self._pressed = false
    end
end

local TextInput = setmetatable({}, {__index = Widget})
TextInput.__index = TextInput

function TextInput.new(x, y, w, placeholder, onChange)
    local self        = Widget.new(x, y, w, 1)
    self.value        = ""
    self.placeholder  = placeholder or ""
    self.onChange     = onChange
    self.focused      = false
    self.maxLen       = w - 2
    return setmetatable(self, TextInput)
end

function TextInput:render(win, theme)
    if not self.visible then return end
    win.setCursorPos(self.x, self.y)
    win.setBackgroundColor(theme.inputBg)
    win.setTextColor(self.focused and theme.inputText or theme.mutedColor)
    local display = #self.value > 0 and self.value or self.placeholder
    display = display:sub(-(self.width - 1))
    win.write(" " .. display .. string.rep(" ", self.width - 1 - #display))
    win.setCursorPos(self.x, self.y + 1)
    win.setBackgroundColor(theme.bg)
    win.setTextColor(theme.inputBorder)
    if self.y + 1 <= select(2, win.getSize()) then
        win.write(string.char(131):rep(self.width))
    end
    if self.focused then
        win.setCursorPos(self.x + 1 + math.min(#self.value, self.maxLen), self.y)
        win.setCursorBlink(true)
    end
end

function TextInput:onClick(wx, wy, button)
    self.focused = true
end

function TextInput:onChar(ch)
    if not self.focused then return end
    if #self.value < self.maxLen then
        self.value = self.value .. ch
        if self.onChange then self.onChange(self.value) end
    end
end

function TextInput:onKey(key)
    if not self.focused then return end
    if key == keys.backspace then
        self.value = self.value:sub(1, -2)
        if self.onChange then self.onChange(self.value) end
    end
end

-- Single inventory slot.
local Slot = setmetatable({}, {__index = Widget})
Slot.__index = Slot

function Slot.new(x, y, onInteract)
    local self       = Widget.new(x, y, 2, 1)
    self.blockId     = nil     -- full block id or nil if empty
    self.count       = 0
    self.selected    = false
    self.onInteract  = onInteract   -- fn(slot, button)
    return setmetatable(self, Slot)
end

function Slot:setItem(blockId, count)
    self.blockId = blockId
    self.count   = count or 1
end

function Slot:clear()
    self.blockId = nil
    self.count   = 0
end

function Slot:render(win, theme)
    if not self.visible then return end
    local bg = self.selected and theme.slotSelect or theme.slotBg
    win.setBackgroundColor(bg)
    win.setCursorPos(self.x, self.y)
    if self.blockId then
        local displayColor = colors.white
        win.setTextColor(displayColor)
        win.write("\x7f\x7f")   -- two block chars = one "slot icon"
    else
        win.setTextColor(theme.mutedColor)
        win.write("  ")
    end
    win.setBackgroundColor(theme.bg)
    win.setTextColor(self.selected and theme.slotSelect or theme.slotBorder)
    win.setCursorPos(self.x - 1, self.y)
    win.write(string.char(149))
    win.setCursorPos(self.x + 2, self.y)
    win.write(string.char(149))
end

function Slot:onClick(wx, wy, button)
    if self.onInteract then self.onInteract(self, button) end
end

-- NxM grid of slots.
local Grid = setmetatable({}, {__index = Widget})
Grid.__index = Grid

function Grid.new(x, y, cols, rows, onSlotInteract)
    local self    = Widget.new(x, y, cols * 3, rows)
    self.cols     = cols
    self.rows     = rows
    self.slots    = {}
    self.selected = nil   -- {row, col} or nil

    for r = 1, rows do
        self.slots[r] = {}
        for c = 1, cols do
            local sx = x + (c-1) * 3
            local sy = y + (r-1)
            self.slots[r][c] = Slot.new(sx, sy, function(slot, button)
                if onSlotInteract then onSlotInteract(r, c, slot, button) end
            end)
        end
    end

    return setmetatable(self, Grid)
end

function Grid:getSlot(row, col)
    return self.slots[row] and self.slots[row][col]
end

function Grid:render(win, theme)
    if not self.visible then return end
    for r = 1, self.rows do
        for c = 1, self.cols do
            self.slots[r][c]:render(win, theme)
        end
    end
end

function Grid:onClick(wx, wy, button)
    for r = 1, self.rows do
        for c = 1, self.cols do
            local slot = self.slots[r][c]
            if slot:contains(wx, wy) then
                slot:onClick(wx, wy, button)
                return
            end
        end
    end
end

local ProgressBar = setmetatable({}, {__index = Widget})
ProgressBar.__index = ProgressBar

function ProgressBar.new(x, y, w, value, label)
    local self  = Widget.new(x, y, w, 1)
    self.value  = value or 0    -- 0.0 to 1.0
    self.label  = label         -- optional text overlay
    return setmetatable(self, ProgressBar)
end

function ProgressBar:setValue(v)
    self.value = math.max(0, math.min(1, v))
end

function ProgressBar:render(win, theme)
    if not self.visible then return end
    local filled = math.floor(self.value * self.width)
    for i = 0, self.width - 1 do
        win.setCursorPos(self.x + i, self.y)
        win.setBackgroundColor(i < filled and theme.progressFg or theme.progressBg)
        win.write(" ")
    end
    if self.label then
        win.setBackgroundColor(theme.progressFg)
        win.setTextColor(theme.bg)
        win.setCursorPos(math.floor(self.x + self.width*0.5 - #self.label*0.5 + 0.5), self.y)
        win.write(self.label)
    end
end

local Divider = setmetatable({}, {__index = Widget})
Divider.__index = Divider

function Divider.new(x, y, w)
    local self = Widget.new(x, y, w, 1)
    return setmetatable(self, Divider)
end

function Divider:render(win, theme)
    if not self.visible then return end
    win.setCursorPos(self.x, self.y)
    win.setBackgroundColor(theme.bg)
    win.setTextColor(theme.border)
    win.write(string.rep(string.char(131), self.width))
end

local Icon = setmetatable({}, {__index = Widget})
Icon.__index = Icon

function Icon.new(x, y, color, char)
    local self  = Widget.new(x, y, 1, 1)
    self.color  = color
    self.char   = char or "\x7f"
    return setmetatable(self, Icon)
end

function Icon:render(win, theme)
    if not self.visible then return end
    win.setCursorPos(self.x, self.y)
    win.setBackgroundColor(theme.bg)
    win.setTextColor(self.color)
    win.write(self.char)
end

-- Scrollable list. Items: { label, color, data }. onSelect(item, index) on click.

local ScrollList = setmetatable({}, {__index = Widget})
ScrollList.__index = ScrollList

function ScrollList.new(x, y, w, h, items, onSelect)
    local self       = Widget.new(x, y, w, h)
    self.items       = items or {}   -- { label, color, data }
    self.onSelect    = onSelect
    self.scrollTop   = 1             -- first visible item index (1-based)
    self.selected    = nil           -- currently highlighted index
    return setmetatable(self, ScrollList)
end

function ScrollList:setItems(items)
    self.items     = items or {}
    self.scrollTop = 1
    self.selected  = nil
end

function ScrollList:scrollBy(delta)
    local maxTop = math.max(1, #self.items - self.height + 1)
    self.scrollTop = math.max(1, math.min(maxTop, self.scrollTop + delta))
end

function ScrollList:_visibleRows()
    return self.height
end

function ScrollList:render(win, theme)
    if not self.visible then return end
    local rows     = self:_visibleRows()
    local hasBar   = #self.items > rows
    local listW    = hasBar and self.width - 1 or self.width

    for i = 0, rows - 1 do
        local idx  = self.scrollTop + i
        local item = self.items[idx]
        local rx   = self.x
        local ry   = self.y + i
        win.setCursorPos(rx, ry)

        if item then
            local isSelected = (idx == self.selected)
            local bg  = isSelected and theme.slotSelect or theme.bg
            local fg  = item.color or (isSelected and theme.bg or theme.textColor)
            win.setBackgroundColor(bg)
            win.setTextColor(fg)
            local label = item.label or ""
            label = label:sub(1, listW)
            win.write(label .. string.rep(" ", listW - #label))
        else
            win.setBackgroundColor(theme.bg)
            win.write(string.rep(" ", listW))
        end
    end

    if hasBar then
        local barX    = self.x + self.width - 1
        local total   = #self.items
        local ratio   = rows / total
        local barH    = math.max(1, math.floor(rows * ratio))
        local maxTop  = math.max(1, total - rows + 1)
        local barPos  = math.floor((self.scrollTop - 1) / (maxTop - 1) * (rows - barH) + 0.5)

        for i = 0, rows - 1 do
            win.setCursorPos(barX, self.y + i)
            local inThumb = (i >= barPos and i < barPos + barH)
            win.setBackgroundColor(inThumb and theme.border or theme.mutedColor)
            win.setTextColor(theme.bg)
            win.write(" ")
        end
    end
end

function ScrollList:onClick(wx, wy, button)
    local rows   = self:_visibleRows()
    local hasBar = #self.items > rows
    local relX   = wx - self.x
    local relY   = wy - self.y

    if hasBar and relX == self.width - 1 then
        local frac   = relY / rows
        local maxTop = math.max(1, #self.items - rows + 1)
        self.scrollTop = math.max(1, math.min(maxTop, math.floor(frac * #self.items) + 1))
        return
    end

    local idx = self.scrollTop + relY
    if idx >= 1 and idx <= #self.items then
        self.selected = idx
        if self.onSelect then self.onSelect(self.items[idx], idx) end
    end
end

function ScrollList:onKey(key)
    if key == keys.up then
        if self.selected and self.selected > 1 then
            self.selected = self.selected - 1
            if self.selected < self.scrollTop then
                self.scrollTop = self.selected
            end
            if self.onSelect then self.onSelect(self.items[self.selected], self.selected) end
        end
    elseif key == keys.down then
        local max = #self.items
        if self.selected and self.selected < max then
            self.selected = self.selected + 1
            if self.selected >= self.scrollTop + self.height then
                self.scrollTop = self.selected - self.height + 1
            end
            if self.onSelect then self.onSelect(self.items[self.selected], self.selected) end
        end
    end
end

function ScrollList:onScroll(dir)
    self:scrollBy(dir)
end

-- Full overlay screen. Captures all input while open.
local Screen = {}
Screen.__index = Screen

function Screen.new(title, opts, theme)
    opts = opts or {}
    local self       = setmetatable({}, Screen)
    self.title       = title
    self.theme       = GUI.resolveTheme(theme)
    self.widgets     = {}
    self.focusedInput = nil
    self.onClose     = nil      -- optional callback

    self._requestedW = opts.width
    self._requestedH = opts.height
    self._requestedX = opts.x
    self._requestedY = opts.y

    self:_reposition()
    self:_createWindow()
    return self
end

function Screen:_reposition()
    local w = self._requestedW or math.min(40, termWidth - 4)
    local h = self._requestedH or math.min(20, termHeight - 4)
    local x = self._requestedX or math.floor(termWidth  * 0.5 - w * 0.5 + 0.5)
    local y = self._requestedY or math.floor(termHeight * 0.5 - h * 0.5 + 0.5)
    self.x = x ; self.y = y ; self.w = w ; self.h = h
end

function Screen:_createWindow()
    self._win = window.create(GUI._term or term.current(), self.x, self.y, self.w, self.h, false)
end

function Screen:addLabel(x, y, text, color)
    local w = Label.new(x, y, text, color)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:addButton(x, y, width, height, text, callback)
    local w = Button.new(x, y, width, height, text, callback)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:addTextInput(x, y, width, placeholder, onChange)
    local w = TextInput.new(x, y, width, placeholder, onChange)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:addSlot(x, y, onInteract)
    local w = Slot.new(x, y, onInteract)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:addGrid(x, y, cols, rows, onSlotInteract)
    local w = Grid.new(x, y, cols, rows, onSlotInteract)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:addProgressBar(x, y, width, value, label)
    local w = ProgressBar.new(x, y, width, value, label)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:addDivider(x, y, width)
    local w = Divider.new(x, y, width)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:addIcon(x, y, color, char)
    local w = Icon.new(x, y, color, char)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:addScrollList(x, y, width, height, items, onSelect)
    local w = ScrollList.new(x, y, width, height, items, onSelect)
    self.widgets[#self.widgets+1] = w
    return w
end

function Screen:render()
    self._win.setVisible(false)

    local theme = self.theme
    drawBorder(self._win, 1, 1, self.w, self.h, theme)

    if self.title and #self.title > 0 then
        self._win.setBackgroundColor(theme.bg)
        self._win.setTextColor(theme.titleColor)
        local tx = math.floor(self.w * 0.5 - #self.title * 0.5 + 0.5)
        self._win.setCursorPos(tx, 2)
        self._win.write(self.title)
        self._win.setTextColor(theme.border)
        self._win.setCursorPos(2, 3)
        self._win.write(string.rep(string.char(131), self.w - 2))
    end

    for _, widget in ipairs(self.widgets) do
        widget:render(self._win, theme)
    end

    self._win.setVisible(true)
end

function Screen:handleClick(mx, my, button)
    local wx = mx - self.x + 1
    local wy = my - self.y + 1

    if wx < 1 or wx > self.w or wy < 1 or wy > self.h then
        self:close()
        return
    end

    for _, widget in ipairs(self.widgets) do
        if widget.focused ~= nil then widget.focused = false end
    end

    for _, widget in ipairs(self.widgets) do
        if widget.visible and widget:contains(wx, wy) then
            widget:onClick(wx, wy, button)
            if widget.focused ~= nil then self.focusedInput = widget end
            break
        end
    end
    self:render()
end

function Screen:handleKey(key)
    if key == keys.escape then
        self:close()
        return
    end
    if self.focusedInput then
        self.focusedInput:onKey(key)
        self:render()
    end
end

function Screen:handleChar(ch)
    if self.focusedInput then
        self.focusedInput:onChar(ch)
        self:render()
    end
end

function Screen:open()
    openScreens[#openScreens+1] = self
    if state then state.guiOpen = true end
    self:_createWindow()
    self:render()

    while self:isOpen() do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "mouse_click" then
            self:handleClick(p2, p3, p1)
        elseif event == "key" then
            self:handleKey(p1)
        elseif event == "char" then
            self:handleChar(p1)
        elseif event == "mouse_scroll" then
            local mx, my = p2, p3
            for _, widget in ipairs(self.widgets) do
                if widget.visible and widget.onScroll and widget:contains(mx - self.x + 1, my - self.y + 1) then
                    widget:onScroll(p1)
                    self:render()
                    break
                end
            end
        elseif event == "term_resize" then
            GUI.onResize(term.getSize())
            self:render()
        elseif event == "gui_close" then
            break
        end
    end
end

function Screen:close()
    for i = #openScreens, 1, -1 do
        if openScreens[i] == self then
            table.remove(openScreens, i)
            break
        end
    end
    self._win.setVisible(false)
    term.setCursorBlink(false)
    if state then state.guiOpen = (#openScreens > 0) end
    if self.onClose then self.onClose() end
    os.queueEvent("gui_close")
end

function Screen:isOpen()
    for _, s in ipairs(openScreens) do
        if s == self then return true end
    end
    return false
end

function GUI.handleEvent(event, p1, p2, p3)
    local top = openScreens[#openScreens]
    if not top then return end

    if event == "mouse_click" then
        top:handleClick(p2, p3, p1)
    elseif event == "key" then
        top:handleKey(p1)
    elseif event == "char" then
        top:handleChar(p1)
    elseif event == "term_resize" then
        GUI.onResize(p1 or termWidth, p2 or termHeight)
        top:render()
    end
end

function GUI.hasOpenScreen()
    return #openScreens > 0
end

function GUI.closeAll()
    for i = #openScreens, 1, -1 do
        openScreens[i]:close()
    end
end

-- Vanilla block colors for the creative menu swatch.
local vanillaColors = {
    grass  = colors.lime,
    dirt   = colors.brown,
    wood   = colors.brown,
    leaves = colors.green,
    stone  = colors.gray,
    sand   = colors.yellow,
    water  = colors.blue,
}

function GUI.runCreativeMenu()
    if not coreConfig or not state then return end

    local sw, sh = termWidth, termHeight
    local w      = math.min(sw - 4, 44)
    local h      = math.min(sh - 4, 22)
    local screen = Screen.new("Creative Menu", { width = w, height = h })
    local theme  = screen.theme

    local allBlocks = {}
    for _, id in ipairs(coreConfig.blockIds) do
        allBlocks[#allBlocks+1] = {
            id    = id,
            name  = coreConfig.isVanilla(id) and id
                    or (coreConfig.modBlocks[id] and coreConfig.modBlocks[id].displayName or id),
            color = coreConfig.isVanilla(id) and (vanillaColors[id] or colors.white)
                    or (coreConfig.modBlocks[id] and coreConfig.modBlocks[id].displayColor or colors.white),
            isMod = not coreConfig.isVanilla(id),
        }
    end
    for fullId, blockDef in pairs(coreConfig.modBlocks) do
        local found = false
        for _, b in ipairs(allBlocks) do if b.id == fullId then found = true; break end end
        if not found then
            allBlocks[#allBlocks+1] = {
                id    = fullId,
                name  = blockDef.displayName or fullId,
                color = blockDef.displayColor or colors.white,
                isMod = true,
            }
        end
    end

    local listItems = {}
    for _, block in ipairs(allBlocks) do
        local tag = block.isMod and " [mod]" or ""
        listItems[#listItems+1] = {
            label = "  " .. block.name .. tag,
            color = block.color,
            data  = block,
        }
    end

    local listW   = math.floor(w * 0.6)
    local listH   = h - 6    -- title + divider + footer
    local previewX = listW + 3

    local blockList = ScrollList.new(2, 5, listW, listH, listItems, function(item, idx)
        state.selectedBlock = item.data.id
    end)
    for i, item in ipairs(listItems) do
        if item.data.id == state.selectedBlock then
            blockList.selected  = i
            blockList.scrollTop = math.max(1, i - math.floor(listH / 2))
            break
        end
    end
    screen.widgets[#screen.widgets+1] = blockList

    local function renderMenu()
        screen._win.setVisible(false)
        drawBorder(screen._win, 1, 1, w, h, theme)

        screen._win.setBackgroundColor(theme.bg)
        screen._win.setTextColor(theme.titleColor)
        local title = "Creative Menu"
        screen._win.setCursorPos(math.floor(w*0.5 - #title*0.5 + 0.5), 2)
        screen._win.write(title)

        screen._win.setTextColor(theme.mutedColor)
        local sub = tostring(#allBlocks) .. " blocks  [Up/Down or Scroll]"
        screen._win.setCursorPos(math.floor(w*0.5 - #sub*0.5 + 0.5), 3)
        screen._win.write(sub)

        screen._win.setTextColor(theme.border)
        screen._win.setCursorPos(2, 4)
        screen._win.write(string.rep(string.char(131), w-2))

        blockList:render(screen._win, theme)

        local sel = blockList.selected and allBlocks[blockList.selected]
        if sel then
            local px = previewX
            local py = 5
            screen._win.setCursorPos(px, py)
            screen._win.setBackgroundColor(theme.bg)
            screen._win.setTextColor(theme.mutedColor)
            screen._win.write("Selected:")
            screen._win.setCursorPos(px, py+2)
            screen._win.setBackgroundColor(sel.color)
            screen._win.setTextColor(sel.color)
            screen._win.write("    ")
            screen._win.setCursorPos(px, py+3)
            screen._win.setBackgroundColor(theme.bg)
            screen._win.setTextColor(theme.titleColor)
            local dname = sel.name:sub(1, w - previewX)
            screen._win.write(dname)
            if sel.isMod then
                screen._win.setCursorPos(px, py+4)
                screen._win.setTextColor(theme.border)
                screen._win.write("[mod]")
            end
        end

        screen._win.setBackgroundColor(theme.bg)
        screen._win.setTextColor(theme.mutedColor)
        local footer = "[`/E] close  [Enter/Click] select"
        screen._win.setCursorPos(math.floor(w*0.5 - #footer*0.5 + 0.5), h - 1)
        screen._win.write(footer)

        screen._win.setVisible(true)
    end

    openScreens[#openScreens+1] = screen
    if state then state.guiOpen = true end
    screen:_createWindow()
    renderMenu()

    while screen:isOpen() do
        local event, p1, p2, p3 = os.pullEvent()

        if event == "key" then
            if p1 == keys.e or p1 == keys.escape or p1 == keys.grave then
                screen:close()
            elseif p1 == keys.enter then
                screen:close()
            elseif p1 == keys.up or p1 == keys.down then
                blockList:onKey(p1)
                renderMenu()
            end

        elseif event == "mouse_scroll" then
            blockList:onScroll(p1)
            renderMenu()

        elseif event == "mouse_click" then
            local mx, my = p2, p3
            local wx = mx - screen.x + 1
            local wy = my - screen.y + 1
            if wx < 1 or wx > w or wy < 1 or wy > h then
                screen:close()
            elseif blockList:contains(wx, wy) then
                blockList:onClick(wx, wy, p1)
                screen:close()   -- click = select and close
            end

        elseif event == "term_resize" then
            GUI.onResize(term.getSize())
            renderMenu()

        elseif event == "gui_close" then
            break
        end
    end
end

function GUI.makeAPI(namespace)
    local guiAPI = {}

    function guiAPI.screen(title, opts, themeOverride)
        return Screen.new(title, opts, themeOverride)
    end

    function guiAPI.setDefaultTheme(partial)
        GUI.defaultTheme = GUI.resolveTheme(partial)
    end

    guiAPI.Label       = Label
    guiAPI.Button      = Button
    guiAPI.TextInput   = TextInput
    guiAPI.Slot        = Slot
    guiAPI.Grid        = Grid
    guiAPI.ProgressBar = ProgressBar
    guiAPI.Divider     = Divider
    guiAPI.Icon        = Icon
    guiAPI.ScrollList  = ScrollList

    return guiAPI
end

return GUI
