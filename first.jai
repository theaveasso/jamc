#import "Basic";
#import "Compiler";
Autorun :: #import "Autorun";

OUTPUT_EXECUTABLE_NAME :: "jamc";

#run {
    set_build_options_dc(.{ do_output = false });
    args := get_build_options().compile_time_command_line;

    run := array_find(args, "-run");

    cpu_target := CPU;
    os\_target := OS;
    log("Compiling for % %", os_target, cpu_target);

    w := compiler_create_workspace("Target workspace");
    options := get_build_options(w);
    options.cpu_target = cpu_target;
    options.os\_target = os\_target;
    options.output_executable_name = OUTPUT_EXECUTABLE_NAME;
    options.output_path = "";

    set_build_options(options, w);

    compiler_begin_intercept(w);
    add_build_file("source/jamc.jai", w);

    while true {
        message := compiler_wait_for_message();
        if message.kind == {
            case .COMPLETE;
                mc := cast(*Message_Complete) message;
                if mc.error_code != .NONE {
                    exit(1);
                }
                break;
        }
    }

    compiler_end_intercept(w);

    if run Autorun.run_build_result(w);
}
