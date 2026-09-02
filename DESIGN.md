# Roll the Reckoning — Design Doc

**Pitch:** Slay the Spire meets auto-battler. You play the villain — a god
summoning creatures through portals to pillage villages across a roguelike
island map.

## Core gameplay loop (current MVP scope)

CLASH is cut from the loop for now (still present in code as `Phase.CLASH`
but not part of the target experience).

1. **Roll dice → TYPE.** A 2d6 sum determines the unit drafted, mapped to a
   creature pool by rarity range (`SUM_TO_RANGE` in `Scripts/main.gd`):
   snake eyes (2) drafts from the boss pool, 3/4/10/11/12 draft rare, and
   5–9 draft common.
2. **Roll dice → QUANTITY.** A second roll sets how many of the unit are
   drafted, tinted by rarity (Common → Legendary), which also affects
   stats. Rarity is picked per-die via weighted odds in `Die.gd`
   (`RARITY_WEIGHTS`: 60/25/10/4/1 for Common/Uncommon/Rare/Epic/Legendary).
3. **Units march** across the track (`march_track` group, `Path2D` +
   `PathFollow2D`) — hoverable in the target UI for live stat info (e.g.
   "Skelebro: 3 dmg, 10 HP, but you've got 6").
4. **Units emerge from a portal** and pillage the village — kill
   villagers, destroy buildings, earn gold.
5. **Win condition:** destroy all buildings (small villages) or the castle
   (later, guarded villages).
6. **Chests** drop RNG-based trinkets (passive buffs) as you go.

## Meta-structure

- **Run layer:** Slay the Spire-style node map, alternating raid nodes and
  shop nodes. Gold is spent mid-run on dice, units, and trinkets. Each run
  starts with a small unit pool that grows via post-battle reward drops
  (choice of 3, dice-or-units).
- **Dice-as-cards:** a hand-of-5-dice system, drawn and selected like a
  deck — persistent or one-time-use dice, mirroring Slay the Spire's card
  economy but built from the existing physical dice-roll mechanic instead
  of bolting a card system on top.
- **Meta layer:** a pirate cove hub (click-through, not walked-around) that
  persistently unlocks new shops as you pillage more across runs, funded
  by "crowns" (earned per village or castle — still undecided which).

## What's strong about this design

- Everything routes through dice — type, quantity, rewards, even
  deckbuilding — so the identity stays coherent instead of feeling like
  separate systems duct-taped together.
- The portal is the best mechanical hook: it doubles as unit-delivery and
  the strategic layer (placement, maybe dual portal-gun-style swapping)
  once developed further.
- Cutting CLASH for MVP was the right call — the loop stays complete and
  winnable without it.

## Open questions

- **Loss condition is unresolved.** Design moved away from
  portal-destruction toward portal-placement strategy, but nothing
  currently makes the player capable of losing a raid. Worth revisiting
  once the core loop is running — the gap will show up in playtesting.
- **Portal mechanics:** portal-gun-style dual portals vs. hand-placed vs.
  hand-crafted-per-level — three real options still on the table, not
  decided.
- **Crowns' exact earn condition:** per village vs. castle-only.
- **Dice hand size, draw timing** (per roll-phase vs. per wave), and
  end-of-run deck size are unspecified.

## Implementation status (Godot project)

- `Scripts/main.gd` drives the TYPE → QUANTITY → (CLASH, currently
  unused) phase loop and unit drafting from dice sums.
- `Scripts/Die.gd` is a physics-based die (`RigidBody2D`) that flings,
  tumbles, settles, and reports `(value, rarity)`.
- `Scripts/DiceCountSelector.gd` is a drag-to-select pip-row UI for
  choosing dice count with no text, just lit/dimmed icons.
- `Scripts/unit_token.gd` is the marching unit visual (stick + icon,
  bobbing animation) that rides a `Path2D` march track.
- `scenes/` has `main.tscn`, `battle_ui.tscn`, and `village.tscn` as the
  current scene scaffolding.
- Art/audio assets: Tiny Swords packs (`Tiny/`) for units/buildings/terrain,
  a cute-dice asset pack and d4/d6/d8/d10/d12/d20 roll SFX (`dice/`).
