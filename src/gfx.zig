const std = @import("std");
const platform = @import("platform.zig");
pub const vmath = @import("vectormath.zig");
pub const gl = @import("opengl.zig");
const glfw = if (platform.IS_DESKTOP) @import("glfw") else result: {
    break :result struct {
        pub const Window = struct{};
    };
};
const vert_shader_source: []const u8 = @embedFile("../shader.vert");
const frag_shader_source: []const u8 = @embedFile("../shader.frag");
const default_allocator = std.heap.page_allocator;

pub const Texture = gl.Texture;
pub const LabeledData = gl.LabeledData;
pub const VertexObject = gl.VertexObject;
pub const ShaderProgram = gl.ShaderProgram;
pub const Mat4 = vmath.Mat4;
pub const Vec2 = vmath.Vec2;
pub const Vec3 = vmath.Vec3;
pub const Vec4 = vmath.Vec4;
pub const Quat = vmath.Quat;

pub fn init() !void
{
    if (platform.IS_DESKTOP)
    {
        try glfw.init(.{});
    }
}

pub fn deinit() void
{
    if (platform.IS_DESKTOP)
    {
        glfw.terminate();
    }
}

pub const MouseButton = enum {
    left, middle, right
};

pub fn createWindow(desiredWidth: u32, desiredHeight: u32, name: [*:0]const u8, 
    on_init_fn: Window.CallbackSignature, on_frame_fn: Window.CallbackSignature) !Window
{
    var window = Window{
        .width = desiredWidth,
        .height = desiredHeight,
        .on_init_fn = on_init_fn,
        .on_frame_fn = on_frame_fn
    };

    if (platform.IS_DESKTOP)
    {
        window.glfw_window = try glfw.Window.create(desiredWidth, desiredHeight, name, null, null, .{
            .samples = 1,
            .context_version_major = 3,
            .context_version_minor = 3,
            .opengl_forward_compat = true,
            .opengl_profile = .opengl_core_profile
        });
    }
    else if (platform.IS_WEB)
    {
        window.width = platform.web.webCanvasWidth();
        window.height = platform.web.webCanvasHeight();
    }

    window.init();
    on_init_fn();
    return window;
}

