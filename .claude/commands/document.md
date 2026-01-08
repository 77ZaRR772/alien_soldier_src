# Document Procedures Skill

Documents a batch of assembly procedures by analyzing their code and creating rename mappings.

## Trigger

Use `/document` or `/document COUNT` to document procedures.

## Workflow

1. Read `workflow/batch_procedures.txt` (created by `make prepare-batch`)
2. Analyze each procedure's code and context
3. Create `workflow/rename_batch.csv` with new names

## Instructions

When this skill is invoked:

### Step 1: Check Prerequisites

Verify `workflow/batch_procedures.txt` exists. If not, tell user to run:
```bash
make prepare-batch COUNT=40
```

### Step 2: Read Batch File

Read `workflow/batch_procedures.txt` which contains:
- Procedure code listings
- Scene and frame context
- Memory change indicators (RAM, VDP, Z80, YM2612, PSG)
- Visual diff paths

### Step 3: Analyze Each Procedure

For each procedure, determine:

1. **What it does** - Read the assembly code
2. **Category** - Based on operations:
   - `Gfx_` - VDP registers, VRAM writes, DMA, palettes
   - `Sys_` - System init, main loop, memory clear
   - `Sound_` - Z80, audio, YM2612, PSG
   - `Input_` - Controller reading
   - `Physics_` - Movement, collision
   - `Sprite_` - Sprite table, OAM
   - `Anim_` - Animation frames
   - `Effect_` - Visual effects
   - `Player_` - Player logic
   - `Boss_` - Boss AI
   - `Enemy_` - Enemy AI
   - `UI_` - HUD, menus, text
   - `Math_` - Calculations, RNG
   - `Stage_` - Level logic
   - `Object_` - Game objects
   - `Data_` - Data processing, decompression

3. **Descriptive name** - Action-oriented: `Category_VerbNoun`
   - Good: `Gfx_LoadTilesToVRAM`, `Player_CheckDeath`
   - Bad: `DoStuff`, `Process`, `Handler`

### Step 4: Create CSV

Create `workflow/rename_batch.csv`:

```csv
old_name,new_name,description
sub_1234,Gfx_LoadSegaTiles,Loads Sega logo tiles to VRAM via DMA
loc_5678,Sys_MainLoop,Main game loop that calls update routines
```

Rules:
- First line must be header: `old_name,new_name,description`
- Use double quotes around descriptions with commas
- No duplicate new_name values
- Names must be valid assembly labels (alphanumeric + underscore, start with letter)

### Step 5: Summary

Report:
- Total procedures documented
- Categories breakdown (how many Gfx_, Sys_, etc.)
- Any uncertain procedures that need human review

## Naming Heuristics

### Code Patterns → Categories

| Pattern | Category |
|---------|----------|
| `move.* (VDP_CTRL)` | `Gfx_` |
| `move.* (VDP_DATA)` | `Gfx_` |
| `jsr.*DMA` | `Gfx_` |
| `move.* (Z80_*)` | `Sound_` |
| `move.* (YM2612_*)` | `Sound_` |
| `move.* (IO_DATA*)` | `Input_` |
| `move.* (word_FFF7*)` | `Input_` (controller state) |
| `jsr.*Random` | `Math_` |
| `clr/move (word_FF*)` | RAM variable access |
| `rts` only | Short helper or stub |

### Scene Context → Naming

| Scene | Likely Content |
|-------|----------------|
| `Sega screen` | Init, logo, system setup |
| `Title screen` | Menu, options, UI |
| `Stage *` | Gameplay, enemies, player |
| `Boss *` | Boss AI, attacks |
| `Results` | Score, UI |

## Example Analysis

```
Procedure: sub_4BA
Scene: Sega screen
Code:
    move.w  #$8F02,(VDP_CTRL).l
    move.l  #$40000003,(VDP_CTRL).l
    lea     (TilesData_Sega).l,a0
    move.w  #$2000,d0
    jsr     (Gfx_DMATransfer).l
    rts

Analysis:
- Sets VDP auto-increment ($8F02)
- Sets VRAM write address
- Loads Sega tiles address
- Transfers 8KB via DMA
- Category: Gfx_
- Name: Gfx_LoadSegaLogoTiles
- Description: Loads Sega logo tile graphics to VRAM via DMA

CSV entry:
sub_4BA,Gfx_LoadSegaLogoTiles,Loads Sega logo tile graphics to VRAM via DMA
```

## After Completion

Tell the user to run:
```bash
make rename                   # Apply renames
make build && make compare    # Verify ROM unchanged
git add alien_soldier_j.s && git commit
```
