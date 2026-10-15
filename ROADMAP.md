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

- [x] Pinned toolchain: Zig 0.17.0 and MicroZig 0.17.20 integration
- [x] Build infrastructure: Nix development shell with `zig-overlay`, pre-commit hooks, and CI
- [x] WAMR embedding: C runtime compilation, header translation, and static library linkage
- [x] VM abstraction: Zig wrapper for runtime lifecycle, module loading, and execution environments
- [x] Host function registration: native callback export to WebAssembly modules
- [x] Host CLI runner: command-line tool (`tinybird run`) with module loading and argument passing
- [x] WebAssembly samples: minimal applications (`add.wasm` and `hello.wasm`)
- [x] Packaging support: self-contained Zig package declaration in `build.zig.zon`

### Phase 2: Hardware API and Abstraction

- [ ] Core API specification: standardized imports under the `"tinybird"` module namespace
- [ ] GPIO operations: `gpio_configure`, `gpio_write`, and `gpio_read` functions
- [ ] Time and scheduling: `uptime_ms` and `sleep_ms` functions
- [ ] Diagnostic logging: `log_write` string and integer logging functions
- [ ] Hardware capability queries: runtime discovery of available peripherals and pin counts
- [ ] Error conventions: standard integer return codes and validation across host functions
- [ ] Host simulation layer: mock GPIO and timing drivers for Linux development and testing

### Phase 3: Microcontroller Execution (RP2350)

- [ ] Bare-metal WAMR port: interpreter integration with RP2350 and MicroZig HAL
- [ ] Memory pool management: fixed-budget memory allocation from SRAM without general dynamic allocation
- [ ] Memory footprint profiling: tracking flash consumption, runtime overhead, and linear memory
- [ ] RP2350 platform drivers: hardware GPIO and timer drivers backing the Tinybird API
- [ ] Embedded module execution: running bundled `.wasm` applications controlling physical hardware
- [ ] Host and device parity: identical application behavior on Linux simulation and real hardware

### Phase 4: Portability Verification (ESP32-C3)

- [ ] RISC-V architecture support: platform abstraction layer for ESP32-C3
- [ ] Platform drivers: ESP-IDF or bare-metal driver implementations
- [ ] Binary compatibility verification: execution of unmodified `.wasm` binaries across Linux, Pico 2, and ESP32-C3

### Phase 5: Dynamic Application Management

- [ ] Serial interactive shell: command interpreter with `help`, `info`, `apps`, `install`, `run`, and `remove`
- [ ] Storage abstraction: partitioned flash storage for persistent application storage
- [ ] Application upload protocol: transferring compiled `.wasm` binaries over USB serial
- [ ] Flash safety mechanisms: write boundary verification and execution protection during flash updates
- [ ] Application lifecycle states: installation, verification, startup, and termination

### Phase 6: Isolation and Scheduling

- [ ] Memory limits: per-application heap and linear memory quotas
- [ ] Peripheral permissions: capability-based hardware resource access control
- [ ] Execution budgets: execution timeouts and watchdog timer integration
- [ ] Non-blocking execution: cooperative yielding and interruption of misbehaving modules
- [ ] Multi-tenant execution: running and scheduling multiple applications concurrently

### Development, Testing, and Quality

- [x] Unit tests for hardware-free core logic on host
- [x] Host tests for WAMR runtime lifecycle and module instantiation
- [x] Coverage reporting and pre-commit hook automation
- [ ] Automated integration tests for simulated hardware interactions
- [ ] Real-hardware test runner for physical microcontroller verification
- [ ] Benchmarks for Wasm execution overhead and memory consumption