pub const Window = struct {
    const CharacterPressCallbackSignature = fn (_: Window, _: u8) void;
    const CallbackSignature = fn() void;
    const Self = @This();
    
    width: u32,
    height: u32,
    glfw_window: ?glfw.Window = null,
    default_shaders: ShaderProgram = undefined,
    default_vertex_object: VertexObject = undefined,
    default_vertex_lines_object: VertexObject = undefined,
    default_vertex_array_id: gl.Uint = 0,
    on_init_fn: CallbackSignature,
    on_frame_fn: CallbackSignature,
    last_frame_time: f64 = 0.0,
    frames_per_second_limit: f64 = 60.0,
    delta_frame_time: f64 = 0.0,

    pub fn init(self: *Self) void
    {
        if (platform.IS_DESKTOP)
        {
            glfw.makeContextCurrent(self.glfw_window.?) catch @panic("Failed to change GL context.");
            if (platform.OS != .macos) {
                gl.linkGlFunctions(glfw.getProcAddress);
            }
            const shader_version = gl.getShaderVersion();
            std.log.info("shader version: {s}\n", .{shader_version});
        }

        // Vertex Array Object.
        var vertex_array_id: gl.Uint = 0;
        gl.GenVertexArrays(1, &vertex_array_id);
        gl.BindVertexArray(vertex_array_id);
        self.default_vertex_array_id = vertex_array_id;

        // Default shaders.
        self.default_shaders = gl.createShaderProgram(vert_shader_source, frag_shader_source);
        _ = gl.setActiveShaderProgram(self.default_shaders);

        // Default texture.
        const default_tex = Texture.init1by1();
        const default_tex_id = default_tex.sendToGpu();
        std.log.info("default tex id: {d}", .{default_tex_id});

        // Triangles buffer.
        self.default_vertex_object = VertexObject.init(
            &[1]f32{0}, &[1]f32{0}, &[1]f32{0},
            null, self.default_shaders,
            Mat4.initIdentity(),
            .triangles
        );
        self.default_vertex_object.texture_id = default_tex_id;
        
        // Lines buffer.
        self.default_vertex_lines_object = VertexObject.init(
            &[1]f32{0}, null, &[1]f32{0},
            null, self.default_shaders,
            Mat4.initIdentity(),
            .lines
        );
        self.default_vertex_lines_object.texture_id = default_tex_id;
    }

    pub fn destroy(self: Self) void
    {
        if (platform.IS_DESKTOP)
        {
            self.glfw_window.?.destroy();
        }
    }

    pub fn setCharacterPressCallback(_: Self, _: CharacterPressCallbackSignature) void
    {
    }

    pub fn startEventLoop(self: *Self) void
    {
        if (platform.IS_DESKTOP)
        {
            glfw.swapInterval(1) catch @panic("Failed to change GL swap interval.");
            while (!self.glfw_window.?.shouldClose())
            {
                const now_time: f64 = glfw.getTime();
                const dt: f64 = now_time - self.last_frame_time;
                if (dt >= (1.0/self.frames_per_second_limit))
                {
                    self.delta_frame_time = dt;
                    self.on_frame_fn();
                    self.glfw_window.?.swapBuffers() catch @panic("Failed to GL swap buffers.");
                    glfw.pollEvents() catch {
                        @panic("Failed to poll events.");
                    };
                    self.last_frame_time = now_time;
                }
            }
        }
        else
        {
            platform.web.webStartEventLoop(self.on_frame_fn);
        }
    }

    pub fn getMousePos(self: Self) struct{x:f64, y:f64}
    {
        if (platform.IS_DESKTOP)
        {
            const pos = self.glfw_window.?.getCursorPos() catch @panic("TODO");
            return .{.x = pos.xpos, .y = pos.ypos};
        }
        else if (platform.IS_WEB)
        {
            return .{
                .x = platform.web.webGetMouseX(),
                .y = platform.web.webGetMouseY()
            };
        }
        @panic("unsupported platform");
    }

    pub fn isMouseDown(self: Self, mouse_button: MouseButton) bool
    {
        if (platform.IS_DESKTOP)
        {
            const action = switch (mouse_button) {
                .left => self.glfw_window.?.getMouseButton(.left),
                .right => self.glfw_window.?.getMouseButton(.right),
                .middle => self.glfw_window.?.getMouseButton(.middle)
            };
            return (action == .press);
        }
        else if (platform.IS_WEB)
        {
            return switch (mouse_button) {
                .left => platform.web.webIsMouseLeftDown(),
                .right => platform.web.webIsMouseRightDown(),
                .middle => platform.web.webIsMouseMiddleDown()
            };
        }
        @panic("unsupported platform");
    }

    pub fn isKeyDown(self: Self, comptime key_name: []const u8) bool
    {
        if (platform.IS_DESKTOP)
        {
            const key = std.enums.nameCast(glfw.Key, key_name);
            const action = self.glfw_window.?.getKey(key);
            return (action == .press);
        }
        else if (platform.IS_WEB)
        {
            return platform.web.webIsKeyDown(key_name.ptr);
        }
        @panic("unsupported platform");
    }

    pub fn getDeltaTime(self: Self) f64
    {
        if (platform.IS_DESKTOP)
        {
            return self.delta_frame_time;
        }
        else if (platform.IS_WEB)
        {
            return 1.0 / 60.0;
        }
        @panic("unsupported platform");
    }

    pub fn getFramebufferSize(self: Self) struct{w:u32, h:u32}
    {
        if (platform.IS_DESKTOP)
        {
            const size = self.glfw_window.?.getFramebufferSize() catch @panic("Failed to get GLFW framebuffer size.");
            return .{.w = size.width, .h = size.height};
        }
        else if (platform.IS_WEB)
        {
            return .{.w = self.width, .h = self.height};
        }
        @panic("unsupported platform");
    }

    pub fn clear(_: Self, r: f32, g: f32, b: f32) void 
    {
        gl.clear(r, g, b);
    }

    pub fn perspectiveViewMatrix(self: Self, fovy_degrees: f32, camera_pos: Vec3, camera_look_at: Vec3) Mat4
    {
        const screen_w = @intToFloat(f32, self.width);
        const screen_h = @intToFloat(f32, self.height);
        const projection_mtx = Mat4.initPerspectiveFovLh(
            fovy_degrees * (std.math.pi/180.0), 
            screen_w/screen_h, 
            0.01, 
            200.0
        );
        const view_mtx = Mat4.initLookAtLh(
            camera_pos, 
            camera_look_at,
            Vec3.init(0, 1, 0)
        );
        return view_mtx.mul(projection_mtx);   
    }

    pub fn orthographicScreenMatrix(self: Self) Mat4
    {
        const screen_w = @intToFloat(f32, self.width);
        const screen_h = @intToFloat(f32, self.height);
        const ortho_mtx = Mat4.initOrthoOffCenterLh(
            0,
            screen_w,
            screen_h,
            0,
            0.0,
            1.0
        );
        return ortho_mtx;
    }
};

