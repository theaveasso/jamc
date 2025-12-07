#import "Basic";
#import "Window_Creation";
#import "Input";
#import "System";
#import "File_Utilities";
#import "Random";
#import "String";
#import "Sort";
#import "Hash_Table";
#import "Math";
#import "GL";
Simp :: #import "Simp";
Texture :: Simp.Texture;

#load "camera.jai";
#load "entity.jai";
#load "event.jai";
#load "render.jai";
#load "world.jai";
#load "texture.jai";

#import,dir "../modules/fastnoise";

ASPECT :: (16.0 / 9.0);
VPIXELS :: 360;

TARGET_FPS :: 60;
TARGET_DT  :: 1.0 / TARGET_FPS;

RENDER_DISTANCE :: 16;
CHUNKS_PER_FRAME :: 2;

Game_Camera :: struct {
    using camera    : Camera;
    control_camera  : bool;
}

Game_Asset :: struct {
    font: *Simp.Dynamic_Font;
    textures: Table(string, Texture);
}

Game_Event :: struct {
    queue:          [..]JAMC_Event;
    subscribers:    Table(JAMC_Event_Type, [..]JAMC_Event_Callback_Func);
}

Game_Time :: struct {
    delta:      float64;
    frame:      s32;

    current_dt: float = 0.016667;
    last_time:  float64;
    DT_MAX:     float = 0.15;
}

Game_Input :: struct {
    key_left:   u32;
    key_down:   u32;
    key_up:     u32;
    key_right:  u32;
}

Game_Entity :: struct {
    entities:               [..]Entity;
    generations:            [..]s32;
    unused_entity_handles:  [..]Entity_Handle;
    active_entities:        [..]s32;
}

Game_State :: struct {
   window_\width    : s32;
   window_height    : s32;
   window_aspect    := ASPECT;
   playfield_\width : s32;
   playfield_height : s32;

   noise            : Noise_Gen;
   world            : Table(s64, *JAMC_Chunk);

   player_handle    : Entity_Handle;

   using _camera    : Game_Camera;
   using asset      : Game_Asset;
   using event      : Game_Event;
   using time       : Game_Time;
   using entity     : Game_Entity;
   using input      : Game_Input;

   window: Window_Type;
   should_quit_game := false;
}

using gs : Game_State;

data_folder : string;

main :: () {
    base_path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(base_path);

    playfield_width  = cast(s32) (VPIXELS * ASPECT);
    playfield_height = VPIXELS;

    window_width  = playfield_width;
    window_height = playfield_height;

    data_folder = join(base_path, "data");
    print("data_folder is '%'\n", data_folder);

    last_time = seconds_since_init();

    window = create_window(window_name="JAMC", width=gs.window_width, height=gs.window_height);
    Simp.set_render_target(window);

    init_fonts();
    init_textures();

    init_camera();
    init_entities();

    init_noise_generator(*noise);
    
    // Initial generation will happen in the loop or we can force it here
    update_world_generation();

    init_rendering_objects();

    glEnable(GL_BLEND);
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    while !gs.should_quit_game {
        frame += 1;
        reset_temporary_storage();

        now := seconds_since_init();
        delta = now - last_time;
        current_dt = cast(float) delta;

        if current_dt > DT_MAX current_dt = DT_MAX;
        last_time = now;

        process_input();
        event_update();
        camera_update(current_dt);
        update_world_generation();


        glDepthMask(GL_TRUE);
        glEnable(GL_DEPTH_TEST);
        glClear(GL_DEPTH_BUFFER_BIT);
        Simp.clear_render_target(.1, .1, .1, 1);

        draw_line(.{}, .{x=1}, .{x=1, w=1});
		draw_line(.{}, .{y=1}, .{y=1, w=1});
		draw_line(.{}, .{z=1}, .{z=1, w=1});

		for chunk, key : world {
            draw_chunk(chunk);
        }


        Simp.clear_scissor();
        Simp.swap_buffers(window);

        frame_time := seconds_since_init() - now;
        if frame_time < TARGET_DT {
            sleep_ms := cast(s32)((TARGET_DT - frame_time) * 1000.0);
            if sleep_ms > 0 sleep_milliseconds(sleep_ms);
        }
    }
}

