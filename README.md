# ZeroPoint Game Template

A small game for the ZeroPoint console, built on the C layers library: two scrolling tile layers, sprites, a text box. Put your own PNGs in
`assets/`, run `make`, get a signed ROM that boots on the real Boot ROM.

```
src/main.c          the game: what moves, when (C, builds with zpcc and with def88186cc)
assets/             art: *.png and assets.json, which says what each image is (see below)
tools/make_art.py   draws the sample art; you will not need it once you have your own
Makefile            PNGs -> assets, C -> ROM, sign
```

## Build and run

You need the toolchain built (`make` in ZPdevtools, `llvm_compiler/` and/or `c_compiler/`), python3 with Pillow, and the emulator.

```sh
make                          # build/game.zpb with zpcc (clang); signed with the dev key
make CC=dos                   # the same with def88186cc (BUILD=build-dos keeps both)
make run                      # zeropoint_sdl build/game.zpb
make elf                      # build/game.elf, the unsigned link: what you submit to HQ to ship
make ASSETS=other-art         # take assets.json and the PNGs from another directory
```

This repo is the submodule `game-template` of ZPdevtools, so `ZPDEV` (the toolchain checkout) defaults to `..`. Copied out to a project of your
own, say where it is: `make ZPDEV=/path/to/ZPdevtools`. The emulator is found next to ZPdevtools (`../ZeroPoint/build/bin/zeropoint_sdl`) or on
`PATH`; override with `EMU=`.

## The art

`assets/assets.json` lists the images; `scripts/png2zp.py` in ZPdevtools converts them (full reference: `docs/tools/png2zp.md` there):

| In `assets.json` | Image | Becomes |
|---|---|---|
| `bg0` | any size up to 512x512, **opaque** | the back scrolling layer (tile bank 0) |
| `bg1` | up to 512x512, transparent where the layer is see-through | the front layer (bank 2); or `"tiled"`: a Tiled `.tmj` map |
| `sprites` | one PNG each, `frame_w`/`frame_h` in tiles for sheets | sprite cells (bank 1) and `ASSET_SPR_<NAME>_*` constants |
| `font`, `frame`, `boxes` | an 8x8-glyph sheet, a border tile; text in the JSON | window text boxes (bank 3) |

Rules of thumb: **indexed-colour PNGs** (or `--quantize`), image sizes in multiples of 8, at most **240 opaque colours** across the whole game,
at most 256 different tiles per layer (identical tiles are stored once, `"flips": true` also folds mirror images). Transparency is PNG transparency.
Swap `ground.png`, `make`, and the picture changes; no C changes.

## The code

`src/main.c` is the whole loop: load palette, tiles, maps and cells (`zpl_*_load` with the `ASSET_*` addresses from the generated
`build/assets.h`), place sprites, `zpl_start()`, then every frame move things, `zpl_scroll`, `zpl_frame()` (waits for the 60 Hz tick and sends the
frame). The library (`zp_layers.h`, `zp_pad.h`) is documented in `docs/sdk/README.md` in ZPdevtools. Notes that matter:

- The C compilers have no writable globals, `typedef`/`static`/`const`, or struct values (`def88186cc`); `main` is written `int main()`. Build
  with both compilers now and then, `make CC=dos`.
- Tiles are uploaded before `zpl_start()` only. Maps and sprite cells are read as drawn.
- A ROM over a few KB must be signed with `--codesize N --trailer 2` or the real Boot ROM hashes it in software and never finishes; the Makefile does it.
- Test on the real Boot ROM (`zeropoint_sdl --boot ...`), not only the native boot: it hands off in a different machine state.

ZPdevtools' `tests/layers/run.sh` builds this repo with both compilers, runs it on the native boot and the real Boot ROM, and compares frames
pixel for pixel against the sample art (so it expects the sample art; your own game needs its own checks).

## Signing

`zplink` holds no key: it only emits the ELF. `zpbuild` signs the ELF into a `.zpb` with the bundled **development** key, which the emulator trusts.
Real hardware only trusts HQ-signed ROMs, so to ship you submit `build/game.elf` (`make elf`), not the locally signed `.zpb`.
