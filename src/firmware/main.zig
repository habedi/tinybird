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
const usb = microzig.core.usb;
const UsbDevice = hal.usb.Polled(.{});
const Controller = usb.DeviceController(.{
    .bcd_usb = .v1_10,
    .device_triple = .{ .class = .Miscellaneous, .subclass = 2, .protocol = 1 },
    .vendor = UsbDevice.default_vendor_id,
    .product = .{ .id = UsbDevice.default_product_id.id, .str = "Tinybird" },
    .bcd_device = .from(0, 1),
    .serial = "",
    .max_supported_packet_size = UsbDevice.max_supported_packet_size,
    .configurations = &.{.{
        .attributes = .{ .self_powered = false },
        .max_current_ma = 100,
        .Drivers = struct {
            serial: usb.drivers.CDC,
            reset: hal.usb.ResetDriver(null, 0),
        },
    }},
}, .{.{ .serial = .{}, .reset = "Pico reset" }});

const status_message = "Tinybird running\r\n";

comptime {
    std.debug.assert(status_message.len <= UsbDevice.max_supported_packet_size);
}

// shortcut: MicroZig's CDC driver omits the line-coding data phase; remove
// this adapter when the pinned driver handles SetLineCoding.
const UsbController = struct {
    controller: Controller = .init,
    line_coding_pending: bool = false,

    pub fn on_setup_req(self: *@This(), device: *usb.DeviceInterface, setup: *const usb.types.SetupPacket) void {
        self.line_coding_pending = false;
        // Each control transfer starts its OUT data or status phase with DATA1.
        microzig.chip.peripherals.USB_DPRAM.EP0_OUT_BUFFER_CONTROL.modify(.{ .AVAILABLE_0 = 0, .PID_0 = 0 });
        if (setup.request_type.direction == .in and setup.length.native() > 0)
            device.ep_listen(.ep0, 0);
        if (setup.request_type.type == .class and
            setup.request_type.recipient == .interface and
            setup.request_type.direction == .out and
            setup.request == @backingInt(usb.drivers.CDC.ManagementRequestType.SetLineCoding) and
            setup.index.native() == 0 and setup.length.native() == 7 and
            self.controller.drivers() != null)
        {
            self.line_coding_pending = true;
            device.ep_listen(.ep0, 7);
            return;
        }
        self.controller.on_setup_req(device, setup);
    }

    pub fn on_buffer(self: *@This(), device: *usb.DeviceInterface, comptime ep: usb.types.Endpoint) void {
        if (comptime ep == usb.types.Endpoint.out(.ep0)) {
            var data: [64]u8 = undefined;
            const len = device.ep_readv(.ep0, &.{&data});
            if (self.line_coding_pending) {
                self.line_coding_pending = false;
                if (len == 7) {
                    const serial = &self.controller.drivers().?.serial;
                    @memcpy(std.mem.asBytes(&serial.line_coding)[0..7], data[0..7]);
                    device.ep_ack(.ep0);
                }
            }
            return;
        }
        self.controller.on_buffer(device, ep);
    }

    pub fn on_bus_reset(self: *@This(), device: *usb.DeviceInterface) void {
        self.line_coding_pending = false;
        self.controller.on_bus_reset(device);
    }
};

// GPIO 25 drives the onboard LED on the plain Pico 2. On the Pico 2 W the
// onboard LED hangs off the wireless chip instead, so wire an external LED
// to GPIO 25 to see the blink there.
const led = gpio.num(25);

pub fn main() void {
    led.set_function(.sio);
    led.set_direction(.out);

    var usb_device = UsbDevice.init();
    var usb_controller: UsbController = .{};
    var step: u32 = 0;
    var blink_deadline = time.deadline_in_ms(0);
    var report_deadline = time.deadline_in_ms(1000);
    while (true) {
        usb_device.poll(&usb_controller);
        const now = time.get_time_since_boot();
        if (blink_deadline.is_reached_by(now)) {
            led.toggle();
            blink_deadline = time.deadline_in_ms(core.blinkDelayMs(step));
            step +%= 1;
        }
        if (usb_controller.controller.drivers()) |drivers| {
            if (report_deadline.is_reached_by(now) and drivers.serial.flush()) {
                _ = drivers.serial.write(status_message);
                report_deadline = time.deadline_in_ms(1000);
            }
            _ = drivers.serial.flush();
        }
        // Service USB between LED transitions so enumeration stays responsive.
        time.sleep_ms(1);
    }
}
