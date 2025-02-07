local ddf = require 'test.ddf'

local position = ddf.vector3()
local color = ddf.vector4(125 / 255, 222 / 255, 148 / 255, 1)

local cp = ddf.component_property('iid'):set_property('iid', "1an5to", "PROPERTY_TYPE_HASH")

local go1 = ddf.instance('go1', '/main/player.go'):position(123, 100, 1)
local go2 = ddf.instance('go2', '/main/player.go'):position(-123, 100, 1)

local gameobject = ddf.instance('go', '/main/player.go')
    :position(123, 100, 1)
    :add_child(go1)
    :add_child(go2)
    :set_component_properties(cp)

local collection = ddf.collection('collection')
    :add_instance(gameobject)
    :add_instance(go1)
    :add_instance(go2)

local tilesource = ddf.tile_set('/main/Cavernas_by_Adam_Saltsman.png', 8, 8)
    :set_collision('/main/Cavernas_by_Adam_Saltsman.png')

local str = tostring(tilesource)
local file = io.open('./test/cavernas.tilesource', 'w')
file:write(str)
file:close()
