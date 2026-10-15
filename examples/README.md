## Tinybird Application Examples

Build the examples with `zig build examples`.
The Wasm files are stored in `zig-out/examples/`.
Each module has a 4 KB stack, 64 KB initial linear memory, and a 128 KB memory limit so it fits on the Pico 2.

### Host Execution

```shell
./zig-out/bin/tinybird run zig-out/examples/add.wasm add 15 27
./zig-out/bin/tinybird run zig-out/examples/hello.wasm
```

### NuttX Execution

With WAMR enabled in NuttX, transfer `add.wasm` to `/data` and run:

```text
nsh> iwasm -f add /data/add.wasm 15 27
0x2a:i32
```

This returned 42 on a Pico 2 after a serial file transfer without reflashing.
The `hello.wasm` example requires the runner to register `tinybird.log`.
The Tinybird host runner provides it; the tested NuttX `iwasm` runner does not.

[!NOTE]
> The instructions here assume that the NuttX image [from this project](https://github.com/habedi/microcontroller-playground) is on the Pico 2 board.
