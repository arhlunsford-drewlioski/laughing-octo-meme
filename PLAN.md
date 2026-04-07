# Goals & Goblins - Engine Rewrite Plan

## Vision
Roguelike soccer game. You're a dark sorcerer commanding 6 goblins vs 6 opponent goblins in real-time matches. 14 goblins per run - if they die, they're gone. Between matches: shop, level up survivors, manage injuries, curate spell/item deck. Top-down 2D vector art with procedural goblin appearances.

---

## STAT SYSTEM (Hexagon Display)

Six stats, 1-10 scale:

| Stat | What it does |
|------|-------------|
| **Shooting** | Goal conversion, accuracy, finishing |
| **Speed** | Movement, closing down, runs, transitions |
| **Defense** | Tackling, interception, positioning |
| **Strength** | Physical duels, holding ball, aerials, shot blocking |
| **Health** | Stamina/durability through a run, injury resistance |
| **Chaos** | Random factor - brilliant or terrible, wider outcome range |

Keeper is a position, not a stat. High Strength + High Defense = good keeper.

---

## POSITIONS

### Base (2 strong stats)

| Position | Primary | Secondary |
|----------|---------|-----------|
| **Striker** | Shooting | Speed |
| **Winger** | Speed | Chaos |
| **Midfielder** | Defense | Speed |
| **Keeper** | Strength | Defense |

### Hybrids (3 strong stats, unlocked through progression)

| # | Position | Stats | Identity |
|---|----------|-------|----------|
| 1 | **False Nine** | Shooting + Chaos + Strength | Drops deep, holds ball, unpredictable |
| 2 | **Attacking Mid** | Shooting + Speed + Defense | Complete player, scores and tracks back |
| 3 | **Sweeper** | Defense + Strength + Speed | Last line, intercepts everything |
| 4 | **Target Man** | Shooting + Strength + Health | Tank, holds ball up, wins headers |
| 5 | **Box-to-Box** | Defense + Speed + Health | Tireless, covers the whole pitch |
| 6 | **Playmaker** | Chaos + Speed + Shooting | Creative genius, occasional disaster |
| 7 | **Enforcer** | Defense + Strength + Chaos | Dirty tackles, intimidation, red card risk |
| 8 | **Shadow Striker** | Shooting + Chaos + Health | Lurks, appears from nowhere, survives deep into runs |
| 9 | **Wing-Back** | Speed + Defense + Health | Attacks and defends the flank endlessly |
| 10 | **Anchor** | Defense + Strength + Health | Immovable wall, never injured |
| 11 | **Poacher** | Shooting + Strength + Chaos | Ugly goals, rebounds, bulldozes keepers |
| 12 | **Trequartista** | Shooting + Speed + Chaos | Pure flair, zero defensive effort |

Each hybrid has a unique 3-stat combo. Each has a distinct position tendency that drives their AI behavior.

---

## BALL MODEL

The ball is a real object with its own state. Not always owned by a goblin.

| State | What's happening | Duration |
|-------|-----------------|----------|
| **Controlled** | Goblin has it at feet | Until they act |
| **Loose** | Rolling free, nobody owns it | 0.5-2s, goblins race to it |
| **Contested** | Two+ goblins fighting for it | 0.3-1s, stat contest resolves |
| **Travelling** | Pass/shot/cross in flight | 0.2-0.8s, can be intercepted |
| **Dead** | Out of play - goal kick, corner, foul | 1-2s pause, set piece restart |

Loose ball creates organic drama. After tackles, deflections, bad touches, headers - ball is just *there*. Nearest goblins from both teams race to it. Speed determines who arrives first, Strength determines who wins the contest, Chaos determines if something weird happens.

---

## SCORING CHAIN

Goals are the end of a chain, not a single roll:

