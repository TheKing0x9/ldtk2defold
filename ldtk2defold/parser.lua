local json = require "ldtk2defold.json"
local defold = require 'ldtk2defold.defold'

local M = {}

-- initialized in parse function (see below)
---@type any
local config

-- metatable to identify iid strings. This is needed to differentiate between iids and normal keys
local iid = {}
iid.__index = iid

function iid.new(id)
    local self = setmetatable({}, iid)
    self.id = id
    return self
end

function iid.is(t)
    return getmetatable(t) == iid
end

local function from_hex(str)
    local r, g, b, a = str:match("#(%x%x)(%x%x)(%x%x)(%x?%x?)")
    a = a ~= '' or 'ff'
    return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255
end

local function hextostring(r, g, b, a)
    return string.format("%f, %f, %f, %f", r, g, b, a)
end

local function ldtk_to_defold_types(value, ldtk_type, h)
    if ldtk_type == 'Int' then
        value = tonumber(value)
    elseif ldtk_type == 'Float' then
        value = tonumber(value)
    elseif ldtk_type == 'Bool' then
        value = value == 'true'
    elseif ldtk_type == 'Color' then
        local r, g, b, a = from_hex(value)
        value = string.format('vmath.vector4(%f, %f, %f, %f)', r, g, b, a)
    elseif ldtk_type == 'String' or ldtk_type == 'FilePath' or ldtk_type == 'Multilines' then
        value = value and string.format('%q', value)
    elseif ldtk_type == 'Point' then
        value = value and string.format('vmath.vector3(%f, %f, 0)', value.cx, h - value.cy)
    elseif ldtk_type == 'EntityRef' then
        value = value and {
            levelIid = '"' .. value.levelIid .. '"',
            entityIid = '"' .. value.entityIid .. '"'
        }
    elseif ldtk_type == 'Tile' then
        -- perhaps change tilemap uid to a tileset path
    elseif type(value) == 'string' then
        local enumType = string.match(ldtk_type, 'LocalEnum.(%w+)', 1)
        value = enumType and value and string.format('enums[%q][%q]', enumType, value)
    end

    return value
end

local function recursively_create_lines(lines, t, indent)
    for k, v in pairs(t) do
        k = type(k) == 'string' and string.format('%q', k) or k
        k = type(k) == 'table' and iid.is(k) and string.format("hash(%q)", k.id) or k

        if type(v) == 'table' then
            table.insert(lines, string.rep(' ', indent) .. '[' .. k .. ']' .. ' = {')
            recursively_create_lines(lines, v, indent + 4)
            table.insert(lines, string.rep(' ', indent) .. '},')
        else
            table.insert(lines, string.rep(' ', indent) .. '[' .. k .. ']' .. ' = ' .. tostring(v) .. ',')
        end
    end
end

local function to_local_variable(identifier, t, indent)
    local lines = {}

    table.insert(lines, 'local ' .. identifier .. ' = {')
    recursively_create_lines(lines, t, indent)
    table.insert(lines, '}')
    return lines
end

local function handle_entities(identifier, instance, _, collection, root, height, z)
    local h = instance.__cHei
    local entity_fields = {}
    for _, entity in ipairs(instance.entityInstances) do
        if not config.entities[entity.__identifier] then
            print('Entity not found in config: ' .. entity.__identifier)
        else
            local id = collection:add_gameobject_file(entity.__identifier, config.entities[entity.__identifier])
            collection:set_instance_position(id, entity.px[1], height - entity.px[2], z):set_gameobject_iid(id,
                entity.iid)

            local id = iid.new(entity.iid)
            entity_fields[id] = {}
            -- write a serializer for field instances
            for k, v in ipairs(entity.fieldInstances) do
                local field = v.__identifier
                if field then
                    local value = v.__value
                    if type(value) == "table" and value[1] then
                        local type = v.__type:match('Array<(.-)>')
                        for k, v in ipairs(value) do
                            value[k] = ldtk_to_defold_types(v, type, h)
                        end
                    else
                        value = ldtk_to_defold_types(value, v.__type, h)
                    end
                    entity_fields[id][field] = value
                end
            end
        end
    end

    return entity_fields
end

