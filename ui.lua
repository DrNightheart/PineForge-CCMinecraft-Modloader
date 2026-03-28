-- ui.lua
-- Main menu, world selection, world creation, and mod config screens.

local ui = {}

local cfg, renderer, betterblittle, blittle
local bigMenuWindow, menusWindow, worldListWindow, logoWindow
local logo, screenWidth, screenHeight, oldTerm, termResize

local newWorldName      = ""
local worldSelectionScroll = 0

function ui.init(deps)
	cfg            = deps.config
	renderer       = deps.renderer
	betterblittle  = deps.betterblittle
	blittle        = deps.blittle
	bigMenuWindow  = deps.bigMenuWindow
	menusWindow    = deps.menusWindow
	worldListWindow = deps.worldListWindow
	logoWindow     = deps.logoWindow
	logo           = deps.logo
	screenWidth    = deps.screenWidth
	screenHeight   = deps.screenHeight
	oldTerm        = deps.oldTerm
	termResize     = deps.termResize
end

local function runLogoAnimation()
	local randomMap = {}
	for x = 1, #logo[1] do
		local sx = math.floor((x-1)/2)
		randomMap[sx] = math.random(0, 4)
	end

	local startT = os.clock()
	local t = 100
	while t >= 0 do
		local newBuffer = {}
		for y = 1, #logo do
			newBuffer[y] = {}
			for x = 1, #logo[1] do
				newBuffer[y][x] = colors.brown
			end
		end
		for y = 1, #logo do
			for x = 1, #logo[1] do
				local px  = logo[y][x]
				local sx  = math.floor((x-1)/2)
				local sy  = math.floor((y-1)/2)
				local ran = randomMap[sx]
				local yOffset = 2 * math.max(0, t*0.2 - ran - sy*2)
				local newY = math.floor(y - yOffset)
				if newY >= 1 then
					newBuffer[newY][x] = px
				end
			end
		end
		betterblittle.drawBuffer(newBuffer, logoWindow)
		while os.clock() < startT + (100-t)/100 do
			os.queueEvent("logoAnimation")
			os.pullEvent("logoAnimation")
		end
		t = t - 1
	end
end

