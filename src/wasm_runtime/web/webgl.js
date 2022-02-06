import { writeNumberToPtr, writeStringToPtr, readCString, memBuffer } from "./wasm.js";
export function WebGlInit(canvas, wasm_module) {
    const gl = canvas.getContext("webgl2");
    const gl_context = {
        shaders: [],
        programs: [],
        buffers: [],
        uniforms: [],
        textures: [],
        vertex_arrays: [],
        vertex_arrays_free_list: [0]
    };
    const stub = (name) => {
        return (...args) => console.log("[opengl stub]", name, ...args);
    };
    const gl_functions = {
        glGetString: stub("getString"),
        glEnable: (feature) => { gl.enable(feature); },
        glDisable: (feature) => { gl.disable(feature); },
        glIsEnabled: (feature) => { return gl.isEnabled(feature); },
        glBlendEquation: (mode) => { gl.blendEquation(mode); },
        glBlendFunc: (src_factor, dst_factor) => { gl.blendFunc(src_factor, dst_factor); },
        glViewport: (...args) => { gl.viewport(...args); },
        glScissor: (...args) => {  gl.scissor(...args); },
        glDrawElements: (...args) => { gl.drawElements(...args); },
        glGenVertexArrays: (count, arrays_ptr) => {
            for (let i = 0; i < count; i++) {
                let vertex_array = gl.createVertexArray();
                let id = gl_context.vertex_arrays_free_list.pop();
                if (id == gl_context.vertex_arrays.length) {
                    gl_context.vertex_arrays_free_list.push(id + 1);
                }
                gl_context.vertex_arrays[id] = vertex_array;
                writeNumberToPtr(wasm_module.obj, id+1, arrays_ptr + (i * 4));
            }
        },
        glBindVertexArray: (id) => {
            let vertex_array = gl_context.vertex_arrays[id-1];
            if (!vertex_array) console.error("Unknown vertex_array id", id-1);
            return gl.bindVertexArray(vertex_array);
        },
        glDeleteVertexArrays: (count, ids_ptr) => {
            let ids = new Uint32Array(memBuffer(wasm_module.obj), ids_ptr, count);
            for (let i = 0; i < count; i++) {
                let id = ids[i]-1;
                let vertex_array = gl_context.vertex_arrays[id];
                gl.deleteVertexArray(vertex_array);
                gl_context.vertex_arrays[id] = undefined;
                gl_context.vertex_arrays_free_list.push(id);
            }
        },
        glGenBuffers: (count, buffer_ptr) => {
            for (let i = 0; i < count; i++) {
                let buffer = gl.createBuffer();
                gl_context.buffers.push(buffer);
                let buffer_id = gl_context.buffers.length;
                writeNumberToPtr(wasm_module.obj, buffer_id, buffer_ptr + (i * 4));
            }
        },
        glBindBuffer: (target, buffer_id) => {
            let buffer = gl_context.buffers[buffer_id-1];
            if (!buffer) console.error("Unknown buffer id", buffer_id-1);
            return gl.bindBuffer(target, buffer);
        },
        glBufferData: (target, size, data_ptr, usage) => {
            gl.bufferData(target, size, usage);
            gl.bufferSubData(target, 0, new Uint8Array(memBuffer(wasm_module.obj), data_ptr, size))
        },
        glGetShaderiv: (shader_id, param_id, out_ptr) => {
            let shader = gl_context.shaders[shader_id];
            if (!shader) console.error("Unknown shader id", shader_id);
            if (param_id == 35716) { // info_log_length 
                let log_length = gl.getShaderInfoLog(shader).length;
                writeNumberToPtr(wasm_module.obj, log_length, out_ptr);
            } else {
                let param = gl.getShaderParameter(shader, param_id);
                writeNumberToPtr(wasm_module.obj, param, out_ptr);
            }
        },
        glGetShaderInfoLog: (shader_id, log_length, _, out_ptr) => {
            let shader = gl_context.shaders[shader_id];
            if (!shader) console.error("Unknown shader id", shader_id);
            let log = gl.getShaderInfoLog(shader);
            writeStringToPtr(log, out_ptr, log_length);
        },
        glGetProgramiv: (program_id, param_id, out_ptr) => {
            let program = gl_context.programs[program_id];
            if (!program) console.error("Unknown program id", program_id);
            if (param_id == 35716) { // info_log_length 
                let log_length = gl.getProgramInfoLog(program).length;
                writeNumberToPtr(wasm_module.obj, log_length, out_ptr);
            } else {
                let param = gl.getProgramParameter(program, param_id);
                writeNumberToPtr(wasm_module.obj, param, out_ptr);
            }
        },
        glGetProgramInfoLog: (program_id, log_length, _, out_ptr) => {
            let program = gl_context.programs[program_id];
            if (!program) console.error("Unknown program id", program_id);
            let log = gl.getProgramInfoLog(program);
            writeStringToPtr(wasm_module.obj, log, out_ptr, log_length);
        },
        glUseProgram: (program_id) => {
            let program = gl_context.programs[program_id];
            if (!program) console.error("Unknown program id", program_id);
            return gl.useProgram(program);
        },
        glCreateShader: (...args) => {
            let shader = gl.createShader(...args);
            gl_context.shaders.push(shader);
            return gl_context.shaders.length-1;
        },
        glShaderSource: (shader_id, _1, shader_src_ptr_ptr, _2) => {
            let shader = gl_context.shaders[shader_id];
            if (!shader) console.error("Unknown shader id", shader_id);
            let shader_src_ptr = new Uint32Array(memBuffer(wasm_module.obj), shader_src_ptr_ptr)[0];
            let shader_str = readCString(wasm_module.obj, shader_src_ptr);
            shader_str = shader_str.replace("#version 330", "#version 300 es");
            console.log("glShaderSource", shader_str);
            return gl.shaderSource(shader, shader_str);
        },
        glCompileShader: (shader_id) => {
            return gl.compileShader(gl_context.shaders[shader_id]);
        },
        glCreateProgram: () => {
            let program = gl.createProgram();
            gl_context.programs.push(program);
            return gl_context.programs.length-1;
        },
        glAttachShader: (program_id, shader_id) => {
            let program = gl_context.programs[program_id];
            if (!program) console.error("Unknown program id", program_id);
            let shader = gl_context.shaders[shader_id];
            if (!shader) console.error("Unknown shader id", shader_id);
            return gl.attachShader(program, shader);
        },
        glLinkProgram: (program_id) => {
            let program = gl_context.programs[program_id];
            if (!program) console.error("Unknown program id", program_id);
            return gl.linkProgram(program);
        },
        glEnableVertexAttribArray: (...args) => gl.enableVertexAttribArray(...args),
        glDisableVertexAttribArray: (...args) => gl.disableVertexAttribArray(...args),
        glVertexAttribPointer: (...args) => gl.vertexAttribPointer(...args),
        glDrawArrays: (...args) => gl.drawArrays(...args),
        glClearColor: (...args) => gl.clearColor(...args),
        glClear: (...args) => gl.clear(...args),
        glGetUniformLocation: (program_id, uniform_name_ptr) => {
            let program = gl_context.programs[program_id];
            if (!program) console.error("Unknown program id", program_id);
            let uniform_name = readCString(wasm_module.obj, uniform_name_ptr);
            let uniform_location = gl.getUniformLocation(program, uniform_name);
            gl_context.uniforms.push(uniform_location);
            return gl_context.uniforms.length - 1;
        },
        glUniformMatrix4fv: (uniform_id, count, transpose, matrix_ptr) => {
            let uniform_location = gl_context.uniforms[uniform_id];
            if (!uniform_location) console.error("Unknown uniform id", uniform_id);
            let data = new Float32Array(memBuffer(wasm_module.obj), matrix_ptr, 64);
            return gl.uniformMatrix4fv(uniform_location, transpose, data, 0, 16);
        },
        glGenTextures: (count, id_ptr) => {
            for (let i = 0; i < count; i++) {
                let tex = gl.createTexture();
                gl_context.textures.push(tex);
                writeNumberToPtr(wasm_module.obj, gl_context.textures.length, id_ptr + (i * 4));
            }
        },
        glBindTexture: (target, tex_id) => {
            let tex = gl_context.textures[tex_id-1];
            if (!tex) console.error("Unknown texture id", tex_id-1);
            return gl.bindTexture(target, tex);
        },
        glTexImage2D: (target, level, internalformat, width, height, border, format, type, dataPtr) => {
            let channelsPerPixel = 0;
            if (internalformat === gl.R8) { channelsPerPixel = 1; }
            if (internalformat === gl.RGB) { channelsPerPixel = 3; }
            if (internalformat === gl.RGBA) { channelsPerPixel = 4; }
            let tex_data = new Uint8Array(memBuffer(wasm_module.obj), dataPtr, (width * height * channelsPerPixel));
            gl.texImage2D(target, level, internalformat, width, height, border, format, type, tex_data);
        },
        glTexParameteri: (target, pname, param) => {
            gl.texParameteri(target, pname, param);
        },
        glTexParameterf: (target, pname, param) => {
            gl.texParameterf(target, pname, param);
        },
        glActiveTexture: (tex_unit) => {
            gl.activeTexture(tex_unit);
        },
        glUniform1i: (uniform_id, v0) => {
            let uniform_location = gl_context.uniforms[uniform_id];
            if (!uniform_location) console.error("Unknown uniform id", uniform_id);
            gl.uniform1i(uniform_location, v0);
        },
    };
    return {
        gl_functions, gl, gl_context
    };
}
