-- renderer.lua
-- 3D scene rendering, HUD, FPS display, and pause menu.
-- Only reads shared state; never processes input.

local renderer = {}

local cfg, ThreeDFrame, objects, state
local hotbar, hotbarb
local frameTimes    = {}
local lastFrameTime = os.clock()

function renderer.init(deps)
	cfg         = deps.config
	ThreeDFrame = deps.ThreeDFrame
	objects     = deps.objects
	state       = deps.state
	hotbar      = paintutils.loadImage("hotbar.nfp")
	hotbarb     = paintutils.loadImage("hotbarb.nfp")
end

function renderer.drawNiceBorder(win, x1, y1, x2, y2, bg, fg)
	local s = string.rep(" ", x2-x1+1-2)
	win.setBackgroundColor(bg)
	for y = y1+1, y2-1 do
		win.setCursorPos(x1+1, y)
		win.write(s)
	end

	for i = x1+1, x2-1 do
		win.setBackgroundColor(bg)
		win.setTextColor(fg)
		win.setCursorPos(i, y1)
		win.write(string.char(131))
	end
	for i = x1+1, x2-1 do
		win.setBackgroundColor(fg)
		win.setTextColor(bg)
		win.setCursorPos(i, y2)
		win.write(string.char(143))
	end
	for i = y1+1, y2-1 do
		win.setBackgroundColor(bg)
		win.setTextColor(fg)
		win.setCursorPos(x1, i)
		win.write(string.char(149))
	end
	for i = y1+1, y2-1 do
		win.setBackgroundColor(fg)
		win.setTextColor(bg)
		win.setCursorPos(x2, i)
		win.write(string.char(149))
	end

	win.setCursorPos(x1, y1)
	win.setBackgroundColor(bg)
	win.setTextColor(fg)
	win.write(string.char(151))

	win.setCursorPos(x1, y2)
	win.setBackgroundColor(fg)
	win.setTextColor(bg)
	win.write(string.char(138))

	win.setCursorPos(x2, y1)
	win.setBackgroundColor(fg)
	win.setTextColor(bg)
	win.write(string.char(148))

	win.setCursorPos(x2, y2)
	win.setBackgroundColor(fg)
	win.setTextColor(bg)
	win.write(string.char(133))
end

function renderer.drawButton(win, x1, y1, x2, y2, text, bg, fg, tc)
	renderer.drawNiceBorder(win, x1, y1, x2, y2, bg, fg)
	win.setTextColor(tc)
	win.setBackgroundColor(bg)
	win.setCursorPos(math.floor((x1+x2)*0.5 - #text*0.5 + 0.5), math.floor((y1+y2)*0.5))
	win.write(text)
end

function renderer.renderPauseMenu(menusWindow)
	menusWindow.setVisible(false)
	local w, h = menusWindow.getSize()
	renderer.drawNiceBorder(menusWindow, 1, 1, w, h, colors.brown, colors.green)

	local pattern = {131, 135, 139, 135, 139, 143}
	local s = ""
	math.randomseed(0)
	for _ = 2, w-1 do
		s = s .. string.char(pattern[math.random(6)])
	end
	menusWindow.setBackgroundColor(colors.brown)
	menusWindow.setTextColor(colors.green)
	menusWindow.setCursorPos(2, 1)
	menusWindow.write(s)

	menusWindow.setBackgroundColor(colors.brown)
	menusWindow.setTextColor(colors.white)
	menusWindow.setCursorPos(math.floor(w*0.5 - #("Game Paused")*0.5 + 0.5), 2)
	menusWindow.write("Game Paused")

	renderer.drawButton(menusWindow, 3, 4,   w-2, 6,   "Back to Game",  colors.gray, colors.lightGray, colors.white)
	renderer.drawButton(menusWindow, 3, 4+4, w-2, 6+4, "Save and Quit", colors.gray, colors.lightGray, colors.white)

	menusWindow.setVisible(true)
end

local function render3DGraphics()
	ThreeDFrame:drawObjects(objects)

	local buff           = ThreeDFrame.buffer
	local width, height  = buff.width, buff.height
	local blockIds       = cfg.blockIds
	local selectedBlock  = state.selectedBlock

	if state.f3MenuOpen then
		for i = 1, #frameTimes do
			local time = frameTimes[#frameTimes-i+1]
			for y = 1, time*200 do
				local c = colors.yellow
				if time > 1/20 then c = colors.red
				elseif time > 1/30 then c = colors.orange end
				buff:setPixel(i, y, c)
			end
		end
	end

	if state.drawHotbar then
		if state.blittleOn then
			local hotX = math.floor((width*0.5 - #hotbarb[1]*0.5) * 0.5 + 0.5)
			local hotY = height/3 - 2
			buff:image(hotX, hotY, hotbarb)
			for i = 1, #blockIds do
				local col = colors.gray
				local dy  = 0
				if blockIds[i] == selectedBlock then col = colors.lightGray; dy = 1 end
				for x = hotX*2 + (i-1)*4*2-1, hotX*2 + (i-1)*4*2+4 do
					for y = hotY*3+4, hotY*3+5+dy do
						buff:setPixel(x, y, col)
					end
				end
			end
		else
			local hotX = math.floor(width*0.5 - #hotbar[1]*0.5 + 0.5)
			local hotY = height - 2
			buff:image(hotX, hotY, hotbar)
			for i = 1, #blockIds do
				local col = colors.gray
				if blockIds[i] == selectedBlock then col = colors.lightGray end
				buff:setPixel(hotX + (i-1)*3,   hotY+2, col)
				buff:setPixel(hotX + (i-1)*3+1, hotY+2, col)
			end
		end
	end

	ThreeDFrame:drawBuffer()
end

function renderer.renderFPS(frames, lastFPSTime)
	local currentTime = os.clock()
	frames = frames + 1

	if currentTime > lastFPSTime + 1 then
		lastFPSTime = os.clock()
		if state.viewFPS then
			term.setBackgroundColor(colors.black)
			term.setCursorPos(1, 1)
			term.clearLine()
			term.setTextColor(colors.white)
			term.write("Average FPS: " .. frames)
		end
		frames = 0
	end

	frameTimes[#frameTimes+1] = currentTime - lastFrameTime
	lastFrameTime = currentTime
	if #frameTimes > 30 then table.remove(frameTimes, 1) end

	return frames, lastFPSTime
end

function renderer.renderLoop(menusWindow)
	local frames      = 0
	local lastFPSTime = 0
	while true do
		if state.guiOpen then
			sleep(0.05)
		elseif state.pauseMenu then
			renderer.renderPauseMenu(menusWindow)
			sleep(0.05)
		else
			render3DGraphics()
		end
		frames, lastFPSTime = renderer.renderFPS(frames, lastFPSTime)
		os.queueEvent("FakeEvent")
		os.pullEvent("FakeEvent")
	end
end

return renderer
