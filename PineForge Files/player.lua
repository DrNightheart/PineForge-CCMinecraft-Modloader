-- player.lua
-- Camera state, movement, and save/load.

local player = {}

local cfg, ThreeDFrame, world, keysDown, PineForge

function player.init(deps)
	cfg         = deps.config
	ThreeDFrame = deps.ThreeDFrame
	world       = deps.world
	keysDown    = deps.keysDown
	PineForge   = deps.PineForge
end

player.camera = {
	x    = 0,
	y    = 0,
	z    = 0,
	rotX = 0,
	rotY = 0,
	rotZ = 0,
}

function player.handleMovement(dt)
	local camera = player.camera
	local speed  = cfg.speed
	local turn   = cfg.turnSpeed

	if keysDown[keys.left]  then camera.rotY = (camera.rotY - turn * dt) % 360 end
	if keysDown[keys.right] then camera.rotY = (camera.rotY + turn * dt) % 360 end
	if keysDown[keys.down]  then camera.rotZ = math.max(-80, camera.rotZ - turn * dt) end
	if keysDown[keys.up]    then camera.rotZ = math.min( 80, camera.rotZ + turn * dt) end

	local dx, dy, dz = 0, 0, 0

	if keysDown[keys.w] then
		dx = dx + speed * math.cos(math.rad(camera.rotY))
		dz = dz + speed * math.sin(math.rad(camera.rotY))
	end
	if keysDown[keys.s] then
		dx = dx - speed * math.cos(math.rad(camera.rotY))
		dz = dz - speed * math.sin(math.rad(camera.rotY))
	end
	if keysDown[keys.a] then
		dx = dx + speed * math.cos(math.rad(camera.rotY - 90))
		dz = dz + speed * math.sin(math.rad(camera.rotY - 90))
	end
	if keysDown[keys.d] then
		dx = dx + speed * math.cos(math.rad(camera.rotY + 90))
		dz = dz + speed * math.sin(math.rad(camera.rotY + 90))
	end

	if keysDown[keys.space]     then dy = dy + speed end
	if keysDown[keys.leftShift] then dy = dy - speed end

	camera.x = camera.x + dx * dt
	camera.y = camera.y + dy * dt
	camera.z = camera.z + dz * dt

	ThreeDFrame:setCamera(camera)
	world.updateWorld(camera)

	if PineForge then
		PineForge.fire("tick", dt)
		if dx ~= 0 or dy ~= 0 or dz ~= 0 then
			PineForge.fire("playerMove", camera.x, camera.y, camera.z)
		end
	end
end

function player.load(worldId)
	local camera     = player.camera
	local playerPath = "worlds/" .. worldId .. "/player.txt"

	if fs.exists(playerPath) then
		local f   = fs.open(playerPath, "r")
		local raw = f.readAll()
		f.close()
		local data = textutils.unserialise(raw)
		if data then
			camera.x    = data.x
			camera.y    = data.y
			camera.z    = data.z
			camera.rotY = data.camHor
			camera.rotZ = data.camVer
			return
		end
	end

	camera.x    = 0
	camera.y    = 0
	camera.z    = 0
	camera.rotY = 0
	camera.rotZ = 0
end

function player.save(worldId)
	local camera     = player.camera
	local playerPath = "worlds/" .. worldId .. "/player.txt"
	local f = fs.open(playerPath, "w")
	f.write(textutils.serialise({
		x          = camera.x,
		y          = camera.y,
		z          = camera.z,
		camHor     = camera.rotY,
		camVer     = camera.rotZ,
		lastActive = os.time(os.date("!*t")),
	}))
	f.close()
end

return player