```
1. Win possession (tackle, interception, keeper save)
       ↓
2. Build up (passes through midfield - each can be intercepted)
       ↓
3. Create chance (through ball, cross, dribble into box)
       ↓
4. Shooting opportunity (attacker vs keeper area)
       ↓
5. Shot resolution
       ↓
   GOAL  /  SAVE  /  MISS  /  BLOCK
           ↓         ↓         ↓
        Rebound   Goal kick  Corner/loose ball
```

### Shot Resolution

```
Shot power:    Shooting + Strength (+ Chaos variance)
Shot accuracy: Shooting + Speed (+ Chaos variance)
Keeper save:   Keeper's Strength + Defense
Block chance:  Defender in zone: Defense + Strength

  power > save AND accurate  →  GOAL
  power > save AND inaccurate →  MISS (wide/over)
  power < save               →  SAVE → rebound?
  defender in the way         →  BLOCK → corner/loose
```

### Point of No Return (Spells Lock)

```
WINDUP   → shooter decides to shoot (0.3s) - CAN cast spells
SHOT     → ball leaves the foot, locked (0.3-0.6s) - SPELLS LOCKED
RESULT   → engine decided: goal/save/miss/block
AFTERMATH → ball loose/dead, spells unlock
```

Same pattern for tackles (committed), headers (ball contacted), keeper dives (committed).

---

## THREE INTERVENTION LAYERS

### Spells (cast any time, mana cost, cooldowns)

No response windows. You're a sorcerer - you cast when you want. Spells locked only during committed actions (~0.5-1s).

| Spell | Effect | Mana | Rarity |
|-------|--------|------|--------|
| **Dark Surge** | +3 shooting to target goblin, 15s | 1 | Common |
| **Shadow Wall** | +3 defense to all defenders, 10s | 2 | Common |
| **Haste** | +3 speed to target goblin, 15s | 1 | Common |
| **Hex** | -2 all stats on one opponent, 30s | 2 | Uncommon |
| **Soul Swap** | Swap positions of two goblins instantly | 1 | Uncommon |
| **Blood Pact** | Double shooting, goblin takes injury post-match | 3 | Rare |
| **Necromancy** | Revive dead goblin at half stats, this match only | 4 | Rare |
| **Curse of the Post** | Opponent's next shot auto-misses | 2 | Uncommon |
| **Frenzy** | All goblins +1 speed +1 shooting -2 defense, 60s | 3 | Rare |
| **Dark Vision** | See opponent tendencies for 60s | 2 | Uncommon |

### Items (equipped between matches, 1 slot per goblin)

| Item | Effect | Shop cost |
|------|--------|-----------|
| **Spiked Boots** | +1 speed permanently | 50g |
| **Cursed Gloves** | +1 shooting, -1 defense | 30g |
| **Iron Shinguards** | +1 defense permanently | 50g |
| **Healing Salve** | Remove one injury | 40g |
| **Lucky Charm** | Morale can't drop below 5 | 60g |
| **Berserker Talisman** | +2 shooting when health below 50% | 45g |
| **Shadow Cloak** | Harder for opponents to mark this goblin | 70g |
| **Goblin Grog** | Full stamina restore between matches | 25g |

### Commands (tactical toggles, 1 active at a time, cooldown between switches)

| Command | Effect |
|---------|--------|
| **Press High** | All goblins push forward, more events but exposed at back |
| **Park the Bus** | Everyone drops deep, fewer chances but hard to score against |
| **Counter Attack** | Sit deep without ball, sprint forward with ball |
| **Target Left/Right** | Events weighted to a flank, wing positions activate |
| **Mark Him** | One goblin shadows a specific opponent, reduces their effectiveness |
| **All Out Attack** | Final 5 minutes desperation, massive attack bonus, no defense |

---

## MATCH ENGINE ARCHITECTURE

Simulation and visuals are completely separated.

