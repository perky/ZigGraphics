const std = @import("std");
const vmath = @import("vectormath.zig");
const platform = @import("platform.zig");
pub const imgui = @import("imgui");
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

fn compileShaders(vert_shader_src: []const u8, frag_shader_src: []const u8) Gl.Uint
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

// const my_font = @embedFile("roboto.ttf");

pub const ImguiState = struct {
    shader_program: Gl.Uint,
    projection_matrix_id: Gl.Int,
    texture_sampler_id: Gl.Int,
    vbo_id: Gl.Uint,
    elements_id: Gl.Uint,
    ctx: *imgui.ImGuiContext,
    io: *imgui.ImGuiIO
};
pub fn initImgui() ImguiState
{
    var imgui_ctx = imgui.igCreateContext(null);
    var imgui_io = imgui.igGetIO();
    // _ = imgui.ImFontAtlas_AddFontDefault(imgui_io.*.Fonts, null);
    // imgui_io.*.ConfigFlags |= imgui.ImGuiConfigFlags_DockingEnable;
    // imgui_io.*.ConfigFlags |= imgui.ImGuiConfigFlags_ViewportsEnable;
    imgui_io.*.BackendPlatformName = "imgui_impl_zig";

    const shader_program = compileShaders(imgui.VertexShaderSrc, imgui.FragmentShaderSrc);    
    const mvp_matrix_id = Gl.GetUniformLocation(shader_program, "ProjMtx");
    const texture_sampler_id = Gl.GetUniformLocation(shader_program, "Texture");

    // Create buffers
    var vbo_id: Gl.Uint = 0;
    var elements_id: Gl.Uint = 0;
    Gl.GenBuffers(1, &vbo_id);
    Gl.GenBuffers(1, &elements_id);

    // Build atlas
    var tex_pixels: [*c]u8 = undefined;
    var tex_width: c_int = 0;
    var tex_height: c_int = 0;

    // var font_copy = std.heap.page_allocator.alloc(u8, my_font.len) catch unreachable;
    // defer std.heap.page_allocator.free(font_copy);
    // std.mem.copy(u8, font_copy, my_font);
    // const ig_font = imgui.ImFontAtlas_AddFontFromMemoryTTF(imgui_io.*.Fonts, font_copy.ptr, @intCast(c_int, font_copy.len), 20, null, null);

    imgui.ImFontAtlas_GetTexDataAsRGBA32(imgui_io.*.Fonts, &tex_pixels, &tex_width, &tex_height, null);
    
    // Bind atlas texture
    var imgui_tex_id: Gl.Uint = 0;
    Gl.GenTextures(1, &imgui_tex_id);
    Gl.BindTexture(c.GL_TEXTURE_2D, imgui_tex_id);
    Gl.TexImage2D(
        c.GL_TEXTURE_2D, 
        0, 
        c.GL_RGBA, 
        @intCast(Gl.Sizei, tex_width), 
        @intCast(Gl.Sizei, tex_height), 
        0, 
        c.GL_RGBA, 
        c.GL_UNSIGNED_BYTE, 
        tex_pixels
    );
    Gl.TexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    Gl.TexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

    imgui_io.*.Fonts.*.TexID = @intToPtr(*anyopaque, imgui_tex_id);
    // imgui.ImFontAtlas_SetTexID(imgui_io.*.Fonts, @intToPtr(*anyopaque, imgui_tex_id));

    return ImguiState{
        .shader_program = shader_program,
        .projection_matrix_id = mvp_matrix_id,
        .texture_sampler_id = texture_sampler_id,
        .vbo_id = vbo_id,
        .elements_id = elements_id,
        .ctx = imgui_ctx,
        .io = imgui_io
    };
}

