const std = @import("std");
const glfw = @import("lib/mach-glfw/build.zig");

pub fn build(b: *std.build.Builder) void
{
    const mode = b.standardReleaseOptions();

    writeOpenGlBindings("src/opengl_static.gen.zig", true) catch @panic("Failed to write file.");
    writeOpenGlBindings("src/opengl_runtime.gen.zig", false) catch @panic("Failed to write file.");
    
    // DESKTOP
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable("zig_graphics", "main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.addPackagePath("glfw", "lib/mach-glfw/src/main.zig");
    exe.addPackagePath("opengl_bindings", "src/opengl_runtime.gen.zig");
    exe.addIncludeDir("include/");
    switch (target.getOsTag()) {
        .windows => {
            exe.linkSystemLibrary("opengl32");
        },
        .linux => {
            exe.linkSystemLibrary("GL");
        },
        .macos => {
            exe.linkFramework("OpenGL");
        },
        else => {
            @panic("Unsupported os.");
        }
    }
    exe.install();
    glfw.link(b, exe, .{});
    b.getInstallStep().dependOn(&exe.step);

    // WASM
    const web = b.addSharedLibrary("zig_graphics_web", "main.zig", .unversioned);
    web.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding
    });
    web.setBuildMode(mode);
    web.linkLibC();
    web.addPackagePath("opengl_bindings", "src/opengl_static.gen.zig");
    web.addIncludeDir("include");
    web.setOutputDir("docs/");
    web.initial_memory = 65536 * 250;
    web.install();
    b.getInstallStep().dependOn(&web.step);
}

pub fn writeOpenGlBindings(output_filename: []const u8, write_externs: bool) !void
{
    const GlTypes = @import("src/opengl_types.zig");
    const in_file = try std.fs.cwd().openFile(
        "src/opengl_bindings.txt",
        .{ .read = true },
    );
    defer in_file.close();
    
    const out_file = try std.fs.cwd().createFile(
        output_filename,
        .{ .read = true },
    );
    defer out_file.close();

    // _ = try out_file.write("pub usingnamespace @import(\"opengl_types.zig\");\n");
    inline for (@typeInfo(GlTypes).Struct.decls) |decl|
    {
        _ = try out_file.write("pub const ");
        _ = try out_file.write(decl.name);
        _ = try out_file.write(" = ");
        _ = try out_file.write(@typeName(decl.data.Type));
        _ = try out_file.write(";\n");
    }

    var buf: [1024]u8 = undefined;
    if (write_externs)
    {
        while(try in_file.reader().readUntilDelimiterOrEof(&buf, '\n')) |line|
        {
            _ = try out_file.write("pub extern fn ");
            _ = try out_file.write(line);
            _ = try out_file.write("\n");
        }
        try in_file.seekTo(0);
    }
    while(try in_file.reader().readUntilDelimiterOrEof(&buf, '\n')) |line|
    {
        var sig_start: u32 = 0;
        while (sig_start < line.len) : (sig_start += 1) {
            if (line[sig_start] == '(') {
                break;
            }
        }
        var sig_end: u32 = sig_start;
        while (sig_end < line.len) : (sig_end += 1) {
            if (line[sig_end] == ';') {
                break;
            }
        }
        const name = line[0..sig_start];
        var short_name: [1024]u8 = undefined;
        const short_name_size = std.mem.replacementSize(u8, name, "gl", "");
        _ = std.mem.replace(u8, name, "gl", "", short_name[0..]);
        _ = try out_file.write("pub var ");
        _ = try out_file.write(short_name[0..short_name_size]);
        if (write_externs)
        {
            _ = try out_file.write(" = ");
            _ = try out_file.write(name);
            _ = try out_file.write(";");
        }
        else
        {
            _ = try out_file.write(": fn");
            _ = try out_file.write(line[sig_start..sig_end]);
            _ = try out_file.write(" = undefined;");
        }
        _ = try out_file.write("\n");
    }
}