# ZeroPoint game template: C game on the layers library, art from PNGs.
#
#   make              # build/game.zpb with zpcc (the clang compiler), signed with the dev key
#   make CC=dos       # the same with def88186cc (-DZP_CC_DOS); use BUILD=build-dos to keep both
#   make run          # zeropoint_sdl build/game.zpb
#   make elf          # build/game.elf: the unsigned link, what you submit to HQ to ship
#   make ASSETS=dir   # take assets.json and the PNGs from another directory
#   make clean
#
# ZPDEV is the toolchain checkout (executables/, include/, lib/, scripts/, ucode/, llvm_compiler/, c_compiler/, all built: `make` in each).
# Inside ZPdevtools this repo is the submodule game-template, so the default is `..`; copied out, say where it is:
#   make ZPDEV=/path/to/ZPdevtools
# Needs python3 with Pillow (png2zp reads the PNGs).
ZPDEV  ?= ..
BIN     = $(ZPDEV)/executables
CC     ?= zpcc
EMU    ?= $(firstword $(wildcard $(ZPDEV)/../ZeroPoint/build/bin/zeropoint_sdl) zeropoint_sdl)
BUILD  ?= build
ASSETS ?= assets

GAME   ?= game
TITLE  ?= MY ZEROPOINT GAME
DEV    ?= ZP

# Where things sit in ROM: the CPU program, the layers microcode and the converted art.
CPU_BASE    = 0x8000
LAYERS_BASE = 0x100000
ASSETS_BASE = 0x110000

ifeq ($(CC),dos)
  COMPILE = $(ZPDEV)/c_compiler/def88186cc -DZP_CC_DOS
else
  COMPILE = $(ZPDEV)/llvm_compiler/zpcc
endif

all: $(BUILD)/$(GAME).zpb
elf: $(BUILD)/$(GAME).elf

# the microcode, padded to whole 256-byte pages (the Boot ROM loader copies pages); LAYERS_PAGES says how many
$(BUILD)/layers.bin: $(ZPDEV)/ucode/layers/gen_layers.py
	mkdir -p $(BUILD)
	python3 $< -o $(BUILD)/layers.raw > /dev/null
	python3 -c "d=open('$(BUILD)/layers.raw','rb').read(); d+=bytes(-len(d)%256); open('$@','wb').write(d); open('$(BUILD)/pages.txt','w').write(str(len(d)//256))"

# assets/*.png (and Tiled maps) -> build/assets.bin + build/assets.h, driven by assets/assets.json
$(BUILD)/assets.bin $(BUILD)/assets.h: $(ASSETS)/assets.json $(filter-out $(ASSETS)/assets.json,$(wildcard $(ASSETS)/*)) $(ZPDEV)/scripts/png2zp.py
	python3 $(ZPDEV)/scripts/png2zp.py $(ASSETS)/assets.json -o $(BUILD) --rom-base $(ASSETS_BASE)

$(BUILD)/main.asm: src/main.c $(BUILD)/assets.h $(BUILD)/layers.bin $(wildcard $(ZPDEV)/include/zeropoint/*.h)
	$(COMPILE) -DLAYERS_PAGES=$$(cat $(BUILD)/pages.txt) -I $(ZPDEV)/include -I $(BUILD) src/main.c -o $@

# crt0 (the entry stub), the compiled program, then the runtime it calls (peek/poke, COP, 32-bit arithmetic)
$(BUILD)/$(GAME).asm: $(BUILD)/main.asm
	printf '.org $(CPU_BASE)\n.include "$(abspath $(ZPDEV))/lib/crt0_entry.asm"\n.include "$(abspath $<)"\n.include "$(abspath $(ZPDEV))/lib/zp_mmio.asm"\n.include "$(abspath $(ZPDEV))/lib/zp_cop.asm"\n.include "$(abspath $(ZPDEV))/lib/zp_long.asm"\n' > $@

$(BUILD)/$(GAME).bin: $(BUILD)/$(GAME).asm
	$(BIN)/cpuasm $< $@

$(BUILD)/$(GAME).elf: $(BUILD)/$(GAME).bin $(BUILD)/layers.bin $(BUILD)/assets.bin
	$(BIN)/zplink -o $@ --cpu $(BUILD)/$(GAME).bin@$(CPU_BASE) --ppu $(BUILD)/layers.bin@$(LAYERS_BASE) --data $(BUILD)/assets.bin@$(ASSETS_BASE) --entry $(CPU_BASE)

# zpbuild signs the ELF into a .zpb with the bundled dev key (a ROM the emulator loads; real hardware only trusts HQ's key: ship the .elf).
# --codesize N --trailer 2: the console's BLAKE2s engine hashes the whole ROM at boot in a fraction of a second. Without them the real Boot ROM
# hashes the ROM in software, which for a ROM this size never finishes (the lightning splash stays up for good). N covers the CPU program.
$(BUILD)/$(GAME).zpb: $(BUILD)/$(GAME).elf
	$(BIN)/zpbuild $< -o $@ --title "$(TITLE)" --dev "$(DEV)" --codesize $$(python3 -c "import os; print(($(CPU_BASE) + os.path.getsize('$(BUILD)/$(GAME).bin') + 255) // 256 * 256)") --trailer 2

run: $(BUILD)/$(GAME).zpb
	$(EMU) $<

clean:
	rm -rf $(BUILD)

help:
	@sed -n '2,13p' Makefile

.PHONY: all elf run clean help
