Camera :: struct {
    FLY_SPEED           :: 1.0;
    ROTATION_SPEED      :: 0.3;
    ROTATION_SMOOTHING  :: 0.3;

    position:           Vector3;
    euler_angles:       Vector3;
    rotation:           Quaternion;
    rotation_input:     Vector2;

    fov         := 60.0;

    transform               := Matrix4_Identity;
    view_matrix             := Matrix4_Identity;
    projection_matrix       := Matrix4_Identity;
    view_projection_matrix  := Matrix4_Identity;
}

init_camera :: () {
    camera.position = xyz(8., 6., 8.);
    camera.euler_angles.x = -20 * PI / 180.0;
    camera.euler_angles.y =  45 * PI / 180.0;
}

camera_update :: (delta_time: float) {
    using gs.camera;
    mouse_delta: Vector2;
    move_input : Vector3;
    move_speed : float;

    if _camera.control_camera {
        move_speed = FLY_SPEED;
        mouse_delta = xy(xx mouse_delta_x, xx mouse_delta_y);
        if is_key_down(.SHIFT) then move_speed *= 10;
        move_speed *= delta_time;
        move_input.x = cast(float) key_right - cast(float) key_left;
        move_input.y = cast(float) is_key_down (xx #char "E") - cast(float) is_key_down(xx #char "Q");
        move_input.z = cast(float) key_down - cast(float) key_up;
        move_input = rotate(unit_vector(move_input), rotation);
    }

    position += move_input * move_speed;
    rotation_input = lerp(rotation_input, mouse_delta, ROTATION_SMOOTHING);
    delta := rotation_input * ROTATION_SPEED;
    euler_angles.x += delta.x * PI / 180.0;
    euler_angles.y += delta.y * PI / 180.0;
    euler_angles.y = clamp(euler_angles.y, -80 * PI / 180.0, 80 * PI / 180.0);
    yaw:    Quaternion;
    pitch:  Quaternion;
    set_from_axis_and_angle(*yaw, 0, -1, 0, euler_angles.x);
    set_from_axis_and_angle(*pitch, -1, 0, 0, euler_angles.y);
    rotation = yaw * pitch;

    transform = make_translation_matrix4(position) * rotation_matrix(Matrix4, rotation);
    success:, view_matrix = inverse(transform);

    vx, vy, vw, vh := get_dimensions(gs.window, false);
    aspect_ratio := vw / cast(float) vh;
    projection_matrix = make_projection_matrix(fov * PI / 180.0, aspect_ratio, 0.001, 1000.0);
    view_projection_matrix = projection_matrix * view_matrix;
}
