//! The core module holds the logic that does not need the hardware.
//! It must stay freestanding-safe: no allocation, no I/O, and no OS calls,
//! so the same code compiles for the host tests and for the firmware.

const std = @import("std");

/// Adds two integers. A placeholder for real application logic.
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Returns the LED delay in milliseconds for a given blink step.
/// The firmware uses it to blink in a repeating fast-slow pattern.
pub fn blinkDelayMs(step: u32) u32 {
    const delays = [_]u32{ 500, 250, 125, 250 };
    return delays[step % delays.len];
}

test "basic addition" {
    try std.testing.expectEqual(@as(i32, 5), add(2, 3));
}

test "addition with negative numbers" {
    try std.testing.expectEqual(@as(i32, -1), add(2, -3));
    try std.testing.expectEqual(@as(i32, -5), add(-2, -3));
}

test "blink pattern repeats" {
    try std.testing.expectEqual(blinkDelayMs(0), blinkDelayMs(4));
    try std.testing.expectEqual(@as(u32, 125), blinkDelayMs(2));
}
