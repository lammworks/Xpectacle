# Migrating from Spectacle to Xpectacle 2026

## What carries over automatically

On first launch, `LegacyImporter` looks at:

1. `defaults` domain `com.divisiblebyzero.Spectacle` — the canonical Spectacle storage.
2. `~/Library/Application Support/Spectacle/Shortcuts.json` — used by Spectacle's later versions when JSON storage was enabled.

For each Spectacle `WindowAction` identifier (`MoveToLeftHalf`, `MoveToUpperRight`, etc.), the keyCode + modifier flags are read out of the archived `SpectacleShortcut` and registered with `KeyboardShortcuts` under `Xpectacle.<identifier>`.

The importer is one-shot, gated on the absence of `~/Library/Application Support/Xpectacle/settings.json`. Reset that file to re-import.

## Behavior parity

| Spectacle feature | Xpectacle 2026 equivalent |
|---|---|
| Halves / corners / fullscreen / center | Same `WindowAction` enum cases, same geometry math (1:1 port) |
| Thirds with cycling | `nextThirdHorizontal` / `nextThirdVertical` + `ThirdsCycler` state |
| Make larger / smaller | `largerLeft` / `smallerLeft` etc, 30 px step preserved |
| Move to next/prev display | `nextDisplay` / `previousDisplay` with proportional rescale |
| Undo / redo | `UndoStack` per-window, 16-entry ring buffer |
| Disable for app | `Settings.disabledBundleIDs` (UI surface to come) |
| Disable for 1 hour | Removed; rebuild as a Focus mode integration if needed |

## What changed intentionally

- **Storage moves from NSUserDefaults to JSON** at `~/Library/Application Support/Xpectacle/settings.json`. Plain text, easy to back up, easy to sync.
- **Hotkey engine** swapped from PTHotKey (Carbon RegisterEventHotKey) to `sindresorhus/KeyboardShortcuts`. Identical UX, modern Swift API.
- **Sparkle 1.22 → Sparkle 2** with EdDSA. Generate a new key pair, host appcast on the project site.
- **Bundle identifier**: `com.divisiblebyzero.Spectacle` → `com.xpectacle.Xpectacle`. Both apps can coexist during transition.
