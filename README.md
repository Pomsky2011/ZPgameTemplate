# ZeroPoint Game Template

A minimal, buildable skeleton for a ZeroPoint game. Copy it, edit the sources
and the `PROJECT` block in the `Makefile`, and `make` produces a signed ROM the
emulator can load.

This repo is also vendored into the [ZPdevtools](../ZPdevtools) toolchain as a
git submodule at `ZPdevtools/game-template`, so the default toolchain paths in
the `Makefile` point one level up at `../executables` and `../c_compiler`. If
you copy this template out to a project of your own, point the tools at your
ZPdevtools checkout instead:

```sh
make ZPTOOLS=/path/to/ZPdevtools/executables ZPCC=/path/to/ZPdevtools/c_compiler/def88186cc
```

## Layout

```
cpu/main.asm       DEF88186 CPU program (entry point). May be main.c instead — def88186cc compiles it.
ppu/graphics.asm   PPU microcode (optional — blank PPU_SRC to omit).
apu/audio.asm      APU program (optional — blank APU_SRC to omit).
Makefile           Drives the ZPdevtools toolchain. Edit the PROJECT block.
```

## Building

```sh
make            # assemble + link + sign  -> build/<ROM>.zpb   (loadable in the emulator)
make elf        # dev link only           -> build/<ROM>.elf   (submit THIS to HQ to ship)
make clean
make help       # full option list
```

The link path: `cpuasm/ppuasm/apuasm` → `zplink` (ELF) → `zpbuild` (signed `.zpb`).

## Running

```sh
zeropoint_sdl build/<ROM>.zpb      # or the Qt / Vulkan frontend
```

## Signing, in one paragraph

`zplink` holds no key — it only emits the ELF. `zpbuild` turns that ELF into a
signed `.zpb`; locally it uses the bundled **development** key, so `make`
produces a ROM the emulator trusts for testing. Real hardware only trusts
**HQ-signed** ROMs, so to ship you submit `build/<ROM>.elf` (from `make elf`),
not a locally-signed `.zpb`.

## Options

Everything is overridable on the command line — see `make help`. The common ones:

| Var | Default | Meaning |
|-----|---------|---------|
| `ROM` `TITLE` `DEV` | `game` / `My ZeroPoint Game` / `ZP` | output name + embedded metadata |
| `CPU_SRC` `PPU_SRC` `APU_SRC` | `cpu/main.asm` etc. | component sources (`.asm` or `.c` for CPU) |
| `ENTRY` `CPU_BASE` `PPU_BASE` `APU_BASE` | console memory map | load addresses |
| `PLATFORM` | `unix` | `dos` / `windows` (`.exe` tools) |
| `ZPTOOLS` `ZPCC` | `../executables`, `../c_compiler/def88186cc` | toolchain locations |
