line_shader, line_vao, line_vbo : GLuint;
block_vbo : GLuint;
chunk_shader, chunk_vao, chunk_instance_vbo : GLuint;

JAMC_Block_Vertex :: struct {
    position:   Vector3;
    uv:         Vector2;
}

JAMC_Line_Vetex :: struct {
    position:   Vector3;
    color:      Vector4;
}

#scope_file

create_shader_program :: (vertex_source : string, fragment_source : string) -> bool, GLuint {
    check_compile_errors :: (shader : GLuint) -> bool, info_log: string {
		success : s32;
		glGetShaderiv(shader, GL_COMPILE_STATUS, *success);
		if !success {
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

	check_link_errors :: (program : GLuint) -> bool, info_log : string {
		success : s32;
		glGetProgramiv(program, GL_LINK_STATUS, *success);
		if !success {
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
	if !ok {
		log_error("Could not link shader program: %", info_log);
		glDeleteProgram(result);
		return false, 0;
	}

	return true, result;
 }

#scope_export

init_rendering_objects :: () -> bool {
    ok : bool;
    ok, line_shader  = create_shader_program(LINE_VERTEX_SHADER, LINE_FRAGMENT_SHADER);
    ok, chunk_shader = create_shader_program(CUBE_INSTANCING_VERTEX_SHADER, CUBE_FRAGMENT_SHADER);
    if !ok then return false;

    {
        glGenVertexArrays(1, *line_vao);
        glBindVertexArray(line_vao);
        defer glBindVertexArray(0);

        glGenBuffers(1, *line_vbo);
        glBindBuffer(GL_ARRAY_BUFFER, line_vbo);
        defer glBindBuffer(GL_ARRAY_BUFFER, 0);

        glBufferData(GL_ARRAY_BUFFER, size_of(JAMC_Line_Vetex) * 2, null, GL_DYNAMIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(JAMC_Line_Vetex), cast(*void) 0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, size_of(JAMC_Line_Vetex), cast(*void) size_of(Vector3));
    }
    {
        glGenVertexArrays(1, *chunk_vao);
        glBindVertexArray(chunk_vao);
        defer glBindVertexArray(0);

        glGenBuffers(1, *block_vbo);
        glBindBuffer(GL_ARRAY_BUFFER, block_vbo);
        glBufferData(GL_ARRAY_BUFFER, size_of(JAMC_Block_Vertex) * 36, cube_vertices.data, GL_STATIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(JAMC_Block_Vertex), cast(*void) 0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(JAMC_Block_Vertex), cast(*void) size_of(Vector3));

        glGenBuffers(1, *chunk_instance_vbo);
        glBindBuffer(GL_ARRAY_BUFFER, chunk_instance_vbo);

        MAX_INSTANCES :: TOTAL_CHUNKS;
        glBufferData(GL_ARRAY_BUFFER, MAX_INSTANCES * size_of(JAMC_Block), null, GL_DYNAMIC_DRAW);

        for i: 0..3 {
            loc := 2 + i;
            glEnableVertexAttribArray(xx loc);
            glVertexAttribPointer(xx loc, 4, GL_FLOAT, GL_FALSE, size_of(JAMC_Block), cast(*void) (size_of(Vector4) * i));
            glVertexAttribDivisor(xx loc, 1);
        }

        glEnableVertexAttribArray(6);
        glVertexAttribPointer(6, 1, GL_FLOAT, GL_FALSE, size_of(JAMC_Block), cast(*void) size_of(Matrix4));
        glVertexAttribDivisor(6, 1);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }

    event_enqueue(.{debug_message = "Rendering Objects initialized!"});
    return true;
}

draw_line :: inline (start : Vector3, end : Vector3, color : Vector4) {
    draw_line(start, end, color, color);
}

draw_line :: (start : Vector3, end : Vector3, start_color : Vector4, end_color : Vector4) {
    data : [2]JAMC_Line_Vetex = ---;
    data[0].position = start;
    data[0].color    = start_color;
    data[1].position = end;
    data[1].color    = end_color;

    glBindVertexArray(line_vao);
    glBindBuffer(GL_ARRAY_BUFFER, line_vbo);
    glBufferSubData(GL_ARRAY_BUFFER, 0, size_of (JAMC_Line_Vetex) * 2, data.data);
    glUseProgram(line_shader);
    glUniformMatrix4fv(glGetUniformLocation(line_shader, "u_View_Projection_Matrix"), 1, GL_TRUE, *camera.view_projection_matrix.coef[0][0]);
    glDrawArrays(GL_LINES, 0, 2);
}

draw_chunk :: (using chunk : *JAMC_Chunk) {
    glBindVertexArray(chunk_vao);
    defer glBindVertexArray(0);

    glBindBuffer(GL_ARRAY_BUFFER, chunk_instance_vbo);
    glBufferSubData(GL_ARRAY_BUFFER, 0, blocks.count * size_of(JAMC_Block), blocks.data);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    glUseProgram(chunk_shader);
    glActiveTexture(GL_TEXTURE0);
    success, texture := table_find(*textures, BLOCK_TEXTURE_HANDLE);
    if !success {
        log_error("Error: retreive texture from table");
        return;
    }
    glBindTexture(GL_TEXTURE_2D_ARRAY, texture.gl_handle);

    view_proj_loc := glGetUniformLocation(chunk_shader, "u_View_Projection_Matrix");
    tex\     _loc := glGetUniformLocation(chunk_shader, "u_Block_Textures");
    glUniformMatrix4fv(view_proj_loc, 1, GL_TRUE, *camera.view_projection_matrix.coef[0][0]);
    glUniform1i(tex_loc, 0);
    glDrawArraysInstanced(GL_TRIANGLES, 0, 36, xx blocks.count);
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

CUBE_INSTANCING_VERTEX_SHADER :: #string GLSL

layout (location = 0) in vec3  a_Position;
layout (location = 1) in vec2  a_UV;
layout (location = 2) in mat4  a_Model_Matrix;
layout (location = 6) in float a_TexID;

uniform mat4 u_View_Projection_Matrix;

out vec2  v_UV;
out float v_TexID;

void main () {
    v_UV    = a_UV;
    v_TexID = a_TexID;
    gl_Position = u_View_Projection_Matrix * a_Model_Matrix * vec4(a_Position, 1);
}
GLSL

CUBE_FRAGMENT_SHADER :: #string GLSL

in vec2  v_UV;
in float v_TexID;

out vec4 Frag_Color;

uniform sampler2DArray u_Block_Textures;

void main () {
    vec4 Tex_Color = texture(u_Block_Textures, vec3(v_UV, v_TexID));
    if (Tex_Color.a < 0.1) discard;

    Frag_Color = Tex_Color;
}
GLSL
