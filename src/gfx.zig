const std = @import("std");
const wasm = @import("wasm.zig");
pub const vmath = @import("vectormath.zig");
pub const opengl = @import("opengl.zig");
const native_arch = @import("builtin").target.cpu.arch;
const USE_GLFW = (native_arch != .wasm32);
const glfw = if (USE_GLFW) @import("glfw") else result: {
    break :result struct {
        pub const Window = struct{};
    };
};
const vert_shader_source: []const u8 = @embedFile("../shader.vert");
const frag_shader_source: []const u8 = @embedFile("../shader.frag");

pub const Window = struct {
    const CharacterPressCallbackSignature = fn (_: Window, _: u8) void;
    const FrameLoopSignature = fn (_: Window) void;
    const Self = @This();
    
    glfwWindow: ?glfw.Window = null,
    default_shaders: opengl.ShaderProgram = undefined,

    pub fn init(self: *Self) void
    {
        const c = opengl.c;
        const gl = opengl.GlFunctions;

        if (USE_GLFW)
        {
            glfw.makeContextCurrent(self.glfwWindow.?) catch @panic("Failed to change GL context.");
            // opengl.linkGlFunctions(glfw.getProcAddress);
            const shader_version = gl.GetString(c.GL_SHADING_LANGUAGE_VERSION);
            std.log.info("shader version: {s}\n", .{shader_version});
        }
        var VertexArrayID: opengl.Uint = 0;
        gl.GenVertexArrays(1, &VertexArrayID);
        gl.BindVertexArray(VertexArrayID);
        self.default_shaders = opengl.createShaderProgram(vert_shader_source, frag_shader_source);
    }

    pub fn destroy(self: Self) void
    {
        if (USE_GLFW)
        {
            self.glfwWindow.?.destroy();
        }
    }

    pub fn setCharacterPressCallback(_: Self, _: CharacterPressCallbackSignature) void
    {
    }

    pub fn startEventLoop(self: Self, frame_fn: FrameLoopSignature) void
    {
        if (USE_GLFW)
        {
            glfw.swapInterval(1) catch @panic("Failed to change GL swap interval.");
            while (!self.glfwWindow.?.shouldClose())
            {
                frame_fn(self);
                self.glfwWindow.?.swapBuffers() catch @panic("Failed to GL swap buffers.");
                glfw.pollEvents() catch {
                    @panic("Failed to poll events.");
                };
            }
        }
        else
        {
            wasm.webStartEventLoop(frame_fn);
        }
    }
};

pub fn init() !void
{
    if (USE_GLFW)
    {
        try glfw.init(.{});
    }
}

pub fn deinit() void
{
    if (USE_GLFW)
    {
        glfw.terminate();
    }
}

pub fn createWindow(desiredWidth: u32, desiredHeight: u32, name: [*:0]const u8) !Window
{
    var window = Window{};
    if (USE_GLFW)
    {
        window.glfwWindow = try glfw.Window.create(desiredWidth, desiredHeight, name, null, null, .{
            .context_version_major = 3,
            .context_version_minor = 3,
            .opengl_forward_compat = true,
            .opengl_profile = .opengl_core_profile
        });
    }
    else
    {
        wasm.webInitCanvas();
    }

    window.init();
    return window;
}

pub fn clear(r: f32, g: f32, b: f32) void 
{
    const c = opengl.c;
    c.glClearColor(r, g, b, 1.0);
    c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
}