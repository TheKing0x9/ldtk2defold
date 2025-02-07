local inspect = require 'inspect'
local schemas = require 'test.schemas'

local ddf     = {}
local INDENT  = "  "

-- basic class definition
local class   = {}
class.__index = class

function class:new(...)
end

function class:extend(schema)
    local cls = {}
    for k, v in pairs(self) do
        if k:find("__") == 1 then
            cls[k] = v
        end
    end
    cls.__index = cls
    cls.super = self
    cls.schema = schema
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

local function formatNumber(x)
    x = string.format("%f", x)
    x = string.match(x, "(%-?%d+%.0?[0-9]-)[0]*$") -- Cut off extra zeroes.
    return x
end

-- forward declaration
local all_types = {}

-- start creating classes
local ddf_type = class:extend()

function ddf_type:new(schema)
    self.schema = schema
    self.default = {}
    self.data = {}

    -- find and store all default and required values beforehand
    for key, value in pairs(schema) do
        if value.default then
            -- self.default[key] = value.default
            self.data[key] = value.default
        end
    end
end

function ddf_type:validate(key, value)
    local schema = self.schema[key]
    if not schema then
        return false, ("key %s not found in schema"):format(key)
    end

    if schema.required and not value then
        return false, "value required"
    elseif not value and schema.default then
        return true
    elseif not value then
        return false, "value required"
    end

    local atomic_types = {
        string = 'string',
        float = 'number',
        uint32 = 'number',
    }

    if atomic_types[schema.datatype] then
        if type(value) ~= atomic_types[schema.datatype] then
            return false,
                ("Type mismatch while setting key %s. Expected %s, got %s"):format(key, schema.datatype, type(value))
        else
            return true
        end
    end

    local type_schema = schemas[schema.datatype]

    if type_schema.enum then
        if type(value) ~= "string" then
            return false,
                ("Type mismatch while setting key %s. Expected %s, got %s"):format(key, schema.datatype, type(value))
        end

        if not type_schema[value] then
            return false, ("Key %s not found in enum %s"):format(key, schema.datatype)
        end

        return true
    end

    local edited_type = string.gsub(schema.datatype, "_desc", "")
    local ddftype = all_types[edited_type].schema
    if not ddftype then
        return false, ("Type %s not found"):format(schema.datatype)
    end

    return true
end

function ddf_type:set(key, value)
    local ok, err = self:validate(key, value)
    if not ok then
        error(err)
    end

    if self.schema[key].repeated then
        self.data[key] = self.data[key] or {}
        table.insert(self.data[key], value)
    else
        self.data[key] = value or self.schema[key].default
    end

    return self
end

function ddf_type:get(key)
    if not self.data[key] then
        return error(("Key %s not found"):format(key))
    end

    return self.data[key]
end

local function indent_line(line, indent)
    return ("%s%s"):format(INDENT:rep(indent), line)
end

local function serialize_value(schema, key, value, indent)
    if schema[key].datatype == 'string' then
        value = ("%q"):format(value)
    elseif schema[key].datatype == 'float' then
        value = formatNumber(value)
    elseif schema[key].datatype == 'uint32' then
        value = ("%d"):format(value)
    elseif type(value) == 'table' and value.is then
        value = ("{\n%s\n%s}"):format(value:tostring(indent + 1), string.rep(INDENT, indent))
    end

    return ("%s%s: %s"):format(string.rep(INDENT, indent), key, value)
end

function ddf_type:serialize(indent)
    local lines = {}
    indent = indent or 0

    local schema = self.schema
    for key, value in pairs(self.data) do
        -- process the value
        if schema[key].repeated then
            for i = 1, #value do
                local line = serialize_value(schema, key, value[i], indent)
                table.insert(lines, line)
            end
        else
            table.insert(lines, serialize_value(schema, key, value, indent))
        end
    end

    return lines
end

function ddf_type:tostring(indent)
    indent = indent or 0

    local lines = self:serialize(indent)
    local str = table.concat(lines, "\n")
    return str
end

function ddf_type:__tostring()
    return self:tostring(0)
end

local vector3 = ddf_type:extend(schemas.vector3)

function vector3:new(x, y, z)
    vector3.super.new(self, schemas.vector3)

    self:set('x', x)
    self:set('y', y)
    self:set('z', z)
end

function vector3:x(x) return self:set('x', x) end

function vector3:y(y) return self:set('y', y) end

function vector3:z(z) return self:set('z', z) end

local vector4 = ddf_type:extend(schemas.vector4)

function vector4:new(x, y, z, w)
    ddf_type.new(self, schemas.vector4)

    self:set('x', x)
    self:set('y', y)
    self:set('z', z)
    self:set('w', w)
end

function vector4:x(x) return self:set('x', x) end

function vector4:y(y) return self:set('y', y) end

function vector4:z(z) return self:set('z', z) end

function vector4:w(w) return self:set('w', w) end

function vector4:__tostring()
    local x = formatNumber(self.data.x)
    local y = formatNumber(self.data.y)
    local z = formatNumber(self.data.z)
    local w = formatNumber(self.data.w)

    return ("%s, %s, %s, %s"):format(x, y, z, w)
end

local property = ddf_type:extend(schemas.property_desc)

function property:new(id, value, type)
    self.super.new(self, schemas.property_desc)

    self:set('id', id)
    self:set('value', value)
    self:set('type', type)
end

local component_property = ddf_type:extend(schemas.component_property_desc)

function component_property:new(id)
    self.super.new(self, schemas.component_property_desc)

    self:set('id', id)
