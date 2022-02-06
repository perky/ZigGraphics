//! Functions to communicate with the web browser.

/// TODO: document.
pub extern fn webStartEventLoop(*const anyopaque) void;

/// TODO: document.
pub extern fn webCanvasWidth() u32;

/// TODO: document.
pub extern fn webCanvasHeight() u32;

/// TODO: document.
pub extern fn webPrint(str: ?[*]const u8, len: usize) void;

pub extern fn webGetMouseX() f64;
pub extern fn webGetMouseY() f64;
pub extern fn webIsMouseLeftDown() bool;
pub extern fn webIsMouseRightDown() bool;
pub extern fn webIsMouseMiddleDown() bool;
pub extern fn webIsKeyDown(key_name: ?[*]const u8) bool;
pub extern fn webBreakpoint() void;

const std = @import("std");
pub fn log(comptime level: std.log.Level,
           comptime scope: @TypeOf(.EnumLiteral),
           comptime format: []const u8,
           args: anytype) void 
{
    const level_txt = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const allocator = std.heap.page_allocator;
    const str = std.fmt.allocPrint(allocator, level_txt ++ prefix2 ++ format, args) catch unreachable;
    webPrint(str.ptr, str.len);
    allocator.free(str);
}

pub fn panic(str: []const u8, _: ?*std.builtin.StackTrace) noreturn
{
    @setCold(true);
    std.log.err("{s}", .{str});
    while(true) {
        @breakpoint();
    }
}