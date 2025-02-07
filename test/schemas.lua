local vector3                  = {
    x = { datatype = 'float', default = 0.0 },
    y = { datatype = 'float', default = 0.0 },
    z = { datatype = 'float', default = 0.0 }
}

local quat                     = {
    x = { datatype = 'float', default = 0.0 },
    y = { datatype = 'float', default = 0.0 },
    z = { datatype = 'float', default = 0.0 },
    w = { datatype = 'float', default = 0.0 }
}

local vector4                  = quat

-- identity matrix
local matrix4                  = {
    m00 = { datatype = 'float', default = 1.0 },
    m01 = { datatype = 'float', default = 0.0 },
    m02 = { datatype = 'float', default = 0.0 },
    m03 = { datatype = 'float', default = 0.0 },
    m10 = { datatype = 'float', default = 0.0 },
    m11 = { datatype = 'float', default = 1.0 },
    m12 = { datatype = 'float', default = 0.0 },
    m13 = { datatype = 'float', default = 0.0 },
    m20 = { datatype = 'float', default = 0.0 },
    m21 = { datatype = 'float', default = 0.0 },
    m22 = { datatype = 'float', default = 1.0 },
    m23 = { datatype = 'float', default = 0.0 },
    m30 = { datatype = 'float', default = 0.0 },
    m31 = { datatype = 'float', default = 0.0 },
    m32 = { datatype = 'float', default = 0.0 },
    m33 = { datatype = 'float', default = 1.0 }
}

local property_types           = {
    enum                  = true,
    PROPERTY_TYPE_NUMBER  = "PROPERTY_TYPE_NUMBER",
    PROPERTY_TYPE_HASH    = "PROPERTY_TYPE_HASH",
    PROPERTY_TYPE_URL     = "PROPERTY_TYPE_URL",
    PROPERTY_TYPE_VECTOR3 = "PROPERTY_TYPE_VECTOR3",
    PROPERTY_TYPE_VECTOR4 = "PROPERTY_TYPE_VECTOR4",
    PROPERTY_TYPE_QUAT    = "PROPERTY_TYPE_QUAT",
    PROPERTY_TYPE_BOOLEAN = "PROPERTY_TYPE_BOOLEAN",
    PROPERTY_TYPE_COUNT   = "PROPERTY_TYPE_COUNT",
}

local property_desc            = {
    id    = { required = true, datatype = 'string' },
    value = { required = true, datatype = 'string' },
    type  = { required = true, datatype = 'property_types', },
}

local component_desc           = {
    id             = { required = true, datatype = 'string' },
    component      = { required = true, datatype = 'string' },
    position       = { datatype = 'vector3' },
    rotation       = { datatype = 'quat' },
    properties     = { repeated = true, datatype = 'property_desc' },
    property_decls = { datatype = 'property_decls' }
}

local embedded_component_desc  = {
    id       = { required = true, datatype = 'string' },
    type     = { required = true, datatype = 'string' },
    data     = { required = true, datatype = 'string' },
    position = { datatype = 'vector3' },
    rotation = { datatype = 'quat' },
}

local prototype_desc           = {
    components          = { repeated = true, datatype = 'component_desc' },
    embedded_components = { repeated = true, datatype = 'embedded_component_desc' },
    property_resources  = { repeated = true, datatype = 'string' }
}

local component_property_desc  = {
    id             = { required = true, datatype = 'string' },
    properties     = { repeated = true, datatype = 'property_desc' },
    property_decls = { datatype = 'property_decls' }
}

local instance_desc            = {
    id                   = { required = true, datatype = 'string' },
    prototype            = { required = true, datatype = 'string' },
    children             = { repeated = true, datatype = 'string' },
    position             = { datatype = 'vector3' },
    rotation             = { datatype = 'quat' },
    scale3               = { datatype = 'vector3' },
    scale                = { datatype = 'float' },
    component_properties = { repeated = true, datatype = 'component_property_desc' }
}

local embedded_instance_desc   = {
    id                   = { required = true, datatype = 'string' },
    children             = { repeated = true, datatype = 'string' },
    data                 = { required = true, datatype = 'string' },
    position             = { datatype = 'vector3' },
    rotation             = { datatype = 'quat' },
    scale3               = { datatype = 'vector3' },
    scale                = { datatype = 'float' },
    component_properties = { repeated = true, datatype = 'component_property_desc' }
}

local instance_property_desc   = {
    id         = { required = true, datatype = 'string' },
    properties = { repeated = true, datatype = 'component_property_desc' },
}

local collection_instance_desc = {
    id                  = { required = true, datatype = 'string' },
    collection          = { required = true, datatype = 'string' },
    position            = { datatype = 'vector3' },
    rotation            = { datatype = 'quat' },
    scale3              = { datatype = 'vector3' },
    scale               = { datatype = 'float' },
    instance_properties = { repeated = true, datatype = 'instance_property_desc' }
}

local collection_desc          = {
    name                 = { required = true, datatype = 'string' },
    instances            = { repeated = true, datatype = 'instance_desc' },
    collection_instances = { repeated = true, datatype = 'collection_instance_desc' },
    scale_along_z        = { datatype = 'uint32', default = 0 },
    embedded_instances   = { repeated = true, datatype = 'embedded_instance_desc' },
    property_resources   = { repeated = true, datatype = 'string' }
}

