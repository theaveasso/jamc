#scope_file

Texture_Load_Context :: struct {
    files: [..]string;
}

#scope_export

BLOCK_TEXTURE_HANDLE  :: "block_textures";
BLOCK_NORMAL_HANDLE   :: "block_normal_maps";
BLOCK_SPECULAR_HANDLE :: "block_specular_maps";

material_ids : [#run enum_highest_value(JAMC_Block_Type) + 1] float;

init_textures :: () {
    find_and_load_block_textures();
}

find_and_load_block_textures :: inline () {
	collector :: (info : *File_Visit_Info, data : *void) {
	    _, basename, ext := path_decomp(info.full_name);
	    ctx := cast(*Texture_Load_Context)data;

		if info.is_directory return;
		if ext != "png" return;

		if ends_with(basename, "_n") return;
		if ends_with(basename, "_s") return;

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
	for *id : material_ids id.* = -1.0;

	first_bitmap : Simp.Bitmap;
	if !Simp.bitmap_load(*first_bitmap, load_ctx.files[0]) return;
	defer Simp.deinit(*first_bitmap);

	w := first_bitmap.width;
	h := first_bitmap.height;

	block_texture_array : Texture;
    normal_texture_array : Texture;
    specular_texture_array : Texture;

	layer_count := cast(u32) load_ctx.files.count;

	glGenTextures(1, *block_texture_array.gl_handle);
	glBindTexture(GL_TEXTURE_2D_ARRAY, block_texture_array.gl_handle);
	glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, xx w, xx h, xx layer_count, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);

    glGenTextures(1, *normal_texture_array.gl_handle);
	glBindTexture(GL_TEXTURE_2D_ARRAY, normal_texture_array.gl_handle);
	glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, xx w, xx h, xx layer_count, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);

    glGenTextures(1, *specular_texture_array.gl_handle);
	glBindTexture(GL_TEXTURE_2D_ARRAY, specular_texture_array.gl_handle);
	glTexImage3D(GL_TEXTURE_2D_ARRAY, 0, GL_RGBA8, xx w, xx h, xx layer_count, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_REPEAT);
    
    glBindTexture(GL_TEXTURE_2D_ARRAY, 0);

	get_gl_format :: (format: Simp.Texture_Format) -> GLenum {
	    if format == .RGBA8 return GL_RGBA;
		if format == .RGB8  return GL_RGB;
	    return GL_RGBA;
	}

    // Default textures
    default_normal_data := alloc(w * h * 4,, temp);
    default_specular_data := alloc(w * h * 4,, temp);
    
    // Fill defaults (Flat blue normal 128, 128, 255, Black specular 0)
    dn_ptr := cast(*u8) default_normal_data;
    ds_ptr := cast(*u8) default_specular_data;
    for 0..(w * h) - 1 {
        dn_ptr[it * 4 + 0] = 128;
        dn_ptr[it * 4 + 1] = 128;
        dn_ptr[it * 4 + 2] = 255;
        dn_ptr[it * 4 + 3] = 255;

        ds_ptr[it * 4 + 0] = 0;
        ds_ptr[it * 4 + 1] = 0;
        ds_ptr[it * 4 + 2] = 0;
        ds_ptr[it * 4 + 3] = 255; // Specular alpha usually unused or glossiness
    }

	for load_ctx.files {
        // Load Diffuse
	    using bitmap : Simp.Bitmap;
		if !Simp.bitmap_load(*bitmap, it) {
		    log_error("Error: loading %", it);
		    continue;
		}
		defer Simp.deinit(*bitmap);

		if width != w || height != h {
            log_error("Error: skipping % (wrong size: %x% expected %x%)", it, width, height, w, h);
		    continue;
		}

        glBindTexture(GL_TEXTURE_2D_ARRAY, block_texture_array.gl_handle);
		glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, xx it_index, xx w, xx h, 1, get_gl_format(bitmap.format), GL_UNSIGNED_BYTE, data.data);

        // Try load Normal
        {
             path_no_ext := path_strip_extension(it);
             normal_path := sprint("%_n.png", path_no_ext);
             
             normal_bmp : Simp.Bitmap;
             has_normal := Simp.bitmap_load(*normal_bmp, normal_path);
             defer if has_normal Simp.deinit(*normal_bmp);

             glBindTexture(GL_TEXTURE_2D_ARRAY, normal_texture_array.gl_handle);
             if has_normal {
                 glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, xx it_index, xx w, xx h, 1, get_gl_format(normal_bmp.format), GL_UNSIGNED_BYTE, normal_bmp.data.data);
             } else {
                 glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, xx it_index, xx w, xx h, 1, GL_RGBA, GL_UNSIGNED_BYTE, default_normal_data);
             }
        }

        // Try load Specular
        {
             path_no_ext := path_strip_extension(it);
             spec_path := sprint("%_s.png", path_no_ext);
             
             spec_bmp : Simp.Bitmap;
             has_spec := Simp.bitmap_load(*spec_bmp, spec_path);
             defer if has_spec Simp.deinit(*spec_bmp);

             glBindTexture(GL_TEXTURE_2D_ARRAY, specular_texture_array.gl_handle);
             if has_spec {
                 glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, xx it_index, xx w, xx h, 1, get_gl_format(spec_bmp.format), GL_UNSIGNED_BYTE, spec_bmp.data.data);
             } else {
                 glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, xx it_index, xx w, xx h, 1, GL_RGBA, GL_UNSIGNED_BYTE, default_specular_data);
             }
        }


		full_name := path_filename(it);
		base_name := path_strip_extension(full_name);
		info := type_info(JAMC_Block_Type);

		found_enum := false;
		enum_value : s64;

		for name, i : info.names {
		    if equal_nocase(name, base_name) {
				enum_value = info.values[i];
				found_enum = true;
				break;
			}
		}

		if found_enum material_ids[enum_value] = xx it_index;
	}

	table_add(*textures, copy_string(BLOCK_TEXTURE_HANDLE), block_texture_array);
    table_add(*textures, copy_string(BLOCK_NORMAL_HANDLE), normal_texture_array);
    table_add(*textures, copy_string(BLOCK_SPECULAR_HANDLE), specular_texture_array);
	event_enqueue(.{debug_message = "All Block textures (Diffuse, Normal, Specular) initialized!"});
}