```
┌─────────────────┐     ┌──────────────────┐
│  MATCH ENGINE    │────→│  VISUAL LAYER    │
│  (pure numbers)  │     │  (what you see)  │
│                  │     │                  │
│  Ticks 4x/sec    │     │  Renders 60fps   │
│  Positions as %  │     │  Lerps between   │
│  States + events │     │  engine states   │
│  No nodes/scenes │     │  All the art     │
└─────────────────┘     └──────────────────┘
```

### State Snapshot (output every tick)

```
{
  ball: { x, y, state, owner, velocity },
  goblins: [
    { name, x, y, state, facing, active_effects },
    ...
  ],
  spells_locked: bool,
  mana: float,
  score: [int, int],
  clock: float,
}
```

### Tick Loop (4x/second)

```
1. Update ball physics (move loose/travelling ball)
2. For each goblin (sorted by readiness):
   a. Fill readiness meter (+= speed * tick_delta)
   b. If readiness >= threshold:
      - Decide action (GoblinAI based on position type + command)
      - Execute action (stat contest if opponent involved)
      - Set cooldown, reset readiness
3. Resolve loose ball contests (multiple goblins near loose ball)
4. Resolve committed actions (shot reaching goal, pass arriving)
5. Check goals, out of play, fouls
6. Tick active spell effects (decrement durations)
7. Emit state snapshot
```

### Position Tendencies (what each position DOES)

| Position | With ball | Without ball (own team has it) | Without ball (opponent has it) |
|----------|-----------|-------------------------------|-------------------------------|
| Striker | Shoot or dribble toward goal | Hold high line, find space | Press opponent defense lazily |
| Winger | Cross or cut inside | Hug touchline, offer width | Track back to own half |
| Midfielder | Pass forward, distribute | Sit central, offer passing option | Press, win ball back |
| Keeper | Distribute quickly | Stay in goal | Stay in goal |
| Target Man | Hold up ball, lay off | Post up near goal | Minimal pressing |
| Playmaker | Through ball, creative pass | Roam to find space | Avoid defending |
| Enforcer | Simple pass, clear danger | Track opponent's best player | Hard tackle, foul risk |
| Shadow Striker | Quick shot, first time finish | Drift into blind spots | Appear after rebounds |
| Poacher | Tap in, rebound | Lurk on last defender's shoulder | Don't press |
| Wing-Back | Overlap, cross | Overlap on flank | Sprint back to defend |
| Box-to-Box | Simple forward pass | Fill gaps | Cover everywhere |
| Anchor | Clear it | Block central space | Block central space |
| Sweeper | Clear to safety | Cover behind defense | Intercept through balls |
| False Nine | Drop deep, hold up, create | Pull defenders out of position | Press from front |
| Trequartista | Dribble, shoot, flair | Float between lines | Don't defend |
| Attacking Mid | Shoot from distance, pass | Push into attacking third | Track back reluctantly |

### Chaos Mechanic

High Chaos goblins:
- Generate unexpected events outside their position tendency
- Have wider outcome ranges (better successes, worse failures)
- Can chain events (Chaos moment triggers bonus action before next tick)
- Create foul/card risk (Chaos + Strength = dramatic fouls)
- Genuinely risky to field. Low Chaos goblins are reliable but boring.

---

## GOBLIN TOKEN ANIMATION STATES

| State | Circle placeholder (now) | Future art |
|-------|-------------------------|------------|
| **Idle** | Gentle bob | Breathing animation |
| **Running** | Token moves toward target | Run cycle |
| **With ball** | Ball stuck to token | Dribble animation |
| **Shooting** | Quick forward lurch | Wind up + kick |
| **Tackling** | Quick sideways lunge | Slide tackle |
| **Celebrating** | Scale bounce | Arms up, jumping |
| **Fouled** | Flash red | Falling down |
| **Hexed** | Purple tint | Purple aura VFX |
| **Boosted** | Gold tint + glow | Gold aura VFX |

### Procedural Goblin Appearance (future)

