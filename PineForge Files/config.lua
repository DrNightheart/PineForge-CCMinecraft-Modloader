-- config.lua
-- Global constants and block registry. Required by all modules.

local config = {}

config.speed     = 6
config.turnSpeed = 180

config.seed               = 0
config.maxHeightTerrain   = 20
config.maxHeightChunk     = config.maxHeightTerrain + 20
config.chunkSize          = 16
config.terrainSmoothness  = 2
config.renderDistance     = 1

-- "a" is reserved for air; vanilla blocks start at "b".
config.blockIds = {"grass", "dirt", "wood", "leaves", "stone", "sand", "water"}

config.idEncode = {air = "a"}
config.idDecode = {a = "air"}

local letters = "abcdefghijklmnopqrstuvwxyz"
for i, name in ipairs(config.blockIds) do
	local letter = letters:sub(i + 1, i + 1)
	config.idEncode[name]   = letter
	config.idDecode[letter] = name
end

config.selectedBlock = "dirt"
config.drawHotbar    = true
config.viewFPS       = false
config.blittleOn     = true

-- Filled at runtime by PineForge.
-- [fullId] = { saveKey, namespace, displayName, model }
config.modBlocks = {}

function config.isVanilla(id)
	return not id:find(":")
end

function config.getDisplayName(id)
	if config.isVanilla(id) then
		return id
	end
	local block = config.modBlocks[id]
	return block and block.displayName or id
end

return config