local function create_tilemap(identifier, instance, tileset, collection, root, lvlHeight, z)
    local h = instance.__cHei
    local layers = { [1] = identifier .. 1 }
    local setgrid = { [1] = {} }

    local grid = (defold.tilemap.from(root .. identifier .. ".tilemap") or defold.tilemap(identifier, root))
        :set_source(tileset)
        :add_layer(identifier .. 1)

    local function get_empty_layer(x, y)
        local i = 1
        while i <= #setgrid do
            if not setgrid[i][x] or not setgrid[i][x][y] then
                return i
            end
            i = i + 1
        end
        -- no layer found, create a new layer and return it
        grid:add_layer(identifier .. i, 0.0001 * i)
        setgrid[i] = {}
        return i
    end

    local tiles = (instance.autoLayerTiles and instance.autoLayerTiles) or instance.gridTiles
    for _, tile in ipairs(tiles) do
        -- find which tiles are half pixel off
        local x = math.floor(tile.px[1] / tileset.data.tile_width)
        local y = math.floor(h - tile.px[2] / tileset.data.tile_height - 1)
        local tile_id = tile.t

        local fx, fy = tile.f % 2 ~= 0, tile.f > 1
        local i = get_empty_layer(x, y)
        setgrid[i][x] = setgrid[i][x] or {}
        setgrid[i][x][y] = true

        print(x, y, tile_id)

        grid:add_tile(identifier .. i, x, y, tile_id, fx and 1 or 0, fy and 1 or 0)
    end

    grid:write()

    -- add the componenent to the collection
    local go = collection:get_gameobject(instance.__type)
    if not go then go = collection:add_gameobject(instance.__type) end

    go:add_component_file(identifier, grid.path)
    go:set_component_position(identifier, instance.__pxTotalOffsetX, -instance.__pxTotalOffsetY, z)

    if config.assign_collision then
        local world = config.collisions[collection.name]
        if not world then
            print(('No Collision object defined for %s. Skipping...'):format(collection.name))
            return
        end

        local component = world[identifier]

        if component then
            go:add_component_file('collisionobject', component)
        else
            print(('No Collision object defined for %s. Skipping...'):format(identifier))
        end
    end
end

local instance_lookup = {
    ['Entities'] = handle_entities,
    ['Tiles'] = create_tilemap,
    ['IntGrid'] = create_tilemap,
    ['AutoLayer'] = create_tilemap
}

local function loadsafestring(untrusted)
    local untrusted_function, message = load(untrusted, nil, 't', {})
    if not untrusted_function then return nil, message end
    return pcall(untrusted_function)
end

local function read_config(file)
    local config_path = '.' .. (file or 'config.lua')
    local file = io.open(config_path, 'r')
    if not file then error('Error opening config file: ' .. file) end

    local ok, c = loadsafestring(file:read('*a'))
    if not c then
        error('Error loading config file: ' .. config_path)
    end

    config = c
    file:close()
    return config
end

