const std = @import("std");
const microzig = @import("microzig");

// Enable the ports the firmware targets need. Adding a chip family later
// means flipping its port on here and picking a target from `mb.ports`.
const MicroBuild = microzig.MicroBuild(.{ .rp2xxx = true });

fn buildWamr(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *std.Build.Step.Compile {
    const wamr_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    wamr_mod.addIncludePath(b.path("external/wamr/core/iwasm/include"));
    wamr_mod.addIncludePath(b.path("external/wamr/core/iwasm/interpreter"));
    wamr_mod.addIncludePath(b.path("external/wamr/core/iwasm/common"));
    wamr_mod.addIncludePath(b.path("external/wamr/core/shared/platform/linux"));
    wamr_mod.addIncludePath(b.path("external/wamr/core/shared/platform/include"));
    wamr_mod.addIncludePath(b.path("external/wamr/core/shared/mem-alloc"));
    wamr_mod.addIncludePath(b.path("external/wamr/core/shared/utils"));
    wamr_mod.addIncludePath(b.path("external/wamr/core/iwasm/libraries/libc-builtin"));

    wamr_mod.addCMacro("BH_PLATFORM_LINUX", "1");
    wamr_mod.addCMacro("WASM_ENABLE_INTERP", "1");
    wamr_mod.addCMacro("WASM_ENABLE_FAST_INTERP", "1");
    wamr_mod.addCMacro("WASM_ENABLE_LIBC_BUILTIN", "1");
    wamr_mod.addCMacro("BH_MALLOC", "wasm_runtime_malloc");
    wamr_mod.addCMacro("BH_FREE", "wasm_runtime_free");
    wamr_mod.addCMacro("_GNU_SOURCE", "1");
    wamr_mod.addCMacro("WASM_HAVE_MREMAP", "1");

    const c_flags: []const []const u8 = &.{
        "-std=gnu99",
        "-fno-sanitize=alignment",
        "-Wno-unused-parameter",
        "-Wno-pedantic",
        "-Wno-unused-variable",
    };

    wamr_mod.addCSourceFiles(.{
        .files = &.{
            "external/wamr/core/shared/platform/linux/platform_init.c",
            "external/wamr/core/shared/platform/common/posix/posix_blocking_op.c",
            "external/wamr/core/shared/platform/common/posix/posix_malloc.c",
            "external/wamr/core/shared/platform/common/posix/posix_memmap.c",
            "external/wamr/core/shared/platform/common/posix/posix_sleep.c",
            "external/wamr/core/shared/platform/common/posix/posix_thread.c",
            "external/wamr/core/shared/platform/common/posix/posix_time.c",
            "external/wamr/core/shared/mem-alloc/mem_alloc.c",
            "external/wamr/core/shared/mem-alloc/ems/ems_alloc.c",
            "external/wamr/core/shared/mem-alloc/ems/ems_gc.c",
            "external/wamr/core/shared/mem-alloc/ems/ems_hmu.c",
            "external/wamr/core/shared/mem-alloc/ems/ems_kfc.c",
            "external/wamr/core/shared/utils/bh_assert.c",
            "external/wamr/core/shared/utils/bh_bitmap.c",
            "external/wamr/core/shared/utils/bh_common.c",
            "external/wamr/core/shared/utils/bh_hashmap.c",
            "external/wamr/core/shared/utils/bh_leb128.c",
            "external/wamr/core/shared/utils/bh_list.c",
            "external/wamr/core/shared/utils/bh_log.c",
            "external/wamr/core/shared/utils/bh_queue.c",
            "external/wamr/core/shared/utils/bh_vector.c",
            "external/wamr/core/shared/utils/runtime_timer.c",
            "external/wamr/core/iwasm/common/wasm_application.c",
            "external/wamr/core/iwasm/common/wasm_blocking_op.c",
            "external/wamr/core/iwasm/common/wasm_c_api.c",
            "external/wamr/core/iwasm/common/wasm_exec_env.c",
            "external/wamr/core/iwasm/common/wasm_loader_common.c",
            "external/wamr/core/iwasm/common/wasm_memory.c",
            "external/wamr/core/iwasm/common/wasm_native.c",
            "external/wamr/core/iwasm/common/wasm_runtime_common.c",
            "external/wamr/core/iwasm/common/wasm_shared_memory.c",
            "external/wamr/core/iwasm/interpreter/wasm_interp_fast.c",
            "external/wamr/core/iwasm/interpreter/wasm_loader.c",
            "external/wamr/core/iwasm/interpreter/wasm_runtime.c",
            "external/wamr/core/iwasm/libraries/libc-builtin/libc_builtin_wrapper.c",
        },
        .flags = c_flags,
    });

    switch (target.result.cpu.arch) {
        .x86_64 => wamr_mod.addAssemblyFile(b.path("external/wamr/core/iwasm/common/arch/invokeNative_em64.s")),
        .aarch64 => wamr_mod.addAssemblyFile(b.path("external/wamr/core/iwasm/common/arch/invokeNative_aarch64.s")),
        else => {
            wamr_mod.addCMacro("WAMR_BUILD_INVOKE_NATIVE_GENERAL", "1");
            wamr_mod.addCSourceFiles(.{
                .files = &.{"external/wamr/core/iwasm/common/arch/invokeNative_general.c"},
                .flags = c_flags,
            });
        },
    }

    return b.addLibrary(.{
        .name = "wamr",
        .root_module = wamr_mod,
    });
}

pub fn build(b: *std.Build) void {
    const host_target = b.standardTargetOptions(.{});
    if (host_target.result.os.tag != .linux) {
        @panic("The Tinybird host runner supports Linux only");
    }
    const optimize = b.standardOptimizeOption(.{});
    const fw_optimize = b.option(
        std.builtin.Optimize,
        "firmware-optimize",
        "Optimization mode for firmware targets (defaults to small)",
    ) orelse .small;

    // The core module holds the hardware-free logic. Its tests run on the
    // host, so `zig build test` needs no board attached.
    const test_step = b.step("test", "Run the unit tests on the host");

    {
        const core_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/core/core.zig"),
                .target = host_target,
                .optimize = optimize,
            }),
        });
        const core_run = b.addRunArtifact(core_tests);
        test_step.dependOn(&core_run.step);
        const core_install = b.addInstallArtifact(core_tests, .{ .dest_sub_path = "test-root" });
        test_step.dependOn(&core_install.step);
    }

    {
        const core_mod = b.createModule(.{
            .root_source_file = b.path("src/core/core.zig"),
            .target = host_target,
            .optimize = optimize,
        });
        const ext_tests = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("tests/main.zig"),
                .target = host_target,
                .optimize = optimize,
                .imports = &.{.{ .name = "core", .module = core_mod }},
            }),
        });
        const ext_run = b.addRunArtifact(ext_tests);
        test_step.dependOn(&ext_run.step);
        const ext_install = b.addInstallArtifact(ext_tests, .{ .dest_sub_path = "test-ext" });
        test_step.dependOn(&ext_install.step);
    }

    const wamr_lib = buildWamr(b, host_target, optimize);

    const wamr_c = b.addTranslateC(.{
        .root_source_file = b.path("external/wamr/core/iwasm/include/wasm_export.h"),
        .target = host_target,
        .optimize = optimize,
    });
    wamr_c.addIncludePath(b.path("external/wamr/core/iwasm/include"));
    const wamr_c_mod = wamr_c.createModule();

    const vm_mod = b.createModule(.{
        .root_source_file = b.path("src/vm/wamr.zig"),
        .target = host_target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "wamr_c", .module = wamr_c_mod },
        },
    });
    vm_mod.linkLibrary(wamr_lib);

    {
        const vm_tests = b.addTest(.{
            .root_module = vm_mod,
        });
        const vm_run = b.addRunArtifact(vm_tests);
        test_step.dependOn(&vm_run.step);
        const vm_install = b.addInstallArtifact(vm_tests, .{ .dest_sub_path = "test-vm" });
        test_step.dependOn(&vm_install.step);
    }

    // Host runner CLI executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = host_target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "vm/wamr.zig", .module = vm_mod },
        },
    });
    exe_mod.linkLibrary(wamr_lib);

    const exe = b.addExecutable(.{
        .name = "tinybird",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();
    const run_step = b.step("run", "Run the tinybird CLI runner");
    run_step.dependOn(&run_cmd.step);

    // Sample WebAssembly applications
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const add_wasm = b.addExecutable(.{
        .name = "add",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/add/main.zig"),
            .target = wasm_target,
            .optimize = .small,
        }),
    });
    add_wasm.entry = .disabled;
    add_wasm.rdynamic = true;
    // The default 1 MB linear memory exceeds the Pico 2's SRAM.
    add_wasm.stack_size = 4096;
    add_wasm.initial_memory = 65536;
    add_wasm.max_memory = 131072;
    const install_add_wasm = b.addInstallArtifact(add_wasm, .{ .dest_dir = .{ .override = .{ .custom = "examples" } } });

    const hello_wasm = b.addExecutable(.{
        .name = "hello",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/hello/main.zig"),
            .target = wasm_target,
            .optimize = .small,
        }),
    });
    hello_wasm.entry = .disabled;
    hello_wasm.rdynamic = true;
    hello_wasm.stack_size = 4096;
    hello_wasm.initial_memory = 65536;
    hello_wasm.max_memory = 131072;
    const install_hello_wasm = b.addInstallArtifact(hello_wasm, .{ .dest_dir = .{ .override = .{ .custom = "examples" } } });

    const examples_step = b.step("examples", "Build sample WebAssembly applications");
    examples_step.dependOn(&install_add_wasm.step);
    examples_step.dependOn(&install_hello_wasm.step);
    b.default_step.dependOn(examples_step);

    const add_test = b.addRunArtifact(exe);
    add_test.addArg("run");
    add_test.addArtifactArg(add_wasm);
    add_test.addArgs(&.{ "add", "-15", "27" });
    add_test.expectStdErrEqual("Result: 12\n");
    test_step.dependOn(&add_test.step);

    const unsigned_arg_test = b.addRunArtifact(exe);
    unsigned_arg_test.addArg("run");
    unsigned_arg_test.addArtifactArg(add_wasm);
    unsigned_arg_test.addArgs(&.{ "add", "4294967295", "1" });
    unsigned_arg_test.expectStdErrEqual("Result: 0\n");
    test_step.dependOn(&unsigned_arg_test.step);

    const hello_test = b.addRunArtifact(exe);
    hello_test.addArg("run");
    hello_test.addArtifactArg(hello_wasm);
    hello_test.expectStdErrEqual("42\n");
    test_step.dependOn(&hello_test.step);

    const explicit_hello_test = b.addRunArtifact(exe);
    explicit_hello_test.addArg("run");
    explicit_hello_test.addArtifactArg(hello_wasm);
    explicit_hello_test.addArg("main");
    explicit_hello_test.expectStdErrEqual("42\n");
    test_step.dependOn(&explicit_hello_test.step);

    const missing_arg_test = b.addRunArtifact(exe);
    missing_arg_test.addArg("run");
    missing_arg_test.addArtifactArg(add_wasm);
    missing_arg_test.addArgs(&.{ "add", "15" });
    missing_arg_test.expectExitCode(1);
    missing_arg_test.expectStdErrEqual("Error: expected 2 arguments, received 1\n");
    test_step.dependOn(&missing_arg_test.step);

    // The firmware. MicroZig provides the startup code, the linker script,
    // and the HAL; the core module is imported into it unchanged.
    const mz_dep = b.dependency("microzig", .{});
    const mb = MicroBuild.init(b, mz_dep) orelse return;

    const fw_core = b.createModule(.{
        .root_source_file = b.path("src/core/core.zig"),
        .optimize = fw_optimize,
    });
    const firmware = mb.add_firmware(.{
        .name = "tinybird",
        .target = mb.ports.rp2xxx.boards.raspberrypi.pico2_arm,
        .optimize = fw_optimize,
        .root_source_file = b.path("src/firmware/main.zig"),
        .imports = &.{.{ .name = "core", .module = fw_core }},
    });
    // Installs both the ELF (for debugging) and the UF2 (for flashing) into `zig-out/firmware/`.
    mb.install_firmware(firmware, .{});
}
