components {
  id: "iid"
  component: "/ldtk2defold/scripts/iid.script"
}
components {
  id: "player"
  component: "/example/scripts/player.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"player_idle\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/example/assets/atlases/objects.atlas\"\n"
  "}\n"
  ""
  position {
    y: 16.0
  }
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"player\"\n"
  "mask: \"interactable\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "      y: 15.0\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "  }\n"
  "  data: 7.236842\n"
  "  data: 14.887494\n"
  "  data: 10.0\n"
  "}\n"
  ""
}
