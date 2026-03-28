-- Minecraft.lua
-- Entry point. Wires all modules together and runs the game loop.

local path = "/" .. shell.dir()

local Pine3D        = require("Pine3D-minified")
local betterblittle = require("betterblittle")
local noise         = require("noise")
os.loadAPI(path .. "/blittle")

local config    = require("config")
local world     = require("world")
local player    = require("player")
local renderer  = require("renderer")
local input     = require("input")
local ui        = require("ui")
local PineForge = require("PineForge")
local GUI       = require("gui")
local Inventory = require("inventory")

if not fs.exists("worlds") then
	fs.makeDir("worlds")
end

-- Shared gameplay flags, passed by reference to all modules that need them.
local state = {
	pauseMenu     = false,
	drawHotbar    = config.drawHotbar,
	viewFPS       = config.viewFPS,
	blittleOn     = config.blittleOn,
	selectedBlock = config.selectedBlock,
	f3MenuOpen    = false,
	guiOpen       = false,
}

local keysDown = {}
local objects  = {}

local screenWidth, screenHeight = term.getSize()
local ThreeDFrame = Pine3D.newFrame()

local menusWindow = window.create(
	term.current(),
	1 + math.max(0, screenWidth*0.5-20),
	2 + math.max(0, screenHeight*0.5-7),
	screenWidth - math.max(0, screenWidth*0.5-20)*2,
	screenHeight - 1 - math.max(0, screenHeight*0.5-6)*2
)

local bigMenuWindow = window.create(term.current(), 1, 1, screenWidth, screenHeight)
local oldTerm = term.redirect(bigMenuWindow)

local x1 = math.floor(4 +             math.max(0, screenWidth - 51)*0.5)
local x2 = math.floor(screenWidth-3 - math.max(0, screenWidth - 51)*0.5)
local worldListWindow = window.create(term.current(), x1+1, 5, x2 - (x1+1), screenHeight-5-5)

