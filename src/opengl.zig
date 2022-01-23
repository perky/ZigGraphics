pub usingnamespace @import("opengl_externs.zig");
const std = @import("std");
const vmath = @import("vectormath.zig");
pub const c = @cImport({
    @cInclude("GL/gl.h");
    @cInclude("GL/glext.h");
});
const Gl = struct {
    usingnamespace @import("opengl_externs.zig");
    usingnamespace @import("opengl_externs.zig").Functions;
};
pub const GlFunctions = @import("opengl_bindings");

// NOTE: Maybe we don't need to runtime load the function pointers?
// For now, we don't.
pub const GetGlProcAddressSig = fn([*:0]const u8) callconv(.C) (?fn() callconv(.C) void);
pub fn linkGlFunctions(get_proc_fn: ?GetGlProcAddressSig) void
{
    inline for(@typeInfo(GlFunctions).Struct.decls) |decl| 
    {
        if (comptime std.mem.eql(u8, decl.name, "Gl") == false)
        {
            const proc_name = "gl" ++ decl.name ++ "\x00";
            const bare_proc = get_proc_fn.?(proc_name).?;
            const FnType = @TypeOf(@field(GlFunctions, decl.name));
            @field(GlFunctions, decl.name) = @ptrCast(FnType, bare_proc);
            std.log.info("linked {s} with signature {}\n", .{
                proc_name, FnType
            });
        }
    }
}

pub const ShaderProgram = struct {
    program_id: Gl.Uint,
    mvp_matrix_uniform_id: Gl.Int,
};
pub fn createShaderProgram(vert_shader_src: []const u8, frag_shader_src: []const u8) ShaderProgram
{
    const gl = GlFunctions;
    var compile_result: Gl.Int = c.GL_FALSE;
    var info_log_length: Gl.Int = 0;

    const vert_shader = gl.CreateShader(c.GL_VERTEX_SHADER);
    gl.ShaderSource(vert_shader, 1, &@ptrCast([*c]const u8, vert_shader_src), null);
    gl.CompileShader(vert_shader);

    // Check Vertex Shader
    gl.GetShaderiv(vert_shader, c.GL_COMPILE_STATUS, &compile_result);
    gl.GetShaderiv(vert_shader, c.GL_INFO_LOG_LENGTH, &info_log_length);
    if ( info_log_length > 0 ){
        var err_msg = std.heap.page_allocator.alloc(u8, @intCast(u32, info_log_length) + 1) catch @panic("Failed to alloc");
        defer std.heap.page_allocator.free(err_msg);
        gl.GetShaderInfoLog(vert_shader, @intCast(u32, info_log_length), null, @ptrCast(Gl.String, err_msg));
        std.log.err("OpenGL {s}\n", .{err_msg});
    }
    
    const frag_shader = gl.CreateShader(c.GL_FRAGMENT_SHADER);
    gl.ShaderSource(frag_shader, 1, &@ptrCast([*c]const u8, frag_shader_src), null);
    gl.CompileShader(frag_shader);

    // Check Frag Shader
    gl.GetShaderiv(frag_shader, c.GL_COMPILE_STATUS, &compile_result);
    gl.GetShaderiv(frag_shader, c.GL_INFO_LOG_LENGTH, &info_log_length);
    if ( info_log_length > 0 ){
        var err_msg = std.heap.page_allocator.alloc(u8, @intCast(u32, info_log_length)) catch @panic("Failed to alloc");
        defer std.heap.page_allocator.free(err_msg);
        gl.GetShaderInfoLog(frag_shader, @intCast(u32, info_log_length), null, @ptrCast(Gl.String, err_msg));
        std.log.err("OpenGL {s}\n", .{err_msg});
    }

    // Link the program
    const shader_program = gl.CreateProgram();
    gl.AttachShader(shader_program, vert_shader);
    gl.AttachShader(shader_program, frag_shader);
    gl.LinkProgram(shader_program);

    // Check the program
    gl.GetProgramiv(shader_program, c.GL_LINK_STATUS, &compile_result);
    gl.GetProgramiv(shader_program, c.GL_INFO_LOG_LENGTH, &info_log_length);
    if (info_log_length > 0)
    {
        var err_msg = std.heap.page_allocator.alloc(u8, @intCast(u32, info_log_length)) catch @panic("Failed to alloc");
        defer std.heap.page_allocator.free(err_msg);
        gl.GetProgramInfoLog(shader_program, @intCast(u32, info_log_length), null, @ptrCast(Gl.String, err_msg));
        std.log.err("OpenGL {s}", .{err_msg});
    }

    const mvp_matrix_id = gl.GetUniformLocation(shader_program, "MVP");

    return ShaderProgram{
        .program_id = shader_program,
        .mvp_matrix_uniform_id = mvp_matrix_id
    };
}

pub const VertexObject = struct {
    buffer_id: Gl.Uint,
    shader_program: ShaderProgram = undefined,

    pub fn draw(self: VertexObject, matrix: vmath.Mat4) void
    {
        const gl = GlFunctions;
        gl.UseProgram(self.shader_program.program_id);
        const transpose_matrix_to_column_major = c.GL_FALSE;
        gl.UniformMatrix4fv(
            self.shader_program.mvp_matrix_uniform_id, // Uniform ID
            1,                                         // count
            transpose_matrix_to_column_major,          // transpose?
            matrix.rawPtr()                            // ptr to matrix data
        );
        // 1st attribute buffer : vertices
        gl.EnableVertexAttribArray(0);
        gl.BindBuffer(c.GL_ARRAY_BUFFER, self.buffer_id);
        gl.VertexAttribPointer(
            0,                      // attribute 0. No particular reason for 0, but must match the layout in the shader.
            3,                      // size
            c.GL_FLOAT,             // type
            c.GL_FALSE,             // normalized?
            0,                      // stride
            null                    // array buffer offset
        );
        // Draw the triangle !
        gl.DrawArrays(c.GL_TRIANGLES, 0, 3); // Starting from vertex 0; 3 vertices total -> 1 triangle
        gl.DisableVertexAttribArray(0);
    }
};
pub fn createVertexObject(vertices: []const f32, shader_program: ShaderProgram) VertexObject
{
    const gl = GlFunctions;
    const size = vertices.len * @sizeOf(@TypeOf(vertices[0])); 
    var buffer: Gl.Uint = 0;
    // Generate 1 buffer, put the resulting identifier in vertexbuffer
    gl.GenBuffers(1, &buffer);
    // The following commands will talk about our 'vertexbuffer' buffer
    gl.BindBuffer(c.GL_ARRAY_BUFFER, buffer);
    // Give our vertices to OpenGL.
    gl.BufferData(c.GL_ARRAY_BUFFER, @intCast(u32, size), &vertices[0], c.GL_STATIC_DRAW);

    return VertexObject{
        .buffer_id = buffer,
        .shader_program = shader_program
    };
}