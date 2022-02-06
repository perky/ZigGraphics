const std = @import("std");
const glfw = @import("lib/mach-glfw/build.zig");
const imgui = @import("lib/imgui/build.zig");

pub fn pkgMake(comptime name: []const u8, comptime src: []const u8) std.build.Pkg
{
    return std.build.Pkg{.name = name, .path = .{.path = src}};
}

pub fn linkZigGraphics(b: *std.build.Builder, exe: *std.build.LibExeObjStep) void
{
    // Add packages.
    const imgui_pkg = pkgMake("imgui", "lib/imgui/imgui_entry.zig");
    const glfw_pkg = pkgMake("glfw", "lib/mach-glfw/src/main.zig");
    const ogl_runtime_pkg = pkgMake("opengl_bindings", "src/opengl_runtime.gen.zig");
    const ogl_static_pkg = pkgMake("opengl_bindings", "src/opengl_static.gen.zig");
    var zig_graphics_pkg = pkgMake("zig_graphics", "src/zig_graphics.zig");
    switch (exe.target.getOsTag()) {
        .windows, .linux => {
            zig_graphics_pkg.dependencies = &[_]std.build.Pkg{imgui_pkg, glfw_pkg, ogl_runtime_pkg};
            exe.addPackage(zig_graphics_pkg);
        },
        .macos, => {
            zig_graphics_pkg.dependencies = &[_]std.build.Pkg{imgui_pkg, glfw_pkg, ogl_static_pkg};
            exe.addPackage(zig_graphics_pkg);
        },
        .freestanding => {
            zig_graphics_pkg.dependencies = &[_]std.build.Pkg{imgui_pkg, ogl_static_pkg};
            exe.addPackage(zig_graphics_pkg);
        },
        else => @panic("unsupported target")
    }

    // Common settings.
    exe.addIncludeDir("include");
    exe.linkLibC();
    imgui.linkArtifact(b, exe, "lib/imgui");

    // Link GLFW.
    switch (exe.target.getOsTag()) {
        .windows, .linux, .macos => {
            glfw.link(b, exe, .{});
        },
        .freestanding => {},
        else => @panic("unsupported target")
    }

    // Link system libraries.
    switch (exe.target.getOsTag()) {
        .windows => {
            exe.linkSystemLibrary("opengl32");
        },
        .linux => {
            exe.linkSystemLibrary("GL");
        },
        .macos => {
            exe.linkFramework("OpenGL");
        },
        .freestanding => {},
        else => {
            @panic("Unsupported target");
        }
    }
}

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
    linkZigGraphics(b, exe);
    exe.install();
    b.getInstallStep().dependOn(&exe.step);

    // RUN DESKTOP
    const run_exe = exe.run();
    const run_exe_step = b.step("run", "Run the desktop executable");
    run_exe_step.dependOn(&run_exe.step);

    // WASM
    const web = b.addSharedLibrary("zig_graphics", "main.zig", .unversioned);
    web.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding
    });
    web.setBuildMode(mode);
    linkZigGraphics(b, web);
    web.setOutputDir("zig-out/web/");
    web.initial_memory = 65536 * 250;
    web.install();
    
    // WEB CONTENT
    const web_content = b.addInstallDirectory(
        .{ .source_dir = "src/wasm_runtime/web", .install_dir = .{ .custom = "web/" }, .install_subdir = "" },
    );
    web.step.dependOn(&web_content.step);

    const web_step = b.step("web", "Build and deploy WebAssembly version");
    web_step.dependOn(&web.step);
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