pub fn renderImgui(state: ImguiState) void
{
    const draw_data = imgui.igGetDrawData().*;

    // Vertex Array Object.
    var vertex_array_id: Gl.Uint = 0;
    Gl.GenVertexArrays(1, &vertex_array_id);

    Gl.Enable(c.GL_BLEND);
    Gl.BlendEquation(c.GL_FUNC_ADD);
    Gl.BlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
    Gl.Enable(c.GL_SCISSOR_TEST);
    Gl.Disable(c.GL_CULL_FACE);
    Gl.Disable(c.GL_DEPTH_TEST);

    const fb_width = draw_data.DisplaySize.x * draw_data.FramebufferScale.x;
    const fb_height = draw_data.DisplaySize.y * draw_data.FramebufferScale.y;
    Gl.Viewport(
        0,
        0, 
        @floatToInt(usize, fb_width), 
        @floatToInt(usize, fb_height)
    );
    // std.log.info("glViewport {d} {d}", .{@floatToInt(usize, fb_width), @floatToInt(usize, fb_height)});
    const L: f32 = draw_data.DisplayPos.x;
    const R: f32 = draw_data.DisplayPos.x + draw_data.DisplaySize.x;
    const T: f32 = draw_data.DisplayPos.y;
    const B: f32 = draw_data.DisplayPos.y + draw_data.DisplaySize.y;
    const ortho_projection = [_]f32{
        2.0/(R-L),   0.0,         0.0,   0.0,
        0.0,         2.0/(T-B),   0.0,   0.0,
        0.0,         0.0,        -1.0,   0.0,
        (R+L)/(L-R), (T+B)/(B-T), 0.0,   1.0,
    };

    Gl.UseProgram(state.shader_program);
    Gl.Uniform1i(state.texture_sampler_id, 0);
    Gl.UniformMatrix4fv(state.projection_matrix_id, 1, c.GL_FALSE, &ortho_projection[0]);

    // Bind vertex/index buffers and setup attributes for ImDrawVert
    Gl.BindVertexArray(vertex_array_id);
    Gl.BindBuffer(c.GL_ARRAY_BUFFER, state.vbo_id);
    Gl.BindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, state.elements_id);
    Gl.EnableVertexAttribArray(0);
    Gl.EnableVertexAttribArray(1);
    Gl.EnableVertexAttribArray(2);
    Gl.VertexAttribPointer(0, 2, c.GL_FLOAT,         c.GL_FALSE, @sizeOf(imgui.ImDrawVert), @intToPtr(?*const anyopaque, @offsetOf(imgui.ImDrawVert, "pos")));
    Gl.VertexAttribPointer(1, 2, c.GL_FLOAT,         c.GL_FALSE, @sizeOf(imgui.ImDrawVert), @intToPtr(?*const anyopaque, @offsetOf(imgui.ImDrawVert, "uv")));
    Gl.VertexAttribPointer(2, 4, c.GL_UNSIGNED_BYTE, c.GL_TRUE,  @sizeOf(imgui.ImDrawVert), @intToPtr(?*const anyopaque, @offsetOf(imgui.ImDrawVert, "col")));

    // Will project scissor/clipping rectangles into framebuffer space
    var clip_off: imgui.ImVec2 = draw_data.DisplayPos;         // (0,0) unless using multi-viewports
    var clip_scale: imgui.ImVec2 = draw_data.FramebufferScale; // (1,1) unless using retina display which are often (2,2)

    // Render command lists
    var n: usize = 0;
    while (n < draw_data.CmdListsCount) : (n += 1)
    {
        const cmd_list_ptr = draw_data.CmdLists[n];
        const cmd_list = cmd_list_ptr.*;

        // Upload vertex/index buffers
        Gl.BufferData(c.GL_ARRAY_BUFFER, 
            @intCast(usize, cmd_list.VtxBuffer.Size) * @sizeOf(imgui.ImDrawVert), 
            cmd_list.VtxBuffer.Data, 
            c.GL_STREAM_DRAW);
        Gl.BufferData(c.GL_ELEMENT_ARRAY_BUFFER, 
            @intCast(usize, cmd_list.IdxBuffer.Size) * @sizeOf(imgui.ImDrawIdx), 
            cmd_list.IdxBuffer.Data, 
            c.GL_STREAM_DRAW);

        var cmd_i: usize = 0;
        while (cmd_i < cmd_list.CmdBuffer.Size) : (cmd_i += 1)
        {
            const pcmd_ptr = &cmd_list.CmdBuffer.Data[cmd_i];
            const pcmd = cmd_list.CmdBuffer.Data[cmd_i];
            if (pcmd.UserCallback) |user_callback|
            {
                // User callback, registered via ImDrawList::AddCallback()
                user_callback(cmd_list_ptr, pcmd_ptr);
            }
            else
            {
                // Project scissor/clipping rectangles into framebuffer space
                var clip_rect = imgui.ImVec4{
                    .x = (pcmd.ClipRect.x - clip_off.x) * clip_scale.x,
                    .y = (pcmd.ClipRect.y - clip_off.y) * clip_scale.y,
                    .z = (pcmd.ClipRect.z - clip_off.x) * clip_scale.x,
                    .w = (pcmd.ClipRect.w - clip_off.y) * clip_scale.y,
                };

                if (clip_rect.x < fb_width 
                and clip_rect.y < fb_height 
                and clip_rect.z >= 0.0 
                and clip_rect.w >= 0.0 
                and clip_rect.w >= clip_rect.y)
                {
                    Gl.Scissor(
                        @floatToInt(Gl.Int, @floor(clip_rect.x)), 
                        @floatToInt(Gl.Int, @floor(fb_height - clip_rect.w)),
                        @floatToInt(Gl.Sizei, @floor(clip_rect.z - clip_rect.x)), 
                        @floatToInt(Gl.Sizei, @floor(clip_rect.w - clip_rect.y))
                    );

                    // Bind texture, Draw
                    if (pcmd.TextureId) |tex_id|
                    {
                        Gl.BindTexture(c.GL_TEXTURE_2D, @intCast(u32, @ptrToInt(tex_id)));
                    }
                    const draw_idx_size = @sizeOf(imgui.ImDrawIdx);
                    Gl.DrawElements(
                        c.GL_TRIANGLES, 
                        pcmd.ElemCount, 
                        if (draw_idx_size == 2) c.GL_UNSIGNED_SHORT else c.GL_UNSIGNED_INT, 
                        @intToPtr(?*anyopaque, pcmd.IdxOffset * draw_idx_size)
                    );
                }
            }
        }
    }

    Gl.DeleteVertexArrays(1, &vertex_array_id);
    Gl.Disable(c.GL_SCISSOR_TEST);
}