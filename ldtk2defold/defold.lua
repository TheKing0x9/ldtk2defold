local parser = require 'ldtk2defold.collection'

local function split(path)
    return path:match("^(.-)([^\\/]-)(%.[^\\/%.]-)%.?$")
end

-- basic class definition
local class = {}
class.__index = class

function class:new(...)
end

function class:extend()
    local cls = {}
    for k, v in pairs(self) do
        if k:find("__") == 1 then
            cls[k] = v
        end
    end
    cls.__index = cls
    cls.super = self
    setmetatable(cls, self)
    return cls
end

function class:is(t)
    local mt = getmetatable(self)
    while mt do
        if mt == t then
            return true
        end
        mt = getmetatable(mt)
    end
    return false
end

function class:__call(...)
    local obj = setmetatable({}, self)
    obj:new(...)
    return obj
end

-- defold basic component type
local component = class:extend()

function component:new(name, basepath, ext)
    self.name = name
    self.basepath = basepath
    self.path = basepath .. name .. '.' .. ext
    self.encode_fn = parser.encodeFile
end

function component:write()
    -- if there is no compose function, return
    if not self.compose then return end

    local path = self.path
    if self.path:sub(1, 1) == '/' then
        path = '.' .. self.path
    end
    local file = io.open(path, 'w')
    assert(file, 'Could not open file ' .. self.path)

    local data = self:compose()
    file:write(self.encode_fn(file, data))
    file:flush()

    file:close()

    return self
end

-- defold tilesource
local tilesource = component:extend()

function tilesource:new(name, basepath)
    self.super.new(self, name, basepath, 'tilesource')
    self.data = { extrude_borders = 2 }
end

function tilesource:set_image(path, gridsize)
    self.data.image = path
    self.data.tile_width = gridsize
    self.data.tile_height = gridsize
    return self
end

function tilesource:set_collision(path)
    self.data.collision = path
    if path == nil then self.data.convex_hulls = nil end
    return self
end

function tilesource:set_properties(margin, spacing, padding)
    if spacing then self.data.tile_spacing = spacing end
    if margin then self.data.tile_margin = margin end
    if padding then self.data.inner_padding = padding end
    return self
end

function tilesource:compose()
    return self.data
end

function tilesource.from(path)
    local file, err = io.open('.' .. path, 'r')
    if not file then return nil, err end

    local base, name, ext = split(path)
    local temp = parser.decodeFile(file, "")
    file:close()

    local self = tilesource(name, base)
    self.data = temp
    return self
end

-- defold tilemaps
local tilemap = component:extend()

function tilemap:new(name, basepath)
    self.super.new(self, name, basepath, 'tilemap')
    self.layers = {}
    self.encode_fn = parser.encodeTilemap
end

function tilemap:set_source(s)
    self.tilesource = s
    return self
end

function tilemap:add_layer(id, z)
    z = z or 0
    self.layers[id] = { z = z, tiles = {} }
    return self
end

function tilemap:add_tile(layer, x, y, tile, fx, fy)
    table.insert(self.layers[layer].tiles, { x = x, y = y, tile = tile, h_flip = fx, v_flip = fy })
    return self
end

function tilemap:compose()
    local data = {
        tile_set = self.tilesource.path,
        layers = {},
    }

    data.material = self.material or '/builtins/materials/tile_map.material'
    data.blend_mode = self.blend_mode or "BLEND_MODE_ALPHA"

    for k, v in pairs(self.layers) do
        local l = { id = k, z = v.z }
        if #v.tiles > 0 then l.cell = {} end

        for _, tile in ipairs(v.tiles) do
            table.insert(l.cell, tile)
        end
        table.insert(data.layers, l)
    end

    return data
end

function tilemap.from(path)
    local file, err = io.open('.' .. path, 'r')
    if not file then return nil, err end

    local base, name, ext = split(path)
    local temp = parser.decodeFile(file, "")
    file:close()

    local self = tilemap(name, base)

    -- only copy blend mode and material for now. layers are rewritten
    self.material = temp.material
    self.blend_mode = temp.blend_mode

    return self
end

-- defold gameobject
local gameobject = component:extend()

function gameobject:new(name, basename, embedded)
    if embedded then
        self.name = name
        self.write = nil
    else
        self.super.new(self, name, basename, 'go')
    end

    self.position = { x = 0, y = 0, z = 0 }
    self.scale = { x = 1, y = 1, z = 1 }

    self.components = {}
    self.scripts = {}
    self.embedded = embedded
    self.encode_fn = parser.encodeTilemap
end

function gameobject:set_position(x, y, z)
    if x then self.position.x = x end
    if y then self.position.y = y end
    if z then self.position.z = z end

    return self
end

function gameobject:set_scale(x, y, z)
    if x then self.scale.x = x end
    if y then self.scale.y = y end
    if z then self.scale.z = z end

    return self
end

function gameobject:set_component_position(id, x, y, z)
    assert(self.components[id], 'Component ' .. id .. ' does not exist')
    self.components[id].position = { x = x, y = y, z = z }
    return self
end

function gameobject:compose()
    local data = {
        id = self.name,
        position = self.position,
        scale3 = self.scale,
        data = {}
    }

    if self.children then
        data.children = self.children
    end

    local c = {}
    for k, v in pairs(self.components) do
        table.insert(c, { id = k, component = v.path, position = v.position })
    end

    for k, v in pairs(self.scripts) do
        table.insert(c, { id = k, component = v.path, properties = v.properties })
    end
    if #c > 0 then data.data.components = c end

    if self.embedded_components then
        data.data.embedded_components = self.embedded_components
    end

    return data
