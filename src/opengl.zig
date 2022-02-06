const std = @import("std");
const vmath = @import("vectormath.zig");
const platform = @import("platform.zig");
pub const Gl = @import("opengl_bindings");
pub usingnamespace Gl;
pub const c = @cImport({
    if (platform.IS_WEB) {
        @cDefine("PLATFORM_WEB", "1");
    } else {
        @cDefine("PLATFORM_DESKTOP", "1");
    }
    @cInclude("GL/gl.h");
    @cInclude("GL/glext.h");
    @cInclude("stb_image.c");
});

pub const GetGlProcAddressSig = fn([*:0]const u8) callconv(.C) (?fn() callconv(.C) void);
pub fn linkGlFunctions(get_proc_fn: ?GetGlProcAddressSig) void
{
    inline for(@typeInfo(Gl).Struct.decls) |decl| 
    {
        if (comptime decl.is_pub and decl.data == .Var)
        {
            const proc_name = "gl" ++ decl.name ++ "\x00";
            const bare_proc = get_proc_fn.?(proc_name).?;
            const FnType = @TypeOf(@field(Gl, decl.name));
            @field(Gl, decl.name) = @ptrCast(FnType, bare_proc);
        }
    }
}

var currently_bound_shader_program: ?ShaderProgram = null;
pub const ShaderProgram = struct {
    program_id: Gl.Uint,
    mvp_matrix_uniform_id: Gl.Int = 0,
    texture_sampler_uniform_id: Gl.Int = 0,
};

fn checkForShaderCompileErrors(shader_id: Gl.Uint, comptime is_program: bool) void
{
    var compile_result: Gl.Int = c.GL_FALSE;
    var info_log_length: Gl.Int = 0;
    const getShaderParam = if (is_program) Gl.GetProgramiv else Gl.GetShaderiv;
    const status_type = if (is_program) c.GL_LINK_STATUS else c.GL_COMPILE_STATUS;
    getShaderParam(shader_id, status_type, &compile_result);
    getShaderParam(shader_id, c.GL_INFO_LOG_LENGTH, &info_log_length);
    if (compile_result == c.GL_FALSE) {
        var err_msg = std.heap.page_allocator.alloc(u8, @intCast(u32, info_log_length) + 1) catch @panic("Failed to alloc.");
        defer std.heap.page_allocator.free(err_msg);
        const getInfoLog = if (is_program) Gl.GetProgramInfoLog else Gl.GetShaderInfoLog;
        getInfoLog(shader_id, @intCast(u32, info_log_length), null, @ptrCast(Gl.String, err_msg));
        std.log.err("OpenGL {s}\n", .{err_msg});
    }
}

pub fn compileShaders(vert_shader_src: []const u8, frag_shader_src: []const u8) Gl.Uint
{
    const vert_shader = Gl.CreateShader(c.GL_VERTEX_SHADER);
    Gl.ShaderSource(vert_shader, 1, &@ptrCast([*c]const u8, vert_shader_src), null);
    Gl.CompileShader(vert_shader);
    checkForShaderCompileErrors(vert_shader, false);
    
    const frag_shader = Gl.CreateShader(c.GL_FRAGMENT_SHADER);
    Gl.ShaderSource(frag_shader, 1, &@ptrCast([*c]const u8, frag_shader_src), null);
    Gl.CompileShader(frag_shader);
    checkForShaderCompileErrors(frag_shader, false);

    // Link the program
    const shader_program_id = Gl.CreateProgram();
    Gl.AttachShader(shader_program_id, vert_shader);
    Gl.AttachShader(shader_program_id, frag_shader);
    Gl.LinkProgram(shader_program_id);
    checkForShaderCompileErrors(shader_program_id, true);

    return shader_program_id;
}

pub fn createShaderProgram(vert_shader_src: []const u8, frag_shader_src: []const u8) ShaderProgram
{
    const shader_program = compileShaders(vert_shader_src, frag_shader_src);
    const mvp_matrix_id = Gl.GetUniformLocation(shader_program, "transform");
    const texture_sampler_id = Gl.GetUniformLocation(shader_program, "texSampler");
    return ShaderProgram{
        .program_id = shader_program,
        .mvp_matrix_uniform_id = mvp_matrix_id,
        .texture_sampler_uniform_id = texture_sampler_id
    };
}

pub fn setActiveShaderProgram(maybe_shader_program: ?ShaderProgram) ShaderProgram
{
    if (maybe_shader_program) |shader_program| {
        Gl.UseProgram(shader_program.program_id);
        currently_bound_shader_program = shader_program;
    }
    return currently_bound_shader_program.?;
}