const square_buffer_data = [_]f32 {
    -1.0, -1.0, 0.0,
    1.0, -1.0, 0.0,
    -1.0,  1.0, 0.0,
    -1.0,  1.0, 0.0,
    1.0, -1.0, 0.0,
    1.0,  1.0, 0.0
};
const square_uv_data = [_]f32 {
    0.0, 0.0,
    1.0, 0.0,
    0.0, 1.0,
    0.0, 1.0,
    1.0, 0.0,
    1.0, 1.0
};
const square_color_data = [_]f32 {1.0} ** 24;

pub const Transform = struct {
    position: Vec3 = Vec3.init(0,0,0),
    scale: Vec3 = Vec3.init(1,1,1),
    rotation: Quat = Quat.initIdentity()
};

pub const LinearColor = struct {
    const white = LinearColor{.r = 1, .g = 1, .b = 1, .a = 1};
    r: f32 = 0, g: f32 = 0, b: f32 = 0, a: f32 = 1
};

const DrawCommandKind = enum {
    rectangle,
    line,
    circle
};

const RectangleInfo = struct {
    origin: Vec3 = Vec3.init(0,0,0)
};

const LineInfo = struct {
    start: Vec3,
    end: Vec3
};

const CircleInfo = struct {
    radius: f32,
    angle_degrees_start: f32 = 0,
    angle_degrees_end: f32 = 360
};

const DrawCommandInfo = struct {
    // required:
    kind: union(DrawCommandKind) {
        rectangle: RectangleInfo,
        line: LineInfo,
        circle: CircleInfo
    },
    transform: Transform,
    color: LinearColor = LinearColor{},

    // optionals:
    vertex_colors: ?[]const LinearColor = null,
    texture_id: gl.Uint = 0,
    texture_coords: ?[]const f32 = null
};