Each goblin assembled from parts at generation:
- Head shape (5+ variants)
- Skin color (greens, grays, purples)
- Eyes (6+ variants)
- Ears (4+ variants)
- Mouth/teeth (5+ variants)
- Kit/jersey (team colored, numbered)
- Accessories (unlockable: helmets, warpaint, scars, piercings)

Stored in GoblinData as appearance dict. AnimatedSprite2D composites layers at runtime.

---

## FILE ARCHITECTURE

### Keep as-is
- `scenes/ui/animated_pitch.gd` - FIFA pitch drawing (wire to new engine snapshots)
- `scenes/ui/goblin_token.gd` - Token scene (add animation states)
- `scenes/ui/toast_manager.gd` - Notifications
- `scenes/ui/score_display.gd` - Score
- `scripts/autoload/ui_theme.gd` - Styling
- `scenes/screens/main_menu.gd` - Entry point
- Scene shells: tournament hub, shop, etc.

### Rewrite
| File | Becomes |
|------|---------|
| `resources/goblin_data.gd` | 6 stats, position type, appearance, items, injury state |
| `resources/card_data.gd` | `resources/spell_data.gd` - mana, duration, target type, cooldown |
| `scripts/realtime_engine.gd` | Replaced by `match_simulation.gd` |
| `scripts/match_choreographer.gd` | Rewritten to read state snapshots |
| `scenes/match_realtime/match_realtime.gd` | New controller: simulation + visuals + casting |
| `scripts/formation.gd` | Position-based, 6v6 with position types |
| `scripts/deck.gd` | Spell hand manager - mana, cooldowns |
| `scripts/buff_card_database.gd` | `scripts/spell_database.gd` |
| `scripts/autoload/game_manager.gd` | Mana instead of energy, drop round/phase |

### Build new
| File | Purpose |
|------|---------|
| `scripts/match_simulation.gd` | Core engine. Ticks match, goblin AI, ball, stat contests |
| `scripts/goblin_ai.gd` | Per-position decision making each tick |
| `scripts/ball.gd` | Ball state machine and physics |
| `scripts/spell_system.gd` | Mana pool, cast, cooldowns, active effects |
| `scripts/command_system.gd` | Tactical commands: press/park/target/mark |
| `scripts/position_database.gd` | 4 base + 12 hybrid definitions, tendencies |
| `scripts/goblin_generator.gd` | Procedural goblin creation |
| `scripts/injury_system.gd` | Health degradation, injury rolls, death |
| `scripts/shop/spell_shop.gd` | Buy/sell/upgrade spells |
| `scripts/shop/item_shop.gd` | Equip items, manage inventory |
| `scripts/run_state.gd` | 14-goblin roster, gold, spell deck, progression |
| `scenes/ui/hex_display.gd` | Hexagonal stat radar |
| `scenes/ui/spell_bar.gd` | Always-visible spell hand + mana bar |
| `scenes/ui/command_bar.gd` | Tactical command toggles |
| `scenes/screens/roster_screen.gd` | View/manage 14 goblins, equip items |

---

## BUILD ORDER

| Phase | What | Milestone |
|-------|------|-----------|
| **1** | `goblin_data.gd` rewrite + `position_database.gd` | Data model exists |
| **2** | `match_simulation.gd` + `ball.gd` + `goblin_ai.gd` | Headless sim runs, outputs snapshots |
| **3** | Wire `animated_pitch.gd` to read snapshots | Watch a match play itself |
| **4** | `spell_system.gd` + `spell_data.gd` + `spell_bar.gd` | Cast spells during matches |
| **5** | `command_system.gd` + `command_bar.gd` | Tactical orders |
| **6** | `hex_display.gd` + roster screen | Goblin management UI |
| **7** | `run_state.gd` + shop + injury system | Meta progression loop |
| **8** | `goblin_generator.gd` + procedural appearance | Content generation |

**Phase 1-3**: Watchable match with goblins doing stuff.
**Phase 4-5**: Playable match with sorcerer intervention.
**Phase 6-8**: Full roguelike loop.
