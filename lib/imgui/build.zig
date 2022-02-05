const builtin = @import("builtin");
const std = @import("std");
const Builder = std.build.Builder;

pub fn linkArtifact(b: *Builder, exe: *std.build.LibExeObjStep, os: std.Target.Os.Tag, comptime prefix_path: []const u8) void
{
    exe.linkLibC();
    switch (os)
    {
        .macos => {
            const frameworks_dir = macosFrameworksDir(b) catch unreachable;
            exe.addFrameworkDir(frameworks_dir);
            exe.linkFramework("Foundation");
            exe.linkSystemLibrary("c++");
        },
        .windows => {
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("c++");
        },
        .linux => {
            exe.linkSystemLibrary("c++");
            exe.linkSystemLibrary("X11");
        },
        .freestanding => {},
        else => @panic("OS not supported.")
    }

    const freestanding_arg = if (os == .freestanding) "-DIS_OS_FREESTANDING" else "";

    exe.addIncludeDir(prefix_path ++ "");
    const cpp_args = [_][]const u8{
        "-Wno-return-type-c-linkage",
        freestanding_arg
    };
    exe.addCSourceFile(prefix_path ++ "/imgui.cpp", &cpp_args);
    exe.addCSourceFile(prefix_path ++ "/imgui_demo.cpp", &cpp_args);
    exe.addCSourceFile(prefix_path ++ "/imgui_draw.cpp", &cpp_args);
    exe.addCSourceFile(prefix_path ++ "/imgui_widgets.cpp", &cpp_args);
    exe.addCSourceFile(prefix_path ++ "/imgui_tables.cpp", &cpp_args);
    exe.addCSourceFile(prefix_path ++ "/cimgui.cpp", &cpp_args);
    exe.addCSourceFile(prefix_path ++ "/temporary_hacks.cpp", &cpp_args);
    exe.addPackagePath("imgui", prefix_path ++ "/imgui_entry.zig");
}

// helper function to get SDK path on Mac
fn macosFrameworksDir(b: *Builder) ![]u8 {
    var str = try b.exec(&[_][]const u8{ "xcrun", "--show-sdk-path" });
    const strip_newline = std.mem.lastIndexOf(u8, str, "\n");
    if (strip_newline) |index| {
        str = str[0..index];
    }
    const frameworks_dir = try std.mem.concat(b.allocator, u8, &[_][]const u8{ str, "/System/Library/Frameworks" });
    return frameworks_dir;
}
