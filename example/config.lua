local config = {}

-- assign collision map for images or not
-- if this option is enabled, the generator first searches for an upvalue in collsions table,
-- otherwise, the same image is assigned as the collision source
config.assign_collision = true
config.generate_main_collection = false

config.data_file = '/example/scripts/data.lua'

config.collisions = {
    ['Level_0'] = {
        ['IntGrid'] = '/example/collisions/IntGrid.collisionobject'
    }
}

config.entities = {
    ['Saw'] = '/example/gameobjects/saw.go',
    ['Turret'] = '/example/gameobjects/turret.go',
    ['Laser'] = '/example/gameobjects/laser.go',
    ['Spike'] = '/example/gameobjects/spike.go',
    ['HiddenSpike'] = '/example/gameobjects/hidden_spike.go',
    ['Terminal'] = '/example/gameobjects/terminal.go',
    ['Barrier'] = '/example/gameobjects/barrier.go',
    ['WallSpikes'] = '/example/gameobjects/wall_spikes.go',
    ['Camera'] = '/example/gameobjects/camera.go',
    ['Player'] = '/example/gameobjects/player.go',
    ['Lift'] = '/example/gameobjects/lift.go'
}

config.tilesets = {
    ['Scifi_tileset'] = '/example/assets/images/tileset/level_tileset.png'
}

return config
