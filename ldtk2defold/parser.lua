-- todo : add collisionobjects to gameobjects

local json = require("ldtk2defold.json")
local enums = require('ldtk2defold.enums')

local parser = {}

local config
local scripts = {
    opacity = '/ldtk2defold/scripts/opacity.script',
    iid = '/ldtk2defold/scripts/iid.script',
    clear_color = '/ldtk2defold/scripts/clear_color.script'
}

local unpack = table.unpack or unpack

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

local function parse_hex(hex)
    local r, g, b, a = hex:match("#(%x%x)(%x%x)(%x%x)(%x?%x?)")
    a = a ~= '' or 'ff'
    return { tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255, tonumber(a, 16) / 255 }
end

local function ldtk_to_defold_types(value, ldtk_type, h)
    if ldtk_type == 'Int' then
        value = tonumber(value)
    elseif ldtk_type == 'Float' then
        value = tonumber(value)
    elseif ldtk_type == 'Bool' then
        value = value == 'true'
    elseif ldtk_type == 'Color' then
        local r, g, b, a = unpack(parse_hex(value))
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

local function create_tilemap(layer, tileset, root, txns)
    local identifier = layer.__identifier
    local path = root .. identifier .. '.tilemap'
    local attr = editor.resource_attributes(path)
    if not attr.exists then
        editor.create_resources({ path })
    end
    table.insert(txns, editor.tx.set(path, 'tile_source', tileset.path))
    table.insert(txns, editor.tx.clear(path, 'layers'))

    local h = layer.__cHei
    local layers = { [1] = tilemap.tiles.new() }
    local layers_z = { [1] = 0.0 }

    local function get_empty_tiles(x, y)
        for i = 1, #layers do
            if not tilemap.tiles.get_info(layers[i], x, y) then
                return layers[i]
            end
        end
        table.insert(layers, tilemap.tiles.new())
        table.insert(layers_z, 0.0001 * (#layers_z))
        return layers[#layers]
    end

    local is_auto_layer_tiles = layer.autoLayerTiles and (#layer.autoLayerTiles > 0)

    local tiles = (is_auto_layer_tiles and layer.autoLayerTiles) or layer.gridTiles
    for _, tile in ipairs(tiles) do
        local x = math.floor(tile.px[1] / tileset.grid_size)
        local y = math.floor(h - tile.px[2] / tileset.grid_size - 1)
        local idx = tile.t + 1

        local fx, fy = tile.f % 2 ~= 0, tile.f > 1
        local empty = get_empty_tiles(x, y)
        tilemap.tiles.set(empty, x, y, {
            index = idx,
            h_flip = fx,
            v_flip = fy
        })
    end

    for k, v in ipairs(layers) do
        table.insert(txns, editor.tx.add(path, 'layers', {
            id = identifier .. k,
            tiles = v,
            z = layers_z[k]
        }))
    end

    return path
end

local function build_tree(ref, depth)
    local tree = {}
    depth = depth or -1
    if depth < 0 then
        return {}
    end

    local children = editor.get(ref, 'children')
    for i = 1, #children do
        local node = children[i]
        local id = editor.get(node, 'id')
        tree[id] = { children = {}, components = {} }
        tree[id].__ref = node

        local r_child = editor.can_get(node, 'children')
        if r_child then
            local children = build_tree(node, depth - 1)
            tree[id].children = children
        end

        local r_comp = editor.can_get(node, 'components')
        if r_comp then
            local components = editor.get(node, 'components')
            for j = 1, #components do
                node = components[j]
                tree[id].components[editor.get(node, 'id')] = node
            end
        end
    end
    return tree
end

local function loadsafestring(untrusted)
    local sandbox = { enums = enums }
    local untrusted_function, message = load(untrusted, nil, 't', sandbox)
    if not untrusted_function then return nil, message end
    return pcall(untrusted_function)
end

local function read_config(path)
    local config_path = '.' .. (path or 'config.lua')
    local file = io.open(config_path, 'r')
    if not file then error('Error opening config file: ' .. file) end

    local ok, c = loadsafestring(file:read('*a'))
    if not c then
        error('Error loading config file: ' .. config_path)
    end

    file:close()
    return c
end

function parser.parse(root, identifier, text, config_file)
    local data = json.decode(text)
    config = read_config(config_file)

    -- assign sane defaults to config
    config.assign_collision = config.assign_collision or false
    config.entities = config.entities or {}
    config.save = config.save or false
    config.tilesets = config.tilesets or {}
    config.map_type = config.map_type or enums.map_type.LEVELS_ONLY
    config.lvl_offsets = config.lvl_offsets or 0

    local project_root = config.project_root or (root .. identifier .. '/')
    local tilesource_root = project_root .. 'tilesources/'

    editor.create_directory(tilesource_root)

    local datafile_path = config.data_file or project_root .. identifier .. '.lua'
    local datafile = io.open('.' .. datafile_path, 'w')
    if not datafile then
        print('Could not open data file for writing ')
        return
    end

    local tilesets = {}
    -- create tilsources
    for _, tileset in ipairs(data.defs.tilesets) do
        if tileset.relPath then
            local tileset_path = config.tilesets[tileset.identifier]
            if tileset_path then
                local resource_path = tilesource_root .. tileset.identifier .. '.tilesource'
                local attr = editor.resource_attributes(resource_path)
                if not attr.exists then
                    editor.create_resources({ resource_path })
                end

                editor.transact({
                    editor.tx.set(resource_path, 'image', tileset_path),
                    editor.tx.set(resource_path, 'tile_width', tileset.tileGridSize),
                    editor.tx.set(resource_path, 'tile_height', tileset.tileGridSize),
                    editor.tx.set(resource_path, 'tile_spacing', tileset.spacing or 0),
                    editor.tx.set(resource_path, 'inner_padding', tileset.padding or 0),
                    editor.tx.set(resource_path, 'tile_margin', tileset.margin or 0),
                    editor.tx.set(resource_path, 'collision', config.assign_collision and
                        (config.collisions and config.collisions[tileset.identifier] or tileset_path) or ""),
                })

                tilesets[tileset.relPath] = {
                    path = resource_path,
                    grid_size = tileset.tileGridSize,
                }
            else
                pprint('No image defined for tileset ' .. tileset.identifier .. ' in config file. Skipping ...')
            end
        end
    end

    local enums_t = {}
    for _, enum in ipairs(data.defs.enums) do
        local values = {}
        for k, value in ipairs(enum.values) do
            values[value.id] = k
        end
        enums_t[enum.identifier] = values
    end

    local lines = to_local_variable('enums', enums_t, 4)
    for _, line in ipairs(lines) do
        datafile:write(line .. '\n')
    end
    datafile:write('\n')

    -- read layers and assign relative z offsets
    local layers_z = {}
    local offset = 0.0
    for i, layer in ipairs(data.defs.layers) do
        layers_z[layer.identifier] = offset - 0.001 * i
    end

    local level_fields = {}
    local entity_fields = {}
    for _, level in ipairs(data.levels) do
        local identifier = level.identifier
        local collection_path = project_root .. identifier .. '.collection'
        local tilemap_root = project_root .. level.identifier .. '/'

        editor.create_directory(tilemap_root)

        local attr = editor.resource_attributes(collection_path)
        if not attr.exists then
            editor.create_resources({ collection_path })
        end

        -- list of all transactions
        local txns = {}
        local tree = build_tree(collection_path, 2)

        -- handle level fields
        local id = iid.new(level.iid)
        level_fields[id] = {}
        entity_fields[id] = {}
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

        -- stage 1 : create world gameobject with attached properties
        local world_id = 'world'
        if not tree[world_id] then
            tree[world_id] = {}
            table.insert(txns, editor.tx.add(collection_path, 'children', {
                type = 'go',
                id = world_id,
                components = {
                    {
                        type = 'component-reference',
                        id = 'iid',
                        path = scripts.iid,
                        __iid = level.iid
                    },
                    {
                        type = 'component-reference',
                        id = 'clear_color',
                        path = scripts.clear_color,
                        __color = parse_hex(level.__bgColor)
                    }
                },
            }))
        else
            if not tree[world_id].components.iid then
                table.insert(txns, editor.tx.add(tree[world_id].__ref, 'components', {
                    type = 'component-reference',
                    id = 'iid',
                    path = scripts.iid,
                    __iid = level.iid
                }))
            else
                table.insert(txns, editor.tx.set(tree[world_id].components.iid, '__iid', level.iid))
            end

            if not tree[world_id].components.clear_color then
                table.insert(txns, editor.tx.add(tree[world_id].__ref, 'components', {
                    type = 'component-reference',
                    id = 'clear_color',
                    path = scripts.clear_color,
                    __color = level.__bgColor
                }))
            else
                table.insert(txns,
                    editor.tx.set(tree[world_id].components.clear_color, '__color', parse_hex(level.__bgColor)))
            end
        end

        local layers = {}
        local entities = {}
        local entity_iids = {}

        -- stage 2 : create tilemaps and store them alongwith entities to be processed later
        for _, layer in ipairs(level.layerInstances) do
            local layer_type = layer.__type
            if layer_type == 'Entities' then
                for _, entity in pairs(layer.entityInstances) do
                    entity_iids[entity.__identifier] = entity.iid
                    if config.entities[entity.__identifier] then
                        table.insert(entities, {
                            type = 'go-reference',
                            id = entity.__identifier,
                            path = config.entities[entity.__identifier],
                            position = {
                                entity.px[1],
                                level.pxHei - entity.px[2],
                                layers_z[layer.__identifier]
                            },
                        })
                    else
                        pprint('Entity ' .. entity.__identifier .. ' not found in config file. Skipping !!!')
                    end

                    local eid = iid.new(entity.iid)
                    entity_fields[id][eid] = {}
                    -- write a serializer for field instances
                    for k, v in ipairs(entity.fieldInstances) do
                        local field = v.__identifier
                        if field then
                            local value = v.__value
                            if type(value) == "table" and value[1] then
                                local type = v.__type:match('Array<(.-)>')
                                for k, v in ipairs(value) do
                                    value[k] = ldtk_to_defold_types(v, type, layer.__cHei)
                                end
                            else
                                value = ldtk_to_defold_types(value, v.__type, layer.__cHei)
                            end
                            entity_fields[id][eid][field] = value
                        end
                    end
                end
            else
                local tilemap_path = create_tilemap(
                    layer,
                    tilesets[layer.__tilesetRelPath],
                    tilemap_root,
                    txns
                )

                layers[layer.__type] = layers[layer.__type] or {}
                table.insert(layers[layer_type], {
                    id = layer.__identifier,
                    path = tilemap_path,
                    x = layer.__pxTotalOffsetX + tilesets[layer.__tilesetRelPath].grid_size,
                    y = -layer.__pxTotalOffsetY + tilesets[layer.__tilesetRelPath].grid_size,
                    z = layers_z[layer.__identifier],
                    opacity = layer.__opacity
                })
            end
        end

        -- transact
        if #txns > 0 then
            editor.transact(txns)
            txns = {}
        end

        -- stage 3 : add tilemaps to the collection
        for key, value in pairs(layers) do
            key = 'Layer_' .. key
            if tree[key] then
                local children_tree = tree[key].children

                for i = 1, #value do
                    local map = value[i]

                    if children_tree[map.id] then
                        local components = children_tree[map.id].components
                        if components[map.id] then
                            table.insert(txns,
                                editor.tx.set(components[map.id], 'position', { 0, 0, 0 }))
                            table.insert(txns, editor.tx.set(components[map.id], 'path', map.path))
                        else
                            table.insert(txns, editor.tx.add(children_tree[map.id].__ref, "components", {
                                type = 'component-reference',
                                id = map.id,
                                path = map.path,
                            }))
                        end

                        if components.opacity then
                            table.insert(txns, editor.tx.set(components.opacity, '__opacity', map.opacity))
                            table.insert(txns, editor.tx.set(components.opacity, '__ref', '#' .. map.id))
                        else
                            table.insert(txns, editor.tx.add(children_tree[map.id].__ref, "components", {
                                type = 'component-reference',
                                id = 'opacity',
                                path = scripts.opacity,
                                __opacity = map.opacity,
                                __ref = '#' .. map.id
                            }))
                        end
                    else
                        table.insert(txns, editor.tx.add(tree[key].__ref, "children", {
                            type = 'go',
                            id = map.id,
                            position = { map.x, map.y, map.z },
                            components = {
                                {
                                    type = 'component-reference',
                                    id = map.id,
                                    path = map.path,
                                },
                                {
                                    type = 'component-reference',
                                    id = 'opacity',
                                    path = scripts.opacity,
                                    __opacity = map.opacity,
                                    __ref = '#' .. map.id
                                }
                            }
                        }))
                    end
                end
            else
                local children = {}
                for i = 1, #value do
                    local map = value[i]
                    table.insert(children, {
                        type = 'go',
                        id = map.id,
                        position = { map.x, map.y, map.z },
                        components = {
                            {
                                type = 'component-reference',
                                id = map.id,
                                path = map.path,
                            },
                            {
                                type = 'component-reference',
                                id = 'opacity',
                                path = scripts.opacity,
                                __opacity = map.opacity,
                                __ref = '#' .. map.id
                            }
                        }
                    })
                end

                table.insert(txns, editor.tx.add(collection_path, 'children', {
                    type = 'go',
                    id = key,
                    children = children
                }))
            end
        end

        if #txns > 0 then
            editor.transact(txns)
            txns = {}
        end

        -- stage 4 : add entities to collection
        if tree['Entities'] then
            local node = tree['Entities'].__ref
            for i = 1, #entities do
                local entity = entities[i]
                if not tree['Entities'].children[entity.id] then
                    table.insert(txns, editor.tx.add(node, 'children', entity))
                end
            end
        else
            table.insert(txns, editor.tx.add(collection_path, 'children', {
                type = 'go',
                id = 'Entities',
                children = entities
            }))
        end


        if #txns > 0 then
            editor.transact(txns)
            txns = {}
        end

        -- stage 5 : update the iid of all entities
        tree = build_tree(collection_path, 1)
        if tree['Entities'] and tree['Entities'].children then
            for id, node in pairs(tree['Entities'].children) do
                local iid = node.components and node.components.iid
                if iid then
                    table.insert(txns, editor.tx.set(node.components.iid, '__iid', entity_iids[id]))
                end
            end
        end

        if #txns > 0 then
            editor.transact(txns)
        end
    end

    -- take worldDepth into account?
    if config.map_type == enums.map_type.MAIN_COLLECTION then
        local collection_path = project_root .. config.main_collection_name .. '.collection'
        local attr = editor.resource_attributes(collection_path)
        if not attr.exists then
            editor.create_resources({ collection_path })
        end

        local x, y = 0, 0
        local tree = build_tree(collection_path, 1)
        local txns = {}
        for i = 1, #data.levels do
            local level = data.levels[i]
            local id = level.identifier
            local path = project_root .. id .. '.collection'
            local world_x, world_y = level.worldX, -level.worldY
            if data.worldLayout == "LinearHorizontal" then
                worldX, worldY = x, y - level.pxHei
                x = x + level.pxWid + (config.lvl_offsets or 0)
            elseif data.worldLayout == "LinearVertical" then
                worldX, worldY = x, y - level.pxHei
                y = y - level.pxHei - (config.lvl_offsets or 0)
            elseif data.worldLayout == "GridVania" then
                world_y = world_y - level.pxHei
            elseif data.worldLayout == "Free" then
                world_y = world_y - level.pxHei
            end

            local position = { world_x, world_y, 0 }
            if tree[id] then
                table.insert(txns, editor.tx.set(tree[id].__ref, 'path', path))
                table.insert(txns, editor.tx.set(tree[id].__ref, 'position', position))
            else
                table.insert(txns, editor.tx.add(collection_path, 'children', {
                    type = "collection-reference",
                    id = id,
                    path = path,
                    position = position
                }))
            end
        end

        if #txns > 0 then
            editor.transact(txns)
        end
    end

    if config.save then
        editor.save()
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

    -- close the data file
    datafile:write('return {\n')
    datafile:write(string.rep(' ', 4) .. 'enums = enums,\n')
    datafile:write(string.rep(' ', 4) .. 'entity_fields = entity_fields,\n')
    datafile:write(string.rep(' ', 4) .. 'level_fields = level_fields,\n')
    datafile:write('}\n')
    datafile:close()
end

return parser
