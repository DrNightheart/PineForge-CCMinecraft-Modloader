-- PineForge.lua
-- Mod loader, event bus, and sandboxed API.
-- Handles .ccmod files and folder mods in /CCMods/

local PineForge = {}


local loadedMods     = {}
local eventListeners = {}
local modModels      = {}
local rawUsers       = {}   -- namespaces that accessed api.raw
local currentWorldId = nil  -- set by PineForge.setWorldId() when a world opens

local coreConfig, coreWorld, coreGUI

-- Pine3D triangle face indices:
--   1-2=bottom  3-4=top  5-6=north(x-)  7-8=south(x+)  9-10=east(z-)  11-12=west(z+)

local FACE_BOTTOM = {1, 2}
local FACE_TOP    = {3, 4}
local FACE_NORTH  = {5, 6}
local FACE_SOUTH  = {7, 8}
local FACE_EAST   = {9, 10}
local FACE_WEST   = {11, 12}

-- Unit cube vertex definitions for each triangle.
local CUBE_VERTS = {
    -- 1: bottom tri A
    { x1=-0.5, y1=-0.5, z1=-0.5,  x2= 0.5, y2=-0.5, z2= 0.5,  x3=-0.5, y3=-0.5, z3= 0.5 },
    -- 2: bottom tri B
    { x1=-0.5, y1=-0.5, z1=-0.5,  x2= 0.5, y2=-0.5, z2=-0.5,  x3= 0.5, y3=-0.5, z3= 0.5 },
    -- 3: top tri A
    { x1=-0.5, y1= 0.5, z1=-0.5,  x2=-0.5, y2= 0.5, z2= 0.5,  x3= 0.5, y3= 0.5, z3= 0.5 },
    -- 4: top tri B
    { x1=-0.5, y1= 0.5, z1=-0.5,  x2= 0.5, y2= 0.5, z2= 0.5,  x3= 0.5, y3= 0.5, z3=-0.5 },
    -- 5: north tri A  (x-)
    { x1=-0.5, y1=-0.5, z1=-0.5,  x2=-0.5, y2=-0.5, z2= 0.5,  x3=-0.5, y3= 0.5, z3=-0.5 },
    -- 6: north tri B
    { x1=-0.5, y1= 0.5, z1=-0.5,  x2=-0.5, y2=-0.5, z2= 0.5,  x3=-0.5, y3= 0.5, z3= 0.5 },
    -- 7: south tri A  (x+)
    { x1= 0.5, y1=-0.5, z1=-0.5,  x2= 0.5, y2= 0.5, z2= 0.5,  x3= 0.5, y3=-0.5, z3= 0.5 },
    -- 8: south tri B
    { x1= 0.5, y1=-0.5, z1=-0.5,  x2= 0.5, y2= 0.5, z2=-0.5,  x3= 0.5, y3= 0.5, z3= 0.5 },
    -- 9: east tri A   (z-)
    { x1=-0.5, y1=-0.5, z1=-0.5,  x2= 0.5, y2= 0.5, z2=-0.5,  x3= 0.5, y3=-0.5, z3=-0.5 },
    -- 10: east tri B
    { x1=-0.5, y1=-0.5, z1=-0.5,  x2=-0.5, y2= 0.5, z2=-0.5,  x3= 0.5, y3= 0.5, z3=-0.5 },
    -- 11: west tri A  (z+)
    { x1=-0.5, y1=-0.5, z1= 0.5,  x2= 0.5, y2=-0.5, z2= 0.5,  x3=-0.5, y3= 0.5, z3= 0.5 },
    -- 12: west tri B
    { x1= 0.5, y1=-0.5, z1= 0.5,  x2= 0.5, y2= 0.5, z2= 0.5,  x3=-0.5, y3= 0.5, z3= 0.5 },
}

-- Light/dark color pairs — tri A (odd) is the lit face, tri B (even) is the shadow.
local DARKER = {
    [colors.white]     = colors.lightGray,
    [colors.lightGray] = colors.gray,
    [colors.gray]      = colors.black,
    [colors.black]     = colors.black,
    [colors.yellow]    = colors.orange,
    [colors.orange]    = colors.brown,
    [colors.brown]     = colors.black,
    [colors.lime]      = colors.green,
    [colors.green]     = colors.black,
    [colors.cyan]      = colors.blue,
    [colors.lightBlue] = colors.blue,
    [colors.blue]      = colors.black,
    [colors.red]       = colors.black,
    [colors.pink]      = colors.red,
    [colors.magenta]   = colors.purple,
    [colors.purple]    = colors.black,
}

