 line_shader, line_vao, line_vbo : GLuint;
 cube_shader, cube_vao, cube_vbo : GLuint;

 Vertex_Pos_Color :: struct {
     position:  Vector3;
     color:     Vector4;
 }

 #scope_file

 create_shader_program :: (vertex_source : string, fragment_source : string) -> bool, GLuint
 {
	check_compile_errors :: (shader : GLuint) -> bool, info_log: string
	{
		success : s32;
		glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
		if !success
		{
			info_len : s32;
			glGetShaderiv(shader, GL_INFO_LOG_LENGTH, *info_len);
			info_data := cast (*u8) alloc (info_len,, temp);
			glGetShaderInfoLog(shader, xx info_len, xx *info_len, info_data);
			result : string;
			result.data = info_data;
			result.count = info_len;

			return false, result;
		}

		return true, "";
	}

	check_link_errors :: (program : GLuint) -> bool, info_log : string
	{
		success : s32;
		glGetProgramiv(program, GL_LINK_STATUS, *success);
		if !success
		{
			info_len : s32;
			glGetProgramiv(program, GL_INFO_LOG_LENGTH, *info_len);
			info_data := cast (*u8) alloc (info_len,, temp);
			glGetProgramInfoLog(program, xx info_len, xx *info_len, info_data);
			result : string;
			result.data = info_data;
			result.count = info_len;

			return false, result;
		}

		return true, "";
	}

	vs := glCreateShader(GL_VERTEX_SHADER);
	defer glDeleteShader(vs);

    shaders := *u8.[   SHADER_PREFIX.data ,    vertex_source.data ];
    lengths := s32.[xx SHADER_PREFIX.count, xx vertex_source.count];
	glShaderSource(vs, 2, shaders.data, lengths.data);
	glCompileShader(vs);
	ok, info_log := check_compile_errors(vs);
	if !ok {
		log_error("Could not compile vertex shader %", info_log);
		return false, 0;
	}

	fs := glCreateShader(GL_FRAGMENT_SHADER);
	defer glDeleteShader(fs);
	shaders[1] =    fragment_source.data;
	lengths[1] = xx fragment_source.count;
	glShaderSource(fs, 2, shaders.data, lengths.data);
	glCompileShader(fs);
	ok, info_log = check_compile_errors(fs);
	if !ok {
		log_error ("Could not compile fragment shader: %", info_log);
		return false, 0;
	}

	result := glCreateProgram();
	glAttachShader(result, vs);
	glAttachShader(result, fs);
	glLinkProgram(result);
	ok, info_log = check_link_errors(result);
	if !ok
	{
		log_error("Could not link shader program: %", info_log);
		glDeleteProgram(result);
		return false, 0;
	}

	return true, result;
 }

 #scope_export

 init_rendering_objects :: () -> bool {
     ok : bool;
     ok, line_shader = create_shader_program(LINE_VERTEX_SHADER, LINE_FRAGMENT_SHADER);
     ok, cube_shader = create_shader_program(CUBE_VERTEX_SHADER, CUBE_FRAGMENT_SHADER);
     if !ok then return false;

     glGenVertexArrays(1, *line_vao);
     glBindVertexArray(line_vao);

     glGenBuffers(1, *line_vbo);
     glBindBuffer(GL_ARRAY_BUFFER, line_vbo);
     glBufferData(GL_ARRAY_BUFFER, size_of(Vertex_Pos_Color) * 2, null, GL_DYNAMIC_DRAW);
     glEnableVertexAttribArray(0);
     glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex_Pos_Color), cast(*void) 0);
     glEnableVertexAttribArray(1);
     glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, size_of(Vertex_Pos_Color), cast(*void) size_of(Vector3));

     glBindVertexArray(0);
     glBindBuffer(GL_ARRAY_BUFFER, 0);

     glGenVertexArrays(1, *cube_vao);
     glBindVertexArray(cube_vao);

     glGenBuffers(1, *cube_vbo);
     glBindBuffer(GL_ARRAY_BUFFER, cube_vbo);
     glBufferData(GL_ARRAY_BUFFER, size_of(Vertex_Pos_Color) * 36, null, GL_DYNAMIC_DRAW);

     glEnableVertexAttribArray(0);
     glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vertex_Pos_Color), cast(*void) 0);
     glEnableVertexAttribArray(1);
     glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, size_of(Vertex_Pos_Color), cast(*void) size_of(Vector3));

     glBindVertexArray(0);
     glBindBuffer(GL_ARRAY_BUFFER, 0);

     event_enqueue(.{debug_message = "Rendering Objects initialized!"});
     return true;
 }

 draw_line :: inline (start : Vector3, end : Vector3, color : Vector4) {
     draw_line(start, end, color, color);
 }

 draw_line :: (start : Vector3, end : Vector3, start_color : Vector4, end_color : Vector4) {
    data : [2]Vertex_Pos_Color = ---;
	data[0].position = start;
	data[0].color    = start_color;
	data[1].position = end;
	data[1].color    = end_color;

	glBindVertexArray(line_vao);
	glBindBuffer(GL_ARRAY_BUFFER, line_vbo);
	glBufferSubData(GL_ARRAY_BUFFER, 0, size_of (Vertex_Pos_Color) * 2, data.data);
	glUseProgram(line_shader);
	glUniformMatrix4fv(glGetUniformLocation(line_shader, "u_View_Projection_Matrix"), 1, GL_TRUE, *camera.view_projection_matrix.coef[0][0]);
	glDrawArrays(GL_LINES, 0, 2);
 }

