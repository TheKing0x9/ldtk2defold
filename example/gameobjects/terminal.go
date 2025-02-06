components {
  id: "entity"
  component: "/example/scripts/entity.script"
}
components {
  id: "terminal"
  component: "/example/scripts/terminal.script"
}
components {
  id: "iid"
  component: "/ldtk2defold/scripts/iid.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"terminal_idle\"\n"
  "material: \"/example/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/example/assets/atlases/objects.atlas\"\n"
  "}\n"
  ""
  position {
    x: 16.0
    y: -16.0
  }
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_KINEMATIC\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"interactable\"\n"
  "mask: \"player\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "      x: 16.0\n"
  "      y: -16.0\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "  }\n"
  "  data: 16.092802\n"
  "  data: 16.061968\n"
  "  data: 10.0\n"
  "}\n"
  ""
}
