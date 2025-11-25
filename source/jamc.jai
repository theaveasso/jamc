#import "Basic";
#import "Window_Creation";
#import "Input";
Simp :: #import "Simp";

ASPECT :: (16.0 / 9.0);
VPIXELS :: 360;

should_quit_game := false;

main :: () {
    window_width := cast(s32) (VPIXELS * ASPECT);
    window_height : s32 = VPIXELS;

    window := create_window(window_name="JMAC", width=window_width, height=window_height);
    Simp.set_render_target(window);

    while !should_quit_game {
        reset_temporary_storage();
        update_window_events();
        for events_this_frame {
            if it.type == {
                case .QUIT;
                    should_quit_game = true;
                case .KEYBOARD;
                    if it.key_pressed {
                        if it.key_code == .ESCAPE should_quit_game = true;
                    }
            }
        }

        Simp.clear_render_target(.1, .1, .1, 1);
        Simp.swap_buffers(window);
    }
}
