const std = @import("std");
const native_arch = @import("builtin").target.cpu.arch;

pub extern fn webInitCanvas() void;
pub extern fn webStartEventLoop(_: *const anyopaque) void;
pub extern fn jsPrint(msg: [*c]const u8, len: usize) void;
pub fn print(msg: []const u8) void {
    jsPrint(@ptrCast([*c]const u8, msg), msg.len);
}

pub export fn memAlloc(size: usize) [*c]u8
{
    std.log.info("Allocating {d} bytes", .{size});
    var slice = std.heap.page_allocator.alloc(u8, size) catch @panic("Failed to allocate memory.");
    return @ptrCast([*c]u8, slice);
}

pub export fn memFree(ptr: usize, size: usize) void
{
    var slice: []u8 = @intToPtr([*]u8, ptr)[0..size];
    std.heap.page_allocator.free(slice);
}