local blend_mode               = {
    enum                 = true,
    BLEND_MODE_ALPHA     = "BLEND_MODE_ALPHA",
    BLEND_MODE_ADD       = "BLEND_MODE_ADD",
    BLEND_MODE_ADD_ALPHA = "BLEND_MODE_ADD_ALPHA",
    BLEND_MODE_MULT      = "BLEND_MODE_MULT",
    BLEND_MODE_SCREEN    = "BLEND_MODE_SCREEN",
}

local playback                 = {
    enum                   = true,
    PLAYBACK_NONE          = "PLAYBACK_NONE",
    PLAYBACK_ONCE_FORWARD  = "PLAYBACK_ONCE_FORWARD",
    PLAYBACK_ONCE_BACKWARD = "PLAYBACK_ONCE_BACKWARD",
    PLAYBACK_ONCE_PINGPONG = "PLAYBACK_ONCE_PINGPONG",
    PLAYBACK_LOOP_FORWARD  = "PLAYBACK_LOOP_FORWARD",
    PLAYBACK_LOOP_BACKWARD = "PLAYBACK_LOOP_BACKWARD",
    PLAYBACK_LOOP_PINGPONG = "PLAYBACK_LOOP_PINGPONG",
}

local sprite_trimming_mode     = {
    enum                 = true,
    SPRITE_TRIM_MODE_OFF = "SPRITE_TRIM_MODE_OFF",
    SPRITE_TRIM_MODE_4   = "SPRITE_TRIM_MODE_4",
    SPRITE_TRIM_MODE_5   = "SPRITE_TRIM_MODE_5",
    SPRITE_TRIM_MODE_6   = "SPRITE_TRIM_MODE_6",
    SPRITE_TRIM_MODE_7   = "SPRITE_TRIM_MODE_7",
    SPRITE_TRIM_MODE_8   = "SPRITE_TRIM_MODE_8",
    SPRITE_TRIM_POLYGONS = "SPRITE_TRIM_POLYGONS",
}

local convex_hull              = {
    index = { required = true, datatype = 'uint32' },
    count = { required = true, datatype = 'uint32' },
    collision_group = { required = true, datatype = 'string' }
}

local cue                      = {
    id    = { required = true, datatype = 'string' },
    frame = { required = true, datatype = 'uint32' },
    value = { datatype = 'float', default = 0.0 }
}

local animation                = {
    id              = { required = true, datatype = 'string' },
    start_tile      = { required = true, datatype = 'uint32' },
    end_tile        = { required = true, datatype = 'uint32' },
    playback        = { datatype = 'playback', default = "PLAYBACK_ONCE_FORWARD" },
    fps             = { datatype = 'float', default = 30.0 },
    flip_horizontal = { datatype = 'uint32', default = false },
    flip_vertical   = { datatype = 'uint32', default = false },
    cues            = { repeated = true, datatype = 'cue' }
}

local tile_set                 = {
    image            = { required = true, datatype = 'string' },
    tile_width       = { required = true, datatype = 'uint32' },
    tile_height      = { required = true, datatype = 'uint32' },
    tile_margin      = { datatype = 'uint32', default = 0 },
    tile_spacing     = { datatype = 'uint32', default = 0 },
    collision        = { datatype = 'string' },
    material_tag     = { datatype = 'string', default = 'tile' },
    convex_hulls     = { repeated = true, datatype = 'convex_hull' },
    collision_groups = { repeated = true, datatype = 'string' },
    animations       = { repeated = true, datatype = 'animation' },
    extrude_borders  = { datatype = 'uint32', default = 0 },
    inner_padding    = { datatype = 'uint32', default = 0 },
    sprite_trim_mode = { datatype = 'sprite_trimm_mode', default = sprite_trimming_mode.SPRITE_TRIM_MODE_OFF },
}

local tile_cell                = {
    x        = { default = 0, datatype = 'int32' },
    y        = { default = 0, datatype = 'int32' },
    tile     = { default = 0, datatype = 'uint32' },
    h_flip   = { datatype = 'uint32', default = 0 },
    v_flip   = { datatype = 'uint32', default = 0 },
    rotate90 = { datatype = 'uint32', default = 0 },
}

local tile_layer               =
{
    id         = { required = true, datatype = 'string' },
    z          = { datatype = 'float', default = 0 },
    is_visible = { datatype = 'uint32', default = 1 },
    cell       = { repeated = true, datatype = 'tile_cell' },
}

local tile_grid                = {
    tile_set   = { required = true, datatype = 'string' },
    layers     = { repeated = true, datatype = 'tile_layer' },
    material   = { datatype = 'string', default = "/builtins/materials/tile_map.material" },
    blend_mode = { datatype = 'blend_mode', default = blend_mode.BLEND_MODE_ALPHA },
}

local schemas                  = {
    vector3                  = vector3,
    vector4                  = vector4,
    quat                     = quat,
    matrix4                  = matrix4,

    property_types           = property_types,
    property_desc            = property_desc,
    component_desc           = component_desc,
    embedded_component_desc  = embedded_component_desc,
    prototype_desc           = prototype_desc,
    component_property_desc  = component_property_desc,
    instance_desc            = instance_desc,
    embedded_instance_desc   = embedded_instance_desc,
    instance_property_desc   = instance_property_desc,
    collection_instance_desc = collection_instance_desc,
    collection_desc          = collection_desc,

    blend_mode               = blend_mode,
    playback                 = playback,
    sprite_trimming_mode     = sprite_trimming_mode,
    convex_hull              = convex_hull,
    cue                      = cue,
    animation                = animation,
    tile_set                 = tile_set,
    tile_cell                = tile_cell,
    tile_layer               = tile_layer,
    tile_grid                = tile_grid,
}

return schemas
