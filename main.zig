const std = @import("std");
const builtin = @import("builtin");
const gfx = @import("src/gfx.zig");
const platform = @import("src/platform.zig");
const V3 = gfx.Vec3.init;
const imgui = gfx.gl.imgui;

pub const os = platform.os;
pub const log = platform.log;
pub const panic = platform.panic;

var window: gfx.Window = undefined;
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
        imgui_state = gfx.gl.initImgui();
    }
}

const USE_IMGUI = true;

var imgui_state: gfx.gl.ImguiState = undefined;
var camera_pos = V3(0, 0, 1);
var time: f32 = 0;
var demo_window_open = true;
var show_another_window = true;
var circle_color = gfx.LinearColor{ .r = 0.0, .g = 0.5, .b = 0.2 };
pub fn onFrame() void
{
    time += 0.01;
    window.clear(0.05, 0.05, 0.05);

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
        const window_w = @intToFloat(f32, window.width);
        const window_h = @intToFloat(f32, window.height);
        imgui_state.io.*.DisplaySize = imgui.ImVec2{
            .x = window_w, 
            .y = window_h
        };
        const framebuffer_size = window.getFramebufferSize();
        imgui_state.io.*.DisplayFramebufferScale = imgui.ImVec2{
            .x = @intToFloat(f32, framebuffer_size.w) / window_w,
            .y = @intToFloat(f32, framebuffer_size.h) / window_h
        };
        imgui_state.io.*.DeltaTime = 1.0 / 60.0;
        const mouse_pos = window.getMousePos();
        imgui_state.io.*.MousePos = imgui.ImVec2{.x = @floatCast(f32, mouse_pos.x), .y = @floatCast(f32, mouse_pos.y)};
        imgui_state.io.*.MouseDown[0] = window.isLeftMouseDown();

        imgui.igNewFrame();

        _ = imgui.igBegin("Some Window", null, 0);
        imgui.igText("Hello from a window!");
        if (imgui.igSmallButton("Change colour"))
        {
            circle_color.r += 0.1;
        }
        imgui.igEnd();

        imgui.igRender();
        gfx.gl.renderImgui(imgui_state);
    }
}