local function darker(c)
    return DARKER[c] or colors.black
end

-- Resolves a color spec into a 12-entry color table for buildModel.
-- Accepts: color, topColor/sideColor, colors{top/bottom/etc}, or modelData.
local function resolveColors(opts)
    if opts.modelData then
        return nil, opts.modelData
    end

    local light = {}
    local dark  = {}

    local function setFace(indices, c1, c2)
        light[indices[1]] = c1
        dark [indices[2]] = c2 or darker(c1)
    end

    if opts.color then
        local c1 = opts.color
        local c2 = opts.color2 or darker(c1)
        setFace(FACE_BOTTOM, c1, c2)
        setFace(FACE_TOP,    c1, c2)
        setFace(FACE_NORTH,  c1, c2)
        setFace(FACE_SOUTH,  c1, c2)
        setFace(FACE_EAST,   c1, c2)
        setFace(FACE_WEST,   c1, c2)

    elseif opts.topColor or opts.sideColor then
        local top   = opts.topColor    or opts.sideColor
        local top2  = opts.topColor2   or darker(top)
        local side  = opts.sideColor   or opts.topColor
        local side2 = opts.sideColor2  or darker(side)
        local bot   = opts.bottomColor or side
        local bot2  = opts.bottomColor2 or darker(bot)
        setFace(FACE_BOTTOM, bot,  bot2)
        setFace(FACE_TOP,    top,  top2)
        setFace(FACE_NORTH,  side, side2)
        setFace(FACE_SOUTH,  side, side2)
        setFace(FACE_EAST,   side, side2)
        setFace(FACE_WEST,   side, side2)

    elseif opts.colors then
        local fc   = opts.colors
        local side  = fc.side  or colors.white
        local side2 = fc.side2 or darker(side)
        setFace(FACE_BOTTOM, fc.bottom or side,  fc.bottom2 or darker(fc.bottom or side))
        setFace(FACE_TOP,    fc.top    or side,  fc.top2    or darker(fc.top    or side))
        setFace(FACE_NORTH,  fc.north  or side,  fc.north2  or darker(fc.north  or side))
        setFace(FACE_SOUTH,  fc.south  or side,  fc.south2  or darker(fc.south  or side))
        setFace(FACE_EAST,   fc.east   or side,  fc.east2   or darker(fc.east   or side))
        setFace(FACE_WEST,   fc.west   or side,  fc.west2   or darker(fc.west   or side))

    else
        return "registerBlock: must provide color, topColor/sideColor, colors{}, or modelData"
    end

    local c = {}
    for face = 1, 6 do
        local triA = face * 2 - 1
        local triB = face * 2
        c[triA] = light[triA]
        c[triB] = dark[triB]
    end

    return nil, c
end

local function buildModel(colorTable)
    local model = {}
    for i = 1, 12 do
        local v = CUBE_VERTS[i]
        model[i] = {
            x1 = v.x1, y1 = v.y1, z1 = v.z1,
            x2 = v.x2, y2 = v.y2, z2 = v.z2,
            x3 = v.x3, y3 = v.y3, z3 = v.z3,
            c  = colorTable[i],
        }
    end
    return model
end

local function deriveNamespace(entry)
    return entry:match("^(.+)%.ccmod$") or entry
end

-- Returns a sandboxed API table scoped to the given namespace.

