# LDTK To Defold

A Defold library for parsing and converting [LDTK](https://ldtk.io/) levels to Defold's Collections.

## Installation

Add this project as a Defold library dependency under the dependecies field in your `game.project` file:

[https://github.com/TheKing0x9/ldtk2defold/archive/main.zip](https://github.com/TheKing0x9/ldtk2defold/archive/main.zip)

Or point to the zip file of a [specific release](https://github.com/TheKing0x9/ldtk2defold/releases)

## Usage

* Add this library to your project
* Copy the LDTK project file and relevant tileset images to your Defold project
* Add a configuration file as detailed below
* Click `View -> Change LDTK Config File` and select the config file.
* Click `Right Click -> Generate Tilemaps` on the LDTK file in the editor.

This will create a folder with the same name as the LDTK file and place the generated tilemaps, tilesources and collections in it.

The converter generates the following:

* Defold tilesources using the same settings as specified in the LDTK file
* Defold tilemaps (one tilemap per layer)
* Defold collections (one collection per level) with all the tilemaps and gameobjects placed as in the LDTK file.
* A collection that has levels placed exactly as in LDTK world view.
* A Lua Module that contains Enums, and Entities and World properties.

> Ensure that the images referred to in LDTK projects are within the Defold project's directory.

> Remember to add the provided iid.script to any gameobject that needs to be generated as an entity.

## Configuration File

The project expects a config file for defining entity -> gameobject mapping and other settings. By default the file should be named `config.lua` and placed at the root of the project.

However, this is configurable in the editor using `View -> Change LDTK Config File`. At the moment the config file has the following settings:

> The config file is loaded sandboxed, which means that all of the lua global functions and libraries are **not** available.

```lua
local config = {}

-- assigns collision images to the tilesources.
config.assign_collision = true

-- directory in which project files are generated. Defaults to the directory .ldtk file is in.
config.project_root = '/path/to/project'

-- whether to generate only levels or to also generate a main collection with all levels placed as in LDTK world view.
config.map_type = enums.map_type.LEVELS_ONLY -- or enums.map_type.MAIN_COLLECTION

-- when the LDTK Layout is set to Horizontal or Vertical, this value is used to offset the levels
config.lvl_offsets = 48

-- assigns a gameobject to an entity. The key is the entity name and the value is the gameobject name
-- example: to create a reference for entitiy player
-- config.entities = { ['Player'] = '/example/gameobjects/player.go', }
config.entities = {}

-- mapping of tileset identifer to the respective images
-- example: to specify image for tileset Scifi_tileset in LDTK project
-- config.tilesets = { ["Scifi_tileset"] = '/example/assets/images/tileset/level_tileset.png' }
config.tilesets = {}

-- save the Defold project after generation?
config.save = false

return config
```

## Example

An example project is provided in the `example` folder. It is a small platformer game with the aim to demonstrate the features of the generator. Some samples shipped alongwith LDTK are also provided in the `samples` folder.

## Differences between LDTK and Defold

Following section details some major differences between LDTK and Defold.

* **Important** If the provided image is not a multiple of the tile size, Defold ignores the excess part of image, while LDTK counts it as a tile. This creates differences in numbering of tiles, leading to undefined behaviour
* Defold uses a X -> Right, Y -> Up coordinate system, while LDTK uses a X -> Right, Y -> Down coordinate system. While the layout of generated collections will be the same, expect some changes in the actual positions.
* Defold uses a Z - order to determine the rendering order of the tilemaps, while LDTK uses the order of the layers.

## Unsupported Features

* Tile offsets are not supported at the moment, because Defold tilemaps do not support tile offsets
* Tile opacity is not supported for the same reason. However, a common layer opacity is supported.
* Tilemaps without an images are also not supported. This may change in the near future, perhaps by exporting such tilemaps to a simple table?
* Background images are not supported at the moment. Will be added in the next release
* A way to specify the a layer / entity Z - order needs to be decided upon.

## Credits

- [LDTK](https://ldtk.io/) by [Deepnight](https://deepnight.net/)
- [json.lua](https://github.com/rxi/json.lua) by [rxi](https://github.com/rxi/)
- [Defold Collection Parser](https://github.com/rgrams/defold_collection_parser/) by [rgrams](https://github.com/rgrams/) was used in earlier iterations of this project.

---
