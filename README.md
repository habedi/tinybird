<div align="center">
  <picture>
    <img alt="Tinybird Logo" src="docs/assets/logo.svg" height="25%" width="25%">
  </picture>
<br>

<h2>Tinybird</h2>

[![Tests](https://img.shields.io/github/actions/workflow/status/habedi/tinybird/tests.yml?label=tests&style=flat&labelColor=282c34&logo=github)](https://github.com/habedi/tinybird/actions/workflows/tests.yml)
[![Examples](https://img.shields.io/badge/examples-view-507ec6?label=examples&style=flat&labelColor=282c34&logo=github)](examples)
[![Docs](https://img.shields.io/badge/docs-read-507ec6?label=docs&style=flat&labelColor=282c34&logo=readthedocs)](docs)
[![Zig Version](https://img.shields.io/badge/Zig-0.17-F7A41D?logo=zig&labelColor=282c34)](https://ziglang.org/download/)
[![MicroZig Version](https://img.shields.io/badge/MicroZig-0.17.20-F7A41D?logo=zig&labelColor=282c34)](https://microzig.tech/)
[![License](https://img.shields.io/badge/license-Apache_2.0-007ec6?label=license&style=flat&labelColor=282c34&logo=open-source-initiative)](LICENSE)

A tiny application platform for microcontrollers

</div>

---

Tinybird is a tiny Wasm-based application platform for microcontrollers.
The main goal of the project is to provide a consistent execution environment and hardware API that allows developers to write applications once
and run them on different devices without modifying their code.

See [ROADMAP.md](ROADMAP.md) for the list of implemented and planned features.

> [!IMPORTANT]
> Tinybird is in early development, so bugs and breaking changes are expected.
> Use the [issues page](https://github.com/habedi/tinybird/issues) to report bugs or request features.

---

### Quickstart

To follow the steps below, you need to have Git and [Nix](https://nixos.org/download/) (with flakes enabled) installed on your machine.

> [!IMPORTANT]
> The instructions below are for Linux.
> Use Windows Subsystem for Linux (WSL) on Windows.
> A working Nix installation with flakes enabled is needed.
> Currently, the primary microcontroller target is the Raspberry Pi Pico 2.

#### 1. Clone the repository

```bash
git clone --recurse-submodules https://github.com/habedi/tinybird.git
cd tinybird
```

#### 2. Enter the development environment

```bash
nix develop
```

#### 3. Install development tools and dependencies

```bash
# Install Python tools
make install

# Run host-side unit tests (no board needed)
make test

# Build the host CLI, sample Wasm applications, and MCU firmware
make build
```

#### 4. Run a sample WebAssembly application

```bash
# Run the hello world example
./zig-out/bin/tinybird run zig-out/examples/hello.wasm

# Run the add example with arguments
./zig-out/bin/tinybird run zig-out/examples/add.wasm add 10 20
```

#### 5. Flashing the firmware to the Raspberry Pi Pico 2

1. Enter BOOTSEL mode by holding down the white `BOOTSEL` button on the Pico 2 while plugging the USB cable into your machine, then release it.
2. Flash the board:

```bash
# Option A: Automatic flash over USB using picotool
make flash

# Option B: Flash a specific UF2 file path
make flash FIRMWARE_UF2=zig-out/firmware/tinybird.uf2
```

<div align="center">
  <img alt="Raspberry Pi Pico 2" src="docs/assets/images/pico/pico2wh.png" width="50%">
</div>

#### 6. Connecting to the serial console

```bash
make console TTY=/dev/ttyACM0
```

> [!TIP]
> On Linux, access to `/dev/ttyACM0` needs membership in the `dialout` group:
> ```bash
> sudo usermod -aG dialout $USER
> ```

---

### Documentation

Check out the project [documentation](docs/README.md) for more information.

To see all available commands in [Makefile](Makefile) and their descriptions, run:

```bash
make help
```

---

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to make a contribution.

### License

Tinybird is licensed under the Apache License, Version 2.0 (see [LICENSE](LICENSE)).

### Acknowledgements

- The logo is from [SVG Repo](https://www.svgrepo.com/svg/417382/bird) with some modifications.
