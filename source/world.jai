CHUNK_SIZE_X :: 16;
CHUNK_SIZE_Y :: 1;
CHUNK_SIZE_Z :: 16;

BLOCK_PER_CHUNK :: CHUNK_SIZE_X * CHUNK_SIZE_Y * CHUNK_SIZE_Z;

JAMC_Block_Type :: enum u8 {
    AIR;
    DIRT;
    GRASS;
    SAND;
    SNOW;
    STONE;
}

JAMC_Block :: struct {
    model:      Matrix4;
    texture_id: float;
}

JAMC_Chunk :: struct {
    blocks : [BLOCK_PER_CHUNK]JAMC_Block;
}

cube_vertices : [36]JAMC_Block_Vertex : .[
    // Top face (y = 1)
    .{.{-1, 1, 1}, .{0, 1}},
    .{.{ 1, 1, 1}, .{1, 1}},
    .{.{ 1, 1,-1}, .{1, 0}},
    .{.{-1, 1, 1}, .{0, 1}},
    .{.{ 1, 1,-1}, .{1, 0}},
    .{.{-1, 1,-1}, .{0, 0}},

    // Bottom face (y = -1)
    .{.{-1,-1, 1}, .{0, 1}}, // Note: Bottom face mapping is often flipped depending on preference
    .{.{ 1,-1,-1}, .{1, 0}},
    .{.{ 1,-1, 1}, .{1, 1}},
    .{.{-1,-1, 1}, .{0, 1}},
    .{.{-1,-1,-1}, .{0, 0}},
    .{.{ 1,-1,-1}, .{1, 0}},

    // Front face (z = 1)
    .{.{-1,-1, 1}, .{0, 0}},
    .{.{ 1,-1, 1}, .{1, 0}},
    .{.{ 1, 1, 1}, .{1, 1}},
    .{.{-1,-1, 1}, .{0, 0}},
    .{.{ 1, 1, 1}, .{1, 1}},
    .{.{-1, 1, 1}, .{0, 1}},

    // Back face (z = -1)
    .{.{-1,-1,-1}, .{1, 0}},
    .{.{ 1, 1,-1}, .{0, 1}},
    .{.{ 1,-1,-1}, .{1, 1}}, // Adjusted to ensure texture isn't mirrored
    .{.{-1,-1,-1}, .{1, 0}},
    .{.{-1, 1,-1}, .{0, 0}},
    .{.{ 1, 1,-1}, .{0, 1}},

    // Right face (x = 1)
    .{.{ 1,-1, 1}, .{0, 0}},
    .{.{ 1,-1,-1}, .{1, 0}},
    .{.{ 1, 1,-1}, .{1, 1}},
    .{.{ 1,-1, 1}, .{0, 0}},
    .{.{ 1, 1,-1}, .{1, 1}},
    .{.{ 1, 1, 1}, .{0, 1}},

    // Left face (x = -1)
    .{.{-1,-1, 1}, .{1, 0}},
    .{.{-1, 1,-1}, .{0, 1}},
    .{.{-1,-1,-1}, .{0, 0}},
    .{.{-1,-1, 1}, .{1, 0}},
    .{.{-1, 1, 1}, .{1, 1}},
    .{.{-1, 1,-1}, .{0, 1}},
];