pub fn getActiveShaderProgram() ShaderProgram
{
    return currently_bound_shader_program.?;
}

pub fn setMatrixUniform(matrix: vmath.Mat4, uniform_id: Gl.Int) void
{
    Gl.UniformMatrix4fv(
        uniform_id,         // Uniform ID
        1,                  // count
        c.GL_FALSE,         // transpose?
        matrix.rawPtr()     // ptr to matrix data
    );
}

pub const VertexObject = struct {
    vertex_pos_buffer_id: Gl.Uint,
    vertex_uv_buffer_id: Gl.Uint,
    vertex_color_buffer_id: Gl.Uint,
    vertex_count: usize,
    texture_id: Gl.Uint,
    shader_program: ?ShaderProgram = null,
    model_matrix: vmath.Mat4,
    draw_kind: DrawKind,

    pub const DrawKind = enum {
        triangles,
        lines
    };

    pub fn init(vertices: []const f32, 
                uvs: ?[]const f32, 
                colors: ?[]const f32, 
                texture_data: ?LabeledData, 
                shader_program: ?ShaderProgram,
                model_matrix: vmath.Mat4,
                draw_kind: DrawKind) VertexObject
    {
        var texture_id: Gl.Uint = 0;
        const maybe_bitmap = Texture.initFromMemory(texture_data) catch null;
        if (maybe_bitmap) |bitmap| {
            texture_id = bitmap.sendToGpu();
            bitmap.deinit();
        }

        return VertexObject{
            .vertex_pos_buffer_id = generateAndSendBufferData(vertices),
            .vertex_uv_buffer_id = generateAndSendBufferData(uvs),
            .vertex_color_buffer_id = generateAndSendBufferData(colors),
            .vertex_count = vertices.len/3,
            .shader_program = shader_program,
            .texture_id = texture_id,
            .model_matrix = model_matrix,
            .draw_kind = draw_kind
        };
    }

    pub fn deinit(self: VertexObject) void
    {
        Gl.DeleteBuffers(1, self.vertex_pos_buffer_id);
        if (self.vertex_uv_buffer_id != 0)
            Gl.DeleteBuffers(1, self.vertex_uv_buffer_id);
        if (self.vertex_color_buffer_id != 0)
            Gl.DeleteBuffers(1, self.vertex_color_buffer_id);
        if (self.texture_id != 0)
            Gl.DeleteTextures(1, self.texture_id);
    }

    pub fn updateVertexBuffer(self: *VertexObject, data: []const f32) void
    {
        if (data.len > 0)
            sendBufferDataToGpu(f32, self.vertex_pos_buffer_id, data);
        self.vertex_count = data.len / 3;
    }

    pub fn updateUvBuffer(self: *VertexObject, data: []const f32) void
    {
        if (data.len > 0)
            sendBufferDataToGpu(f32, self.vertex_uv_buffer_id, data);
    }

    pub fn updateColorBuffer(self: *VertexObject, data: []const f32) void
    {
        if (data.len > 0)
            sendBufferDataToGpu(f32, self.vertex_color_buffer_id, data);
    }

    pub fn draw(self: VertexObject, camera_transform: vmath.Mat4) void
    {
        // Enable shader.
        const program = setActiveShaderProgram(self.shader_program);

        // Send Model matrix to shader.
        //const transform = self.model_matrix.mul(camera_transform);
        const transform = camera_transform;
        setMatrixUniform(transform, program.mvp_matrix_uniform_id);

        // Bind texture in graphics card.
        if (self.texture_id != 0) {
            Gl.ActiveTexture(c.GL_TEXTURE0);
            Gl.BindTexture(c.GL_TEXTURE_2D, self.texture_id);
            // Set sampler to use bound texture.
            Gl.Uniform1i(program.texture_sampler_uniform_id, 0);
        }

        // 1st attribute buffer : vertices
        Gl.EnableVertexAttribArray(0);
        Gl.BindBuffer(c.GL_ARRAY_BUFFER, self.vertex_pos_buffer_id);
        Gl.VertexAttribPointer(
            0,                      // attribute index.
            3,                      // size
            c.GL_FLOAT,             // type
            c.GL_FALSE,             // normalized?
            0,                      // stride
            null                    // array buffer offset
        );

        // 2nd attribute buffer : UVs
        if (self.vertex_uv_buffer_id != 0) {
            Gl.EnableVertexAttribArray(1);
            Gl.BindBuffer(c.GL_ARRAY_BUFFER, self.vertex_uv_buffer_id);
            Gl.VertexAttribPointer(
                1,                      // attribute index.
                2,                      // size
                c.GL_FLOAT,             // type
                c.GL_FALSE,             // normalized?
                0,                      // stride
                null                    // array buffer offset
            );
        }

        // 3rd attribute buffer : Colors
        if (self.vertex_color_buffer_id != 0) {
            Gl.EnableVertexAttribArray(2);
            Gl.BindBuffer(c.GL_ARRAY_BUFFER, self.vertex_color_buffer_id);
            Gl.VertexAttribPointer(
                2,                      // attribute index.
                4,                      // size
                c.GL_FLOAT,             // type
                c.GL_FALSE,             // normalized?
                0,                      // stride
                null                    // array buffer offset
            );
        }

        // Draw it.
        const draw_kind_enum: u32 = switch(self.draw_kind) {
            .triangles => c.GL_TRIANGLES,
            .lines => c.GL_LINES
        };
        Gl.DrawArrays(draw_kind_enum, 0, self.vertex_count); // Starting from vertex 0; 3 vertices total -> 1 triangle
        Gl.DisableVertexAttribArray(0);
        if (self.vertex_uv_buffer_id != 0) {
            Gl.DisableVertexAttribArray(1);
        }
        if (self.vertex_color_buffer_id != 0) {
            Gl.DisableVertexAttribArray(2);
        }
    }
};

