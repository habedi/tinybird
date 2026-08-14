//! Minimal WebAssembly application that invokes a native host function.

extern "tinybird" fn log(value: i32) void;

pub export fn main() void {
    log(42);
}
