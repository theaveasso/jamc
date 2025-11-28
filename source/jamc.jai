#import "Basic";
#import "Window_Creation";
#import "Input";
#import "System";
#import "String";
#import "Math";
Simp :: #import "Simp";

#load "entity.jai";

ASPECT :: (16.0 / 9.0);
VPIXELS :: 360;

TARGET_FPS :: 60;
TARGET_DT  :: 1.0 / TARGET_FPS;

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

   using time       : Game_Time;
   using entity     : Game_Entity;
   using input      : Game_Input;

   should_quit_game := false;
}

using gs : Game_State;

font: *Simp.Dynamic_Font;

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

    window := create_window(window_name="JMAC", width=gs.window_width, height=gs.window_height);
    Simp.set_render_target(window);

    init_fonts();
    init_entities();

    player_handle = create_entity();
    player := get_entity(player_handle);
    player.position = .{playfield_width/2., playfield_height/2.};
    player.speed    = 200.0;


    while !gs.should_quit_game {
        frame += 1;
        reset_temporary_storage();

        now := seconds_since_init();
        delta = now - last_time;
        current_dt = cast(float) delta;

        if current_dt > DT_MAX current_dt = DT_MAX;
        last_time = now;

        process_input();

        move_dir := Vector2.{};
        if key_left     move_dir.x -= 1;
        if key_down     move_dir.y -= 1;
        if key_up       move_dir.y += 1;
        if key_right    move_dir.x += 1;
        if length(move_dir) > 1 move_dir = unit_vector(move_dir);
        player.position += move_dir * player.speed * current_dt;

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

        half := Vector2.{10, 10};

        p0 := player.position + Vector2.{ -half.x, -half.y };
        p1 := player.position + Vector2.{  half.x, -half.y };
        p2 := player.position + Vector2.{  half.x,  half.y };
        p3 := player.position + Vector2.{ -half.x,  half.y };
        Simp.immediate_quad(p0, p1, p2, p3);

        Simp.clear_scissor(); // :PlayfieldAspect
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
