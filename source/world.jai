CHUNK_SIZE   :: 16;
CHUNK_HEIGHT :: 128;
TOTAL_BLOCKS :: CHUNK_SIZE * CHUNK_SIZE * CHUNK_HEIGHT;

WORLD_SIZE   :: 5;
TOTAL_CHUNKS :: WORLD_SIZE * WORLD_SIZE;

JAMC_Block_Type :: enum u8 {
    AIR;
    DIRT;
    GRASS;
    SAND;
    SNOW;
    STONE;
}

JAMC_Block :: struct {
    model :      Matrix4;
    texture_id : float;
}

JAMC_Chunk :: struct {
    blocks : [TOTAL_BLOCKS]JAMC_Block;
    using position : Vector2;
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

Noise_Gen :: struct {
    node: *void;
}

// Simplex Fractal FBM (example string found via search)
DEFAULT_ENCODED_TREE :: "DQAFAAAAAAAAQAgAAAAAAD8AAAAAAA==";

get_fastnoise_id :: (name : string) -> s32 {
    count := fnGetMetadataCount();
    for i : 0..count - 1 {
        c_name := fnGetMetadataName(i);
        if to_string(c_name) == name return i;
    }
    return -1;
}

init_noise_generator :: (using noise : *Noise_Gen) {
    encoded_str := DEFAULT_ENCODED_TREE;
    c_str := temp_c_string(encoded_str);
    node = fnNewFromEncodedNodeTree(c_str, 0);
    assert(node != null);
}

init_chunk :: (using chunk: *JAMC_Chunk, gen : *Noise_Gen, chunk_x : s32, chunk_z : s32) {
    noise_buffer := NewArray(TOTAL_BLOCKS, float);
    defer array_free(noise_buffer);

    min_max_out : [2]float;

    fnGenUniformGrid3D(gen.node, noise_buffer.data, chunk_x * CHUNK_SIZE, 0, chunk_z * CHUNK_SIZE, CHUNK_SIZE, CHUNK_HEIGHT, CHUNK_SIZE, 0.02, 42, min_max_out.data);

    block_size := make_scale_matrix4(xyz(0.5));
    for y : 0..CHUNK_HEIGHT - 1 {
        for z : 0..CHUNK_SIZE - 1 {
            for x : 0..CHUNK_SIZE - 1 {
                index := x + (y * CHUNK_SIZE) + (z * CHUNK_SIZE * CHUNK_HEIGHT);
                block := *blocks[index];
                pos := Vector3.{xx (x + (chunk_x * CHUNK_SIZE)), xx y, xx (z + (chunk_z * CHUNK_SIZE))};

                noise_val := noise_buffer[index];
                height_gradient := cast(float) y / cast(float) CHUNK_HEIGHT;
                density := noise_val - (height_gradient * 2.0 - 0.2);

                block_type := JAMC_Block_Type.AIR;
                if density < 0.15 {
                    block_type = .DIRT;
                } else {
                    block_type = .STONE;
                }
                model := make_translation_matrix4(pos) * block_size;
                block.model = transpose(model);
                block.texture_id = material_ids[block_type];
            }
        }
    }
}
