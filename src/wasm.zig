const std = @import("std");
const native_arch = @import("builtin").target.cpu.arch;

pub extern fn webInitCanvas() void;
pub extern fn webStartEventLoop(_: *const anyopaque) void;
pub extern fn jsPrint(msg: [*c]const u8, len: usize) void;
pub fn print(msg: []const u8) void {
    jsPrint(@ptrCast([*c]const u8, msg), msg.len);
}

const FreeBlock = struct {
    ptr: usize,
    size: usize
};
var free_list = std.ArrayList(FreeBlock).init(std.heap.page_allocator);

pub export fn memAlloc(size: usize) usize
{
    std.log.info("Allocating {d} bytes", .{size});
    var slice = std.heap.page_allocator.alloc(u8, size) catch @panic("Failed to allocate memory.");
    const ptr_idx = @ptrToInt(&slice[0]);
    free_list.append(FreeBlock{
        .ptr = ptr_idx,
        .size = size
    }) catch @panic("memAlloc: unable to append to free_list.");
    return ptr_idx;
}

pub export fn memFree(ptr_idx: usize) void
{
    for (free_list.items) |block, i| {
        if (block.ptr == ptr_idx) {
            std.log.info("Freeing {d} bytes", .{block.size});
            const ptr = @intToPtr([*]const u8, block.ptr);
            std.heap.page_allocator.free(ptr[0..block.size]);
            _ = free_list.swapRemove(i);
            break;
        }
    }
}