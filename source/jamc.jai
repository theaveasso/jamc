#import "Basic";
#import "Window_Creation";
#import "Input";
#import "System";
#import "String";
#import "Hash_Table";
#import "Math";
#import "GL";
Simp :: #import "Simp";
Texture :: Simp.Texture;

#load "entity.jai";
#load "event.jai";
#load "render.jai";
#load "camera.jai";

ASPECT :: (16.0 / 9.0);
VPIXELS :: 360;

TARGET_FPS :: 60;
TARGET_DT  :: 1.0 / TARGET_FPS;

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

   player_handle    : Entity_Handle;

   camera           : Camera;
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
        camera_update(*camera, current_dt);

        glDepthMask(GL_TRUE);
        glEnable(GL_DEPTH_TEST);
        glClear(GL_DEPTH_BUFFER_BIT);
        Simp.clear_render_target(.1, .1, .1, 1);

        {
            text := sprint("Frame: %", frame);
            Simp.prepare_text(font, text);
            defer free(text);

            x := playfield_width / 30.0;
            y := playfield_height - font.character_height;
            window_coords := window_coords_from_absolute(.{x, xx y});
            color := Vector4.{0.5, 0.8, 0.2, 1.};
            Simp.draw_prepared_text(font, xx window_coords.x, xx window_coords.y, color);
        }
        {
            text := sprint("Left: %, Down: %, Up: %, Right: %", key_left, key_down, key_up, key_right);
            Simp.prepare_text(font, text);
            defer free(text);

            x := playfield_width / 30.0;
            y := playfield_height * .94 - font.character_height;
            window_coords := window_coords_from_absolute(.{x, xx y});
            color := Vector4.{1, 0.8, 0.2, 1.};
            Simp.draw_prepared_text(font, xx window_coords.x, xx window_coords.y, color);
        }

        for i : -10..10
			draw_line(xyz (xx i, 0, -10), xyz (xx i, 0, 10), .{0.4, 0.4, 0.4, 1});
		for i : -10..10
			draw_line(xyz (-10, 0, xx i), xyz (10, 0, xx i), .{0.4, 0.4, 0.4, 1});

        draw_line(.{}, .{x=1}, .{x=1, w=1});
		draw_line(.{}, .{y=1}, .{y=1, w=1});
		draw_line(.{}, .{z=1}, .{z=1, w=1});

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

init_textures :: () {
    make_texture :: (name: string) -> bool, Texture {
        filename := tprint("%/%", data_folder, name);

        result: Texture;
        success := Simp.texture_load_from_file(*result, filename);

        event_enqueue(JAMC_Event.{debug_message = tprint("Loaded texture %", filename)});
        return success, result;
    }

    success, sky := make_texture("sky.png");
    table_add(*textures, copy_string("sky"), sky);
}

process_input :: () {
    update_window_events();
    for events_this_frame {
        if it.type == {
            case .QUIT;
                gs.should_quit_game = true;
            case .KEYBOARD;
                if it.key_pressed {
                    if it.key_code == .ESCAPE gs.should_quit_game = true;
                }

                key := it.key_code;
                if key == #char "A" key_left  = it.key_pressed;
                if key == #char "S" key_down  = it.key_pressed;
                if key == #char "W" key_up    = it.key_pressed;
                if key == #char "D" key_right = it.key_pressed;
        }
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