end

function component_property:set_property(id, value, type)
    self:set('properties', property(id, value, type))
    return self
end

local instance = ddf_type:extend(schemas.instance_desc)

function instance:new(id, prototype)
    self.super.new(self, schemas.instance_desc)

    self:set('id', id)
    self:set('prototype', prototype)

    -- prevent errors if position, rotation, scale3 are not set
    self:set('position', vector3(0, 0, 0))
    self:set('scale3', vector3(1, 1, 1))
end

function instance:position(x, y, z)
    local pos = vector3(x, y, z)
    self:set('position', pos)

    return self
end

function instance:rotation(x, y, z, w)
    local rot = vector4(x, y, z, w)
    self:set('rotation', rot)

    return self
end

function instance:scale3(x, y, z)
    local scale = vector3(x, y, z)
    self:set('scale3', scale)

    return self
end

function instance:add_child(i)
    if not i.is or not i:is(instance) then
        error(("Expected instance, got %s"):format(type(instance)))
    end
    self:set('children', i:get('id'))
    return self
end

function instance:set_component_properties(props)
    self:set('component_properties', props)
    return self
end

local collection = ddf_type:extend(schemas.collection_desc)

function collection:new(name)
    self.super.new(self, schemas.collection_desc)

    self:set('name', name)
end

function collection:add_instance(i)
    self:set('instances', i)
    return self
end

function collection:set_scale_along_z(z)
    self:set('scale_along_z', z)
    return self
end

-- tilesets and tilemaps
local convex_hull = ddf_type:extend(schemas.convex_hull)

function convex_hull:new(index, count, collision_group)
    self.super.new(self, schemas.convex_hull)

    self:set('index', index)
    self:set('count', count)
    self:set('collision_group', collision_group)
end

local cue = ddf_type:extend(schemas.cue)

function cue:new(id, frame)
    self.super.new(self, schemas.cue)

    self:set('id', id)
    self:set('frame', frame)
end

local animation = ddf_type:extend(schemas.animation)

function animation:new(id, start_tile, end_tile)
    self.super.new(self, schemas.animation)

    self:set('id', id)
    self:set('start_tile', start_tile)
    self:set('end_tile', end_tile)
end

function animation:set_playback(pb)
    self:set('playback', pb)
    return self
end

function animation:set_fps(fps)
    self:set('fps', fps)
    return self
end

function animation:set_flip_x(flip_x)
    self:set('flip_horizontal', flip_x)
    return self
end

function animation:set_flip_y(flip_y)
    self:set('flip_vertical', flip_y)
    return self
end

function animation:add_cue(cue)
    self:set('cues', cue)
    return self
end

local tile_set = ddf_type:extend(schemas.tile_set)

function tile_set:new(image, tile_width, tile_height)
    self.super.new(self, schemas.tile_set)

    self:set('image', image)
    self:set('tile_width', tile_width)
    self:set('tile_height', tile_height)
end

function tile_set:set_collision(path)
    self:set('collision', path)
    return self
end

function tile_set:set_properties(margin, spacing, padding)
    if margin then self:set('margin', margin) end
    if spacing then self:set('spacing', spacing) end
    if padding then self:set('padding', padding) end
    return self
end

local tile_cell = ddf_type:extend(schemas.tile_cell)

function tile_cell:new(x, y, tile_id)
    self.super.new(self, schemas.tile_cell)

    self:set('x', x)
    self:set('y', y)
    self:set('tile', tile_id)
end

function tile_cell:set_flip(flip_x, flip_y, rotate90)
    if flip_x ~= nil then self:set('h_flip', flip_x) end
    if flip_y ~= nil then self:set('v_flip', flip_y) end
    if rotate90 ~= nil then self:set('rotate90', rotate90) end
end

local tile_layer = ddf_type:extend(schemas.tile_layer)

function tile_layer:new(id)
    self.super.new(self, schemas.tile_layer)

    self:set('id', id)
end

function tile_layer:set_z(z)
    self:set('z', z)
    return self
end

function tile_layer:set_is_visible(visible)
    self:set('visible', visible)
    return self
end

function tile_layer:add_cell(cell)
    self:set('cell', cell)
    return self
end

local tile_grid = ddf_type:extend(schemas.tile_grid)

function tile_grid:new(set)
    self.super.new(self, schemas.tile_grid)

    self:set('tile_set', set)
    self.layers = {} --hashmap for accessing layers
end

function tile_grid:add_layer(id)
    local layer = tile_layer(id)
    self.set('layers', layer)
    self.layers[id] = layer
    return self
end

function tile_grid:set_material(path)
    self.set('material', path)
    return self
end

function tile_grid:add_cell(layer, x, y, id)
    local layer = self.layers[layer]
    if not layer then
        error(("Layer %s not found"):format(layer))
    end

    local cell = tile_cell(x, y, id)
    layer:add_cell(cell)
    return self, cell
end

function tile_grid:set_blend_mode(mode)
    mode = schemas.blend_mode.BLEND_MODE_ALPHA
    self.set('blend_mode', mode)
    return self
end

all_types.vector3 = vector3
all_types.vector4 = vector4
all_types.quat = vector4
all_types.instance = instance
all_types.collection = collection
all_types.component_property = component_property
all_types.property = property
all_types.convex_hull = convex_hull
all_types.cue = cue
all_types.animation = animation
all_types.tile_set = tile_set
all_types.tile_cell = tile_cell
all_types.tile_layer = tile_layer
all_types.tile_grid = tile_grid

return all_types