pub const LabeledData = struct {
    name: []const u8,
    data: []const u8
};

const ReadTextureError = error {
    ReadError
};
pub const Texture = struct {
    width: usize = 0,
    height: usize = 0,
    data: [*c]u8 = undefined,

    var WHITE_PIXEL = [_]u8{255} ** (4*4);

    pub fn init1by1() Texture
    {
        return Texture{
            .width = 1,
            .height = 1,
            .data = @ptrCast([*c]u8, WHITE_PIXEL[0..])
        };
    }

    pub fn initFromPixels(pixels: [*c]u8, width: usize, height: usize) Texture
    {
        return Texture{
            .width = width,
            .height = height,
            .data = pixels
        };
    }

    pub fn initFromMemory(texture_data: ?LabeledData) !?Texture
    {
        if (texture_data == null) {
            return null;
        }
        const tdata = texture_data.?;

        var width: i32 = undefined;
        var height: i32 = undefined;
        var pixel_size: i32 = undefined;
        const data = c.stbi_load_from_memory(
            &tdata.data[0],
            @intCast(c_int, tdata.data.len), 
            &width, 
            &height, 
            &pixel_size, 
            0
        );
        if (data == 0) {
            std.log.err("Texture.initFromMemory: unable to read texture {s}\n", .{tdata.name});
            return ReadTextureError.ReadError;
        }
        return Texture{
            .width = @intCast(usize, width),
            .height = @intCast(usize, height),
            .data = data
        };
    }

    pub fn deinit(self: *const Texture) void
    {
        c.stbi_image_free(self.data);
    }

    pub fn sendToGpu(self: *const Texture) Gl.Uint
    {
        var texture_id: Gl.Uint = 0;
        if (self.width > 0 and self.height > 0) {
            Gl.GenTextures(1, &texture_id);
            Gl.BindTexture(c.GL_TEXTURE_2D, texture_id);
            Gl.TexImage2D(
                c.GL_TEXTURE_2D, 
                0, 
                c.GL_RGB, 
                @intCast(Gl.Sizei, self.width), 
                @intCast(Gl.Sizei, self.height), 
                0, 
                c.GL_RGB, 
                c.GL_UNSIGNED_BYTE, 
                &self.data[0]
            );
            Gl.TexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
            Gl.TexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
        }
        return texture_id;
    }
};

fn sendBufferDataToGpu(comptime data_type: type, buffer_id: Gl.Uint, data: []const data_type) void
{
    const size = @intCast(u32, data.len * @sizeOf(data_type));
    // The following commands will talk about our 'vertexbuffer' buffer
    Gl.BindBuffer(c.GL_ARRAY_BUFFER, buffer_id);
    // Give our vertices to OpenGL.
    Gl.BufferData(c.GL_ARRAY_BUFFER, size, &data[0], c.GL_STATIC_DRAW);
}

fn generateAndSendBufferData(maybe_data: ?[]const f32) Gl.Uint
{
    if (maybe_data) |data| {
        var buffer_id: Gl.Uint = 0;
        Gl.GenBuffers(1, &buffer_id);
        sendBufferDataToGpu(f32, buffer_id, data);
        return buffer_id;
    } else {
        return 0;
    }
}

pub fn clear(r: f32, g: f32, b: f32) void 
{
    c.glClearColor(r, g, b, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
}

pub fn getShaderVersion() [*c]const u8
{
    return c.glGetString(c.GL_SHADING_LANGUAGE_VERSION);
}