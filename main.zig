const std = @import("std");
const builtin = @import("builtin");
const gfx = @import("zig_graphics").gfx;
const gui = @import("zig_graphics").gui;
const platform = @import("zig_graphics").platform;
const V3 = gfx.Vec3.init;

pub const os = platform.os;
pub const log = platform.log;
pub const panic = platform.panic;

const USE_IMGUI = true;
var window: gfx.Window = undefined;
var imgui_state: gui.GuiState = undefined;
var camera_pos = V3(0, 0, 1);
var time: f32 = 0;
var circle_color = gfx.LinearColor{ .r = 0.0, .g = 0.5, .b = 0.2 };

const Textures = struct {
    const gradient = gfx.LabeledData{ .name = "gradient", .data = @embedFile("assets/gradient.png")};
    const font = gfx.LabeledData{ .name = "font", .data = @embedFile("assets/spleen.png")};
};

pub fn main() void
{
    std.log.info("zig_graphics v0", .{});
    gfx.init() catch @panic("Failed to init GFX system.");
    defer gfx.deinit();

    window = gfx.createWindow(600, 500, "Zig Graphics", onInit, onFrame) catch |err| {
        std.log.err("Failed to make GFX window: {s}", .{err});
        @panic("GFX\n");
    };
    defer window.destroy();
    
    window.startEventLoop();
}


pub fn onInit() void
{
    if (USE_IMGUI)
    {
        imgui_state = gui.init();
    }
}

pub fn onFrame() void
{
    time += 0.01;
    window.clear(0.05, 0.05, 0.05);

    if (window.isKeyDown("h"))
    {
        circle_color.b += 0.02;
    }

    // TODO: assert camera_pos != look_at_pos.
    const view_persp_mtx = window.perspectiveViewMatrix(90, camera_pos, V3(0,0,0));
    const ortho_mtx = window.orthographicScreenMatrix();
    _ = view_persp_mtx;
    _ = ortho_mtx;

    var draw_cmds = gfx.DrawCommands.init(window, null);

    const rect_pos_01 = V3(220, 175, 0);
    const rect_rot_01 = gfx.Quat.init2DAngleDegrees(time*15.0);
    draw_cmds.rectangleGradient(.{
        .transform = .{
            .position = rect_pos_01,
            .scale = V3(100, 50, 1),
            .rotation = rect_rot_01
        },
        .top_left_color = .{ .r = 1, .g = 1, .b = 0, .a = 1 },
        .bot_left_color = .{ .r = 1, .g = 1, .b = 0, .a = 1 },
        .top_right_color = .{ .r = 0, .g = 1, .b = 1, .a = 1 },
        .bot_right_color = .{ .r = 0, .g = 1, .b = 1, .a = 1 },
    });

    draw_cmds.line(.{
        .start = V3(200, 200, 0),
        .end = V3(400, 100, 0),
        .color = .{ .g = 1 }
    });

    draw_cmds.circle(.{
        .transform = .{
            .position = V3(300, 300, 0)
        },
        .color = circle_color,
        .radius = 105
    });

    draw_cmds.sendToGpu(ortho_mtx);

    if (USE_IMGUI)
    {
        gui.newFrame(imgui_state, window);
        _ = gui.igBegin("Some Window", null, 0);
        gui.igText("Hello from a window!");
        if (gui.igSmallButton("Change colour"))
        {
            circle_color.r += 0.1;
        }
        gui.igEnd();
        gui.render(imgui_state);
    }
}