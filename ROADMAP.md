## Project Roadmap

This document outlines the architecture, completed milestones, and future goals for Tinybird.

> [!IMPORTANT]
> This roadmap is a work in progress and is subject to change as the platform evolves.

### Milestones Summary

| Milestone | Target   | Description                                                             | Status      |
|:----------|:---------|:------------------------------------------------------------------------|:------------|
| M0        | Host     | Project bootstrap, Zig 0.17.0, Nix shell, and CI workflows              | Completed   |
| M1        | Host     | WAMR integration, host CLI runner, and sample Wasm applications         | Completed   |
| M2        | Platform | Portable hardware API, host simulation, and error model                 | In Progress |
| M3        | RP2350   | Bare-metal Pico 2 firmware, memory budget, and physical LED control     | Planned     |
| M4        | ESP32-C3 | Portability verification on RISC-V without application recompilation    | Planned     |
| M5        | Device   | Persistent storage, USB serial shell, and dynamic application loading   | Planned     |
| M6        | System   | Memory bounds, peripheral permissions, execution budgets, and isolation | Planned     |

### Phase 1: Host Runtime and Tooling

- [x] Integrate Zig 0.17.0 with MicroZig 0.17.20 across all build configurations.
- [x] Set up build infrastructure using a Nix development shell with `zig-overlay`, pre-commit hooks, and GitHub Actions CI.
- [x] Embed the WAMR C runtime as a static library with translated C header bindings.
- [x] Provide a Zig runtime abstraction layer for module loading, instantiation, and execution environments.
- [x] Implement host function registration to export native callbacks to WebAssembly modules.
- [x] Build the `tinybird` host CLI runner to load modules and invoke exported functions with arguments.
- [x] Provide sample WebAssembly applications, including `add.wasm` and `hello.wasm`.
- [x] Include external runtime sources in `build.zig.zon` so Tinybird can be consumed as a standalone Zig package.

### Phase 2: Hardware API and Abstraction

- [ ] Specify the portable hardware API exposed to WebAssembly applications under the `"tinybird"` module namespace.
- [ ] Implement GPIO operations to configure pin directions, write digital outputs, and read pin inputs.
- [ ] Provide timing primitives for reading system uptime and putting the execution environment to sleep.
- [ ] Implement diagnostic logging functions for printing numeric and string messages from WebAssembly code.
- [ ] Define hardware capability discovery so applications can query available pins and peripherals at runtime.
- [ ] Establish standard integer error codes and input validation across all host functions.
- [ ] Create a host-side simulation layer that mocks GPIO state and timing for Linux development.

### Phase 3: Microcontroller Execution (RP2350)

- [ ] Port the WAMR interpreter to bare-metal RP2350 using the MicroZig HAL.
- [ ] Implement a fixed-budget memory pool in SRAM to avoid unconstrained dynamic allocation.
- [ ] Profile memory usage by tracking flash consumption, runtime overhead, and linear memory footprint.
- [ ] Build RP2350 platform drivers that connect physical GPIO and hardware timers to the Tinybird API.
- [ ] Bundle and execute a WebAssembly application in firmware that drives the onboard LED on a Pico 2.
- [ ] Verify identical application behavior between host simulation and physical hardware.

### Phase 4: Portability Verification (ESP32-C3)

- [ ] Implement the platform abstraction layer for ESP32-C3 on the RISC-V architecture.
- [ ] Provide platform drivers backed by ESP-IDF or bare-metal peripheral registers.
- [ ] Run identical, unmodified `.wasm` binaries across Linux, the Pico 2, and the ESP32-C3.

### Phase 5: Dynamic Application Management

- [ ] Develop an interactive serial shell supporting commands like `help`, `info`, `apps`, `install`, `run`, and `remove`.
- [ ] Implement a storage abstraction that partitions flash memory for persistent application storage.
- [ ] Create a transfer protocol to upload compiled WebAssembly binaries over USB serial.
- [ ] Add safety checks for flash writes to protect against out-of-bounds writes and execution collisions.
- [ ] Manage application lifecycles from installation and verification to execution and removal.

### Phase 6: Isolation and Scheduling

- [ ] Enforce per-application memory quotas on heap and linear memory.
- [ ] Implement capability-based access control to restrict which hardware pins each application can access.
- [ ] Set execution time budgets backed by hardware watchdog timers.
- [ ] Support cooperative yielding and interruption to stop misbehaving modules without rebooting.
- [ ] Enable multi-tenant scheduling so multiple applications can run concurrently.

### Development, Testing, and Quality

- [x] Write host-side unit tests for hardware-free core logic.
- [x] Add host tests that exercise the WAMR runtime lifecycle and module instantiation.
- [x] Configure automated code coverage reporting and pre-commit hook checks.
- [ ] Implement automated integration tests for simulated hardware interactions.
- [ ] Set up an automated test runner for verification on physical microcontroller boards.
- [ ] Create benchmarks to measure execution overhead and memory footprint across targets.