end

function gameobject:add_component_file(id, path)
    self.components[id] = { path = path }
    return self
end

function gameobject:add_child(id)
    self.children = self.children or {}
    table.insert(self.children, id)
    return self
end

function gameobject:add_script(id, path, properties)
    self.scripts[id] = { path = path, properties = properties }
    return self
end

-- defold collection
local collection = component:extend()

function collection:new(name, basepath)
    self.super.new(self, name, basepath, 'collection')

    self.embedded_instances = {}
    self.instances = {}
    self.collection_instances = {}
    -- used to store instance ids
    self.hashes = {}
end

local function get_unique_instance(self, name)
    if self.hashes[name] then
        self.hashes[name] = self.hashes[name] + 1
        return name .. self.hashes[name]
    end

    self.hashes[name] = 0
    return name
end

function collection:add_collection_instance(name, path)
    name = get_unique_instance(self, name)
    if self.data and self.data.collection_instances then
        for k, v in ipairs(self.data.collection_instances) do
            if v.id == name then
                table.remove(self.data.collection_instances, k)
            end
        end
    end

    self.collection_instances[name] = { path = path }
    return name
end

function collection:add_gameobject(name)
    -- very very terrible hack. replace asap
    name = get_unique_instance(self, name)
    if self.data and self.data.embedded_instances then
        for k, v in ipairs(self.data.embedded_instances) do
            if v.id == name then
                table.remove(self.data.embedded_instances, k)
            end
        end
    end

    local go = gameobject(name, self.basepath, true)
    self.embedded_instances[name] = go
    return go
end

function collection:add_gameobject_file(name, path)
    -- same here
    name = get_unique_instance(self, name)
    local component_properties = nil
    if self.data and self.data.instances then
        for k, v in ipairs(self.data.instances) do
            if v.id == name then
                if v.prototype == path then component_properties = v.component_properties end
                table.remove(self.data.instances, k)
            end
        end
    end
    self.instances[name] = { path = path, component_properties = component_properties }
    return name
end

function collection:get_gameobject(id)
    if self.embedded_instances[id] then
        return self.embedded_instances[id]
    end
    return self.instances[id]
end

function collection:set_gameobject_iid(id, iid)
    assert(self.instances[id], 'instance ' .. id .. ' does not exist')
    local go = self.instances[id]

    if go.component_properties and not go.component_properties[1] then
        go.component_properties = { go.component_properties }
    end

    if go.component_properties then
        for k, v in ipairs(go.component_properties) do
            if v.id == 'iid' then
                v.properties = {
                    id = 'iid',
                    value = iid,
                    type = 'PROPERTY_TYPE_HASH'
                }
                return self
            end
        end
    end

    go.component_properties = go.component_properties or {}
    table.insert(go.component_properties,
        { id = 'iid', properties = { id = 'iid', value = iid, type = 'PROPERTY_TYPE_HASH' } })

    return self
end

function collection:set_instance_position(id, x, y)
    assert(self.instances[id], 'Instance ' .. id .. ' does not exist')
    self.instances[id].position = { x = x, y = y, z = 0 }
    return self
end

function collection:set_instance_scale(id, scale)
    assert(self.instances[id], 'Instance ' .. id .. ' does not exist')
    self.instances[id].scale = scale
    return self
end

function collection:set_collection_instance_position(id, x, y)
    assert(self.collection_instances[id], 'Collection instance ' .. id .. ' does not exist')
    self.collection_instances[id].position = { x = x, y = y, z = 0 }
    return self
end

function collection:set_collection_instance_scale(id, scale)
    assert(self.collection_instances[id], 'Collection instance ' .. id .. ' does not exist')
    self.collection_instances[id].scale = scale
    return self
end

function collection:compose()
    local data = self.data or {
        name = self.name,
        scale_along_z = 0,
    }

    data.name = self.name
    local i = (self.data and self.data.embedded_instances) or {}
    for k, v in pairs(self.embedded_instances) do
        table.insert(i, v:compose())
    end
    if #i > 0 then data.embedded_instances = i end

    local j = (self.data and self.data.instances) or {}
    for k, v in pairs(self.instances) do
        table.insert(j,
            {
                id = k,
                prototype = v.path,
                position = v.position,
                scale3 = v.scale,
                component_properties = v.component_properties
            })
    end
    if #j > 0 then data.instances = j end

    local k = (self.data and self.data.collection_instances) or {}
    for key, v in pairs(self.collection_instances) do
        table.insert(k,
            {
                id = key,
                collection = v.path,
                position = v.position,
                scale3 = v.scale,
            })
    end
    if #k > 0 then data.collection_instances = k end

    return data
end

function collection.from(path)
    local file, err = io.open('.' .. path, 'r')
    if not file then return nil, err end

    local base, name, ext = split(path)
    local temp = parser.decodeFile(file, "")
    file:close()

    local self = collection(name, base)

    self.data = temp

    if self.data.embedded_instances then
        if not self.data.embedded_instances[1] then
            self.data.embedded_instances = { self.data.embedded_instances }
        end
    end

    if self.data.instances then
        if not self.data.instances[1] then
            self.data.instances = { self.data.instances }
        end
    end

    if self.data.collection_instances then
        if not self.data.collection_instances[1] then
            self.data.collection_instances = { self.data.collection_instances }
        end
    end

    return self
end

local defold = {
    split = split,
    tilesource = tilesource,
    tilemap = tilemap,
    gameobject = gameobject,
    collection = collection
}

return defold