local function renderCreateWorld(fields, fieldsDefault, fieldsValues, selectedField, errMessage)
	screenWidth, screenHeight = term.getSize()
	bigMenuWindow.setVisible(false)

	local x1 = math.floor(4 +             math.max(0, screenWidth - 51)*0.5)
	local x2 = math.floor(screenWidth-3 - math.max(0, screenWidth - 51)*0.5)
	local cx = math.floor(screenWidth*0.5+0.5)

	term.setBackgroundColor(colors.brown)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(math.floor(cx - #("World Creation")*0.5 + 0.5), 2)
	term.write("World Creation")

	renderer.drawButton(term, x1,    screenHeight-3, cx-1, screenHeight-1, "Create World",    colors.gray, colors.lightGray, colors.white)
	renderer.drawButton(term, cx+1,  screenHeight-3, x2,   screenHeight-1, "Back to Worlds",  colors.gray, colors.lightGray, colors.white)

	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.brown)
	term.setCursorPos(x1+1, 5)
	term.write("Name:")
	renderer.drawNiceBorder(term, x1+7, 4, x2, 6, colors.black, colors.green)

	local largestWidth = 0
	for i = 1, #fields do
		if #fields[i] > largestWidth then largestWidth = #fields[i] end
	end

	term.setBackgroundColor(colors.brown)
	term.setTextColor(colors.white)
	for j = 1, #fields do
		local i = (j - 1) % 2 + 1
		local k = math.floor((j-1) / 2)
		local x = x1+1
		local length = cx - x
		if k == 1 then x = x + 1 + length end
		term.setCursorPos(x, 8+i*2-1)
		term.write(fields[j] .. ":")
	end

	for j = 1, #fields do
		local i = (j - 1) % 2 + 1
		local k = math.floor((j-1) / 2)
		local x = (x1+largestWidth)+2
		local length = cx - x
		if k == 1 then
			x = x + largestWidth + length + 2 + 1
			length = x2 - x + 1
		end
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.white)
		term.setCursorPos(x, 8+i*2-1)
		term.write((" "):rep(length))
		term.setCursorPos(x, 8+i*2-1)
		if #fieldsValues[j] > 0 then
			term.write(fieldsValues[j]:sub(-(length-1)))
		else
			term.setTextColor(colors.gray)
			term.write(fieldsDefault[j])
		end
		term.setBackgroundColor(colors.brown)
		term.setTextColor(colors.green)
		term.setCursorPos(x, 8+i*2)
		term.write(string.char(131):rep(length))
	end

	if #errMessage > 0 then
		term.setBackgroundColor(colors.red)
		term.setTextColor(colors.white)
		term.setCursorPos(math.floor(cx - (#errMessage + 2)*0.5 + 0.5), screenHeight-5)
		term.write(" " .. errMessage .. " ")
	end

	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.black)
	term.setCursorPos(x1+8, 5)
	term.write(newWorldName)

	if selectedField == 0 then
		term.setCursorBlink(true)
	elseif selectedField >= 1 and selectedField <= #fields then
		local j = selectedField
		local i = (j - 1) % 2 + 1
		local k = math.floor((j-1) / 2)
		local x = (x1+largestWidth)+2
		local length = cx - x
		if k == 1 then x = x + largestWidth + length + 2 + 1 end
		local dx = #fieldsValues[j] > 0 and #fieldsValues[j]:sub(-(length-1)) or 0
		term.setCursorPos(x + dx, 8+i*2-1)
		term.setCursorBlink(true)
	end

	bigMenuWindow.setVisible(true)
end

local function createWorld()
	newWorldName = ""

	local fields        = {"Seed", "Chunk Size", "Terr Height", "Smoothness"}
	local fieldsDefault = {"random", 16, 12, 2}
	local fieldsValues  = {"", "", "", ""}
	local selectedField = 0
	local errMessage    = ""

	local largestWidth = 0
	for i = 1, #fields do
		if #fields[i] > largestWidth then largestWidth = #fields[i] end
	end

	while true do
		renderCreateWorld(fields, fieldsDefault, fieldsValues, selectedField, errMessage)
		local event, key, x, y = os.pullEvent()

		if event == "key" then
			if key == keys.backspace then
				if selectedField == 0 then
					newWorldName = newWorldName:sub(1, #newWorldName-1)
				elseif selectedField >= 1 and selectedField <= #fields then
					fieldsValues[selectedField] = fieldsValues[selectedField]:sub(1, #fieldsValues[selectedField]-1)
				end
			elseif key == keys.grave then
				term.setCursorBlink(false)
				return false
			elseif key == keys.tab then
				selectedField = (selectedField + 1) % (#fields + 1)
			end

		elseif event == "char" then
			if selectedField == 0 then
				newWorldName = (newWorldName .. key):sub(1, 20)
			elseif selectedField >= 1 and selectedField <= #fields then
				fieldsValues[selectedField] = (fieldsValues[selectedField] .. key):sub(1, 20)
			end

		elseif event == "mouse_click" then
			local x1 = math.floor(4 +             math.max(0, screenWidth - 51)*0.5)
			local x2 = math.floor(screenWidth-3 - math.max(0, screenWidth - 51)*0.5)
			local cx = math.floor(screenWidth*0.5+0.5)

			if x >= x1 and y >= screenHeight-3 and x <= cx-1 and y <= screenHeight-1 then
				local val1 = #fieldsValues[1] > 0 and fieldsValues[1] or fieldsDefault[1]
				local val2 = #fieldsValues[2] > 0 and fieldsValues[2] or fieldsDefault[2]
				local val3 = #fieldsValues[3] > 0 and fieldsValues[3] or fieldsDefault[3]
				local val4 = #fieldsValues[4] > 0 and fieldsValues[4] or fieldsDefault[4]

				if val1 ~= "random" and not tonumber(val1) then
					errMessage = "Seed must be a number"
				elseif not tonumber(val2) then
					errMessage = "Chunk size must be a number"
				elseif tonumber(val2) <= 1 then
					errMessage = "Chunk size must be at least 2"
				elseif not tonumber(val3) then
					errMessage = "Terrain height must be a number"
				elseif tonumber(val3) <= 0 then
					errMessage = "Terrain height must be larger than 0"
				elseif not tonumber(val4) then
					errMessage = "Terrain smoothness must be a number"
				elseif tonumber(val3) < 0 then
					errMessage = "Terrain smoothness cannot be negative"
				elseif tonumber(val2) / 2^(tonumber(val4)+1) % 1 > 0 then
					errMessage = "Chunk size must be divisible by 2^(smooth. + 1)"
				elseif fs.exists("worlds/" .. newWorldName) then
					errMessage = "World with that name already exists"
				else
					math.randomseed(os.clock())
					term.setCursorBlink(false)
					return true, newWorldName,
						val1 == "random" and math.random(0, 999999) or tonumber(val1),
						tonumber(val2),
						tonumber(val3),
						tonumber(val4)
				end
			elseif x >= cx+1 and y >= screenHeight-3 and x <= x2 and y <= screenHeight-1 then
				term.setCursorBlink(false)
				return false
			else
				if x >= x1+7 and y >= 4 and x <= x2 and y <= 6 then
					selectedField = 0
				else
					for j = 1, #fields do
						local i = (j - 1) % 2 + 1
						local k = math.floor((j-1) / 2)
						local fx = (x1+largestWidth)+2
						local length = cx - fx
						if k == 1 then fx = fx + largestWidth + length + 2 + 1; length = x2 - fx + 1 end
						if x >= fx and x <= fx + length - 1 and (y == 8+i*2 or y == 8+i*2-1) then
							selectedField = j
							break
						end
					end
				end
			end

		elseif event == "term_resize" then
			screenWidth, screenHeight = termResize()
		end
	end
end

local function getWorldTimestamp(wId)
	local playerPath = "worlds/" .. wId .. "/player.txt"
	if not fs.exists(playerPath) then return 0 end
	local f   = fs.open(playerPath, "r")
	local raw = f.readAll()
	f.close()
	local data = textutils.unserialise(raw)
	return data and data.lastActive or 0
end

local function getSortedWorlds()
	local worlds     = fs.list("worlds")
	local timestamps = {}
	table.sort(worlds, function(a, b)
		timestamps[a] = timestamps[a] or getWorldTimestamp(a)
		timestamps[b] = timestamps[b] or getWorldTimestamp(b)
		return timestamps[a] > timestamps[b]
	end)
	return worlds
end

local function confirmDelete(wId)
	screenWidth, screenHeight = term.getSize()
	bigMenuWindow.setVisible(false)
	local cx = math.floor(screenWidth*0.5+0.5)
	local msg1 = "Delete world \"" .. wId .. "\"?"
	local msg2 = "This cannot be undone!"
	term.setBackgroundColor(colors.brown)
	term.clear()
	term.setTextColor(colors.white)
	term.setCursorPos(math.floor(cx - #msg1*0.5 + 0.5), math.floor(screenHeight*0.5) - 2)
	term.write(msg1)
	term.setTextColor(colors.orange)
	term.setCursorPos(math.floor(cx - #msg2*0.5 + 0.5), math.floor(screenHeight*0.5))
	term.write(msg2)
	local bx1 = math.floor(cx - 12)
	local bx2 = math.floor(cx + 1)
	renderer.drawButton(term, bx1,  screenHeight-3, cx-2,        screenHeight-1, "Delete", colors.red,  colors.orange,    colors.white)
	renderer.drawButton(term, cx+1, screenHeight-3, bx1+23, screenHeight-1, "Cancel", colors.gray, colors.lightGray, colors.white)
	bigMenuWindow.setVisible(true)
	while true do
		local event, btn, mx, my = os.pullEvent()
		if event == "mouse_click" then
			if mx >= bx1 and mx <= cx-2 and my >= screenHeight-3 and my <= screenHeight-1 then
				return true   -- confirmed delete
			end
			if mx >= cx+1 and my >= screenHeight-3 and my <= screenHeight-1 then
				return false  -- cancelled
			end
		elseif event == "key" then
			if btn == keys.escape or btn == keys.grave then return false end
			if btn == keys.enter then return true end
		end
	end
end

local function renderWorldSelection()
	screenWidth, screenHeight = term.getSize()
	bigMenuWindow.setVisible(false)

	term.setBackgroundColor(colors.brown)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(math.floor(screenWidth*0.5 - #("World Selection")*0.5 + 0.5), 2)
	term.write("World Selection")

	local x1 = math.floor(4 +             math.max(0, screenWidth - 51)*0.5)
	local x2 = math.floor(screenWidth-3 - math.max(0, screenWidth - 51)*0.5)
	local cx = math.floor(screenWidth*0.5+0.5)

	renderer.drawNiceBorder(term, x1, 4, x2, screenHeight-5, colors.black, colors.orange)
	renderer.drawButton(term, x1,   screenHeight-3, cx-1, screenHeight-1, "New World",          colors.gray, colors.lightGray, colors.white)
	renderer.drawButton(term, cx+1, screenHeight-3, x2,   screenHeight-1, "Back to Main Menu",  colors.gray, colors.lightGray, colors.white)

	local worldGradient = paintutils.loadImage("worldGradient.nfp")
	if #worldGradient[#worldGradient] == 0 then
		worldGradient[#worldGradient] = nil
	end
	local bWorldGradient = blittle.shrink(worldGradient, colors.brown)

	local saved = term.redirect(worldListWindow)
		local width = select(1, term.getSize())
		term.setBackgroundColor(colors.black)
		term.clear()

		for i, wId in ipairs(getSortedWorlds()) do
			local worldY = 1 + (i-1)*4 - worldSelectionScroll
			renderer.drawNiceBorder(term, 1, worldY, width, worldY+2, colors.gray, colors.brown)
			blittle.draw(bWorldGradient, width-11, worldY)
			term.setBackgroundColor(colors.gray)
			term.setTextColor(colors.white)
			term.setCursorPos(2, worldY+1)
			term.write(wId)
			term.setBackgroundColor(colors.red)
			term.setTextColor(colors.white)
			term.setCursorPos(width-13, worldY+1)
			term.write(" Del ")
			term.setBackgroundColor(colors.brown)
			term.setTextColor(colors.lime)
			term.setCursorPos(width-7, worldY+1)
			term.write(" Play ")
		end
	term.redirect(saved)

	worldListWindow.setVisible(true)
	bigMenuWindow.setVisible(true)
	worldListWindow.setVisible(false)
end

function ui.worldSelection()
	worldSelectionScroll = 0

	while true do
		renderWorldSelection()
		local event, key, x, y = os.pullEvent()

		if event == "key" then
			if key == keys.grave then return nil end

		elseif event == "mouse_click" then
			local x1 = math.floor(4 +             math.max(0, screenWidth - 51)*0.5)
			local x2 = math.floor(screenWidth-3 - math.max(0, screenWidth - 51)*0.5)
			local cx = math.floor(screenWidth*0.5+0.5)

			if x >= x1 and y >= screenHeight-3 and x <= cx-1 and y <= screenHeight-1 then
				worldSelectionScroll = 0
				local success, wId, seedW, chunkSizeW, maxHTerrW, smoothW = createWorld()
				if success and #wId > 0 then
					cfg.seed             = seedW
					cfg.chunkSize        = chunkSizeW
					cfg.maxHeightTerrain = maxHTerrW
					cfg.maxHeightChunk   = maxHTerrW + 7
					cfg.terrainSmoothness = smoothW

					local file = fs.open("worlds/" .. wId .. "/world.txt", "w")
					file.write(textutils.serialise({
						seed             = cfg.seed,
						chunkSize        = cfg.chunkSize,
						maxHeightTerrain = cfg.maxHeightTerrain,
						maxHeightChunk   = cfg.maxHeightChunk,
						terrainSmoothness = cfg.terrainSmoothness,
					}))
					file.close()
					sleep(0)
					return wId
				end

			elseif x >= cx+1 and y >= screenHeight-3 and x <= x2 and y <= screenHeight-1 then
				return nil  -- Back to main menu

			elseif x >= x1+1 and y >= 5 and x <= x2 and y <= screenHeight-5 then
				local dx    = x1+1-1
				local dy    = 5-1
				local width = select(1, worldListWindow.getSize())
				for i, wId in ipairs(getSortedWorlds()) do
					local worldY = 1 + (i-1)*4 - worldSelectionScroll + dy
					if math.abs(worldY + 1 - y) <= 1 then
						if x >= dx + width - 7 and x <= dx + width then
							worldSelectionScroll = 0
							return wId
						end
						if x >= dx + width - 14 and x <= dx + width - 8 then
							if confirmDelete(wId) then
								local function rmDir(path)
									for _, f in ipairs(fs.list(path)) do
										local fp = path .. "/" .. f
										if fs.isDir(fp) then rmDir(fp)
										else fs.delete(fp) end
									end
									fs.delete(path)
								end
								rmDir("worlds/" .. wId)
							end
						end
					end
				end
			end

		elseif event == "mouse_scroll" then
			worldSelectionScroll = math.max(0, worldSelectionScroll + key)

		elseif event == "term_resize" then
			screenWidth, screenHeight = termResize()
		end
	end
end

-- Mod config screen — all mods, enable/disable toggles, editable config fields.

local function getDisabledMods()
    local disabled = {}
    if fs.exists("CCMods/disabled.txt") then
        local f = fs.open("CCMods/disabled.txt", "r")
        local raw = f.readAll()
        f.close()
        for line in raw:gmatch("[^\n]+") do
            local ns = line:match("^%s*(.-)%s*$")
            if ns ~= "" then disabled[ns] = true end
        end
    end
    return disabled
end

local function saveDisabledMods(disabled)
    local lines = {}
    for ns in pairs(disabled) do lines[#lines+1] = ns end
    local f = fs.open("CCMods/disabled.txt", "w")
    f.write(table.concat(lines, "\n") .. (next(lines) and "\n" or ""))
    f.close()
end

local function renderModConfig(mods, selectedMod, modKeys, modValues, modDefaults, modEnums, disabledMods, selectedField, errMsg, modListScroll)
    screenWidth, screenHeight = term.getSize()
    bigMenuWindow.setVisible(false)

    local cx = math.floor(screenWidth*0.5+0.5)
    local x1 = math.floor(4 + math.max(0, screenWidth - 51)*0.5)
    local x2 = math.floor(screenWidth-3 - math.max(0, screenWidth - 51)*0.5)

    term.setBackgroundColor(colors.brown)
    term.clear()
    term.setTextColor(colors.white)
    term.setCursorPos(math.floor(cx - #("Mod Config")*0.5 + 0.5), 2)
    term.write("Mod Config")

    local listW    = 18
    local listX1   = x1
    local listX2   = x1 + listW - 1
    local panelX1  = listX2 + 2
    local panelX2  = x2
    local listH    = screenHeight - 8   -- rows available for mod entries

    renderer.drawNiceBorder(term, listX1, 4, listX2, screenHeight-5, colors.black, colors.orange)

    for i = 1, listH do
        local modIdx = i + modListScroll
        local m = mods[modIdx]
        if not m then break end
        local fy = 4 + i
        local isSelected = (modIdx == selectedMod)
        local isDisabled = disabledMods[m.ns]
        term.setCursorPos(listX1+1, fy)
        term.setBackgroundColor(isSelected and colors.orange or colors.black)
        term.setTextColor(isDisabled and colors.red or (isSelected and colors.black or colors.gray))
        local label = m.ns:sub(1, listW - 2)
        term.write(label .. string.rep(" ", listW - 2 - #label))
    end
    if modListScroll > 0 then
        term.setCursorPos(listX1 + math.floor(listW/2), 5)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.orange)
        term.write("^")
    end
    if modListScroll + listH < #mods then
        term.setCursorPos(listX1 + math.floor(listW/2), screenHeight-6)
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.orange)
        term.write("v")
    end

    local mod = mods[selectedMod]
    if mod and panelX1 < panelX2 then
        local isDisabled = disabledMods[mod.ns]
        renderer.drawNiceBorder(term, panelX1, 4, panelX2, screenHeight-5, colors.black, colors.orange)

        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.setCursorPos(panelX1+2, 5)
        term.write(mod.ns)

        local toggleLabel = isDisabled and "[ DISABLED ]" or "[  ENABLED  ]"
        local toggleColor = isDisabled and colors.red    or colors.lime
        term.setTextColor(toggleColor)
        term.setCursorPos(panelX2 - #toggleLabel - 1, 5)
        term.write(toggleLabel)

        term.setCursorPos(panelX1+1, 6)
        term.setTextColor(colors.orange)
        term.write(string.rep(string.char(131), panelX2 - panelX1 - 1))

        local cfgKeys    = modKeys[mod.ns]    or {}
        local cfgValues  = modValues[mod.ns]  or {}
        local cfgDefault = modDefaults[mod.ns] or {}
        local cfgEnums   = modEnums[mod.ns]   or {}

        if #cfgKeys == 0 then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.gray)
            term.setCursorPos(panelX1+2, 8)
            term.write("No configurable options.")
        else
            local panelW = panelX2 - panelX1 - 3
            for j, k in ipairs(cfgKeys) do
                local fy = 7 + (j-1)*2
                if fy >= screenHeight-5 then break end

                local val      = cfgValues[k] or cfgDefault[k] or ""
                local isFocused = (selectedField == j)
                local enumVals  = cfgEnums[k]

                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
                term.setCursorPos(panelX1+2, fy)
                term.write(k .. ":")

                local vx = panelX1 + 2 + #k + 2
                local vw = panelX2 - vx - 2

                if enumVals then
                    term.setBackgroundColor(colors.black)
                    term.setTextColor(isFocused and colors.orange or colors.gray)
                    term.setCursorPos(vx, fy)
                    term.write("<")
                    term.setTextColor(isFocused and colors.white or colors.lime)
                    local display = val:sub(1, vw-4)
                    local pad = math.max(0, vw-4 - #display)
                    term.write(" " .. display .. string.rep(" ", pad))
                    term.setTextColor(isFocused and colors.orange or colors.gray)
                    term.write(">")
                else
                    term.setBackgroundColor(isFocused and colors.gray or colors.black)
                    term.setCursorPos(vx, fy)
                    if #val > 0 then
                        term.setTextColor(colors.lime)
                        term.write(val:sub(-(vw)) .. string.rep(" ", math.max(0, vw - #val)))
                    else
                        term.setTextColor(colors.gray)
                        local ph = #(cfgDefault[k] or "") > 0 and cfgDefault[k] or "(empty)"
                        term.write(ph:sub(-(vw)) .. string.rep(" ", math.max(0, vw - #ph)))
                    end
                    if isFocused then
                        term.setCursorPos(vx + math.min(#val, vw), fy)
                        term.setCursorBlink(true)
                    end
                end
            end
        end
    end

    if #errMsg > 0 then
        local isErr = errMsg:find("^Error") or errMsg:find("^!")
        term.setBackgroundColor(isErr and colors.red or colors.brown)
        term.setTextColor(colors.white)
        term.setCursorPos(math.floor(cx - (#errMsg+2)*0.5 + 0.5), screenHeight-4)
        term.write(" " .. errMsg .. " ")
    end

    renderer.drawButton(term, x1,   screenHeight-3, cx-1, screenHeight-1, "Save",  colors.gray, colors.lightGray, colors.white)
    renderer.drawButton(term, cx+1, screenHeight-3, x2,   screenHeight-1, "Back",  colors.gray, colors.lightGray, colors.white)

    bigMenuWindow.setVisible(true)
end

-- Static enum values for known config keys.
local knownEnums = {
    cave_type = { "classic", "none" },
}

local function modConfigScreen()
    local mods        = {}
    local modKeys     = {}
    local modValues   = {}
    local modDefaults = {}
    local modEnums    = {}
    local disabledMods = getDisabledMods()

    if fs.exists("CCMods") then
        for _, entry in ipairs(fs.list("CCMods")) do
            local ns = entry:match("^(.+)%.ccmod$") or entry
            if ns ~= "disabled" then
                local cfgPath = fs.isDir("CCMods/" .. entry)
                                and "CCMods/" .. entry .. "/config.txt"
                                or  "CCMods/" .. ns .. ".config.txt"

                mods[#mods+1]   = { ns = ns, cfgPath = fs.exists(cfgPath) and cfgPath or nil }
                modKeys[ns]     = {}
                modValues[ns]   = {}
                modDefaults[ns] = {}
                modEnums[ns]    = {}

                if fs.exists(cfgPath) then
                    local f   = fs.open(cfgPath, "r")
                    local raw = f.readAll()
                    f.close()
                    for line in raw:gmatch("[^\n]+") do
                        local k, v = line:match("^([%w_]+)%s*=%s*(.+)$")
                        if k and v then
                            v = v:match("^%s*(.-)%s*$")
                            modKeys[ns][#modKeys[ns]+1] = k
                            modDefaults[ns][k] = v
                            modValues[ns][k]   = nil
                            if knownEnums[k] then
                                modEnums[ns][k] = knownEnums[k]
                            end
                        end
                    end
                end
            end
        end
    end

    if #mods == 0 then
        screenWidth, screenHeight = term.getSize()
        bigMenuWindow.setVisible(false)
        term.setBackgroundColor(colors.brown)
        term.clear()
        term.setTextColor(colors.white)
        local cx = math.floor(screenWidth*0.5+0.5)
        term.setCursorPos(math.floor(cx - 12), math.floor(screenHeight*0.5))
        term.write("No mods found in CCMods/")
        term.setCursorPos(math.floor(cx - 12), math.floor(screenHeight*0.5)+2)
        term.setTextColor(colors.gray)
        term.write("Press any key to go back.")
        bigMenuWindow.setVisible(true)
        os.pullEvent("key")
        return
    end

    local selectedMod   = 1
    local selectedField = 0
    local errMsg        = ""
    local modListScroll = 0
    local hasUnsaved    = false

    local function cycleEnum(ns, k, dir)
        local enumVals = modEnums[ns] and modEnums[ns][k]
        if not enumVals then return end
        local cur = modValues[ns][k] or modDefaults[ns][k] or enumVals[1]
        local idx = 1
        for i, v in ipairs(enumVals) do if v == cur then idx = i; break end end
        idx = ((idx - 1 + dir) % #enumVals) + 1
        modValues[ns][k] = enumVals[idx]
        hasUnsaved = true
    end

    while true do
        local mod = mods[selectedMod]
        renderModConfig(mods, selectedMod, modKeys, modValues, modDefaults, modEnums, disabledMods, selectedField, errMsg, modListScroll)

        local event, key, mx, my = os.pullEvent()
        errMsg = ""

        if event == "key" then
            if key == keys.grave then
                if hasUnsaved then
                    errMsg = "Unsaved changes! Save first or press ` again."
                    hasUnsaved = false   -- second press exits without saving
                else
                    term.setCursorBlink(false)
                    return
                end
            elseif key == keys.tab then
                local nkeys = #(modKeys[mod.ns] or {})
                selectedField = nkeys > 0 and (selectedField % nkeys) + 1 or 0
            elseif key == keys.backspace and selectedField >= 1 then
                local k = modKeys[mod.ns] and modKeys[mod.ns][selectedField]
                if k and not modEnums[mod.ns][k] then
                    local v = modValues[mod.ns][k] or modDefaults[mod.ns][k] or ""
                    modValues[mod.ns][k] = v:sub(1, -2)
                    hasUnsaved = true
                end
            elseif key == keys.left then
                if selectedField >= 1 then
                    local k = modKeys[mod.ns] and modKeys[mod.ns][selectedField]
                    if k and modEnums[mod.ns][k] then
                        cycleEnum(mod.ns, k, -1)
                    else
                        selectedMod   = math.max(1, selectedMod - 1)
                        selectedField = 0
                        term.setCursorBlink(false)
                    end
                else
                    selectedMod   = math.max(1, selectedMod - 1)
                    selectedField = 0
                    term.setCursorBlink(false)
                end
            elseif key == keys.right then
                if selectedField >= 1 then
                    local k = modKeys[mod.ns] and modKeys[mod.ns][selectedField]
                    if k and modEnums[mod.ns][k] then
                        cycleEnum(mod.ns, k, 1)
                    else
                        selectedMod   = math.min(#mods, selectedMod + 1)
                        selectedField = 0
                        term.setCursorBlink(false)
                    end
                else
                    selectedMod   = math.min(#mods, selectedMod + 1)
                    selectedField = 0
                    term.setCursorBlink(false)
                end
            elseif key == keys.up then
                selectedMod = math.max(1, selectedMod - 1)
                selectedField = 0
                if selectedMod <= modListScroll then
                    modListScroll = math.max(0, selectedMod - 1)
                end
                term.setCursorBlink(false)
            elseif key == keys.down then
                selectedMod = math.min(#mods, selectedMod + 1)
                selectedField = 0
                local listH = screenHeight - 8
                if selectedMod > modListScroll + listH then
                    modListScroll = selectedMod - listH
                end
                term.setCursorBlink(false)
            end

        elseif event == "char" then
            if selectedField >= 1 then
                local k = modKeys[mod.ns] and modKeys[mod.ns][selectedField]
                if k and not (modEnums[mod.ns] and modEnums[mod.ns][k]) then
                    local cur = modValues[mod.ns][k] or modDefaults[mod.ns][k] or ""
                    modValues[mod.ns][k] = (cur .. key):sub(1, 30)
                    hasUnsaved = true
                end
            end

        elseif event == "mouse_click" then
            local x1c = math.floor(4 + math.max(0, screenWidth - 51)*0.5)
            local x2c = math.floor(screenWidth-3 - math.max(0, screenWidth - 51)*0.5)
            local cx  = math.floor(screenWidth*0.5+0.5)
            local listW   = 18
            local listX1  = x1c
            local listX2  = x1c + listW - 1
            local panelX1 = listX2 + 2
            local panelX2 = x2c
            local listH   = screenHeight - 8

            if mx >= listX1 and mx <= listX2 and my >= 5 and my <= 4 + listH then
                local modIdx = (my - 4) + modListScroll
                if modIdx >= 1 and modIdx <= #mods then
                    selectedMod   = modIdx
                    selectedField = 0
                    term.setCursorBlink(false)
                end
            end

            if mod then
                local toggleLabel = disabledMods[mod.ns] and "[ DISABLED ]" or "[  ENABLED  ]"
                local toggleX = panelX2 - #toggleLabel - 1
                if my == 5 and mx >= toggleX and mx <= panelX2 - 1 then
                    if disabledMods[mod.ns] then disabledMods[mod.ns] = nil
                    else disabledMods[mod.ns] = true end
                    hasUnsaved = true
                    errMsg = "Restart to apply enable/disable changes."
                end

                local cfgKeys = modKeys[mod.ns] or {}
                for j, k in ipairs(cfgKeys) do
                    local fy = 7 + (j-1)*2
                    if my == fy then
                        if modEnums[mod.ns] and modEnums[mod.ns][k] then
                            local vx = panelX1 + 2 + #k + 2
                            if mx == vx then
                                cycleEnum(mod.ns, k, -1)
                            else
                                cycleEnum(mod.ns, k, 1)
                            end
                        else
                            selectedField = j
                        end
                        break
                    end
                end
            end

            if mx >= x1c and mx <= cx-1 and my >= screenHeight-3 and my <= screenHeight-1 then
                for _, m in ipairs(mods) do
                    if m.cfgPath and modKeys[m.ns] then
                        local lines = {}
                        for _, k in ipairs(modKeys[m.ns]) do
                            local val = modValues[m.ns][k] or modDefaults[m.ns][k] or ""
                            lines[#lines+1] = k .. "=" .. val
                        end
                        local f = fs.open(m.cfgPath, "w")
                        f.write(table.concat(lines, "\n") .. "\n")
                        f.close()
                    end
                end
                saveDisabledMods(disabledMods)
                hasUnsaved = false
                errMsg = "Saved! Changes apply on next world load."
            end

            if mx >= cx+1 and mx <= x2c and my >= screenHeight-3 and my <= screenHeight-1 then
                if hasUnsaved then
                    errMsg = "You have unsaved changes! Save first or press ` to discard."
                else
                    term.setCursorBlink(false)
                    return
                end
            end

        elseif event == "mouse_scroll" then
            local listH = screenHeight - 8
            modListScroll = math.max(0, math.min(#mods - listH, modListScroll + key))

        elseif event == "term_resize" then
            screenWidth, screenHeight = termResize()
        end
    end
end

local function renderMainMenu()
    screenWidth, screenHeight = term.getSize()
    term.setBackgroundColor(colors.brown)
    term.clear()

    local x1 = 4 + math.max(0, screenWidth-51)*0.5
    local x2 = screenWidth-3 - math.max(0, screenWidth-51)*0.5
    renderer.drawButton(term, x1, 8,    x2, 8+2,   "Singleplayer", colors.gray, colors.lightGray, colors.white)
    renderer.drawButton(term, x1, 8+4,  x2, 8+2+4, "Mod Config",   colors.gray, colors.lightGray, colors.white)
    renderer.drawButton(term, x1, 8+8,  x2, 8+2+8, "Quit",         colors.gray, colors.lightGray, colors.white)

    term.setBackgroundColor(colors.brown)
    term.setTextColor(colors.white)
    term.setCursorPos(1, screenHeight)
    term.write("CCMinecraft 1.0 by Xella | Pineforge 0.1 ")

    bigMenuWindow.setVisible(false)
    bigMenuWindow.setVisible(true)
    logoWindow.setVisible(false)
    logoWindow.setVisible(true)
end

function ui.mainMenu()
    while true do
        renderMainMenu()

        local event, key, x, y = nil, nil, nil, nil
        parallel.waitForAny(runLogoAnimation, function()
            while true do
                local se, sk, sx, sy = os.pullEvent()
                if se == "mouse_click" then
                    local x1 = 4 + math.max(0, screenWidth-51)*0.5
                    local x2 = screenWidth-3 - math.max(0, screenWidth-51)*0.5
                    if sx >= x1 and sx <= x2 then
                        if sy >= 8 and sy <= 8+2 then
                            event, key, x, y = se, sk, sx, sy; break
                        elseif sy >= 8+4 and sy <= 8+2+4 then
                            event, key, x, y = se, sk, sx, sy; break
                        elseif sy >= 8+8 and sy <= 8+2+8 then
                            event, key, x, y = se, sk, sx, sy; break
                        end
                    end
                elseif se == "term_resize" then
                    betterblittle.drawBuffer(logo, logoWindow)
                    event, key, x, y = se, sk, sx, sy; break
                end
            end
        end)

        renderMainMenu()
        local i = 0
        while true do
            if not event or i > 0 then
                event, key, x, y = os.pullEvent()
            end

            if event == "mouse_click" then
                local x1 = 4 + math.max(0, screenWidth-51)*0.5
                local x2 = screenWidth-3 - math.max(0, screenWidth-51)*0.5
                if x >= x1 and x <= x2 then
                    if y >= 8 and y <= 8+2 then
                        logoWindow.setVisible(false)
                        local worldId = ui.worldSelection()
                        if worldId then return worldId end
                        break

                    elseif y >= 8+4 and y <= 8+2+4 then
                        modConfigScreen()
                        break

                    elseif y >= 8+8 and y <= 8+2+8 then
                        return nil  -- quit
                    end
                end

            elseif event == "term_resize" then
                screenWidth, screenHeight = termResize()
            end
            i = i + 1
        end
    end
end

return ui
