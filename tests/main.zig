const std = @import("std");
const testing = std.testing;
const core = @import("core");

test "addition from an external test" {
    try testing.expectEqual(@as(i32, 100), core.add(75, 25));
}

test "blink delays stay within the pattern bounds" {
    var step: u32 = 0;
    while (step < 16) : (step += 1) {
        const delay = core.blinkDelayMs(step);
        try testing.expect(delay >= 125 and delay <= 500);
    }
}