local logo = paintutils.loadImage("logo.nfp")
for y = 1, math.ceil(#logo / 3)*3 do
	if not logo[y] then logo[y] = {} end
	for x = 1, math.ceil(#logo[7] / 2)*2 do
		if not logo[y][x] or logo[y][x] == 0 then
			logo[y][x] = colors.brown
		end
	end
end
local logoWindow = window.create(
	term.current(),
	math.floor(screenWidth*0.5 - 18 + 0.5),
	1,
	#logo[7]/2,
	#logo/3,
	false
)
betterblittle.drawBuffer(logo, logoWindow)

local function termResize()
	screenWidth, screenHeight = oldTerm.getSize()

	term.setBackgroundColor(colors.lightBlue)
	term.clear()

	if state.viewFPS then
		ThreeDFrame:setSize(1, 2, screenWidth, screenHeight)
	else
		ThreeDFrame:setSize(1, 1, screenWidth, screenHeight)
	end

	menusWindow.reposition(
		1 + math.max(0, screenWidth*0.5-20),
		2 + math.max(0, screenHeight*0.5-7),
		screenWidth - math.max(0, screenWidth*0.5-20)*2,
		screenHeight - 1 - math.max(0, screenHeight*0.5-6)*2
	)
	bigMenuWindow.reposition(1, 1, screenWidth, screenHeight)

	local nx1 = math.floor(4 +             math.max(0, screenWidth - 51)*0.5)
	local nx2 = math.floor(screenWidth-3 - math.max(0, screenWidth - 51)*0.5)
	worldListWindow.reposition(nx1+1, 5, nx2 - (nx1+1), screenHeight-5-5)
	logoWindow.reposition(math.floor(screenWidth*0.5 - 18 + 0.5), 1, #logo[7]/2, #logo/3)

	return screenWidth, screenHeight
end

world.init({
	config      = config,
	Pine3D      = Pine3D,
	noise       = noise,
	ThreeDFrame = ThreeDFrame,
	objects     = objects,
	worldId     = "",
	PineForge   = PineForge,
})

GUI.init({ state = state, screenWidth = screenWidth, screenHeight = screenHeight, config = config, nativeTerm = oldTerm })

PineForge.init({ config = config, world = world, GUI = GUI })
PineForge.loadMods()
world.refreshModModels()

player.init({
	config      = config,
	ThreeDFrame = ThreeDFrame,
	world       = world,
	keysDown    = keysDown,
	PineForge   = PineForge,
})

renderer.init({
	config      = config,
	ThreeDFrame = ThreeDFrame,
	objects     = objects,
	state       = state,
})

input.init({
	config       = config,
	world        = world,
	player       = player,
	renderer     = renderer,
	ThreeDFrame  = ThreeDFrame,
	objects      = objects,
	state        = state,
	keysDown     = keysDown,
	menusWindow  = menusWindow,
	screenWidth  = screenWidth,
	screenHeight = screenHeight,
	termResize   = termResize,
	GUI          = GUI,
	PineForge    = PineForge,
})

ui.init({
	config          = config,
	renderer        = renderer,
	betterblittle   = betterblittle,
	blittle         = blittle,
	bigMenuWindow   = bigMenuWindow,
	menusWindow     = menusWindow,
	worldListWindow = worldListWindow,
	logoWindow      = logoWindow,
	logo            = logo,
	screenWidth     = screenWidth,
	screenHeight    = screenHeight,
	oldTerm         = oldTerm,
	termResize      = termResize,
})

local function openWorld(worldId)
	state.pauseMenu = false

	local worldFile = fs.open("worlds/" .. worldId .. "/world.txt", "r")
	local worldData = textutils.unserialise(worldFile.readAll())
	worldFile.close()

	-- World settings are applied through world.setWorldId so config
	-- stays clean for the next world that opens.
	world.setWorldId(worldId, worldData)

	player.load(worldId)
	player.save(worldId)
	Inventory.loadPlayer(worldId)

	world.updateWorld(player.camera)

	-- GUI screens run inside the input coroutine via blocking event loops,
	-- so parallel never needs to restart when a menu opens.
	local function gameUpdate()
		local lastTime = os.clock()
		while true do
			local now = os.clock()
			local dt  = now - lastTime
			if not state.pauseMenu then
				player.handleMovement(dt)
			else
				sleep(0.05)
			end
			lastTime = now
			os.queueEvent("test")
			os.pullEventRaw("test")
		end
	end

	local function chunkLoading()
		while true do
			world.stepChunkQueue(player.camera)
			sleep(0.1)
		end
	end

	parallel.waitForAny(
		input.inputLoop,
		gameUpdate,
		function() renderer.renderLoop(menusWindow) end,
		chunkLoading
	)
end

local function writeDebug(msg)
	local f = fs.open("debug.txt", "a")
	f.write(msg .. "\n")
	f.close()
end

if fs.exists("debug.txt") then fs.delete("debug.txt") end

local ok, err = pcall(function()
	while true do
		local worldId = ui.mainMenu()

		if not worldId then
			term.redirect(oldTerm)
			term.setBackgroundColor(colors.black)
			term.setTextColor(colors.white)
			term.clear()
			term.setCursorPos(1, 1)
			print("Thanks for playing Xella's CC:Minecraft!")
			break
		end

		-- Warn before entering if any mod touched api.raw
		if not PineForge.checkRawWarning(oldTerm) then
			-- player declined
		else
			local depsOk, depProblems = PineForge.checkDependencies()
			if not depsOk then
				term.redirect(oldTerm)
				term.setBackgroundColor(colors.black)
				term.clear()
				term.setCursorPos(1, 1)
				term.setTextColor(colors.red)
				term.write("[ Missing Mod Dependencies ]")
				term.setCursorPos(1, 3)
				term.setTextColor(colors.white)
				term.write("Cannot load world — fix these before continuing:")
				local row = 5
				for _, prob in ipairs(depProblems) do
					term.setCursorPos(1, row)
					term.setTextColor(colors.orange)
					term.write("  " .. prob.mod .. " needs:")
					row = row + 1
					for _, dep in ipairs(prob.missing) do
						term.setCursorPos(1, row)
						term.setTextColor(colors.red)
						term.write("    - " .. dep .. "  (not installed/loaded)")
						row = row + 1
					end
					row = row + 1
				end
				term.setCursorPos(1, row + 1)
				term.setTextColor(colors.yellow)
				term.write("Press any key to return to the menu.")
				os.pullEvent("key")
				term.redirect(bigMenuWindow)
			else
				PineForge.setWorldId(worldId)
				openWorld(worldId)
				PineForge.setWorldId(nil)

				world.saveAll(player.camera)
				player.save(worldId)
				Inventory.savePlayer(worldId)
				GUI.closeAll()
			end
		end
	end
end)

if not ok then
	local trace = debug and debug.traceback and debug.traceback(tostring(err), 2) or tostring(err)
	writeDebug("=== CRASH ===")
	writeDebug(trace)

	term.redirect(oldTerm)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.red)
	term.clear()
	term.setCursorPos(1, 1)
	print("PineForged crashed!")
	print("")
	term.setTextColor(colors.white)
	print(tostring(err))
	print("")
	term.setTextColor(colors.yellow)
	print("Full trace saved to: debug.txt")
	print("Press any key.")
	os.pullEvent("key")
end
