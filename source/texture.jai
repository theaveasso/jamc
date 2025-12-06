#scope_file

Texture_Load_Context :: struct {
    files: [..]string;
}

#scope_export

BLOCK_TEXTURE_HANDLE :: "block_textures";

init_textures :: () {
    find_and_load_block_textures();
}


find_and_load_block_textures :: inline () {
	collector :: (info : *File_Visit_Info, data : *void) {
	    _, _, ext := path_decomp(info.full_name);
	    ctx := cast(*Texture_Load_Context)data;

		if info.is_directory return;

		if ext != "png" return;

		array_add(*ctx.files, copy_string(info.full_name));
	}

	load_ctx: Texture_Load_Context;
	defer for load_ctx.files free(it);
	defer array_reset(*load_ctx.files);

	visit_files("data/texture/block", false, cast(*void)*load_ctx, collector);
	if load_ctx.files.count == 0 return;

	quick_sort(load_ctx.files, compare_strings);

	print("Found % textures. Loading array...\n", load_ctx.files.count);
	for load_ctx.files print("  [%] %\n", it_index, it);

	first_bitmap : Simp.Bitmap;
	if !Simp.bitmap_load(*first_bitmap, load_ctx.files[0]) return;
	defer Simp.deinit(*first_bitmap);

	w := first_bitmap.width;
	h := first_bitmap.height;

	block_texture_array : Texture;
	layer_count := cast(u32) load_ctx.files.count;

	glGenTextures(1, *block_texture_array.gl_handle);
	glBindTexture(GL_TEXTURE_2D_ARRAY, block_texture_array.gl_handle);
	defer glBindTexture(GL_TEXTURE_2D_ARRAY, 0);
	glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, xx w, xx h, xx layer_count, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);

	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);

	get_gl_format :: (format: Simp.Texture_Format) -> GLenum {
	    if format == .RGBA8 return GL_RGBA;
		if format == .RGB8  return GL_RGB;
	    return GL_RGBA;
	}

	format := get_gl_format(first_bitmap.format);
	glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, 0, xx w, xx h, 1, format, GL_UNSIGNED_BYTE, first_bitmap.data.data);

	for index: 1..load_ctx.files.count - 1 {
	    using bitmap : Simp.Bitmap;
		file_path := load_ctx.files[index];
		if !Simp.bitmap_load(*bitmap, file_path) {
		    log_error("Error: loading %", file_path);
		    continue;
		}
		defer Simp.deinit(*bitmap);

		if width != w || height != h {
            log_error("Error: skipping % (wrong size: %x% expected %x%)", file_path, width, height, w, h);
		    continue;
		}

		glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, xx index, xx w, xx h, 1, get_gl_format(bitmap.format), GL_UNSIGNED_BYTE, data.data);
	}

	table_add(*textures, copy_string(BLOCK_TEXTURE_HANDLE), block_texture_array);
	event_enqueue(.{debug_message = "All Block textures initialized!"});
}
