pub const imgui = @import("imgui");
pub usingnamespace imgui;
const gfx = @import("gfx.zig");
const Gl = @import("opengl.zig");
const c = Gl.c;

pub const GuiState = struct {
    shader_program: Gl.Uint,
    projection_matrix_id: Gl.Int,
    texture_sampler_id: Gl.Int,
    vbo_id: Gl.Uint,
    elements_id: Gl.Uint,
    ctx: *imgui.ImGuiContext,
    io: *imgui.ImGuiIO
};

pub const GlState = struct {
    blend: bool,
    cull_face: bool,
    depth_test: bool,
    scissor_test: bool
};

fn storeGlState() GlState
{
    return GlState{
        .blend = Gl.IsEnabled(c.GL_BLEND) > 0,
        .cull_face = Gl.IsEnabled(c.GL_CULL_FACE) > 0,
        .depth_test = Gl.IsEnabled(c.GL_DEPTH_TEST) > 0,
        .scissor_test = Gl.IsEnabled(c.GL_SCISSOR_TEST) > 0
    };
}

fn restoreGlState(state: GlState) void
{
    if (state.blend) Gl.Enable(c.GL_BLEND) else Gl.Disable(c.GL_BLEND);
    if (state.cull_face) Gl.Enable(c.GL_CULL_FACE) else Gl.Disable(c.GL_CULL_FACE);
    if (state.depth_test) Gl.Enable(c.GL_DEPTH_TEST) else Gl.Disable(c.GL_DEPTH_TEST);
    if (state.scissor_test) Gl.Enable(c.GL_SCISSOR_TEST) else Gl.Disable(c.GL_SCISSOR_TEST);
}

pub fn init() GuiState
{
    var imgui_ctx = imgui.igCreateContext(null);
    var imgui_io = imgui.igGetIO();
    // _ = imgui.ImFontAtlas_AddFontDefault(imgui_io.*.Fonts, null);
    // imgui_io.*.ConfigFlags |= imgui.ImGuiConfigFlags_DockingEnable;
    // imgui_io.*.ConfigFlags |= imgui.ImGuiConfigFlags_ViewportsEnable;
    imgui_io.*.BackendPlatformName = "imgui_impl_zig_graphics";

    const shader_program = Gl.compileShaders(imgui.VertexShaderSrc, imgui.FragmentShaderSrc);    
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

    // imgui_io.*.Fonts.*.TexID = @intToPtr(*anyopaque, imgui_tex_id);
    imgui.ImFontAtlas_SetTexID(imgui_io.*.Fonts, @intToPtr(*anyopaque, imgui_tex_id));

    return GuiState{
        .shader_program = shader_program,
        .projection_matrix_id = mvp_matrix_id,
        .texture_sampler_id = texture_sampler_id,
        .vbo_id = vbo_id,
        .elements_id = elements_id,
        .ctx = imgui_ctx,
        .io = imgui_io
    };
}

pub fn newFrame(state: GuiState, window: gfx.Window) void
{
    const window_w = @intToFloat(f32, window.width);
    const window_h = @intToFloat(f32, window.height);
    state.io.*.DisplaySize = imgui.ImVec2{
        .x = window_w, 
        .y = window_h
    };
    const framebuffer_size = window.getFramebufferSize();
    state.io.*.DisplayFramebufferScale = imgui.ImVec2{
        .x = @intToFloat(f32, framebuffer_size.w) / window_w,
        .y = @intToFloat(f32, framebuffer_size.h) / window_h
    };
    state.io.*.DeltaTime = @floatCast(f32, window.getDeltaTime());
    const mouse_pos = window.getMousePos();
    state.io.*.MousePos = imgui.ImVec2{.x = @floatCast(f32, mouse_pos.x), .y = @floatCast(f32, mouse_pos.y)};
    state.io.*.MouseDown[0] = window.isMouseDown(.left);
    state.io.*.MouseDown[1] = window.isMouseDown(.middle);
    state.io.*.MouseDown[2] = window.isMouseDown(.right);
    imgui.igNewFrame();
}

pub fn render(state: GuiState) void
{
    imgui.igRender();
    const draw_data = imgui.igGetDrawData().*;

    // Vertex Array Object.
    var vertex_array_id: Gl.Uint = 0;
    Gl.GenVertexArrays(1, &vertex_array_id);

    const gl_state_previous: GlState = storeGlState();
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
    restoreGlState(gl_state_previous);
}