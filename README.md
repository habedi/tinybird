## Tinybird

<div align="center">
  <picture>
    <img alt="Zig Logo" src="docs/assets/logo.svg" height="35%" width="35%">
  </picture>
</div>
<br>

[![Tests](https://img.shields.io/github/actions/workflow/status/habedi/tinybird/tests.yml?label=tests&style=flat&labelColor=282c34&logo=github)](https://github.com/habedi/tinybird/actions/workflows/tests.yml)
[![Code Coverage](https://img.shields.io/codecov/c/github/habedi/tinybird?label=coverage&style=flat&labelColor=282c34&logo=codecov)](https://codecov.io/gh/habedi/tinybird)
[![Zig Version](https://img.shields.io/badge/Zig-0.17.0-orange?logo=zig&labelColor=282c34)](https://ziglang.org/download/)
[![MicroZig Version](https://img.shields.io/badge/MicroZig-0.17.20-orange?logo=zig&labelColor=282c34)](https://microzig.tech/)
[![Docs](https://img.shields.io/badge/docs-read-007ec6?label=docs&style=flat&labelColor=282c34&logo=readthedocs)](docs)
[![License](https://img.shields.io/badge/license-Apache_2.0-007ec6?label=license&style=flat&labelColor=282c34&logo=open-source-initiative)](LICENSE)

---

Tinybird is a tiny Wasm-based application platform for microcontrollers.
The main goal of the project is to provide a consistent execution environment and hardware API that allows developers to write applications once
and run them on different devices without modifying their code.

---

### Getting Started


```shell
# Enter the Nix dev shell and install the Python tools
make shell
make install

# Run the host-side tests (no board needed)
make test

# Build the firmware (produces zig-out/firmware/blinky.uf2)
make build

# Flash the MCU over USB
make flash
```

```shell
# See all available commands and their descriptions
make help
```

---

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for details on how to make a contribution.

### License

Tinybird is licensed under the Apache License, Version 2.0 (see [LICENSE](LICENSE)).

### Acknowledgements

- The logo is from [SVG Repo](https://www.svgrepo.com/svg/417382/bird) with some modifications.