pub const DrawCommands = struct {
    commands: std.ArrayList(DrawCommandInfo),
    vertex_object: VertexObject,
    vertex_lines_object: VertexObject,
    memory_arena: std.heap.ArenaAllocator,
    screen_width: f32,
    screen_height: f32,
    vertex_array_id: gl.Uint,
    is_flushed: bool = false,

    pub fn init(window: Window, allocator: ?std.mem.Allocator) DrawCommands
    {
        var mem_arena = std.heap.ArenaAllocator.init(allocator orelse default_allocator);
        var wrapped_allocator = mem_arena.allocator();
        var commands = std.ArrayList(DrawCommandInfo).initCapacity(wrapped_allocator, 100) 
            catch @panic("Failed to init DrawCommandInfo array.");
        var result = DrawCommands{
            .commands = commands,
            .memory_arena = mem_arena,
            .vertex_object = window.default_vertex_object,
            .vertex_lines_object = window.default_vertex_lines_object,
            .vertex_array_id = window.default_vertex_array_id,
            .screen_width = @intToFloat(f32, window.width),
            .screen_height = @intToFloat(f32, window.height)
        };
        return result;
    }

    fn appendCommand(self: *DrawCommands, cmd: *const DrawCommandInfo) void
    {
        self.commands.append(cmd.*) catch {
            @panic("Failed to append draw command.");
        };
    }

    fn makeUvBuffer(comptime size: usize) [size*2]f32
    {
        const elem_count = 2;
        var result = [_]f32{0} ** (size*elem_count);
        return result;
    }

    fn makeColorBuffer(comptime size: usize, main_color: LinearColor, maybe_vertex_colors: ?[]const LinearColor) [size*4]f32
    {
        const elem_count = 4;
        var result: [size*elem_count]f32 = [_]f32 {0} ** (size*elem_count);
        var i: usize = 0;
        if (maybe_vertex_colors) |vertex_colors| {
            while (i < size*elem_count) : (i += elem_count) {
                result[i+0] = main_color.r * vertex_colors[i/elem_count].r;
                result[i+1] = main_color.g * vertex_colors[i/elem_count].g;
                result[i+2] = main_color.b * vertex_colors[i/elem_count].b;
                result[i+3] = main_color.a * vertex_colors[i/elem_count].a;
            }
        } else {
            while (i < size*elem_count) : (i += elem_count) {
                result[i+0] = main_color.r;
                result[i+1] = main_color.g;
                result[i+2] = main_color.b;
                result[i+3] = main_color.a;
            }
        }
        return result;
    }

    fn allocArray(self: *DrawCommands, comptime size: usize, comptime data_type: type) *[size]data_type
    {
        return self.memory_arena.allocator().create([size]data_type) catch @panic("Failed to alloc array.");
    }

    fn appendSlice(comptime data_type: type, list: *std.ArrayList(data_type), data: []const data_type) void
    {
        list.appendSlice(data) catch @panic("Failed to append data to ArrayList");
    }

    pub fn sendToGpu(self: *DrawCommands, camera_matrix: Mat4) void
    {
        if (self.is_flushed) {
            @panic("Already flushed DrawCommands, construct a new one.");
        }
        self.is_flushed = true;

        const allocator = self.memory_arena.allocator();
        var vertex_data = std.ArrayList(f32).init(allocator);
        var uv_data = std.ArrayList(f32).init(allocator);
        var color_data = std.ArrayList(f32).init(allocator);
        var vertex_lines_data = std.ArrayList(f32).init(allocator);
        var color_lines_data = std.ArrayList(f32).init(allocator);
        
        for (self.commands.items) |cmd| {
            const scale = Mat4.initScaling(cmd.transform.scale);
            const rotation = Mat4.initRotationQuat(cmd.transform.rotation);
            const translate = Mat4.initTranslation(cmd.transform.position);
            const model_mtx = scale.mul(rotation).mul(translate);

            switch (cmd.kind) {
                .line => |line_info| {
                    const start = line_info.start.transform(model_mtx);
                    const end = line_info.end.transform(model_mtx);
                    var vertices = [_]f32{
                        start.c[0],
                        start.c[1],
                        start.c[2],
                        end.c[0],
                        end.c[1],
                        end.c[2]
                    };
                    appendSlice(f32, &vertex_lines_data, vertices[0..]);
                    var colors = makeColorBuffer(2, cmd.color, cmd.vertex_colors);
                    appendSlice(f32, &color_lines_data, colors[0..]);
                },
                .rectangle => {
                    const half_scale = cmd.transform.scale.scale(0.5);
                    const half_scale_mtx = Mat4.initScaling(half_scale);
                    const pre_translate = Mat4.initTranslation(half_scale);
                    const rect_model_mtx = half_scale_mtx.mul(pre_translate).mul(rotation).mul(translate);
                    var vertices = [_]f32{0} ** (6*3);
                    {
                        var i: usize = 0;
                        while(i < 6*3) : (i += 3) {
                            const vec = Vec3.init(
                                square_buffer_data[i+0],
                                square_buffer_data[i+1],
                                square_buffer_data[i+2]
                            );
                            const tvec = vec.transform(rect_model_mtx);
                            vertices[i+0] = tvec.c[0];
                            vertices[i+1] = tvec.c[1];
                            vertices[i+2] = tvec.c[2];
                        }
                    }
                    appendSlice(f32, &vertex_data, vertices[0..]);
                    const uv_slice = cmd.texture_coords orelse square_uv_data[0..];
                    appendSlice(f32, &uv_data, uv_slice);
                    var colors = makeColorBuffer(6, cmd.color, cmd.vertex_colors);
                    appendSlice(f32, &color_data, colors[0..]);
                },
                .circle => |circle_info| {
                    const num_vertices = 360*3;
                    const num_vert_elems = num_vertices * 3;
                    var vertices = [_]f32{0} ** num_vert_elems;
                    var i: usize = 0;
                    const sin = std.math.sin;
                    const cos = std.math.cos;
                    const origin = Vec3.init(0,0,0).transform(model_mtx);
                    while(i < num_vert_elems) : (i += 9) {
                        const theta0 = @intToFloat(f32, i/9) * std.math.pi / 180.0;
                        var p0 = Vec3.init(sin(theta0) * circle_info.radius, cos(theta0) * circle_info.radius, 0);
                        p0 = p0.transform(model_mtx);
                        const theta1 = @intToFloat(f32, (i/9) + 1) * std.math.pi / 180.0;
                        var p1 = Vec3.init(sin(theta1) * circle_info.radius, cos(theta1) * circle_info.radius, 0);
                        p1 = p1.transform(model_mtx);
                        vertices[i+0] = p0.c[0];
                        vertices[i+1] = p0.c[1];
                        vertices[i+2] = p0.c[2];

                        vertices[i+3] = p1.c[0];
                        vertices[i+4] = p1.c[1];
                        vertices[i+5] = p1.c[2];

                        vertices[i+6] = origin.c[0];
                        vertices[i+7] = origin.c[1];
                        vertices[i+8] = origin.c[2];
                    }
                    appendSlice(f32, &vertex_data, vertices[0..]);
                    var uvs = makeUvBuffer(num_vertices);
                    appendSlice(f32, &uv_data, uvs[0..]);
                    var colors = makeColorBuffer(num_vertices, cmd.color, cmd.vertex_colors);
                    appendSlice(f32, &color_data, colors[0..]);
                }
            }
        }

        gl.BindVertexArray(self.vertex_array_id);
        self.vertex_object.updateVertexBuffer(vertex_data.items);
        self.vertex_object.updateUvBuffer(uv_data.items);
        self.vertex_object.updateColorBuffer(color_data.items);
        self.vertex_object.draw(camera_matrix);

        self.vertex_lines_object.updateVertexBuffer(vertex_lines_data.items);
        self.vertex_lines_object.updateColorBuffer(color_lines_data.items);
        self.vertex_lines_object.draw(camera_matrix);

        self.memory_arena.deinit();
    }

    pub fn rectangle(self: *DrawCommands, params: struct{
        transform: Transform = Transform{},
        color: LinearColor = LinearColor{},
        vertex_colors: ?[]const LinearColor = null,
        texture: gl.Uint = 0,
        texture_coords: ?[]const f32 = null,
        origin: Vec3 = Vec3.init(0, 0, 0)
    }) void
    {
        const cmd = DrawCommandInfo{
            .kind = .{ .rectangle = RectangleInfo{ .origin = params.origin } },
            .transform = params.transform,
            .color = params.color,
            .vertex_colors = params.vertex_colors,
            .texture_id = params.texture,
            .texture_coords = params.texture_coords
        };
        self.appendCommand(&cmd);
    }

    pub fn rectangleGradient(self: *DrawCommands, params: struct{
        transform: Transform = Transform{},
        origin: Vec3 = Vec3.init(0, 0, 0),
        top_left_color: LinearColor = LinearColor{},
        top_right_color: LinearColor = LinearColor{},
        bot_left_color: LinearColor = LinearColor{},
        bot_right_color: LinearColor = LinearColor{},
    }) void
    {
        var gradient_colors = self.allocArray(6, LinearColor);
        gradient_colors[0] = params.top_left_color;
        gradient_colors[1] = params.top_right_color;
        gradient_colors[2] = params.bot_left_color;
        gradient_colors[3] = params.bot_left_color;
        gradient_colors[4] = params.top_right_color;
        gradient_colors[5] = params.bot_right_color;

        const cmd = DrawCommandInfo{
            .kind = .{ .rectangle = RectangleInfo{ .origin = params.origin } },
            .transform = params.transform,
            .color = LinearColor{ .r = 1, .g = 1, .b = 1, .a = 1},
            .vertex_colors = gradient_colors
        };
        self.appendCommand(&cmd);
    }

    pub fn line(self: *DrawCommands, params: struct{
        transform: Transform = Transform{},
        color: LinearColor = LinearColor{},
        vertex_colors: ?[]const LinearColor = null,
        start: Vec3,
        end: Vec3
    }) void
    {
        const cmd = DrawCommandInfo{
            .kind = .{ .line = LineInfo{.start = params.start, .end = params.end} },
            .transform = params.transform,
            .vertex_colors = params.vertex_colors,
            .color = params.color
        };
        self.appendCommand(&cmd);
    }

    pub fn lineGradient(self: *DrawCommands, params: struct{
        transform: Transform = Transform{},
        start: Vec3,
        end: Vec3,
        start_color: LinearColor,
        end_color: LinearColor,
    }) void
    {
        var gradient_colors = self.allocArray(2, LinearColor);
        gradient_colors[0] = params.start_color;
        gradient_colors[1] = params.end_color;
        const cmd = DrawCommandInfo{
            .kind = .{ .line = LineInfo{.start = params.start, .end = params.end} },
            .transform = params.transform,
            .color = LinearColor.white,
            .vertex_colors = gradient_colors,
        };
        self.appendCommand(&cmd);
    }

    pub fn circle(self: *DrawCommands, params: struct{
        transform: Transform = Transform{},
        color: LinearColor = LinearColor{},
        vertex_colors: ?[]const LinearColor = null,
        radius: f32,
    }) void
    {
        const cmd = DrawCommandInfo{
            .kind = .{ .circle = CircleInfo{.radius = params.radius} },
            .transform = params.transform,
            .vertex_colors = params.vertex_colors,
            .color = params.color
        };
        self.appendCommand(&cmd);
    }
};