draw_cube :: (position : Vector3, size : float, color : Vector4) {
    half_size := size * 0.5;
    vertices : [36]Vertex_Pos_Color = ---;

    // Front face
    vertices[0]  = .{position + .{-half_size, -half_size,  half_size}, color};
    vertices[1]  = .{position + .{ half_size, -half_size,  half_size}, color};
    vertices[2]  = .{position + .{ half_size,  half_size,  half_size}, color};
    vertices[3]  = .{position + .{-half_size, -half_size,  half_size}, color};
    vertices[4]  = .{position + .{ half_size,  half_size,  half_size}, color};
    vertices[5]  = .{position + .{-half_size,  half_size,  half_size}, color};

    // Back face
    vertices[6]  = .{position + .{ half_size, -half_size, -half_size}, color};
    vertices[7]  = .{position + .{-half_size, -half_size, -half_size}, color};
    vertices[8]  = .{position + .{-half_size,  half_size, -half_size}, color};
    vertices[9]  = .{position + .{ half_size, -half_size, -half_size}, color};
    vertices[10] = .{position + .{-half_size,  half_size, -half_size}, color};
    vertices[11] = .{position + .{ half_size,  half_size, -half_size}, color};

    // Top face
    vertices[12] = .{position + .{-half_size,  half_size,  half_size}, color};
    vertices[13] = .{position + .{ half_size,  half_size,  half_size}, color};
    vertices[14] = .{position + .{ half_size,  half_size, -half_size}, color};
    vertices[15] = .{position + .{-half_size,  half_size,  half_size}, color};
    vertices[16] = .{position + .{ half_size,  half_size, -half_size}, color};
    vertices[17] = .{position + .{-half_size,  half_size, -half_size}, color};

    // Bottom face
    vertices[18] = .{position + .{-half_size, -half_size, -half_size}, color};
    vertices[19] = .{position + .{ half_size, -half_size, -half_size}, color};
    vertices[20] = .{position + .{ half_size, -half_size,  half_size}, color};
    vertices[21] = .{position + .{-half_size, -half_size, -half_size}, color};
    vertices[22] = .{position + .{ half_size, -half_size,  half_size}, color};
    vertices[23] = .{position + .{-half_size, -half_size,  half_size}, color};

    // Right face
    vertices[24] = .{position + .{ half_size, -half_size,  half_size}, color};
    vertices[25] = .{position + .{ half_size, -half_size, -half_size}, color};
    vertices[26] = .{position + .{ half_size,  half_size, -half_size}, color};
    vertices[27] = .{position + .{ half_size, -half_size,  half_size}, color};
    vertices[28] = .{position + .{ half_size,  half_size, -half_size}, color};
    vertices[29] = .{position + .{ half_size,  half_size,  half_size}, color};

    // Left face
    vertices[30] = .{position + .{-half_size, -half_size, -half_size}, color};
    vertices[31] = .{position + .{-half_size, -half_size,  half_size}, color};
    vertices[32] = .{position + .{-half_size,  half_size,  half_size}, color};
    vertices[33] = .{position + .{-half_size, -half_size, -half_size}, color};
    vertices[34] = .{position + .{-half_size,  half_size,  half_size}, color};
    vertices[35] = .{position + .{-half_size,  half_size, -half_size}, color};

    glBindVertexArray(cube_vao);
    glBindBuffer(GL_ARRAY_BUFFER, cube_vbo);
    glBufferSubData(GL_ARRAY_BUFFER, 0, size_of(Vertex_Pos_Color) * 36, vertices.data);
    glUseProgram(cube_shader);
    glUniformMatrix4fv(glGetUniformLocation(cube_shader, "u_View_Projection_Matrix"), 1, GL_TRUE, *camera.view_projection_matrix.coef[0][0]);
    glDrawArrays(GL_TRIANGLES, 0, 36);
}

SHADER_PREFIX :: #string END
#version 330 core
END

LINE_VERTEX_SHADER :: #string GLSL

layout (location = 0) in vec3 a_Position;
layout (location = 1) in vec4 a_Color;

uniform mat4 u_View_Projection_Matrix;

out vec4 Color;

void main () {
    gl_Position = u_View_Projection_Matrix * vec4 (a_Position, 1);
    Color = a_Color;
}
GLSL

LINE_FRAGMENT_SHADER :: #string GLSL

in vec4 Color;

out vec4 Frag_Color;

void main () {
    Frag_Color = Color;
}
GLSL

CUBE_VERTEX_SHADER :: #string GLSL

layout (location = 0) in vec3 a_Position;
layout (location = 1) in vec4 a_Color;

uniform mat4 u_View_Projection_Matrix;

out vec4 Color;

void main () {
    gl_Position = u_View_Projection_Matrix * vec4 (a_Position, 1);
    Color = a_Color;
}
GLSL

CUBE_FRAGMENT_SHADER :: #string GLSL

in vec4 Color;

out vec4 Frag_Color;

void main () {
    Frag_Color = Color;
}
GLSL
