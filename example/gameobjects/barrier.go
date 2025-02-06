components {
  id: "iid"
  component: "/ldtk2defold/scripts/iid.script"
}
components {
  id: "entity"
  component: "/example/scripts/entity.script"
}
components {
  id: "barrier"
  component: "/example/scripts/barrier.script"
}
embedded_components {
  id: "sprite"
  type: "sprite"
  data: "default_animation: \"barrier_flash\"\n"
  "material: \"/builtins/materials/sprite.material\"\n"
  "textures {\n"
  "  sampler: \"texture_sampler\"\n"
  "  texture: \"/example/assets/atlases/objects.atlas\"\n"
  "}\n"
  ""
}
embedded_components {
  id: "collisionobject"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_STATIC\n"
  "mass: 0.0\n"
  "friction: 0.1\n"
  "restitution: 0.5\n"
  "group: \"ground\"\n"
  "mask: \"player\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "  }\n"
  "  data: 15.955056\n"
  "  data: 31.842106\n"
  "  data: 10.0\n"
  "}\n"
  ""
}
