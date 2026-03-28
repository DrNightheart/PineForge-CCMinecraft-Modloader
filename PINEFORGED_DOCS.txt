
  PineForged - Mod Documentation
  v0.1 | I hope you know this document was made in not that much time so its kinda shitty. HOWEVER, everything in here works according to my testing.

CONTENTS
  1. Getting Started
  2. Mod Structure
  3. The Mod Table
  4. api.registerBlock
  5. Color Options
  6. Block Interaction (onInteract)
  7. Events (api.on)
  8. World Generation (api.onWorldGen)
  9. World API (api.world)
 10. Config API (cfg)
 11. Persistent Data (api.saveData / loadData)
 12. GUI System
 13. GUI Widgets
 14. Raw API Access (api.raw)
 15. Vanilla Blocks Reference
 16. Important Rules That You Probably Dont Want to Forget. Honestly It Doesnt Matter All Too Much But Hey Im Putting It Here Because I am bored. (Lua 5.1)
 17. Full Minimal Example


================================================================}{POKIJHGYHdiewhjfuehiufhfeiuaf
1. GETTING STARTED
================================================================}{POKIJHGYHdiewhjfuehiufhfeiuaf

Mods go in the CCMods/ folder in the computer's root.

Two formats are supported at the moment. I think this is all you need, really.

  Single file mod:
    CCMods/mymod.ccmod

  Folder mod:
    CCMods/mymod/mod.lua
    CCMods/mymod/config.txt   (optional)

The filename or folder name becomes the namespace.
A mod named "mymod.ccmod" has namespace "mymod".

Namespaces must be unique. If two mods share a namespace,
neither will load and a conflict warning is printed. 

Config files for single-file mods go here:
    CCMods/mymod.config.txt

Mods can be enabled or disabled from the main menu
under "Mod Config" without deleting the files.


================================================================
2. MOD STRUCTURE
================================================================

Every mod is a Lua file that returns a table.
The table must have an init() function.

    local mod = {}

    mod.name         = "My Mod"
    mod.version      = "1.0.0"
    mod.author       = "You"
    mod.dependencies = { "pineforge_base" }  -- optional

    function mod.init(api, cfg)
        -- register blocks, listen to events, bla bla bla you know the drill... or, probably not, really
    end

    return mod

Fields:
  mod.name          Display name shown in Mod Config screen.
  mod.version       Version string, shown in Mod Config screen.
  mod.author        Author name. Informational only, doesnt actually show up anywhere in the game YET!
  mod.dependencies  List of namespace strings that must be
                    loaded before this mod. If any are missing
                    the game will refuse to open a world and
                    show an error listing what is missing. 
                    This is to make it so some of those API 
                    mods can exist easier.

PineForge loads mods in dependency order automatically.
If a cycle is detected, a warning is printed and loading
continues anyway.


========================}{POKIJHGYHdiewhjfuehiufhfeiuafFHEIUAHFEUFHEUHFIUEHFIUEHUFIEJIOFEUHE
3. THE MOD TABLE
im so bored writing this dude GOD==============================POKIJHGYHdiewhjfuehiufhfeiuaf

mod.init(api, cfg) receives two arguments:

  api   The PineForge mod API (described below).
  cfg   The config file accessor (see section 10).

Everything your mod does should happen inside init().
Do not use globals. Keep state in locals inside init(). PLEASE


================================================================
4. api.registerBlock
================================================================

Registers a new block type.

    local fullId = api.registerBlock(name, opts)

  name      String. Short name, no colons.
            The full id will be "namespace:name".

  opts      Table with the following fields:

    saveChar      REQUIRED. A single uppercase letter (A-Z).
                  Used to identify this block in saved chunk
                  files. Must be unique within your namespace. 
                  This is going to go away, soon. I just couldnt 
                  get it done fast enough to release 0.1 on time.

    displayName   String shown in the creative menu.
                  Defaults to name if not set.

    inHotbar      Boolean. If true the block appears in the
                  creative menu and hotbar. Defaults to false.
                  NOTE ABOUT THIS: Currently, this is for both Creative Mode
                  AND the normal hotbar. I will make it.. ya know, ONLY the hotbar
                  soon enough whenever i revamp the inventory system. 
                  Classic inventory system will stay, but as a toggle.

    onInteract    Function. Called when a player right-clicks
                  this block. See section 6 for more details :3c

    -- Color options: pick ONE of the formats below.
    -- See section 5 for full details.

    color         Single uniform color for all faces.
    color2        Optional darker shade (auto-derived if omitted)

    topColor      Color for the top face.
    sideColor     Color for all four sides.
    bottomColor   Color for the bottom face (defaults to side).
    topColor2 / sideColor2 / bottomColor2   Dark shades.

    colors        Table with per-face keys:
                  top, bottom, north, south, east, west
                  and optional dark variants:
                  top2, bottom2, north2, south2, east2, west2

    modelData     Raw Pine3D model table. Bypasses all color
                  processing. Use for fully custom shapes.

Returns the full block id string ("namespace:name").


================================================================
5. COLOR OPTIONS!!!!
================================================================

All colors use CC:Tweaked color constants (e.g. colors.lime).... duh.

Each block face is made of two triangles — a light one and a
dark one. This gives blocks a shaded appearance and adds depth! I...
I dont know why I never thought of this for other projects.
If you only provide a light color, a darker shade is chosen
automatically based on a built-in pairing table.
(THIS IS WHAT I MEANT BY AUTO DERIVED ABOVE!)

Built-in dark pairs:
  white      -> lightGray
  lightGray  -> gray
  gray       -> black
  yellow     -> orange
  orange     -> brown
  brown      -> black
  lime       -> green
  green      -> black
  cyan       -> blue
  lightBlue  -> blue
  blue       -> black
  red        -> black
  pink       -> red
  magenta    -> purple
  purple     -> black

OPTION A — Uniform color (all faces the same):

    api.registerBlock("myblock", {
        saveChar = "A",
        color    = colors.cyan,
        -- color2 = colors.blue,  -- optional, auto-derived
    })

OPTION B — Top/side split (like grass or wood logs):

    api.registerBlock("myblock", {
        saveChar  = "B",
        topColor  = colors.lime,
        sideColor = colors.brown,
        -- bottomColor defaults to sideColor
    })

OPTION C — Per-face control:

    api.registerBlock("myblock", {
        saveChar = "C",
        colors = {
            top    = colors.white,
            bottom = colors.gray,
            north  = colors.lightGray,
            south  = colors.lightGray,
            east   = colors.lightGray,
            west   = colors.lightGray,
        },
    })

OPTION D — Raw model (advanced):

    api.registerBlock("myblock", {
        saveChar  = "D",
        modelData = myCustomPine3DModelTable,
    })
    
Being so honest, im not even sure if the above TRUELY works. 
I havent experimented with it all that much, kinda just. Praying. 
Dont rely on this raw models for now.

================================================================
6. BLOCK INTERACTION (onInteract)
================================================================

onInteract is called when a player right-clicks the block.

    onInteract = function(x, y, z, iapi)
        -- x, y, z  world position of the clicked block
        -- iapi     interact API (world + gui access)
    end

The interact API (iapi) has:

  iapi.world.getBlock(x, y, z)
    Returns { name = "fullid" } or nil.

  iapi.world.setBlock(x, y, z, id)
    Places a block. id can be a full "namespace:name" or just
    "name" if it is in the same namespace.

  iapi.world.removeBlock(x, y, z)
    Removes a block.

  iapi.gui
    Same GUI API as api.gui. See section 12.

NOTE: Just like real minecraft, this makes it so you cant place 
blocks on interactable stuff meaning you have to click a block next to it
to place. . I havent added shift right clicking yet... so.. Yeah.


================================================================
7. EVENTS (api.on)
================================================================

Listen for game events:

    api.on(eventName, function(...)
        -- handle event
    end)

Available events:

  "blockPlace"    Fires when any block is placed.
                  Args: x, y, z, blockId (string)

  "blockBreak"    Fires when any block is broken.
                  Args: x, y, z, blockId (string)

  "playerMove"    Fires each tick the player moves.
                  Args: x, y, z (camera position)

  "tick"          Fires every game update.
                  Args: dt (delta time, seconds)

  "chunkLoad"     Fires when a chunk is loaded.
                  Args: chunkX, chunkZ

  "chunkUnload"   Fires when a chunk is unloaded.
                  Args: chunkX, chunkZ

Errors inside event callbacks are caught and printed. 
They will not crash the game. 

Example:

    api.on("blockBreak", function(x, y, z, id)
        if id == "mynamespace:myblock" then
            print("My block was broken at " .. x .. "," .. y .. "," .. z)
        end
    end)


================================================================
8. WORLD GENERATION (api.onWorldGen)
================================================================

Register a function that runs after the base terrain is
generated for each new chunk. Meaning: This does not DIRECTLY 
alter world generation, only making you alter the existing chunk.

    api.onWorldGen(function(chunkX, chunkZ, heightMap,
                            setBlock, getBlock,
                            replaceBlock, removeBlock)
        -- modify the chunk here
    end)

Arguments:

  chunkX, chunkZ    Chunk coordinates (not block coordinates).
                    Block x = chunkX * chunkSize + (1..chunkSize)

  heightMap         Table. heightMap[a][b] is a 0..1 noise value
                    for column (a, b) within the chunk.
                    Multiply by maxHeightTerrain to get the
                    approximate surface Y.

  setBlock(x, y, z, id)
                    Places a block only if the position is empty.
                    Use full "namespace:name" ids.

  getBlock(x, y, z)
                    Returns { name = "fullid" } or nil.

  replaceBlock(x, y, z, id)
                    Overwrites an existing block.
                    Required for stone layering and ore placement.

  removeBlock(x, y, z)
                    Carves a block into air (useful for caves).

World gen hooks only run on NEW chunks being generated
for the first time. They do not re-run on loaded chunks.

Example — replace surface grass with snow on cold chunks:

    api.onWorldGen(function(cx, cz, heightMap,
                            setBlock, getBlock,
                            replaceBlock, removeBlock)
        local cs  = 16
        local mhT = 20
        for a = 1, cs do
            for b = 1, cs do
                local wx = cx * cs + a
                local wz = cz * cs + b
                local surface = math.floor(heightMap[a][b] * mhT)
                local top = getBlock(wx, surface, wz)
                if top and top.name == "grass" then
                    replaceBlock(wx, surface, wz, "mymod:snow_grass")
                end
            end
        end
    end)


================================================================
9. WORLD API (api.world)
================================================================

Safe world access available any time inside init() or
event callbacks.

  api.world.getBlock(x, y, z)
    Returns { name = "fullid" } or nil.

  api.world.setBlock(x, y, z, id)
    Places a block if the position is empty.
    Returns true on success, false + reason on failure.
    id can be "namespace:name" or just "name" (same ns).

  api.world.removeBlock(x, y, z)
    Removes the block at this position.
    Returns true, or false + reason on failure.

Block ids for vanilla blocks (no namespace prefix):
    "air", "grass", "dirt", "wood", "leaves",
    "stone", "sand", "water"
NOTE: If you want i can simply edit it to have a minecraft: namespace.
Block ids for mod blocks always have a namespace:
    "pineforge_base:stone"
    "mymod:myblock"


================================================================
10. CONFIG API (cfg)
================================================================

cfg is passed as the second argument to mod.init().
It reads from the mod's config.txt file. 
This requires having a FOLDER mod. Editting the 
raw mod file is kiiinda risky and could screw up sometimes

  cfg.get(key, default)
    Returns the raw string value, or default if missing.

  cfg.getString(key, default)
    Returns the value as a string, or default if missing.

  cfg.getNumber(key, default)
    Returns the value as a number, or default if it cannot
    be parsed. Prints a warning if the value is invalid.

  cfg.getBool(key, default)
    Returns true or false. Accepts: true/false, 1/0,
    yes/no, on/off. Prints a warning if invalid.

  cfg.set(key, value)
    Writes a value back to the config file immediately.
    Useful for saving runtime state between sessions.

Config file format (plain text, one entry per line):
    cave_type=classic
    ore_gen=true
    spawn_rate=0.25

Folder mods:   CCMods/mymod/config.txt
Single file:   CCMods/mymod.config.txt

Players can edit config values in-game from the
"Mod Config" screen on the main menu. 


================================================================
11. PERSISTENT DATA (api.saveData / loadData)
================================================================ ... do these even look good? I dont know if they look good or not.

Save and load arbitrary Lua values scoped to your mod
and the currently open world.

  api.saveData(key, value)
    Serialises value using textutils and saves it.
    key must be a non-empty string with no slashes.
    Returns true on success, false + reason on failure.
    Returns false silently if no world is open yet.

  api.loadData(key)
    Returns the saved value, or nil if it does not exist
    or cannot be read.

  api.deleteData(key)
    Deletes the saved file for this key.
    Returns true. Silent if no world is open.

Data is saved to:
    worlds/<worldId>/moddata/<namespace>/<key>.txt

Any Lua value that textutils.serialise can handle is
supported: strings, numbers, booleans, and tables
(including nested tables). Functions are not supported.

Example — persistent counter:

    local stats = api.loadData("stats") or { count = 0 }

    api.on("blockBreak", function()
        stats.count = stats.count + 1
        api.saveData("stats", stats)
    end)

Example — per-block position data:

    onInteract = function(x, y, z, iapi)
        local key  = "board_" .. x .. "_" .. y .. "_" .. z
        local data = api.loadData(key) or { notes = {} }
        -- modify data ...
        api.saveData(key, data)
    end


================================================================
12. GUI SYSTEM
================================================================ .. ehh screw it im gonna keep using these. Too deep in now

Open a GUI screen from an onInteract callback or an event.

Creating a screen:

    local screen = api.gui.screen(title, opts, theme)

  title    String shown at the top of the window.
  opts     Optional table:
             width   = number (default: auto)
             height  = number (default: auto)
             x       = number (default: centered)
             y       = number (default: centered)
  theme    Optional table to override theme colors.
           See theme keys below.

Opening and closing:

    screen:open()    Blocks until the screen is closed.
    screen:close()   Closes the screen.
    screen:render()  Redraws. Call after changing widget state.

Screens close automatically if the player clicks outside
the window or presses Escape. Escape is.. Assuming.. that it works? 
Being honest i have NEVER gotten 'escape' presses to do ANYTHING and i dont know why 

Theme keys (all optional, use CC color constants):
    bg, border, titleColor, textColor, mutedColor,
    buttonBg, buttonBorder, buttonText,
    slotBg, slotBorder, slotSelect,
    inputBg, inputText, inputBorder,
    progressFg, progressBg,
    borderStyle   ("nice" | "flat" | "none")


================================================================
13. GUI WIDGETS (OOO FANCY!!!)
================================================================

Add widgets by calling methods on the screen object.
All x/y positions are relative to the top-left of the window.

---------------------------------------------------------------- oooooooo i can use these as sub-headers or whatever you call them. im so smart
Label

    screen:addLabel(x, y, text, color)

  color   CC color constant. Optional, defaults to theme.

----------------------------------------------------------------
Button

    screen:addButton(x, y, width, height, text, callback)

  callback   Function called when clicked.

----------------------------------------------------------------
TextInput

    screen:addTextInput(x, y, width, placeholder, onChange)

  placeholder   Shown when empty.
  onChange      function(value) called on every keystroke.

Click the field to focus it. Type to edit.
Backspace to delete. The field becomes active on click.

----------------------------------------------------------------
Divider

    screen:addDivider(x, y, width)

A horizontal line. Useful for separating sections.

----------------------------------------------------------------
ProgressBar

    screen:addProgressBar(x, y, width, value, label)

  value   0.0 to 1.0.
  label   Optional text drawn over the bar.

Update with:   progressBar.value = newValue

----------------------------------------------------------------
Icon

    screen:addIcon(x, y, color, char)

  char   Single character. Defaults to a block char.

----------------------------------------------------------------
Slot

    screen:addSlot(x, y, onInteract)

A single inventory slot.

  onInteract   function(slot, button) called on click.

Methods:
  slot:setItem(blockId, count)
  slot:clear()

----------------------------------------------------------------
Grid

    screen:addGrid(x, y, cols, rows, onSlotInteract)

  onSlotInteract   function(row, col, slot, button)

Methods:
  grid:getSlot(row, col)   Returns the Slot at that position.

----------------------------------------------------------------
ScrollList

    screen:addScrollList(x, y, width, height, items, onSelect)

  items      Table of item entries:
               { label = "text", color = colors.white, data = any }
  onSelect   function(item, index) called on click.

Methods:
  list:setItems(items)     Replace the item list.
  list:scrollBy(delta)     Scroll by delta rows.

Scroll with the mouse wheel while the cursor is over the list.
Arrow keys also work when the screen is open.

----------------------------------------------------------------
Getting widget references back:

All screen:add* methods return the widget object.
You can store it and modify it later:

    local myLabel = screen:addLabel(3, 5, "Hello", colors.white)
    -- later:
    myLabel.text = "World"
    screen:render()


================================================================
14. RAW API ACCESS (api.raw)
================================================================

api.raw gives direct access to engine internals.
This is an escape hatch for things the safe API cannot do.


  api.raw.world    The internal world module.
  api.raw.config   The internal config table.

Using api.raw will trigger a warning screen the next time
a world is opened, asking the player to confirm.
The player can choose to abort. This is to
prevent malicious mods.. or.. something. I dunno.

Only use api.raw if there is no other way to do what
you need. The safe API (api.world, api.registerBlock, etc.)
is stable. The raw internals may change between versions, tho.
I will try to keep everything compatible. If you spot an incompatibility, 
DM me and ill fix it (discord: @nightheartv) or just make a post about it 
here on github.


================================================================
15. VANILLA BLOCKS REFERENCE (because why not)
================================================================

These block ids are available without any namespace.

  "grass"     Green surface block.
  "dirt"      Brown block under the surface.
  "stone"     Grey rock. Also available as pineforge_base:stone. -
  "sand"      Yellow. Generates near water.
  "water"     Blue. Fills low areas.
  "wood"      Brown log. Generated as tree trunks.
  "leaves"    Green. Generated as tree canopy.
  "air"       Empty space. Cannot be placed directly.

Mod blocks always use the full "namespace:name" format:
  "pineforge_base:stone"
  "pineforge_base:coal_ore"
  "pineforge_base:iron_ore"
  "pineforge_base:gold_ore"


================================================================
16. IMPORTANT RULES
================================================================
Now, i assume you already know all of this, but if you dont, or 
are not used to Lua 5.1, heres some tips. 
CC:Tweaked uses Lua 5.1. Some modern Lua features
are NOT available:

  NO goto / ::labels::          Use if/else blocks instead.
  NO bitwise operators          Use arithmetic equivalents.
    (<<, >>, &, |, ~)           ex. use math.floor(x/2^n)
  NO integer division (//)      Use math.floor(a/b)
  NO string.format %q on all    Test carefully.

Other things to be aware of:

  Do not use globals across mods. Each mod is isolated
  but global pollution can cause subtle bugs. Globals
  also annoy me. LOL

  Event callbacks must return quickly. Heavy computation
  inside a tick or playerMove handler will lag the game.

  saveChar must be an UPPERCASE letter (A-Z).
  Lowercase letters are reserved for vanilla blocks. 
  Once again, this feature will be REMOVED in a later update!
  While my goal is to stay compatible, it is VERY likely that 
some things WILL break!

  Each namespace can use each saveChar only once.
  Two blocks in the same mod cannot share a saveChar.

  api.saveData and api.loadData return nil if called
  before a world is opened. Always provide a default:
    local data = api.loadData("key") or {}


================================================================
17. FULL MINIMAL EXAMPLE
================================================================

-- CCMods/mymod.ccmod

local mod = {}

mod.name    = "My Mod"
mod.version = "1.0.0"
mod.author  = "mr poopy pants or something"

function mod.init(api, cfg)

    -- Read config values
    local spawnRate = cfg.getNumber("spawn_rate", 0.1)
    local label     = cfg.getString("block_label", "Magic Block")

    -- Load persistent stats
    local stats = api.loadData("stats") or { broken = 0 }

    -- Register a block
    api.registerBlock("magic_block", {
        saveChar    = "A",
        displayName = label,
        inHotbar    = true,
        topColor    = colors.purple,
        sideColor   = colors.magenta,

        onInteract = function(x, y, z, iapi)
            local screen = iapi.gui.screen("Magic Block", {
                width = 28, height = 10
            })
            screen:addLabel(3, 3, "Hello from " .. label, colors.purple)
            screen:addLabel(3, 5, "Broken: " .. stats.broken, colors.white)
            screen:addButton(8, 7, 12, 3, "Close", function()
                screen:close()
            end)
            screen:open()
        end,
    })

    -- Listen for break events
    api.on("blockBreak", function(x, y, z, id)
        if id == "mymod:magic_block" then
            stats.broken = stats.broken + 1
            api.saveData("stats", stats)
        end
    end)

    -- World gen: sprinkle magic blocks underground
    api.onWorldGen(function(cx, cz, heightMap,
                            setBlock, getBlock,
                            replaceBlock, removeBlock)
        local cs = 16
        for a = 1, cs do
            for b = 1, cs do
                if math.random() < spawnRate then
                    local wx = cx * cs + a
                    local wz = cz * cs + b
                    local surface = math.floor(heightMap[a][b] * 20)
                    local y = math.random(1, math.max(1, surface - 2))
                    setBlock(wx, y, wz, "mymod:magic_block")
                end
            end
        end
    end)

end

return mod


-- CCMods/mymod.config.txt
-- spawn_rate=0.1
-- block_label=Magic Block


.. I hooe you know. The above mod hasnt actually been tested LMFAO
Just.. trust me bro it works! 3 AM me writing a mod is NOT what i had 
on my bingo card. so... sorry if it doesnt actually work, lol

================================================================
  End of Documentation
================================================================
