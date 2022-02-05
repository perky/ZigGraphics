
// The most important function. Executes a .wasm file within our javascript 'runtime'.
const runWasm = async (wasm_file, canvas_id) => {
    const module_container = { obj: undefined };
    const import_table = ImportTableInit(module_container, canvas_id);
    const wasm_module = await wasmBrowserInstantiate(wasm_file, {env: import_table});
    wasm_module.instance.env = import_table;
    module_container.obj = wasm_module.instance;
    console.log(wasm_module);
    wasm_module.instance.exports._start();
    return wasm_module;
};
window.runWasm = runWasm;

import { WebGlInit } from "./webgl.js";
import { sprintf } from "./sprintf.js";
function ImportTableInit(wasm_module, canvas_id) {
    const canvas = document.querySelector(canvas_id);
    const webgl = WebGlInit(canvas, wasm_module);
    let mouse_state = {
        x: 0, y: 0, left: false, right: false
    };
    canvas.addEventListener("mousemove", function(ev){
        let rect = canvas.getBoundingClientRect();
        mouse_state.x = ev.clientX - rect.left;
        mouse_state.y = ev.clientY - rect.top;
    });
    canvas.addEventListener("mousedown", function(ev){
        if (ev.button === 0) mouse_state.left = true;
        if (ev.button === 2) mouse_state.right = true;
    });
    canvas.addEventListener("mouseup", function(ev){
        if (ev.button === 0) mouse_state.left = false;
        if (ev.button === 2) mouse_state.right = false;
    });
    const import_table = {
        abort: () => console.error("ABORT"),
        webPrint: (ptr, len) => {
            const bytes = new Uint8Array(memBuffer(wasm_module.obj), ptr, len);
            const string = new TextDecoder('utf8').decode(bytes);
            console.log(string);
        },
        
        webStartEventLoop: (onFrame) => {
            doEventLoop(wasm_module.obj, onFrame);
        },
        webCanvasWidth: () => { return canvas.width; },
        webCanvasHeight: () => { return canvas.height; },
        webBreakpoint: () => { debugger; },

        webGetMouseX: () => { return mouse_state.x; },
        webGetMouseY: () => { return mouse_state.y; },
        webIsMouseLeftDown: () => { return mouse_state.left },

        printf: (fmt_ptr, ...args) => {
            let fmt = readCString(wasm_module.obj, fmt_ptr);
            let result = sprintf(fmt, readCInt(wasm_module.obj, args[0]));
            console.log(result);
        },
        vsnprintf: (buf_ptr, buf_size, fmt_ptr, ...args) => {
            let fmt = readCString(wasm_module.obj, fmt_ptr);
            let result = sprintf(fmt, readCInt(wasm_module.obj, args[0]));
            let src = new TextEncoder().encode(result);
            let dst = new Uint8Array(memBuffer(wasm_module.obj), buf_ptr, buf_size);
            for (let i = 0; i < result.length; i++) {
                dst[i] = src[i];
            }
            console.log("vsnprintf", result);
            return src.length;
        },

        isdigit: (c) => { return c >= '0' && c <= '9'; },
        sscanf: stub("sscanf"),
        memchr: stub("memchr"),
        ...webgl.gl_functions,
    };
    return import_table
}

const stub = (name) => {
    return (...args) => console.log("[wasm stub]", name, ...args);
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

export function readCInt(wasm_module, int_ptr) {
    return new Int32Array(memBuffer(wasm_module), int_ptr)[0];
}

export function readCString(wasm_module, c_str) {
    const bytes = new Uint8Array(memBuffer(wasm_module), c_str);
    const read_bytes = [];
    let i = 0;
    while (i < memSize(wasm_module)) {
        if (bytes[i] === '\x00' || bytes[i] === 0) break;
        read_bytes.push(bytes[i]);
        i += 1;
    }
    const string = new TextDecoder('utf8').decode(new Uint8Array(read_bytes));
    return string;
}

export function writeCString(wasm_module, string, ptr_override) {
    console.log(string);
    let ptr = undefined; // TODO alloc from wasm side.
    if (ptr_override) {
        ptr = ptr_override;
    } else {
        // ptr = Module.exports.memAlloc(string.length);
    }
    ///let encoded_string = new TextEncoder().encode(string);
    let encoded_string = string;
    let buf = new Uint8Array(memBuffer(wasm_module), ptr, encoded_string.length + 1);
    buf.set(encoded_string);
    buf[encoded_string.length + 1] = 0;
    return ptr;
}

export function writeStringToPtr(wasm_module, string, ptr, length) {
    let encoded_string = new TextEncoder().encode(string);
    let buf = new Uint8Array(memBuffer(wasm_module), ptr, length);
    buf.set(encoded_string);
    return ptr;
}

export function writeNumberToPtr(wasm_module, number, ptr) {
    let buf = new Int32Array(memBuffer(wasm_module), ptr, 1);
    buf[0] = number;
}

export function memBuffer(wasm_module) { 
    return wasm_module.exports.memory.buffer; 
}

export function memSize(wasm_module) { 
    return wasm_module.exports.memory.buffer.byteLength; 
}

export function invokeCallback(wasm_module, cb, ...args) {
    wasm_module.exports["__indirect_function_table"].get(cb)(...args);
}

function doEventLoop(wasm_module, cb) {
    invokeCallback(wasm_module, cb);
    window.requestAnimationFrame(() => {
        doEventLoop(wasm_module, cb);
    });
}