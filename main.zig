const std = @import("std");
const builtin = @import("builtin");
const gfx = @import("src/gfx.zig");
const wasm = @import("src/wasm.zig");
const native_arch = builtin.target.cpu.arch;
pub const log_level: std.log.Level = .info;
const print = wasm.print;

var stderr_mutex = std.Thread.Mutex{};
pub fn log(comptime level: std.log.Level,
           comptime scope: @TypeOf(.EnumLiteral),
           comptime format: []const u8,
           args: anytype) void 
{
    _ = scope;
    const prefix = "[" ++ level.asText() ++ "] ";
    if (native_arch == .wasm32)
    {
        const allocator = std.heap.page_allocator;
        const str = std.fmt.allocPrint(allocator, prefix ++ format, args) catch unreachable;
        print(str);
        allocator.free(str);
    }
    else
    {
        stderr_mutex.lock();
        defer stderr_mutex.unlock();
        const stderr = std.io.getStdErr().writer();
        nosuspend stderr.print(prefix ++ format, args) catch return;
    }
}

pub fn panic(str: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    std.log.err("PANIC {s}", .{str});
    while(true) {
        @breakpoint();
    }
}

export fn wasmMain() void
{
    main();
}

pub fn main() void
{
    gfx.init() catch @panic("Failed to init GFX system.");
    defer gfx.deinit();

    const window = gfx.createWindow(600, 500, "Zig Graphics") catch |err| {
        std.log.err("Failed to make GFX window: {s}", .{err});
        @panic("GFX\n");
    };
    onInit(window);
    window.startEventLoop(onFrame);
    window.destroy();
}

pub fn onInit(window: gfx.Window) void
{
    // An array of 3 vectors which represents 3 vertices
    const triangle_buffer_data = [_]f32 {
        -1.0, -1.0, 0.0,
        1.0, -1.0, 0.0,
        0.0,  1.0, 0.0,
    };
    triangle_vbo = gfx.opengl.createVertexObject(triangle_buffer_data[0..], window.default_shaders);
}

const vm = gfx.vmath;
const V3 = vm.Vec3.init;
var camera_pos_initial = V3(0, 0, 5);
var camera_pos = V3(0, 0, 0);
var time: f32 = 0;
pub fn onFrame(_: gfx.Window) void
{
    const sin = std.math.sin;
    time += 0.01;
    camera_pos = camera_pos_initial.add(V3(0, 0, sin(time*0.3)*4));
    gfx.clear(1.0, 0.0, 0.0);
    drawTriangle(V3(-2, sin(time) * 3, 0));
    var depth: f32 = 0;
    while (depth < 10) : (depth += 1) {
        drawTriangle(V3(sin(time) * 4, 0, depth * 0.5));
    }
}

var triangle_vbo: gfx.opengl.VertexObject = undefined;
pub fn drawTriangle(model_pos: vm.Vec3) void
{
    const projection_mtx = vm.Mat4.initPerspectiveFovLh(90 * (std.math.pi/180.0), 600.0/500.0, 0.01, 200.0);
    const view_mtx = vm.Mat4.initLookAtLh(
        camera_pos, 
        V3(0, 0, 0),
        V3(0, 1, 0)
    );
    const identity = vm.Mat4.initIdentity();
    _ = identity;
    const model_mtx = vm.Mat4.initTranslation(model_pos);
    const mvp_mtx = model_mtx.mul(view_mtx).mul(projection_mtx);
    triangle_vbo.draw(mvp_mtx);
}