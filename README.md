# Modulo ItemSlot 1.0.0

A lightweight, configurable equipment-slot and trinket swap bar for World of Warcraft Forever. Modulo ItemSlot is an optional child addon in the MODULO suite.

## Requirements

- World of Warcraft Forever client (tested on client interface `16001`, build `70938`).
- MODULO installed and enabled. ItemSlot is an optional dependent addon; MODULO does not depend on ItemSlot.

## Installation

1. Download Modulo ItemSlot 1.0.0 (https://github.com/moonlitfarewell/modulo-itemslot-releases/raw/refs/heads/main/Modulo-ItemSlot-1.0.0.zip).
2. Extract the `ModuloItemSlot` folder into your WoW `_classic_era_/Interface/AddOns/` directory (use the AddOns directory for your client installation).
3. Ensure the folder layout is `.../AddOns/ModuloItemSlot/ModuloItemSlot.toc`.
4. Enable **Modulo ItemSlot** in the AddOns list. Ensure MODULO is also enabled.

## Features

- One movable bar with independently enabled equipment slots, including separate Ring 1/2 and Trinket 1/2 destinations.
- Horizontal and vertical bar layouts; slot flyouts open perpendicular to the bar.
- Equipped-item icons or Blizzard's empty-slot artwork.
- Icon-only compatible-item flyouts with full tooltip, name-only tooltip, or no tooltip.
- Item selection swaps into the exact destination inventory slot.
- Position and preferences persist between sessions.
- Native Blizzard Settings category.
- Independent cooldown overlays for each equipped slot, including separate Trinket 1 and Trinket 2 cooldowns.
- Event-driven updates and on-demand cached bag discovery; no periodic polling loop.

## Commands

- `/mis` or `/mis toggle` — show or hide the bar.
- `/mis settings` — open the settings category.
- `/mis reset` — restore defaults.
- Hold **ALT** and drag the bar or a slot button to move it.

## Behaviour and limitations

- Equipment swapping is unavailable during combat because the required pickup/equipment APIs are protected by the client.
- MODULO is a required dependency. This is a standalone public repository for the ItemSlot addon folder, not a standalone replacement for MODULO.

## Compatibility and testing

- Forever client interface `16001`, build `70938`: player-installed and confirmed working for the 0.6.1 source state promoted in this release, including equipment swapping, independent trinket cooldown indicators and the 0.6.1 efficiency changes.
- Retail interface `120105`: manifest declares the interface, but Retail runtime acceptance is not claimed.
- Automated checks in the release handoff: Lua syntax checks for both source files, archive integrity and extracted-layout verification.

## License

MIT. See [LICENSE](LICENSE).
