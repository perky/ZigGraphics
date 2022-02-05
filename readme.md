# Zig Graphics
A Zig library for creating OpenGL applications for both Desktop (windows, linux & mac) and web (WebAssembly with WebGL2).

## Building
If you have zig 0.9.x installed then simply call `zig build`.

The build command will make an executable for your host platform to `zig-out/bin/` and a web version to the `zig-out/web/` directory.
You can cross-compile to other platforms with the command `zig build -Dtarget=CPU-OS-ABI` with the CPU-OS-ABI triplet of your choice. 
Call `zig targets` for a list of available compilation targets on your host platform.

## Wasm Runtime
You can find the freestanding wasm runtime in `src/wasm_runtime`, feel free to use that for your own WebAssembly projects.