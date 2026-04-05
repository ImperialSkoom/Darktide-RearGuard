# RearGuard

RearGuard is a Warhammer 40,000: Darktide mod for the Darktide Mod Framework (DMF).

It listens for Darktide's melee backstab warning audio and automatically performs a defensive response for you.

## Features

- Reacts to the melee backstab warning sound.
- Supports `Block`, `Dodge`, or `Both` response modes.
- Briefly holds block instead of locking the input down.
- Queues a single dodge when dodge response is enabled.
- Uses special-action input for combat sword parry behavior when appropriate.
- Includes optional in-mission keybinds to toggle the mod and cycle response modes.
- Lets you tune block delay, block hold duration, dodge delay, dodge queue duration, and retrigger cooldown.
- Can optionally suppress itself while sprinting.

## Requirements

- Warhammer 40,000: Darktide
- Darktide Mod Framework (DMF)

## Installation

1. Copy the `RearGuard` folder into your Darktide `mods` directory.
2. Add `RearGuard` to `mod_load_order.txt`.
3. Launch the game with DMF enabled.

## Settings

### Global Settings

- `Enable Mod`
- `Toggle Mod Keybind`
- `Suppress While Sprinting`

### Response Settings

- `Response Mode`
  - `Block`
  - `Dodge`
  - `Both`
- `Cycle Response Mode Keybind`

### Timing Settings

- `Block Delay`
- `Block Hold Duration`
- `Dodge Delay`
- `Dodge Queue Duration`
- `Retrigger Cooldown`

## Notes

- RearGuard only reacts to Darktide's melee backstab warning events.
- Combat swords can use the weapon special/parry input instead of the normal block-hold path when needed.

## Repository Layout

```text
RearGuard/
|-- RearGuard.mod
|-- README.md
`-- scripts/
    `-- mods/
        `-- RearGuard/
            |-- RearGuard.lua
            |-- RearGuard_data.lua
            `-- RearGuard_localization.lua
```
