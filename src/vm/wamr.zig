//! WebAssembly Micro Runtime (WAMR) bindings for Tinybird.

const std = @import("std");

pub const c = @import("wamr_c");

pub const NativeSymbol = extern struct {
    symbol: [*:0]const u8,
    func_ptr: *const anyopaque,
    signature: ?[*:0]const u8 = null,
    attachment: ?*anyopaque = null,
};

pub const Error = error{
    RuntimeInitFailed,
    RegisterNativesFailed,
    ModuleLoadFailed,
    InstantiateFailed,
    ExecEnvCreateFailed,
    FunctionNotFound,
    ExecutionFailed,
    OutOfMemory,
};

pub const Runtime = struct {
    pub fn init() Error!Runtime {
        if (!c.wasm_runtime_init()) {
            return Error.RuntimeInitFailed;
        }
        return Runtime{};
    }

    pub fn deinit(self: *Runtime) void {
        _ = self;
        c.wasm_runtime_destroy();
    }

    pub fn registerNatives(
        self: *Runtime,
        module_name: [:0]const u8,
        symbols: []const NativeSymbol,
    ) Error!void {
        _ = self;
        const count: u32 = @intCast(symbols.len);
        const ptr: [*]c.NativeSymbol = @ptrCast(@constCast(symbols.ptr));
        if (!c.wasm_runtime_register_natives(module_name.ptr, ptr, count)) {
            return Error.RegisterNativesFailed;
        }
    }
};

