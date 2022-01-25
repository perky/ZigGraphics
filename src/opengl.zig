const std = @import("std");
const vmath = @import("vectormath.zig");
pub const Gl = @import("opengl_bindings");
pub usingnamespace Gl;
const native_arch = @import("builtin").target.cpu.arch;
const PLATFORM_WEB = (native_arch == .wasm32);
pub const c = @cImport({
    if (PLATFORM_WEB) {
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
            // std.log.info("linked {s} with signature {}\n", .{
            //     proc_name, FnType
            // });
        }
    }
}

pub const ShaderProgram = struct {
    program_id: Gl.Uint,
    mvp_matrix_uniform_id: Gl.Int,
    texture_sampler_uniform_id: Gl.Int,
};
pub fn createShaderProgram(vert_shader_src: []const u8, frag_shader_src: []const u8) ShaderProgram
{
    var compile_result: Gl.Int = c.GL_FALSE;
    var info_log_length: Gl.Int = 0;

    const vert_shader = Gl.CreateShader(c.GL_VERTEX_SHADER);
    Gl.ShaderSource(vert_shader, 1, &@ptrCast([*c]const u8, vert_shader_src), null);
    Gl.CompileShader(vert_shader);

    // Check Vertex Shader
    Gl.GetShaderiv(vert_shader, c.GL_COMPILE_STATUS, &compile_result);
    Gl.GetShaderiv(vert_shader, c.GL_INFO_LOG_LENGTH, &info_log_length);
    if ( info_log_length > 0 ){
        var err_msg = std.heap.page_allocator.alloc(u8, @intCast(u32, info_log_length) + 1) catch @panic("Failed to alloc");
        defer std.heap.page_allocator.free(err_msg);
        Gl.GetShaderInfoLog(vert_shader, @intCast(u32, info_log_length), null, @ptrCast(Gl.String, err_msg));
        std.log.err("OpenGL {s}\n", .{err_msg});
    }
    
    const frag_shader = Gl.CreateShader(c.GL_FRAGMENT_SHADER);
    Gl.ShaderSource(frag_shader, 1, &@ptrCast([*c]const u8, frag_shader_src), null);
    Gl.CompileShader(frag_shader);

    // Check Frag Shader
    Gl.GetShaderiv(frag_shader, c.GL_COMPILE_STATUS, &compile_result);
    Gl.GetShaderiv(frag_shader, c.GL_INFO_LOG_LENGTH, &info_log_length);
    if ( info_log_length > 0 ){
        var err_msg = std.heap.page_allocator.alloc(u8, @intCast(u32, info_log_length)) catch @panic("Failed to alloc");
        defer std.heap.page_allocator.free(err_msg);
        Gl.GetShaderInfoLog(frag_shader, @intCast(u32, info_log_length), null, @ptrCast(Gl.String, err_msg));
        std.log.err("OpenGL {s}\n", .{err_msg});
    }

    // Link the program
    const shader_program = Gl.CreateProgram();
    Gl.AttachShader(shader_program, vert_shader);
    Gl.AttachShader(shader_program, frag_shader);
    Gl.LinkProgram(shader_program);

    // Check the program
    Gl.GetProgramiv(shader_program, c.GL_LINK_STATUS, &compile_result);
    Gl.GetProgramiv(shader_program, c.GL_INFO_LOG_LENGTH, &info_log_length);
    if (info_log_length > 0)
    {
        var err_msg = std.heap.page_allocator.alloc(u8, @intCast(u32, info_log_length)) catch @panic("Failed to alloc");
        defer std.heap.page_allocator.free(err_msg);
        Gl.GetProgramInfoLog(shader_program, @intCast(u32, info_log_length), null, @ptrCast(Gl.String, err_msg));
        std.log.err("OpenGL {s}", .{err_msg});
    }

    const mvp_matrix_id = Gl.GetUniformLocation(shader_program, "MVP");
    const texture_sampler_id = Gl.GetUniformLocation(shader_program, "texSampler");

    return ShaderProgram{
        .program_id = shader_program,
        .mvp_matrix_uniform_id = mvp_matrix_id,
        .texture_sampler_uniform_id = texture_sampler_id
    };
}

pub const VertexObject = struct {
    vertex_pos_buffer_id: Gl.Uint,
    vertex_uv_buffer_id: Gl.Uint,
    vertex_count: usize,
    texture_id: Gl.Uint,
    shader_program: ShaderProgram = undefined,

    pub fn init(vertices: []const f32, uvs: ?[]const f32, texture_data: ?LabeledData, shader_program: ShaderProgram) VertexObject
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
            .vertex_count = vertices.len/3,
            .shader_program = shader_program,
            .texture_id = texture_id
        };
    }

    pub fn draw(self: VertexObject, matrix: vmath.Mat4) void
    {
        // Enable shader.
        Gl.UseProgram(self.shader_program.program_id);

        // Send ModelViewProjection matrix to shader.
        const transpose_matrix_to_column_major = c.GL_FALSE;
        Gl.UniformMatrix4fv(
            self.shader_program.mvp_matrix_uniform_id, // Uniform ID
            1,                                         // count
            transpose_matrix_to_column_major,          // transpose?
            matrix.rawPtr()                            // ptr to matrix data
        );

        // Bind texture in graphics card.
        if (self.texture_id != 0) {
            Gl.ActiveTexture(c.GL_TEXTURE0);
            Gl.BindTexture(c.GL_TEXTURE_2D, self.texture_id);
            // Set sampler to use bound texture.
            Gl.Uniform1i(self.shader_program.texture_sampler_uniform_id, 0);
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

        if (self.vertex_uv_buffer_id != 0) {
            // 2nd attribute buffer : UVs
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

        // Draw the triangle !
        Gl.DrawArrays(c.GL_TRIANGLES, 0, self.vertex_count); // Starting from vertex 0; 3 vertices total -> 1 triangle
        Gl.DisableVertexAttribArray(0);
        if (self.vertex_uv_buffer_id != 0) {
            Gl.DisableVertexAttribArray(1);
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
const Texture = struct {
    width: usize = 0,
    height: usize = 0,
    data: [*c]u8 = undefined,

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

fn generateAndSendBufferData(maybe_data: ?[]const f32) Gl.Uint
{
    if (maybe_data) |data| {
        const size = data.len * @sizeOf(@TypeOf(data[0])); 
        var buffer_id: Gl.Uint = 0;
        // Generate 1 buffer, put the resulting identifier in vertexbuffer
        Gl.GenBuffers(1, &buffer_id);
        // The following commands will talk about our 'vertexbuffer' buffer
        Gl.BindBuffer(c.GL_ARRAY_BUFFER, buffer_id);
        // Give our vertices to OpenGL.
        Gl.BufferData(c.GL_ARRAY_BUFFER, @intCast(u32, size), &data[0], c.GL_STATIC_DRAW);
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