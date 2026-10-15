//! Tinybird firmware for the Raspberry Pi Pico 2, built with MicroZig.
//! The blink pattern comes from the `core` module, which is the part of the
//! project that also runs and is tested on the host.

const std = @import("std");
const microzig = @import("microzig");
const core = @import("core");

comptime {
    _ = microzig.export_startup();
}

pub const std_options: std.Options = .{
    .logFn = noopLog,
};

fn noopLog(
    comptime message_level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}

const hal = microzig.hal;
const gpio = hal.gpio;
const time = hal.time;

// GPIO 25 drives the onboard LED on the plain Pico 2. On the Pico 2 W the
// onboard LED hangs off the wireless chip instead, so wire an external LED
// to GPIO 25 to see the blink there.
const led = gpio.num(25);

pub fn main() void {
    led.set_function(.sio);
    led.set_direction(.out);

    var step: u32 = 0;
    while (true) : (step +%= 1) {
        led.toggle();
        time.sleep_ms(core.blinkDelayMs(step));
    }
}