pub const Module = struct {
    handle: c.wasm_module_t,
    buffer: []align(4) u8,
    allocator: std.mem.Allocator,

    pub fn load(
        allocator: std.mem.Allocator,
        wasm_bytes: []const u8,
    ) Error!Module {
        const aligned_buf = allocator.alignedAlloc(u8, .@"4", wasm_bytes.len) catch return Error.OutOfMemory;
        errdefer allocator.free(aligned_buf);
        @memcpy(aligned_buf, wasm_bytes);

        var error_buf: [128]u8 = undefined;
        const handle = c.wasm_runtime_load(
            aligned_buf.ptr,
            @intCast(aligned_buf.len),
            &error_buf,
            error_buf.len,
        ) orelse {
            return Error.ModuleLoadFailed;
        };

        return Module{
            .handle = handle,
            .buffer = aligned_buf,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Module) void {
        if (self.handle != null) {
            c.wasm_runtime_unload(self.handle);
            self.handle = null;
        }
        self.allocator.free(self.buffer);
    }
};

pub const Instance = struct {
    handle: c.wasm_module_inst_t,

    pub fn instantiate(
        module: *Module,
        stack_size: u32,
        heap_size: u32,
    ) Error!Instance {
        var error_buf: [128]u8 = undefined;
        const handle = c.wasm_runtime_instantiate(
            module.handle,
            stack_size,
            heap_size,
            &error_buf,
            error_buf.len,
        ) orelse {
            return Error.InstantiateFailed;
        };
        return Instance{ .handle = handle };
    }

    pub fn deinit(self: *Instance) void {
        if (self.handle != null) {
            c.wasm_runtime_deinstantiate(self.handle);
            self.handle = null;
        }
    }

    pub fn lookupFunction(self: *Instance, name: [:0]const u8) ?Function {
        const func = c.wasm_runtime_lookup_function(self.handle, name.ptr) orelse return null;
        return Function{ .handle = func, .instance = self.handle };
    }

    pub fn getException(self: *Instance) ?[:0]const u8 {
        const raw = c.wasm_runtime_get_exception(self.handle);
        if (raw == null) return null;
        return std.mem.span(raw);
    }
};

pub const ExecEnv = struct {
    handle: c.wasm_exec_env_t,

    pub fn create(instance: *Instance, stack_size: u32) Error!ExecEnv {
        const handle = c.wasm_runtime_create_exec_env(instance.handle, stack_size) orelse {
            return Error.ExecEnvCreateFailed;
        };
        return ExecEnv{ .handle = handle };
    }

    pub fn deinit(self: *ExecEnv) void {
        if (self.handle != null) {
            c.wasm_runtime_destroy_exec_env(self.handle);
            self.handle = null;
        }
    }
};

pub const Function = struct {
    handle: c.wasm_function_inst_t,
    instance: c.wasm_module_inst_t,

    pub fn call(self: Function, exec_env: *ExecEnv, args: []c.wasm_val_t, results: []c.wasm_val_t) Error!void {
        if (c.wasm_runtime_get_module_inst(exec_env.handle) != self.instance) {
            return Error.ExecutionFailed;
        }
        const ok = c.wasm_runtime_call_wasm_a(
            exec_env.handle,
            self.handle,
            @intCast(results.len),
            results.ptr,
            @intCast(args.len),
            args.ptr,
        );
        if (!ok) {
            return Error.ExecutionFailed;
        }
    }
};

test "runtime initialization and teardown" {
    var rt = try Runtime.init();
    defer rt.deinit();
}

var test_logged_val: i32 = 0;
fn testNativeLog(exec_env: c.wasm_exec_env_t, val: i32) callconv(.c) void {
    _ = exec_env;
    test_logged_val = val;
}

test "native function registration" {
    var rt = try Runtime.init();
    defer rt.deinit();

    const symbols = [_]NativeSymbol{
        .{
            .symbol = "log",
            .func_ptr = @ptrCast(@constCast(&testNativeLog)),
            .signature = "(i)",
        },
    };
    try rt.registerNatives("tinybird", &symbols);
}

test "module load, instantiate, and execute add" {
    var rt = try Runtime.init();
    defer rt.deinit();

    const wasm_bytes = [_]u8{
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x07, 0x01, 0x60,
        0x02, 0x7f, 0x7f, 0x01, 0x7f, 0x03, 0x02, 0x01, 0x00, 0x05, 0x03, 0x01,
        0x00, 0x10, 0x06, 0x09, 0x01, 0x7f, 0x01, 0x41, 0x80, 0x80, 0xc0, 0x00,
        0x0b, 0x07, 0x10, 0x02, 0x06, 0x6d, 0x65, 0x6d, 0x6f, 0x72, 0x79, 0x02,
        0x00, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00, 0x0a, 0x09, 0x01, 0x07, 0x00,
        0x20, 0x01, 0x20, 0x00, 0x6a, 0x0b,
    };

    var module = try Module.load(std.testing.allocator, &wasm_bytes);
    defer module.deinit();

    var instance = try Instance.instantiate(&module, 8192, 8192);
    defer instance.deinit();

    var exec_env = try ExecEnv.create(&instance, 8192);
    defer exec_env.deinit();

    const func = instance.lookupFunction("add") orelse return error.TestExpectedFunction;

    var args = [_]c.wasm_val_t{
        .{ .kind = c.WASM_I32, .of = .{ .i32 = 15 } },
        .{ .kind = c.WASM_I32, .of = .{ .i32 = 27 } },
    };
    var results: [1]c.wasm_val_t = undefined;
    try func.call(&exec_env, &args, &results);
    try std.testing.expectEqual(@as(i32, 42), results[0].of.i32);
    try std.testing.expectError(error.ExecutionFailed, func.call(&exec_env, args[0..1], &results));

    var other_instance = try Instance.instantiate(&module, 8192, 8192);
    defer other_instance.deinit();
    var other_env = try ExecEnv.create(&other_instance, 8192);
    defer other_env.deinit();
    try std.testing.expectError(error.ExecutionFailed, func.call(&other_env, &args, &results));
}

test "a function result must fit in the call buffer" {
    var rt = try Runtime.init();
    defer rt.deinit();

    const wasm_bytes = [_]u8{
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00,
        0x01, 0x05, 0x01, 0x60, 0x00, 0x01, 0x7e, 0x03,
        0x02, 0x01, 0x00, 0x07, 0x08, 0x01, 0x04, 'm',
        'a',  'i',  'n',  0x00, 0x00, 0x0a, 0x06, 0x01,
        0x04, 0x00, 0x42, 0x2a, 0x0b,
    };
    var module = try Module.load(std.testing.allocator, &wasm_bytes);
    defer module.deinit();
    var instance = try Instance.instantiate(&module, 8192, 8192);
    defer instance.deinit();
    var exec_env = try ExecEnv.create(&instance, 8192);
    defer exec_env.deinit();
    const func = instance.lookupFunction("main") orelse return error.TestExpectedFunction;

    try std.testing.expectError(error.ExecutionFailed, func.call(&exec_env, &.{}, &.{}));
    var results: [1]c.wasm_val_t = undefined;
    try func.call(&exec_env, &.{}, &results);
    try std.testing.expectEqual(@as(i64, 42), results[0].of.i64);
}
