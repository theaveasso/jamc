CHUNK_SIZE   :: 16;
CHUNK_HEIGHT :: 128;
TOTAL_BLOCKS :: CHUNK_SIZE * CHUNK_SIZE * CHUNK_HEIGHT;

JAMC_Block_Type :: enum u8 {
    AIR;
    DIRT;
    GRASS;
    SAND;
    SNOW;
    STONE;
}

JAMC_Block :: struct {
    type : JAMC_Block_Type;
}

JAMC_Chunk :: struct {
    blocks : [TOTAL_BLOCKS]JAMC_Block;
    using position : Vector2;
    
    mesh_vbo : GLuint;
    mesh_vertex_count : s32;
    is_meshed : bool;
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
    .{.{-1,-1, 1}, .{0, 1}},
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
    .{.{ 1,-1,-1}, .{1, 1}}, 
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
VOXEL_SCALE          :: 0.25;

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

generate_chunk_blocks :: (using chunk: *JAMC_Chunk, gen : *Noise_Gen, chunk_x : s32, chunk_z : s32) {
    if !is_meshed {
        glGenBuffers(1, *mesh_vbo);
        is_meshed = true;
    }

    noise_buffer := NewArray(TOTAL_BLOCKS, float);
    defer array_free(noise_buffer);

    min_max_out : [2]float;

    fnGenUniformGrid3D(gen.node, noise_buffer.data, chunk_x * CHUNK_SIZE, 0, chunk_z * CHUNK_SIZE, CHUNK_SIZE, CHUNK_HEIGHT, CHUNK_SIZE, 0.02, 42, min_max_out.data);

    for y : 0..CHUNK_HEIGHT - 1 {
        for z : 0..CHUNK_SIZE - 1 {
            for x : 0..CHUNK_SIZE - 1 {
                index := x + (y * CHUNK_SIZE) + (z * CHUNK_SIZE * CHUNK_HEIGHT);
                block := *blocks[index];
                
                noise_val := noise_buffer[index];
                // Create a more interesting terrain gradient
                // Map y from 0..1
                // We want solid bottom (high density addition) and airy top (high density subtraction)
                height_percent := cast(float) y / cast(float) CHUNK_HEIGHT;
                
                // Base ground bias: +1.0 at bottom, -1.0 at top
                bias := 1.0 - (height_percent * 2.0);
                
                // Simple floor to ensure we don't fall through the world
                if y < 4 bias += 10.0;

                density := noise_val + bias;

                block.type = .AIR;
                if density > 0.1 {
                    block.type = .DIRT;
                    if density > 0.6 {
                         block.type = .STONE;
                    }
                }
            }
        }
    }
}

Chunk_Vertex :: struct {
    p : Vector3;
    uv : Vector2;
    tex_id : float;
}

get_chunk_key :: inline (x: s32, z: s32) -> s64 {
    top := (cast(s64) x) << 32;
    bottom := (cast(s64) z) & 0xFFFF_FFFF;
    return top | bottom;
}

update_chunk_mesh :: (using chunk: *JAMC_Chunk, all_chunks: *Table(s64, *JAMC_Chunk)) {
    // Generate mesh data
    vertices : [..]Chunk_Vertex;
    vertices.allocator = temp;
    
    // Check neighbors
    is_transparent :: (local_x: s32, local_y: s32, local_z: s32, current_chunk: *JAMC_Chunk, all_chunks: *Table(s64, *JAMC_Chunk)) -> bool {
        
        target_x := local_x;
        target_y := local_y;
        target_z := local_z;
        
        chunk_idx_x := cast(s32) current_chunk.position.x;
        chunk_idx_z := cast(s32) current_chunk.position.y; // .y is Z in grid coords

        // Adjust for neighbor chunks
        if target_x < 0 {
            chunk_idx_x -= 1;
            target_x += CHUNK_SIZE;
        } else if target_x >= CHUNK_SIZE {
            chunk_idx_x += 1;
            target_x -= CHUNK_SIZE;
        }

        if target_z < 0 {
            chunk_idx_z -= 1;
            target_z += CHUNK_SIZE;
        } else if target_z >= CHUNK_SIZE {
            chunk_idx_z += 1;
            target_z -= CHUNK_SIZE;
        }

        // Limit Y check
        if target_y < 0 || target_y >= CHUNK_HEIGHT return true;

        // Neighbor Lookup
        key := get_chunk_key(chunk_idx_x, chunk_idx_z);
        
        found, neighbor := table_find(all_chunks, key);
        if !found return true; 

        block_index := target_x + (target_y * CHUNK_SIZE) + (target_z * CHUNK_SIZE * CHUNK_HEIGHT);
        
        idx := cast(s64) block_index;
        if idx < 0 || idx >= TOTAL_BLOCKS return true;
        
        target_block := neighbor.blocks[idx];
        return target_block.type == .AIR;
    }

    for y : 0..cast(s32)(CHUNK_HEIGHT - 1) {
        for z : 0..cast(s32)(CHUNK_SIZE - 1) {
            for x : 0..cast(s32)(CHUNK_SIZE - 1) {
                index := x + (y * CHUNK_SIZE) + (z * CHUNK_SIZE * CHUNK_HEIGHT);
                block := blocks[index];
                if block.type == .AIR continue;
                
                tex_id := material_ids[block.type];

                pos := Vector3.{xx x, xx y, xx z}; // Local position
                
                // Check all 6 faces
                // Top (Y+)
                if is_transparent(x, y + 1, z, chunk, all_chunks) {
                    for i: 0..5 {
                        v := cube_vertices[i];
                        p := (v.position * 0.5) + pos;
                        array_add(*vertices, .{p, v.uv, tex_id});
                    }
                }
                // Bottom (Y-)
                if is_transparent(x, y - 1, z, chunk, all_chunks) {
                    for i: 6..11 {
                        v := cube_vertices[i];
                        p := (v.position * 0.5) + pos;
                        array_add(*vertices, .{p, v.uv, tex_id});
                    }
                }
                // Front (Z+)
                if is_transparent(x, y, z + 1, chunk, all_chunks) {
                    for i: 12..17 {
                        v := cube_vertices[i];
                        p := (v.position * 0.5) + pos;
                        array_add(*vertices, .{p, v.uv, tex_id});
                    }
                }
                // Back (Z-)
                if is_transparent(x, y, z - 1, chunk, all_chunks) {
                    for i: 18..23 {
                        v := cube_vertices[i];
                        p := (v.position * 0.5) + pos;
                        array_add(*vertices, .{p, v.uv, tex_id});
                    }
                }
                 // Right (X+)
                if is_transparent(x + 1, y, z, chunk, all_chunks) {
                    for i: 24..29 {
                        v := cube_vertices[i];
                        p := (v.position * 0.5) + pos;
                        array_add(*vertices, .{p, v.uv, tex_id});
                    }
                }
                // Left (X-)
                if is_transparent(x - 1, y, z, chunk, all_chunks) {
                    for i: 30..35 {
                        v := cube_vertices[i];
                        p := (v.position * 0.5) + pos;
                        array_add(*vertices, .{p, v.uv, tex_id});
                    }
                }
            }
        }
    }

    mesh_vertex_count = xx vertices.count;
    
    glBindBuffer(GL_ARRAY_BUFFER, mesh_vbo);
    glBufferData(GL_ARRAY_BUFFER, vertices.count * size_of(Chunk_Vertex), vertices.data, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}
