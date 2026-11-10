## Project Documentation

This directory contains architecture documentation, hardware references, and development guides for Tinybird.

### Supported Microcontrollers

| Board or Platform     | Microcontroller | Architecture     | Memory (SRAM and Flash) | Runtime Backend       | Support Status                      |
|:----------------------|:----------------|:-----------------|:------------------------|:----------------------|:------------------------------------|
| Raspberry Pi Pico 2   | RP2350          | Arm Cortex-M33   | 520 KB and 4 MB         | MicroZig and WAMR     | Supported (primary target)          |
| Raspberry Pi Pico 2 W | RP2350          | Arm Cortex-M33   | 520 KB and 4 MB         | MicroZig and WAMR     | Supported (external LED on GPIO 25) |
| Apache NuttX          | Generic (RP2350)| Arm, RISC-V, sim | Target dependent        | NuttX and WAMR        | Supported (NSH runner)              |
| ESP32-C3              | ESP32-C3        | RISC-V (RV32IMC) | 400 KB and 4 MB         | ESP-IDF and WAMR      | Planned (Milestone 4)               |
| Host simulation       | Host machine    | x86_64, aarch64  | Host memory             | Native Linux and WAMR | Supported (Milestone 1)             |

### Target Details

- Raspberry Pi Pico 2: This is the default target built out of the box. Building produces `zig-out/firmware/tinybird.uf2`, which loads over USB using
  `make flash`.
- Raspberry Pi Pico 2 W: This board shares the RP2350 core, but routes its onboard LED through the wireless chip. Connect an external LED to GPIO 25
  to see visual feedback.
- Apache NuttX: This platform runs WebAssembly modules within the NuttShell (NSH) using WAMR, with native symbol bindings for Tinybird hardware APIs.
- ESP32-C3: This target tests portability across CPU architectures on RISC-V, executing the same `.wasm` binaries without modification.
- Host simulation: This environment runs and debugs WebAssembly modules directly on development machines without physical hardware.