init_fonts :: () {
    pixel_height := playfield_height / 14;
    font = Simp.get_font_at_size(data_folder, "yoster.ttf", pixel_height);
    assert(font != null);
}

process_input :: () {
    update_window_events();
    for events_this_frame {
        if it.type == {
            case .QUIT;
                gs.should_quit_game = true;
            case .KEYBOARD;
                key := it.key_code;
                if it.key_pressed {
                    if key == .ESCAPE gs.should_quit_game = true;
                    if key == #char "F" set_camera_control(!gs._camera.control_camera);
                }

                if key == #char "A" key_left  = it.key_pressed;
                if key == #char "S" key_down  = it.key_pressed;
                if key == #char "W" key_up    = it.key_pressed;
                if key == #char "D" key_right = it.key_pressed;
        }
    }

    if !input_application_has_focus && control_camera then set_camera_control(false);
    if _camera.control_camera {
        x, y, w, h := get_dimensions(window, false);
        set_mouse_pointer_position(w / 2, h / 2);
    }
}

window_coords_from_absolute :: (v : Vector2) -> Vector2 {
    result := v;
    delta: float;
    if window_aspect > ASPECT {
        delta = (window_width - playfield_width) / 2.;
        result.x += delta;
    } else {
        delta = (window_height - playfield_height) / 2.;
        result.y += delta;
    }

    assert(delta >= 0);
    return result;
}

is_key_down :: inline (key: Key_Code) -> bool {
    return (input_button_states[cast(s64) key] & .DOWN) != 0;
}

set_camera_control :: inline (control : bool) {
	_camera.control_camera = control;
	if _camera.control_camera hide_cursor();
	else show_cursor();
}

hide_cursor :: inline () {
    #if OS == .WINDOWS {
		win32 :: #import "Windows";
		win32.ShowCursor(0);
	}
}

show_cursor :: inline () {
    #if OS == .WINDOWS {
		win32 :: #import "Windows";
		win32.ShowCursor(1);
	}
}

set_mouse_pointer_position :: inline (x : int, y : int)
{
	#if OS == .WINDOWS
	{
		user32 :: #library,system "User32";
		SetCursorPos :: (x : s32, y : s32) -> s32 #foreign user32;
	}
}

update_world_generation :: () {
    // Determine player's chunk position
    px := gs.camera.position.x;
    pz := gs.camera.position.z;

    // chunk_world_size := CHUNK_SIZE * VOXEL_SCALE
    // But we can just do the math inline or define it. VOXEL_SCALE is float, CHUNK_SIZE is int.
    chunk_world_size := cast(float)CHUNK_SIZE * VOXEL_SCALE;

    player_chunk_x := cast(s32) floor(px / chunk_world_size);
    player_chunk_z := cast(s32) floor(pz / chunk_world_size);

    chunks_generated := 0;

    // Simple radius check
    // Optimization: Spiral out or smarter queue, but simple double loop for now
    for x : player_chunk_x - RENDER_DISTANCE .. player_chunk_x + RENDER_DISTANCE {
        for z : player_chunk_z - RENDER_DISTANCE .. player_chunk_z + RENDER_DISTANCE {
            key := get_chunk_key(x, z);
            if !table_contains(*world, key) {
                // Return if we have exceeded our budget for this frame
                if chunks_generated >= CHUNKS_PER_FRAME return;

                // Generate new chunk
                chunk := New(JAMC_Chunk);
                chunk.position.x = xx x;
                chunk.position.y = xx z;
                
                generate_chunk_blocks(chunk, *noise, x, z);
                table_add(*world, key, chunk);
                
                // Mesh this chunk
                // Pass *world explicitly as it expects *Table
                update_chunk_mesh(chunk, *world);
                
                // Update neighbors because they might need to hide/show faces now that this chunk exists
                update_neighbor_mesh(x - 1, z);
                update_neighbor_mesh(x + 1, z);
                update_neighbor_mesh(x, z - 1);
                update_neighbor_mesh(x, z + 1);

                chunks_generated += 1;
            }
        }
    }
}

update_neighbor_mesh :: (x: s32, z: s32) {
    key := get_chunk_key(x, z);
    found, chunk := table_find(*world, key);
    if found update_chunk_mesh(chunk, *world);
}
