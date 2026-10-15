//! Command-line interface for the Tinybird WebAssembly runner.

const std = @import("std");
const vm = @import("vm/wamr.zig");

fn nativeLog(exec_env: vm.c.wasm_exec_env_t, value: i32) callconv(.c) void {
    _ = exec_env;
    std.debug.print("{d}\n", .{value});
}

fn printUsage() void {
    std.debug.print(
        \\Tinybird — A WebAssembly application platform for microcontrollers
        \\
        \\Usage:
        \\  tinybird run <file.wasm> [function] [args...]
        \\  tinybird version
        \\  tinybird help
        \\
        \\Commands:
        \\  run       Load and execute a WebAssembly module
        \\  version   Print version information
        \\  help      Display this help text
        \\
    , .{});
}

fn printVersion() void {
    std.debug.print("tinybird 0.1.0\n", .{});
}

pub fn main(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const raw_args = init.minimal.args.vector;

    var args = try allocator.alloc([:0]const u8, raw_args.len);
    for (raw_args, 0..) |arg, i| {
        args[i] = std.mem.span(arg);
    }

    if (args.len < 2) {
        printUsage();
        return 1;
    }

    const command = args[1];
    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        printUsage();
        return 0;
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        printVersion();
        return 0;
    } else if (!std.mem.eql(u8, command, "run")) {
        std.debug.print("Unknown command: {s}\n\n", .{command});
        printUsage();
        return 1;
    }

    if (args.len < 3) {
        std.debug.print("Error: missing .wasm file path\n\n", .{});
        printUsage();
        return 1;
    }

    const wasm_path = args[2];
    const wasm_bytes = std.Io.Dir.cwd().readFileAlloc(init.io, wasm_path, allocator, .unlimited) catch |err| {
        std.debug.print("Error opening file '{s}': {t}\n", .{ wasm_path, err });
        return 1;
    };

    var runtime = vm.Runtime.init() catch |err| {
        std.debug.print("Failed to initialize WAMR runtime: {t}\n", .{err});
        return 1;
    };
    defer runtime.deinit();

    const native_symbols = [_]vm.NativeSymbol{
        .{
            .symbol = "log",
            .func_ptr = @ptrCast(@constCast(&nativeLog)),
            .signature = "(i)",
            .attachment = null,
        },
    };

    runtime.registerNatives("tinybird", &native_symbols) catch |err| {
        std.debug.print("Failed to register native symbols for 'tinybird': {t}\n", .{err});
        return 1;
    };
    runtime.registerNatives("env", &native_symbols) catch |err| {
        std.debug.print("Failed to register native symbols for 'env': {t}\n", .{err});
        return 1;
    };

    var module = vm.Module.load(allocator, wasm_bytes) catch |err| {
        std.debug.print("Failed to load WebAssembly module '{s}': {t}\n", .{ wasm_path, err });
        return 1;
    };
    defer module.deinit();

    var instance = vm.Instance.instantiate(&module, 64 * 1024, 64 * 1024) catch |err| {
        std.debug.print("Failed to instantiate WebAssembly module: {t}\n", .{err});
        return 1;
    };
    defer instance.deinit();

    var exec_env = vm.ExecEnv.create(&instance, 64 * 1024) catch |err| {
        std.debug.print("Failed to create execution environment: {t}\n", .{err});
        return 1;
    };
    defer exec_env.deinit();

    if (args.len >= 4) {
        const func_name = args[3];

        const func = instance.lookupFunction(func_name) orelse {
            std.debug.print("Error: function '{s}' not found in module\n", .{func_name});
            return 1;
        };

        const param_count = vm.c.wasm_func_get_param_count(func.handle, func.instance);
        if (args.len - 4 != param_count) {
            std.debug.print("Error: expected {d} arguments, received {d}\n", .{ param_count, args.len - 4 });
            return 1;
        }
        const param_types = try allocator.alloc(vm.c.wasm_valkind_t, param_count);
        vm.c.wasm_func_get_param_types(func.handle, func.instance, param_types.ptr);
        const call_args = try allocator.alloc(vm.c.wasm_val_t, param_count);

        for (args[4..], 0..) |arg_str, i| {
            if (param_types[i] != vm.c.WASM_I32) {
                std.debug.print("Error: only i32 arguments are supported\n", .{});
                return 1;
            }
            const value = std.fmt.parseInt(i32, arg_str, 10) catch blk: {
                const bits = std.fmt.parseInt(u32, arg_str, 10) catch |err| {
                    std.debug.print("Invalid integer argument '{s}': {t}\n", .{ arg_str, err });
                    return 1;
                };
                break :blk @as(i32, @bitCast(bits));
            };
            call_args[i] = .{ .kind = vm.c.WASM_I32, .of = .{ .i32 = value } };
        }

        const results = try allocator.alloc(vm.c.wasm_val_t, vm.c.wasm_func_get_result_count(func.handle, func.instance));
        func.call(&exec_env, call_args, results) catch {
            if (instance.getException()) |exc| {
                std.debug.print("Execution error: {s}\n", .{exc});
            } else {
                std.debug.print("Execution failed\n", .{});
            }
            return 1;
        };

        for (results) |result| {
            switch (result.kind) {
                vm.c.WASM_I32 => std.debug.print("Result: {d}\n", .{result.of.i32}),
                vm.c.WASM_I64 => std.debug.print("Result: {d}\n", .{result.of.i64}),
                vm.c.WASM_F32 => std.debug.print("Result: {d}\n", .{result.of.f32}),
                vm.c.WASM_F64 => std.debug.print("Result: {d}\n", .{result.of.f64}),
                else => std.debug.print("Result: unsupported type\n", .{}),
            }
        }
        return 0;
    }

    if (instance.lookupFunction("main")) |main_func| {
        const results = try allocator.alloc(vm.c.wasm_val_t, vm.c.wasm_func_get_result_count(main_func.handle, main_func.instance));
        main_func.call(&exec_env, &.{}, results) catch {
            if (instance.getException()) |exc| {
                std.debug.print("Execution error: {s}\n", .{exc});
            } else {
                std.debug.print("Execution failed\n", .{});
            }
            return 1;
        };
        return 0;
    }

    if (instance.lookupFunction("add")) |add_func| {
        var call_args = [_]vm.c.wasm_val_t{
            .{ .kind = vm.c.WASM_I32, .of = .{ .i32 = 40 } },
            .{ .kind = vm.c.WASM_I32, .of = .{ .i32 = 2 } },
        };
        const results = try allocator.alloc(vm.c.wasm_val_t, vm.c.wasm_func_get_result_count(add_func.handle, add_func.instance));
        add_func.call(&exec_env, &call_args, results) catch {
            if (instance.getException()) |exc| {
                std.debug.print("Execution error: {s}\n", .{exc});
            } else {
                std.debug.print("Execution failed\n", .{});
            }
            return 1;
        };
        if (results.len > 0 and results[0].kind == vm.c.WASM_I32) {
            std.debug.print("Result: {d}\n", .{results[0].of.i32});
        }
        return 0;
    }

    if (instance.lookupFunction("_start")) |start_func| {
        const results = try allocator.alloc(vm.c.wasm_val_t, vm.c.wasm_func_get_result_count(start_func.handle, start_func.instance));
        start_func.call(&exec_env, &.{}, results) catch {
            if (instance.getException()) |exc| {
                std.debug.print("Execution error: {s}\n", .{exc});
            } else {
                std.debug.print("Execution failed\n", .{});
            }
            return 1;
        };
        return 0;
    }

    std.debug.print("Error: no entry function (main, add, _start) found in module\n", .{});
    return 1;
}
