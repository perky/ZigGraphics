import { writeNumberToPtr, writeStringToPtr, writeCString, readCString, memSize, memBuffer } from "./wasm.js";
export function WebGlInit(canvas_id) {
    const canvas = document.querySelector(canvas_id);
    const gl = canvas.getContext("webgl2");
    const gl_context = {
        shaders: [],
        programs: [],
        buffers: [],
        uniforms: [],
        textures: []
    };
    const stub = (name) => {
        return (...args) => console.log("[opengl stub]", name, ...args);
    };
    const gl_functions = {
        glGetString: stub("getString"),
        glGenVertexArrays: stub("genVertexArrays"),
        glBindVertexArray: stub("bindVertexArray"),
        glGenBuffers: (count, buffer_ptr) => {
            for (let i = 0; i < count; i++) {
                let buffer = gl.createBuffer();
                gl_context.buffers.push(buffer);
                let buffer_id = gl_context.buffers.length - 1;
                writeNumberToPtr(buffer_id, buffer_ptr + (i * 4));
            }
        },
        glBindBuffer: (target, buffer_id) => {
            let buffer = gl_context.buffers[buffer_id];
            return gl.bindBuffer(target, buffer);
        },
        glBufferData: (target, size, data_ptr, usage) => {
            gl.bufferData(target, size, usage);
            gl.bufferSubData(target, 0, new Uint8Array(memBuffer(), data_ptr, size))
        },
        glGetShaderiv: (shader_id, param_id, out_ptr) => {
            let shader = gl_context.shaders[shader_id];
            if (param_id == 35716) { // info_log_length 
                let log_length = gl.getShaderInfoLog(shader).length;
                writeNumberToPtr(log_length, out_ptr);
            } else {
                let param = gl.getShaderParameter(shader, param_id);
                writeNumberToPtr(param, out_ptr);
            }
        },
        glGetShaderInfoLog: (shader_id, log_length, _, out_ptr) => {
            let shader = gl_context.shaders[shader_id];
            let log = gl.getShaderInfoLog(shader);
            writeStringToPtr(log, out_ptr, log_length);
        },
        glGetProgramiv: (program_id, param_id, out_ptr) => {
            let program = gl_context.programs[program_id];
            if (param_id == 35716) { // info_log_length 
                let log_length = gl.getProgramInfoLog(program).length;
                writeNumberToPtr(log_length, out_ptr);
            } else {
                let param = gl.getProgramParameter(program, param_id);
                writeNumberToPtr(param, out_ptr);
            }
        },
        glGetProgramInfoLog: (program_id, log_length, _, out_ptr) => {
            let program = gl_context.programs[program_id];
            let log = gl.getProgramInfoLog(program);
            writeStringToPtr(log, out_ptr, log_length);
        },
        glUseProgram: (program_id) => {
            let program = gl_context.programs[program_id];
            return gl.useProgram(program);
        },
        glCreateShader: (...args) => {
            let shader = gl.createShader(...args);
            gl_context.shaders.push(shader);
            return gl_context.shaders.length-1;
        },
        glShaderSource: (shader_id, _1, shader_src_ptr_ptr, _2) => {
            let shader = gl_context.shaders[shader_id];
            let shader_src_ptr = new Uint32Array(memBuffer(), shader_src_ptr_ptr)[0];
            let shader_str = readCString(shader_src_ptr);
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
            let shader = gl_context.shaders[shader_id];
            return gl.attachShader(program, shader);
        },
        glLinkProgram: (program_id) => {
            let program = gl_context.programs[program_id];
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
            let uniform_name = readCString(uniform_name_ptr);
            let uniform_location = gl.getUniformLocation(program, uniform_name);
            gl_context.uniforms.push(uniform_location);
            return gl_context.uniforms.length - 1;
        },
        glUniformMatrix4fv: (uniform_id, count, transpose, matrix_ptr) => {
            let uniform_location = gl_context.uniforms[uniform_id];
            let data = new Float32Array(memBuffer(), matrix_ptr, 64);
            return gl.uniformMatrix4fv(uniform_location, transpose, data, 0, 16);
        },
        glGenTextures: () => {
            let tex = gl.createTexture();
            gl_context.textures.push(tex);
            return gl_context.textures.length-1;
        },
        glBindTexture: (target, tex_id) => {
            let tex = gl_context.textures[tex_id];
            return gl.bindTexture(target, tex);
        },
        //            (Enum,   Int,    Int,           Sizei, Sizei,  Int,    Enum,   Enum, VoidPtr)
        glTexImage2D: (target, level, internalformat, width, height, border, format, type, dataPtr) => {
            let tex_data = new Uint8Array(memBuffer(), dataPtr, (width * height * 3));
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
            gl.uniform1i(uniform_location, v0);
        },
    };
    return {
        gl_functions, gl, gl_context
    };
}