function M.parse(root, identifier, text, config_file)
    local data = json.decode(text)
    config = read_config(config_file)
    local tilesets = {}

    -- start by creating a directory for the project
    local project_root = root .. identifier .. '/'
    local tilesource_root = project_root .. 'tilesource/'
    editor.create_directory(tilesource_root)

    -- create a data file
    local data_file = config.data_file or project_root .. identifier .. '.lua'

    -- create tilesources
    for _, tileset in ipairs(data.defs.tilesets) do
        -- LDTK uses an internal icon tileset that cannot be exported
        -- this rule adds an exception for it
        if tileset.relPath then
            local tileset_path = config.tilesets[tileset.identifier]
            if not tileset_path then
                error('No image defined for tileset ' .. tileset.identifier .. ' in LDTK config. Exiting ...')
            end

            local set = defold.tilesource.from(tilesource_root .. tileset.identifier .. '.tilesource')
            if not set then set = defold.tilesource(tileset.identifier, tilesource_root) end

            set:set_image(tileset_path, tileset.tileGridSize)
                :set_properties(tileset.spacing, tileset.padding, tileset.margin)
                :set_collision(config.assign_collision and
                    (config.collisions and config.collisions[tileset.identifier] or tileset_path) or
                    nil)
                :write()

            tilesets[tileset.relPath] = set
            set.width = tileset.pxWid
        end
    end

    -- read enums and create a lua file
    local enums = {}
    for _, enum in ipairs(data.defs.enums) do
        local values = {}
        for k, value in ipairs(enum.values) do
            values[value.id] = k
        end
        enums[enum.identifier] = values
    end

    -- need to dump it to the file
    local datafile = io.open('.' .. data_file, 'w')
    if not datafile then
        print('Could not open data file for writing ')
        return
    end

    local lines = to_local_variable('enums', enums, 4)
    for _, line in ipairs(lines) do
        datafile:write(line .. '\n')
    end
    datafile:write('\n')

    -- read layers and assign relative z offsets
    local layers = {}
    local offset = 0.0
    for i, layer in ipairs(data.defs.layers) do
        layers[layer.identifier] = offset - 0.001 * i
    end
    -- create collection for each world
    local collections = {}
    local level_fields = {}
    local entity_fields = {}
    for _, level in ipairs(data.levels) do
        local clear_color = level.__bgColor
        local collection = defold.collection.from(project_root .. level.identifier .. ".collection")
            or defold.collection(level.identifier, project_root)

        local tilemap_root = project_root .. level.identifier .. '/'
        editor.create_directory(tilemap_root)

        collection:add_gameobject("world"):add_script("clear_color", "/ldtk2defold/scripts/clear_color.script", {
            id = 'color',
            value = hextostring(from_hex(clear_color)),
            type = 'PROPERTY_TYPE_VECTOR4'
        }):add_script('iid', '/ldtk2defold/scripts/iid.script', {
            id = 'iid',
            value = level.iid,
            type = 'PROPERTY_TYPE_HASH'
        })

        local id = iid.new(level.iid)
        level_fields[id] = {}
        for _, field in ipairs(level.fieldInstances) do
            local value = field.__value
            if type(value) == "table" and value[1] then
                local type = field.__type:match('Array<(.-)>')
                for k, v in ipairs(value) do
                    value[k] = ldtk_to_defold_types(v, type, level.pxHei)
                end
            else
                value = ldtk_to_defold_types(value, field.__type, level.pxHei)
            end
            level_fields[id][field.__identifier] = value
        end

        for _, layer in ipairs(level.layerInstances) do
            local instance = instance_lookup[layer.__type]
            if instance then
                local ret = instance(layer.__identifier, layer, tilesets[layer.__tilesetRelPath], collection,
                    tilemap_root,
                    level.pxHei, layers[layer.__identifier])

                if layer.__type == 'Entities' then
                    entity_fields[id] = ret
                end
            end
        end

        collection:write()
        collections[level.identifier] = collection
    end

    local lines = to_local_variable('entity_fields', entity_fields, 4)
    for _, line in ipairs(lines) do
        datafile:write(line .. '\n')
    end
    datafile:write('\n')

    local lines = to_local_variable('level_fields', level_fields, 4)
    for _, line in ipairs(lines) do
        datafile:write(line .. '\n')
    end
    datafile:write('\n')

    -- create the main collection
    if config.generate_main_collection then
        local main = defold.collection.from(project_root .. 'main.collection') or defold.collection('main', project_root)
        -- add the world collections to the main collection
        local x, y = 0, 0
        for _, level in ipairs(data.levels) do
            local collection = collections[level.identifier]
            local id = main:add_collection_instance(collection.name, collection.path)

            local worldX, worldY = level.worldX, level.worldY
            if data.worldLayout == "LinearHorizontal" then
                worldX, worldY = x, y
                x = x + level.pxWid + (config.lvl_offsets or 0)
            elseif data.worldLayout == "LinearVertical" then
                worldX, worldY = x, y
                y = y + level.pxHei + (config.lvl_offsets or 0)
            elseif data.worldLayout == "GridVania" then
                -- do nothing as of now
            elseif data.worldLayout == "Free" then
                -- do nothing
            end

            print('Adding ' .. level.identifier .. ' at ' .. worldX .. ', ' .. worldY)
            main:set_collection_instance_position(id, worldX, -worldY, 0)
        end

        main:write()
    end

    -- close the data file
    datafile:write('return {\n')
    datafile:write(string.rep(' ', 4) .. 'enums = enums,\n')
    datafile:write(string.rep(' ', 4) .. 'entity_fields = entity_fields,\n')
    datafile:write(string.rep(' ', 4) .. 'level_fields = level_fields,\n')
    datafile:write('}\n')
    datafile:close()
end

function M.clear(root, identifier, config_file)
    config = read_config(config_file)
    local project_root = root .. identifier .. '/'
    local data_file = config.data_file or project_root .. identifier .. '.lua'

    editor.delete_directory(project_root)
    editor.delete_directory(data_file)
end

return M
