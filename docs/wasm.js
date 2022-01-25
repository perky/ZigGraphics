var Module = undefined;

export function memBuffer() { 
    return Module.exports.memory.buffer; 
}

export function memSize() { 
    return Module.exports.memory.buffer.byteLength; 
}

export function readCInt(int_ptr) {
    return new Int32Array(memBuffer(), int_ptr)[0];
}

export function readCString(c_str) {
    const bytes = new Uint8Array(memBuffer(), c_str);
    const read_bytes = [];
    let i = 0;
    while (i < memSize()) {
        if (bytes[i] === '\x00' || bytes[i] === 0) break;
        read_bytes.push(bytes[i]);
        i += 1;
    }
    const string = new TextDecoder('utf8').decode(new Uint8Array(read_bytes));
    return string;
}

export function writeCString(string, ptr_override) {
    console.log(string);
    let ptr = undefined; // TODO alloc from wasm side.
    if (ptr_override) {
        ptr = ptr_override;
    } else {
        // ptr = Module.exports.memAlloc(string.length);
    }
    ///let encoded_string = new TextEncoder().encode(string);
    let encoded_string = string;
    let buf = new Uint8Array(memBuffer(), ptr, encoded_string.length + 1);
    buf.set(encoded_string);
    buf[encoded_string.length + 1] = 0;
    return ptr;
}

export function writeStringToPtr(string, ptr, length) {
    let encoded_string = new TextEncoder().encode(string);
    let buf = new Uint8Array(memBuffer(), ptr, length);
    buf.set(encoded_string);
    return ptr;
}

export function writeNumberToPtr(number, ptr) {
    let buf = new Int32Array(memBuffer(), ptr, 1);
    buf[0] = number;
}

function doEventLoop(cb) {
    invokeCallback(cb);
    window.requestAnimationFrame(() => {
        doEventLoop(cb);
    });
}

function invokeCallback(cb, ...args) {
    Module.exports["__indirect_function_table"].get(cb)(...args);
}

import { WebGlInit } from "./webgl.js";
const webgl = WebGlInit("#glCanvas");

const import_table = {
    abort: () => console.error("ABORT"),
    jsPrint: (ptr, len) => {
        const bytes = new Uint8Array(memBuffer(), ptr, len);
        const string = new TextDecoder('utf8').decode(bytes);
        console.log(string);
    },

    webInitCanvas: () => { 
        // console.log("init canvas");
        // canvas = document.querySelector("#glCanvas");
        // gl = canvas.getContext("webgl");
    },
    webStartEventLoop: (onFrame) => {
        doEventLoop(onFrame);
    },

    glfwGetError: () => {},
    __assert_fail: () => {},
    abs: (a) => { return Math.abs(a); },

    ...webgl.gl_functions,

    printf: (fmt, num_ptr) => { 
        console.log(readCString(fmt), num_ptr, readCString(num_ptr));

    },
    memcpy: (dst_ptr, src_ptr, num) => { 
        let dst = new Uint8Array(memBuffer(), dst_ptr, num);
        let src = new Uint8Array(memBuffer(), src_ptr, num);
        for (let i = 0; i < num; i++) {
            dst[i] = src[i];
        }
        return dst_ptr;
    },
    memset: (ptr, val, num) => { 
        // console.log("memset", ptr, val, num);
        let data = new Uint8Array(memBuffer(), ptr, num);
        for (let i = 0; i < num; i++) {
            data[i] = val;
        }
        return ptr;
    },
    malloc: (size) => { return Module.exports.memAlloc(size); },
    free: (ptr) => { return Module.exports.memFree(ptr); },
};

// https://github.com/torch2424/wasm-by-example/blob/master/demo-util/
export const wasmBrowserInstantiate = async (wasmModuleUrl, importObject) => {
    let response = undefined;
  
    // Check if the browser supports streaming instantiation
    if (WebAssembly.instantiateStreaming) {
      // Fetch the module, and instantiate it as it is downloading
      response = await WebAssembly.instantiateStreaming(
        fetch(wasmModuleUrl),
        importObject
      );
    } else {
      // Fallback to using fetch to download the entire module
      // And then instantiate the module
      const fetchAndInstantiateTask = async () => {
        const wasmArrayBuffer = await fetch(wasmModuleUrl).then(response =>
          response.arrayBuffer()
        );
        return WebAssembly.instantiate(wasmArrayBuffer, importObject);
      };
      response = await fetchAndInstantiateTask();
    }
  
    return response;
};

const runWasm = async (wasm_file) => {
    // Instantiate our wasm module
    const wasmModule = await wasmBrowserInstantiate(wasm_file, {env: import_table});
    wasmModule.instance.env = import_table;
    Module = wasmModule.instance;
    console.log(wasmModule);
    wasmModule.instance.exports.wasmMain();
};

runWasm("./zig_graphics_web.wasm");