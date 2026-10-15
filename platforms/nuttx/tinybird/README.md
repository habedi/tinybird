## Tinybird Runner for NuttX

The Tinybird runner provides a built-in application for the NuttShell (NSH) on Apache NuttX.
It registers the native symbol table for the `"tinybird"` and `"env"` namespaces, loads WebAssembly modules from the NuttX virtual filesystem, and executes their exported functions.

### Overview

Generic WAMR (`iwasm`) in NuttX executes standard WebAssembly modules such as `add.wasm`.
However, modules that import host APIs from `"tinybird"` (such as `log`, `uptime_ms`, or `gpio_write`) require a dedicated runner that registers those native symbols before instantiation.
Without native symbol registration, WAMR raises an unlinked import error when loading the module.

The Tinybird runner solves this issue by exposing:

- Diagnostic logging: `log(value: i32)` and `log_str(offset: i32, len: i32)`.
- Timing functions: `uptime_ms()` and `delay_ms(ms: u32)`.
- Peripheral control: `gpio_write(pin: u32, value: u32)` and `gpio_read(pin: u32)`.

### Installation

To integrate the runner into a NuttX source tree, place this directory inside `apps/interpreters/` in your NuttX apps workspace.

You can create a symbolic link or copy the directory:

```bash
## From your NuttX workspace root:
ln -s /path/to/tinybird/platforms/nuttx/tinybird apps/interpreters/tinybird
```

Or copy the directory:

```bash
cp -r /path/to/tinybird/platforms/nuttx/tinybird apps/interpreters/tinybird
```

### Configuration

Enable the runner in your board configuration using `menuconfig` or `kconfig-tweak`:

```bash
## Ensure WAMR interpreter is enabled
kconfig-tweak --enable CONFIG_INTERPRETERS_WAMR

## Enable the Tinybird runner application
kconfig-tweak --enable CONFIG_INTERPRETERS_TINYBIRD
```

If you use `make menuconfig`, navigate to:

`Application Configuration` -> `Interpreter` -> `Tinybird WebAssembly Runner`

You can also adjust the default task priority, task stack size, and WebAssembly linear memory heap sizes under the configuration submenu.

### Building

Build NuttX with your standard toolchain:

```bash
cd /path/to/nuttx
make -j$(nproc)
```

The build system links `tinybird_main.c` against the WAMR runtime library and registers `tinybird` as an NSH built-in command.

### Usage in NuttShell

Copy your compiled `.wasm` files to a filesystem mounted on NuttX (such as `/data`, `/mnt/sd`, or a ROMFS partition).

#### Running Default Entry Points

Execute a module that defines `main()` or `_start()`:

```text
nsh> tinybird /data/hello.wasm
42
```

You can also use the explicit `run` subcommand:

```text
nsh> tinybird run /data/hello.wasm
42
```

#### Executing Exported Functions with Arguments

Use the `-f` flag to call an exported function with arguments:

```text
nsh> tinybird -f add /data/add.wasm 15 27
0x2a:i32
```

Or use the `run` subcommand syntax:

```text
nsh> tinybird run /data/add.wasm add 15 27
0x2a:i32
```

#### Overriding Memory Budgets

You can override the execution stack and heap sizes from the command line:

```text
nsh> tinybird --stack-size=32768 --heap-size=32768 /data/hello.wasm
42
```

#### Help and Version

Display help information and command options:

```text
nsh> tinybird --help
```

Display version information:

```text
nsh> tinybird --version
tinybird 0.1.0 (NuttX runner)
```
