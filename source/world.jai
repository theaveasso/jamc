CHUNK_SIZE      :: 16;
CHUNK_HEIGHT    :: 128;

JAMC_Block_Type :: enum u8 {
    AIR;
    DIRT;
    GRASS;
    STONE;
}

JAMC_Block :: struct {
    type : JAMC_Block_Type;
}

JAMC_Chunk :: struct {
    blocks : [CHUNK_SIZE * CHUNK_SIZE * CHUNK_HEIGHT]JAMC_Block;
}
