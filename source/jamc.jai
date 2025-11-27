#import "Basic";
#import "Window_Creation";
#import "Input";
#import "System";
#import "String";
#import "Math";
Simp :: #import "Simp";

ASPECT :: (16.0 / 9.0);
VPIXELS :: 360;

Game_State :: struct {
   window_\width    : s32;
   window_height    : s32;
   window_aspect    := ASPECT;
   playfield_\width : s32;
   playfield_height : s32;
   frame_count      : int;


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

    window := create_window(window_name="JMAC", width=gs.window_width, height=gs.window_height);
    Simp.set_render_target(window);

    init_fonts();

    while !gs.should_quit_game {
        gs.frame_count += 1;

        reset_temporary_storage();

        process_input();

        Simp.clear_render_target(.1, .1, .1, 1);

        {
            text := sprint("Frame: %", frame_count);
            defer free(text);

            text_width := Simp.prepare_text(font, text);
            scale := 0.5;
            x := playfield_width / 30.0;
            y := playfield_height - font.character_height;
            window_coords := window_coords_from_absolute(.{x, xx y});
            color := Vector4.{0.5, 0.8, 0.2, 1.};
            Simp.draw_prepared_text(font, xx window_coords.x, xx window_coords.y, color);
        }

        Simp.clear_scissor(); // :PlayfieldAspect
        Simp.swap_buffers(window);
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
