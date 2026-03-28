-- input.lua
-- Keyboard and mouse event handling during gameplay.

local input = {}

local cfg, world, player, renderer, ThreeDFrame, objects, state, keysDown
local menusWindow, screenWidth, screenHeight, termResize
local hotbar, hotbarb
local GUI, PineForge

function input.init(deps)
	cfg          = deps.config
	world        = deps.world
	player       = deps.player
	renderer     = deps.renderer
	ThreeDFrame  = deps.ThreeDFrame
	objects      = deps.objects
	state        = deps.state
	keysDown     = deps.keysDown
	menusWindow  = deps.menusWindow
	screenWidth  = deps.screenWidth
	screenHeight = deps.screenHeight
	termResize   = deps.termResize
	GUI          = deps.GUI
	PineForge    = deps.PineForge
	hotbar       = paintutils.loadImage("hotbar.nfp")
	hotbarb      = paintutils.loadImage("hotbarb.nfp")
end

-- getObjectIndexTrace returns a chunk object + poly index.
-- We resolve the actual block and face from world.getPolyBlockInfo,
-- which is populated by buildChunkMesh for every emitted triangle pair.

local function getPolyInfo(objectIndex, polyIndex)
	local obj = objects[objectIndex]
	if not obj then return nil end
	return world.getPolyBlockInfo(obj, polyIndex)
end

local function getClickedBlockFromPoly(objectIndex, polyIndex)
	local info = getPolyInfo(objectIndex, polyIndex)
	if not info then return nil, 0, 0, 0 end
	return world.getBlock(info.x, info.y, info.z), info.x, info.y, info.z
end

local function placeAdjacentBlock(objectIndex, polyIndex)
	local info = getPolyInfo(objectIndex, polyIndex)
	if not info then return end
	local tx, ty, tz = info.x, info.y, info.z
	if     info.face == "top"    then ty = ty + 1
	elseif info.face == "bottom" then ty = ty - 1
	elseif info.face == "north"  then tx = tx - 1
	elseif info.face == "south"  then tx = tx + 1
	elseif info.face == "east"   then tz = tz - 1
	elseif info.face == "west"   then tz = tz + 1
	end
	if ty < 0 or ty > cfg.maxHeightChunk then return end
	world.placeBlock(tx, ty, tz, state.selectedBlock)
end

local function breakBlock(objectIndex, polyIndex)
	local info = getPolyInfo(objectIndex, polyIndex)
	if not info then return end
	world.breakBlock(info.x, info.y, info.z)
end

local function checkHotbarClick(mx, my)
	local blockIds = cfg.blockIds
	local buff     = ThreeDFrame.buffer
	local width, height = buff.width, buff.height

	if state.blittleOn then
		local hotX   = math.floor((width*0.5 - #hotbarb[1]*0.5) * 0.5 + 0.5)
		local hotY   = height/3 - 2
		local clickX = (mx-1)*2 + 1
		local clickY = (my-1)*3 + 1
		for i = 1, #blockIds do
			if clickX >= hotX*2+(i-1)*4*2-1 and clickX <= hotX*2+(i-1)*4*2+4 then
				if clickY >= hotY*3 then
					state.selectedBlock = blockIds[i]
					return true
				end
			end
		end
	else
		local hotX = math.floor(width*0.5 - #hotbar[1]*0.5 + 0.5)
		local hotY = height - 2
		for i = 1, #blockIds do
			if (mx == hotX+(i-1)*3 or mx == hotX+(i-1)*3+1) and (my == hotY+1 or my == hotY+2) then
				state.selectedBlock = blockIds[i]
				return true
			end
		end
	end
	return false
end

function input.inputLoop()
	while true do
		local event, key, x, y = os.pullEventRaw()

		if event == "key" then
			keysDown[key] = true

			if key == keys.g then
				state.blittleOn = not state.blittleOn
				ThreeDFrame:highResMode(state.blittleOn)

			elseif key == keys.h then
				world.updateWorld(player.camera)

			elseif key == keys.j then
				world.stepChunkQueue(player.camera)

			elseif key == keys.minus then
				cfg.renderDistance = math.max(0, cfg.renderDistance - 1)

			elseif key == keys.equals then
				cfg.renderDistance = cfg.renderDistance + 1

			elseif key == keys.z then
				state.f3MenuOpen = not state.f3MenuOpen

			elseif key == keys.x then
				state.drawHotbar = not state.drawHotbar

			elseif key == keys.c then
				state.viewFPS = not state.viewFPS
				if state.viewFPS then
					ThreeDFrame:setSize(1, 2, screenWidth, screenHeight)
					term.setCursorPos(1, 1)
					term.setBackgroundColor(colors.black)
					term.clearLine()
				else
					ThreeDFrame:setSize(1, 1, screenWidth, screenHeight)
				end

			elseif key >= keys.one and key <= keys.nine then
				local id = cfg.blockIds[key - keys.one + 1]
				if id then state.selectedBlock = id end

			elseif key == keys.grave then
				state.pauseMenu = not state.pauseMenu

			elseif key == keys.e then
				GUI.runCreativeMenu()
			end

		elseif event == "mouse_scroll" then
			local blockIds = cfg.blockIds
			local selectedNr = 0
			while blockIds[selectedNr] ~= state.selectedBlock do
				selectedNr = selectedNr + 1
			end
			state.selectedBlock = blockIds[(selectedNr + key - 1) % #blockIds + 1]

		elseif event == "key_up" then
			keysDown[key] = nil

		elseif event == "mouse_click" then
			if state.pauseMenu then
				local dx, dy = menusWindow.getPosition()
				dx = dx - 1
				dy = dy - 1
				local w, h = menusWindow.getSize()
				if x >= 3+dx and y >= 4+dy and x <= w-2+dx and y <= 6+dy then
					state.pauseMenu = false
				elseif x >= 3+dx and y >= 4+4+dy and x <= w-2+dx and y <= 6+4+dy then
					break
				end
			else
				if not checkHotbarClick(x, y) then
					local objectIndex, polyIndex = ThreeDFrame:getObjectIndexTrace(objects, x, y)
					if objectIndex then
						local obj    = objects[objectIndex]
						local info   = world.getPolyBlockInfo(obj, polyIndex)
						local bx, by, bz = info and info.x or 0, info and info.y or 0, info and info.z or 0
						local block  = info and world.getBlock(bx, by, bz) or nil

						if key == 1 then
							breakBlock(objectIndex, polyIndex)

						elseif key == 2 then
							local interacted = false
							if block then
								local blockDef = cfg.modBlocks[block.originalModel]
								if blockDef and blockDef.onInteract then
									local interactAPI = PineForge and PineForge.getInteractAPI() or nil
									local ok, err = pcall(blockDef.onInteract, bx, by, bz, interactAPI)
									if not ok then
										print("[PineForge] onInteract error on '" ..
										      block.originalModel .. "': " .. tostring(err))
									end
									interacted = true
								end
							end
							if not interacted then
								placeAdjacentBlock(objectIndex, polyIndex)
							end

						elseif key == 3 then
							if block then
								state.selectedBlock = block.originalModel
							end
						end
					end
				end
			end

		elseif event == "term_resize" then
			screenWidth, screenHeight = termResize()
		end
	end
end

return input
