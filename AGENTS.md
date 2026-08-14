# AGENTS.md

This file guides coding agents that work on this repository.

## Mission

This repository is a template for microcontroller projects written in Zig.
It builds firmware with MicroZig and targets the Raspberry Pi Pico 2 out of the box.
Priorities, in order:

1. A working template: the host tests pass, the firmware builds to a UF2, and the blinky runs on the real board.
2. Reproducible setup: the pinned Zig and MicroZig versions, the Nix dev shell, and the uv-managed Python tools define the whole environment, so a
   fresh clone builds without surprises.
3. A clean split between `src/core/` and `src/firmware/`, so projects made from this template keep their logic testable on the host.

## Hardware

- The default target is the Raspberry Pi Pico 2 (RP2350, Arm Cortex-M33). The blinky drives GPIO 25, which is the onboard LED on the plain Pico 2.
  On the Pico 2 W the onboard LED hangs off the wireless chip, so an external LED on GPIO 25 is needed there.
- The board connects over USB to a Linux development machine, on either amd64 or arm64.

## Version Pins

- Zig is pinned to 0.17.0, supported by MicroZig 0.17.20.
- MicroZig is pinned to the 0.17.20 release in `build.zig.zon`.
- Upgrading both together touches four places: the dependency URL and hash in `build.zig.zon`, the Zig paths in the `Makefile`, the Zig version in
  the workflows under `.github/workflows/`, and the version badges in `README.md`.

## Core Rules

- Use English for code, comments, docs, and tests.
- Prefer small, focused changes over large refactoring.
- Add comments only when they explain something the code does not show.
- This is a template, so keep it minimal: no features, abstractions, or dependencies beyond what shows the pattern. A new `build.zig.zon` dependency
  needs prior discussion.
- Do not flash a board or open its serial port without being asked. The user may be using the board.

## External Dependencies

- MicroZig comes through `build.zig.zon` and is the only Zig dependency.
- Python tools (pre-commit) are managed by uv through `pyproject.toml`. Run them as `uv run pre-commit`. Do not install Python tools with pip into
  the system interpreter.
- Everything else (the Zig compiler, picotool, picocom, kcov) comes from the Nix dev shell in `flake.nix`. Enter it with `nix develop` or
  `make shell`. On a Debian-based system without Nix, `make install-deps` installs a partial set with apt.

## Repository Layout

- `src/core/core.zig`: the hardware-free logic. It must stay freestanding-safe: no allocation, no I/O, and no OS calls, so the same code compiles
  for the host tests and for the firmware.
- `src/firmware/main.zig`: the firmware entry point. It uses the MicroZig HAL and imports `core`.
- `tests/main.zig`: host-side tests that exercise `core` from the outside.
- `build.zig`: the host test steps first, then the MicroZig firmware. Keep that order, so the host tests still run when a port dependency is
  missing.
- `docs/`: documentation and assets; `docs/api/` is generated and never committed.
- `.github/workflows/`: CI workflows for checks, tests, coverage, and docs.
- `Makefile`: developer tasks; run `make help` to list them.

## Building and Flashing

All commands run inside the Nix dev shell:

1. `make test` runs the host-side tests; no board is needed.
2. `make build` builds the firmware and installs `zig-out/firmware/blinky.uf2`.
3. `make flash` loads the UF2 onto the Pico 2 over USB with picotool. Copying the UF2 to the board in BOOTSEL mode also works.

Serial access needs membership in the `dialout` group on most Linux distributions (some use `uucp` instead).

## Adding a Board

- Enable the chip family's port in the `MicroBuild` selection at the top of `build.zig`, and pick a target from `mb.ports`.
- Add a second `add_firmware` call rather than editing the existing one, so the template keeps a known-good reference.
- Keep board-specific code inside `src/firmware/`; nothing about a board may leak into `src/core/`.

## Testing

The logic in `src/core/` is tested on the host, and those tests follow the red-green cycle: write the test, watch it fail for the expected reason,
then make it pass. Tests live in two places: inside `core.zig` for internals, and in `tests/main.zig` for the exported surface.

Firmware behavior cannot fail in CI, so it is verified by flashing the real board and watching the LED. A change to `src/firmware/` is not done
until that has happened.

## Writing Style

- Write plain, simple English, in docs and in code comments alike. Use short sentences and everyday words. Keep every fact, name, number, link, and
  file path when you rewrite prose.
- Keep Markdown structure when you rewrite: headings, lists, tables, and links. Do not change fenced code blocks or YAML frontmatter; reproduce them
  exactly.
- Use Oxford commas in inline lists: "a, b, and c" not "a, b, c".
- Do not use em dashes, in documentation or in code comments. Restructure the sentence, or use a colon or semicolon instead.
- Avoid colorful adjectives and adverbs. Write "rate limiter" not "smart rate limiter".
- Prefer noun phrases for checklist items over imperative verbs. Write "rate limit enforcement" not "enforce rate limits".
- Headings in Markdown files must be in title case: "Build from Source" not "Build from source". Minor words stay lowercase unless they are the first
  word: the articles (a, an, the), the coordinating conjunctions (and, but, or, nor, so, yet, for), and the short prepositions (in, on, at, to, by,
  of, up, as, from, with, into, over). The prepositions are named because "from" has to be lowercase for "Build from Source" to be correct.
- Do not bold the lead-in of a list item. Write "Unit tests: ..." not "**Unit tests**: ...".
- Use sentence case for the lead-in of a list item. Write "Seed selection: ..." not "Seed Selection: ...". Proper nouns keep their capitals.
- Capitalize only the first part of a hyphenated compound: "Real-time Scheduling" in a heading, "Real-time" at the start of a sentence, and
  "real-time scheduling" elsewhere. Never write "Real-Time".
- Start each sentence with a capital letter, capitalize proper nouns (Zig, MicroZig, RP2350, Arm, GPIO), and leave common nouns lowercase in the
  middle of a sentence.
- Write correct and complete sentences.
- Avoid made-up words.
- Do not use a colon in place of a verb. Three uses are fine: joining two clauses inside a complete sentence (the replacement the em-dash rule above
  calls for), introducing the gloss of a list item, and introducing an enumeration, whether as a list or inline ("Targets: `make test`,
  `make build`, ..."). What a colon must not do is turn a sentence into a label and a definition: write "Loads the firmware onto the board over USB"
  rather than "Flashing: loads the firmware onto the board". That shape belongs to a list item. Carrying it into prose (a doc comment summary, a
  paragraph) leaves a fragment where a sentence was required.
- Use participial phrases and abbreviations scarcely.

## Validation

Before committing a change:

1. `make format` leaves no diff, and `make lint` passes.
2. `make test` passes on the host.
3. `make build` produces the UF2.
4. `make test-hooks` passes.
5. If the change touches `src/firmware/` or the MicroZig pin, the firmware was flashed and seen running on the real board, and the commit message
   says so.

## Commit Hygiene

- Keep commits scoped to one logical change.
- A version bump of Zig or MicroZig is its own commit, touching all four places the Version Pins section lists.
