/*
 * A small game on the layers library (ZPdevtools/include/zeropoint/zp_layers.h): two scrolling layers (a sky and a ground on BG0, clouds,
 * bushes and trees on BG1 at twice the speed), a hero you move with the pad that draws over everything, a bird that flies BETWEEN the two
 * layers so the clouds pass in front of it, and a text box in the window layer, which never scrolls.
 *
 * The hero is also the save-RAM demo: the cartridge has 1 KB of battery-backed save RAM (the Makefile asks zpbuild for it), and the game keeps the
 * hero's position there, so it starts where you left it. See ZPdevtools/include/zeropoint/zp_save.h; the emulator keeps the bytes in build/game.sav.
 *
 * The art is not in this file: assets/*.png become build/assets.h (where each piece sits in ROM, and its size) through assets/assets.json.
 * Swap a PNG and rebuild; only a change in what the game DOES needs a change here.
 *
 * Builds with both C compilers (see the Makefile):   make          (zpcc)       make CC=dos      (def88186cc)
 */
#include <zeropoint/zeropoint.h>
#include <zeropoint/zp_layers.h>
#include <zeropoint/zp_save.h>
#include "assets.h"

#define HERO_W (ASSET_SPR_HERO_W * 8)
#define HERO_H (ASSET_SPR_HERO_H * 8)

/* def88186cc has no '(void)' parameter list, so write main as main(). */
int main()
{
    int x, y, t, bx, sx, sy;
    zpu8 sav[2];

    /* The microcode sits in ROM at $10:0000 (the Makefile places it there), LAYERS_PAGES pages of 256 bytes. */
    zpl_init(0x10, 0x0000, LAYERS_PAGES);

    /* Everything the PPU draws from goes in before zpl_start(). The tile banks have fixed jobs: 0 is BG0 (opaque), 1 the sprites, 2 BG1
     * (see-through) and 3 the window (font and frame). */
    zpl_palette_load(ASSET_PAL);
    zpl_tiles_load(0, 0, ASSET_TILES0, ASSET_TILES0_N);
    zpl_tiles_load(1, 0, ASSET_TILES1, ASSET_TILES1_N);
    zpl_tiles_load(2, 0, ASSET_TILES2, ASSET_TILES2_N);
    zpl_tiles_load(3, 0, ASSET_TILES3, ASSET_TILES3_N);
    zpl_cells_load(0, ASSET_CELLS, ASSET_CELLS_N);          /* the sprite cells: the hero's, then the bird's */
    zpl_map_load(0, ASSET_MAP0);
    zpl_map_load(1, ASSET_MAP1);

    /* The text box: at column 2, row 26 of the 32 x 32 window grid. Solid: the PPU leaves out the background under it. */
    zpl_window_box(ZPL_BOX_SOLID, 2, 26, ASSET_BOX_MSG_W, ASSET_BOX_MSG_H, zpl_window_cells_load(ASSET_BOX_MSG, ASSET_BOX_MSG_N));

    /* Sprite slots draw in order, later over earlier. The bird is PRIO_MID: in front of BG0, behind BG1. */
    x = 120;
    y = 136;
    /* Two slots of 16 bytes at the start of the save RAM hold the hero's x and y. Nothing is stored in a new cartridge: keep the defaults. */
    if (zp_save_load(0UL, 16, sav, 2)) {
        x = sav[0];
        y = sav[1];
    }
    sx = x;
    sy = y;
    zpl_sprite_set(1, 0, 36, ASSET_SPR_BIRD_W, ASSET_SPR_BIRD_H, ASSET_SPR_BIRD_CELL, ZPL_SPR_PRIO_MID);
    zpl_sprite_set(0, x, y, ASSET_SPR_HERO_W, ASSET_SPR_HERO_H, ASSET_SPR_HERO_CELL, 0);

    zpl_start();

    t = 0;
    for (;;) {
        x = x + 2 * zp_pad_dx(0);
        y = y + 2 * zp_pad_dy(0);
        if (x < 0) x = 0;
        if (x > 256 - HERO_W) x = 256 - HERO_W;
        if (y < 8) y = 8;
        if (y > 208 - HERO_H) y = 208 - HERO_H;
        zpl_sprite_move(0, x, y);

        bx = (t * 2) % 288 - 16;                             /* the bird crosses the screen and wraps */
        zpl_sprite_move(1, bx, 36 + ((t >> 3) & 7));

        zpl_scroll(0, t >> 1, 0);                            /* BG0 at half speed: the ground... */
        zpl_scroll(1, t, 0);                                 /* ...BG1 at full: clouds and bushes in front of it */
        t = t + 1;

        if (t % 60 == 59 && (x != sx || y != sy)) {          /* once a second, if the hero moved: write the position down */
            sav[0] = (zpu8)x;
            sav[1] = (zpu8)y;
            zp_save_store(0UL, 16, sav, 2);
            sx = x;
            sy = y;
        }

        zpl_frame();                                         /* wait for the 60 Hz tick, then send the frame */
    }
}