local function makeAPI(namespace)
    local api = {}

    function api.registerBlock(name, opts)
        assert(type(name) == "string", "registerBlock: name must be a string")
        assert(type(opts) == "table",  "registerBlock: opts must be a table")
        assert(type(opts.saveChar) == "string" and #opts.saveChar == 1,
               "registerBlock: saveChar must be a single character")

        local fullId   = namespace .. ":" .. name
        local saveKey  = namespace .. ":" .. opts.saveChar

        for existingId, data in pairs(coreConfig.modBlocks) do
            if existingId == fullId then
                error("registerBlock: block '" .. fullId .. "' already registered")
            end
            if data.saveKey == saveKey then
                error("registerBlock: saveChar '" .. opts.saveChar ..
                      "' already used by '" .. existingId .. "' in namespace '" .. namespace .. "'")
            end
        end

        local err, colorTableOrRaw = resolveColors(opts)
        if err then error(err) end

        local model, displayColor
        if opts.modelData then
            model        = colorTableOrRaw
            displayColor = model[3] and model[3].c or colors.white
        else
            model        = buildModel(colorTableOrRaw)
            displayColor = colorTableOrRaw[3] or colors.white
        end

        coreConfig.modBlocks[fullId] = {
            saveKey     = saveKey,
            namespace   = namespace,
            displayName = opts.displayName or name,
            model       = model,
            displayColor = displayColor,
            onInteract  = opts.onInteract,
        }
        modModels[fullId] = model

        if opts.inHotbar then
            coreConfig.blockIds[#coreConfig.blockIds + 1] = fullId
        end

        return fullId
    end

    local VALID_EVENTS = {
        blockPlace  = true,
        blockBreak  = true,
        playerMove  = true,
        tick        = true,
        chunkLoad   = true,
        chunkUnload = true,
    }

    function api.on(eventName, callback)
        assert(VALID_EVENTS[eventName],
               "api.on: unknown event '" .. tostring(eventName) .. "'")
        assert(type(callback) == "function",
               "api.on: callback must be a function")

        if not eventListeners[eventName] then
            eventListeners[eventName] = {}
        end
        eventListeners[eventName][#eventListeners[eventName] + 1] = {
            namespace = namespace,
            fn        = callback,
        }
    end

    function api.onWorldGen(callback)
        assert(type(callback) == "function", "onWorldGen: callback must be a function")
        if not eventListeners["worldGen"] then
            eventListeners["worldGen"] = {}
        end
        eventListeners["worldGen"][#eventListeners["worldGen"] + 1] = {
            namespace = namespace,
            fn        = callback,
        }
    end

    api.world = {}

    function api.world.getBlock(x, y, z)
        if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
            return nil
        end
        local block = coreWorld.getBlock(x, y, z)
        if not block then return nil end
        return { name = block.originalModel }
    end

    function api.world.setBlock(x, y, z, id)
        if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
            return false, "invalid coordinates"
        end
        if type(id) ~= "string" then
            return false, "id must be a string"
        end
        local fullId = id:find(":") and id or (namespace .. ":" .. id)
        if not coreConfig.modBlocks[fullId] and not coreConfig.idEncode[fullId] then
            return false, "unknown block id: " .. fullId
        end
        coreWorld.setBlock(x, y, z, fullId, true)
        return true
    end

    function api.world.removeBlock(x, y, z)
        if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
            return false, "invalid coordinates"
        end
        coreWorld.removeBlock(x, y, z)
        return true
    end

    -- api.raw: direct engine access. Triggers a startup warning if used.

    local _rawData = {
        world  = coreWorld,
        config = coreConfig,
    }
    api.raw = setmetatable({}, {
        __index = function(_, k)
            if not rawUsers[namespace] then
                rawUsers[namespace] = true
            end
            return _rawData[k]
        end,
        __newindex = function(_, k, v)
            if not rawUsers[namespace] then
                rawUsers[namespace] = true
            end
            _rawData[k] = v
        end,
    })

    if coreGUI then
        api.gui = coreGUI.makeAPI(namespace)
    end

    -- Per-mod, per-world persistent storage.
    -- Files live at: worlds/<worldId>/moddata/<namespace>/<key>.txt

    local function modDataPath(key)
        assert(type(key) == "string" and #key > 0, "saveData/loadData: key must be a non-empty string")
        assert(not key:find("[/\\]"), "saveData/loadData: key must not contain path separators")
        if not currentWorldId then return nil end
        return "worlds/" .. currentWorldId .. "/moddata/" .. namespace .. "/" .. key .. ".txt"
    end

    function api.saveData(key, value)
        local path = modDataPath(key)
        if not path then return false, "no world loaded" end
        local dir = "worlds/" .. currentWorldId .. "/moddata/" .. namespace
        if not fs.exists(dir) then fs.makeDir(dir) end
        local f = fs.open(path, "w")
        if not f then return false, "could not open file for writing" end
        f.write(textutils.serialise(value))
        f.close()
        return true
    end

    function api.loadData(key)
        local path = modDataPath(key)
        if not path then return nil end
        if not fs.exists(path) then return nil end
        local f = fs.open(path, "r")
        if not f then return nil end
        local raw = f.readAll()
        f.close()
        local ok, result = pcall(textutils.unserialise, raw)
        if not ok then return nil end
        return result
    end

    function api.deleteData(key)
        local path = modDataPath(key)
        if not path then return false end
        if fs.exists(path) then fs.delete(path) end
        return true
    end

    return api
end

-- Stripped-down API passed to onInteract. World access only, no namespace needed.
function PineForge.getInteractAPI()
    return {
        gui   = coreGUI and coreGUI.makeAPI("_interact") or nil,
        world = {
            getBlock    = function(x, y, z) return coreWorld.getBlock(x, y, z) end,
            setBlock    = function(x, y, z, id) return coreWorld.setBlock(x, y, z, id, true) end,
            removeBlock = function(x, y, z) return coreWorld.removeBlock(x, y, z) end,
        },
    }
end

function PineForge.fire(eventName, ...)
    local listeners = eventListeners[eventName]
    if not listeners then return end
    for _, listener in ipairs(listeners) do
        local ok, err = pcall(listener.fn, ...)
        if not ok then
            print("[PineForge] Error in '" .. listener.namespace ..
                  "' handler for '" .. eventName .. "': " .. tostring(err))
        end
    end
end

local function loadMod(namespace, chunk, configPath)
    local modCfg = {}
    if configPath and fs.exists(configPath) then
        local f = fs.open(configPath, "r")
        local raw = f.readAll()
        f.close()
        for line in raw:gmatch("[^\n]+") do
            local k, v = line:match("^([%w_]+)%s*=%s*(.+)$")
            if k and v then modCfg[k] = v:match("^%s*(.-)%s*$") end
        end
    end

    local function flushConfig()
        if not configPath then return end
        local parts = {}
        for p in configPath:gmatch("[^/]+") do parts[#parts + 1] = p end
        local cur = ""
        for i = 1, #parts - 1 do
            cur = cur == "" and parts[i] or (cur .. "/" .. parts[i])
            if not fs.exists(cur) then fs.makeDir(cur) end
        end
        local f = fs.open(configPath, "w")
        if f then
            for k, v in pairs(modCfg) do
                f.write(k .. "=" .. tostring(v) .. "\n")
            end
            f.close()
        end
    end

    local cfgAPI = {
        get = function(key, default)
            return modCfg[key] ~= nil and modCfg[key] or default
        end,
        getString = function(key, default)
            local v = modCfg[key]
            if v == nil then return default end
            return tostring(v)
        end,
        getNumber = function(key, default)
            local v = modCfg[key]
            if v == nil then return default end
            local n = tonumber(v)
            if n == nil then
                print("[PineForge/" .. namespace .. "] cfgAPI.getNumber: '" .. key ..
                      "' = '" .. tostring(v) .. "' is not a number, using default")
                return default
            end
            return n
        end,
        getBool = function(key, default)
            local v = modCfg[key]
            if v == nil then return default end
            local l = tostring(v):lower():match("^%s*(.-)%s*$")
            if l == "true"  or l == "1" or l == "yes" or l == "on"  then return true  end
            if l == "false" or l == "0" or l == "no"  or l == "off" then return false end
            print("[PineForge/" .. namespace .. "] cfgAPI.getBool: '" .. key ..
                  "' = '" .. tostring(v) .. "' is not a boolean, using default")
            return default
        end,
        set = function(key, value)
            modCfg[key] = tostring(value)
            flushConfig()
        end,
    }

    local api = makeAPI(namespace)
    local ok, modTable = pcall(chunk)
    if not ok then
        print("[PineForge] Failed to load mod '" .. namespace .. "': " .. tostring(modTable))
        return false
    end
    if type(modTable) ~= "table" then
        print("[PineForge] Mod '" .. namespace .. "' did not return a table — skipping")
        return false
    end
    if type(modTable.init) ~= "function" then
        print("[PineForge] Mod '" .. namespace .. "' has no init() function — skipping")
        return false
    end

    local initOk, initErr = pcall(modTable.init, api, cfgAPI)
    if not initOk then
        print("[PineForge] ERROR in '" .. namespace .. "': " .. tostring(initErr))
    end

    loadedMods[namespace] = modTable
    local blockCount = 0
    for id in pairs(coreConfig.modBlocks) do
        if id:sub(1, #namespace+1) == namespace .. ":" then
            blockCount = blockCount + 1
        end
    end
    print("[PineForge] Loaded: " .. namespace ..
          " (" .. (modTable.name or namespace) ..
          " v" .. (modTable.version or "?") .. ")" ..
          " | " .. blockCount .. " blocks")
    return true
end

function PineForge.loadMods()
    if not fs.exists("CCMods") then
        fs.makeDir("CCMods")
        return
    end

    local disabledMods = {}
    if fs.exists("CCMods/disabled.txt") then
        local f = fs.open("CCMods/disabled.txt", "r")
        local raw = f.readAll()
        f.close()
        for line in raw:gmatch("[^\n]+") do
            local ns = line:match("^%s*(.-)%s*$")
            if ns ~= "" then disabledMods[ns] = true end
        end
    end

    local entries = fs.list("CCMods")
    local seen    = {}   -- namespace → entry name, for collision detection

    local toLoad = {}
    for _, entry in ipairs(entries) do
        local ns = deriveNamespace(entry)
        if ns ~= "disabled" then  -- skip our own disabled.txt bookkeeping file
            if seen[ns] then
                print("[PineForge] CONFLICT: '" .. entry .. "' and '" ..
                      seen[ns] .. "' share namespace '" .. ns .. "' — neither will load")
                seen[ns] = nil   -- mark as conflicted
            elseif seen[ns] == nil and seen[ns] ~= false then
                seen[ns] = entry
                toLoad[#toLoad + 1] = { ns = ns, entry = entry }
            end
        end
    end

    -- Topological load order: peek each mod's dependency list, then sort.
    -- Kahn's algorithm ensures deps always load before their dependents.
    local function peekDeps(chunk)
        local ok, modTable = pcall(chunk)
        if not ok or type(modTable) ~= "table" then return {} end
        local deps = modTable.dependencies
        if type(deps) ~= "table" then return {} end
        return deps
    end

    local depMap = {}
    local chunkCache = {}   -- ns → chunk (so we don't loadfile twice)
    for _, item in ipairs(toLoad) do
        if seen[item.ns] and not disabledMods[item.ns] then
            local fullPath = "CCMods/" .. item.entry
            local luaPath  = fs.isDir(fullPath) and fullPath .. "/mod.lua" or fullPath
            if fs.exists(luaPath) then
                local chunk, err = loadfile(luaPath)
                if chunk then
                    chunkCache[item.ns] = chunk
                    depMap[item.ns] = peekDeps(chunk)
                    chunk, err = loadfile(luaPath)
                    if chunk then chunkCache[item.ns] = chunk end
                end
            end
        end
    end

    local sorted   = {}
    local inDegree = {}
    local graph    = {}   -- ns → list of ns that depend on it

    for _, item in ipairs(toLoad) do
        inDegree[item.ns] = inDegree[item.ns] or 0
        graph[item.ns]    = graph[item.ns]    or {}
    end
    for ns, deps in pairs(depMap) do
        for _, dep in ipairs(deps) do
            if inDegree[ns] ~= nil then
                inDegree[ns] = inDegree[ns] + 1
                if graph[dep] then
                    graph[dep][#graph[dep]+1] = ns
                end
            end
        end
    end

    local queue = {}
    for ns, deg in pairs(inDegree) do
        if deg == 0 then queue[#queue+1] = ns end
    end
    table.sort(queue)

    while #queue > 0 do
        local ns = table.remove(queue, 1)
        sorted[#sorted+1] = ns
        for _, dependent in ipairs(graph[ns] or {}) do
            inDegree[dependent] = inDegree[dependent] - 1
            if inDegree[dependent] == 0 then
                queue[#queue+1] = dependent
                table.sort(queue)
            end
        end
    end

    -- Cycles: append in original order and warn.
    local inSorted = {}
    for _, ns in ipairs(sorted) do inSorted[ns] = true end
    for _, item in ipairs(toLoad) do
        if not inSorted[item.ns] then
            sorted[#sorted+1] = item.ns
            print("[PineForge] WARNING: possible dependency cycle involving '" .. item.ns .. "'")
        end
    end

    for _, ns in ipairs(sorted) do
        if disabledMods[ns] then
            print("[PineForge] Skipping disabled mod: " .. ns)
        elseif seen[ns] then
            local entry = seen[ns]
            local fullPath = "CCMods/" .. entry
            local luaPath, cfgPath
            local canLoad = true

            if fs.isDir(fullPath) then
                luaPath = fullPath .. "/mod.lua"
                cfgPath = fullPath .. "/config.txt"
                if not fs.exists(luaPath) then
                    print("[PineForge] Folder mod '" .. ns .. "' has no mod.lua — skipping")
                    canLoad = false
                end
            else
                luaPath = fullPath
                cfgPath = "CCMods/" .. ns .. ".config.txt"
            end

            if canLoad then
                local chunk = chunkCache[ns]
                if not chunk then
                    chunk = loadfile(luaPath)
                end
                if not chunk then
                    print("[PineForge] Could not read '" .. luaPath .. "'")
                else
                    loadMod(ns, chunk, cfgPath)
                end
            end
        end
    end

    local count = 0
    for _ in pairs(loadedMods) do count = count + 1 end
    print("[PineForge] " .. count .. " mod(s) loaded.")
end

function PineForge.getModModel(fullId)
    return modModels[fullId]
end

function PineForge.init(deps)
    coreConfig = deps.config
    coreWorld  = deps.world
    coreGUI    = deps.GUI   -- may be nil if GUI system not yet initialised

    if not coreConfig.modBlocks then
        coreConfig.modBlocks = {}
    end
end

function PineForge.setWorldId(id)
    currentWorldId = id
end

function PineForge.checkDependencies()
    local problems = {}

    for ns, modTable in pairs(loadedMods) do
        local deps = modTable.dependencies
        if type(deps) == "table" then
            local missing = {}
            for _, dep in ipairs(deps) do
                if not loadedMods[dep] then
                    missing[#missing+1] = dep
                end
            end
            if #missing > 0 then
                problems[#problems+1] = { mod = ns, missing = missing }
                print("[PineForge] MISSING DEPS for '" .. ns .. "': " ..
                      table.concat(missing, ", "))
            end
        end
    end

    return #problems == 0, problems
end

function PineForge.getLoadedMods()
    return loadedMods
end

-- Prompts the player if any mod used api.raw during init.
-- Returns true to proceed into the world, false to abort.
function PineForge.checkRawWarning(nativeTerm)
    local users = {}
    for ns in pairs(rawUsers) do
        users[#users + 1] = ns
    end
    if #users == 0 then return true end

    table.sort(users)

    local t = nativeTerm or term.current()
    t.setBackgroundColor(colors.black)
    t.clear()
    t.setCursorPos(1, 1)
    t.setTextColor(colors.yellow)
    t.write("[ PineForge Warning ]")
    t.setCursorPos(1, 3)
    t.setTextColor(colors.white)

    if #users == 1 then
        t.write("The mod  \"" .. users[1] .. "\"  is using an")
        t.setCursorPos(1, 4)
        t.write("experimental feature (raw API access)!")
    else
        t.write("These mods are using an experimental")
        t.setCursorPos(1, 4)
        t.write("feature (raw API access):")
        for i, ns in ipairs(users) do
            t.setCursorPos(3, 4 + i)
            t.setTextColor(colors.orange)
            t.write("• " .. ns)
        end
        t.setTextColor(colors.white)
    end

    local warnLines = #users == 1 and 2 or (2 + #users)
    t.setCursorPos(1, 4 + warnLines)
    t.write("Proceed into world?")
    t.setCursorPos(1, 5 + warnLines)
    t.setTextColor(colors.lime)
    t.write("  [Y] Yes")
    t.setCursorPos(1, 6 + warnLines)
    t.setTextColor(colors.red)
    t.write("  [N] No")
    t.setTextColor(colors.white)

    while true do
        local _, key = os.pullEvent("key")
        if key == keys.y then
            return true
        elseif key == keys.n then
            return false
        end
    end
end

return PineForge
