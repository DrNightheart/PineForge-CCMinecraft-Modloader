# PineForged

A modding platform for CC:Tweaked built on top of [CC-Minecraft](https://github.com/Xella37/CC-Minecraft) by Xella.  
PineForged adds a mod loader, event system, GUI framework, persistent data storage, and base world generation. 


## Installation

1. Place `install.lua` on your ComputerCraft computer
This can be by wget, downloading the file, or any other method.
2. Run it:
   ```
   lua install.lua
   ```
3. The installer writes all game files and deletes itself. This is temporary until
a later version, simply because i dont want to take the time to make a proper wget installer. 
5. Start the game!

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Space / Shift | Up / Down |
| Arrow Keys | Look |
| Left Click | Break block |
| Right Click | Place block / Interact |
| Scroll / 1–9 | Select hotbar slot |
| E | Creative menu |
| ` | Pause menu |
| = / - | Increase / decrease render distance |
| G | Toggle high-res mode | NOTE: THIS HAS LIKE ZERO PURPOSE LOL. I  highly suggest not doing this unless you like it or something.
| Z / X / C | Frame times / Hotbar / FPS | 

---

## Mods

Mods go in the `CCMods/` folder.

```
CCMods/mymod.ccmod          single file mod
CCMods/mymod/mod.lua        folder mod
CCMods/mymod/config.txt     optional config
```

The filename or folder name becomes the mod's namespace.  
Mods can be toggled on/off from **Main Menu → Mod Config** without deleting files.

A minimal mod looks like this:

```lua
local mod = {}

mod.name    = "My Mod"
mod.version = "1.0.0"
mod.author  = "You"

function mod.init(api, cfg)

    api.registerBlock("my_block", {
        saveChar    = "A",
        displayName = "My Block",
        inHotbar    = true,
        color       = colors.cyan,
    })

end

return mod
```

See `PINEFORGED_DOCS.txt` for the full API reference.

---

## Included Mods

**pineforge_base** — Built-in content mod. Adds stone layers, cave carving, and coal/iron/gold ore generation. Configurable via `CCMods/pineforge_base/config.txt`.
This is going to become a way better API, but for now, it is being used as the content mod. 

**examplemod** — A full example mod demonstrating blocks, persistent data, GUI screens, world generation hooks, events, and config. Useful as a starting point.

---

## Credits

- **Xella** — original [CC-Minecraft](https://github.com/Xella37/CC-Minecraft) that PineForged is built on top of.
- **Pine3D** — 3D rendering engine for CC:Tweaked... ALSO made by **Xella**!
- **betterblittle / blittle** — high-resolution pixel buffer rendering. not sure who made this one, really. 
- **noise** — Perlin noise library used for terrain generation

---

## License
uses standard MIT. Please respect it. This is not entirely my own code.
PineForged is built on CC-Minecraft. Please respect Xella's original license/ MIT Licence. In no way, shape, and or form do i claim the original code made by Xella. 
This project would not have been the same without them making this game (Letalone even existing), so i thank them for that very much!

## About the maker:
Nightheart, @nightheartv on discord, is a decent coder. Not too good, though.
He LOVES to make Pine3d based games, such as this project here, and also his other projects, like CC Zombies and Blender Animations to Computercraft conversion.
Thats about all, really. 

