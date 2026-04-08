# Goals & Goblins - Game Plan

## Vision
Roguelike soccer manager. You're a dark sorcerer commanding goblins through a World Cup tournament. Two interlocking systems: **roster management** (keep your goblins alive across a brutal tournament) and **spell deck** (play cards during matches for dramatic interventions). Matches are autonomous - your decisions happen before and between them.

---

## SYSTEM 1: ROSTER MANAGEMENT (the core game)

### The Run
- Start with **14 goblins** (need 6 per match, so 8 reserves)
- Tournament is a **World Cup structure**: group stage (3 matches), knockouts (quarters, semis, final)
- **7 matches to win it all**, but your roster degrades every game
- Run ends when you **can't field 6** or you **win the cup**

### The Tension: Attrition
Goblins get hurt and die. Every match costs you something:
- **Minor injury**: -1 to a random stat. Can play through it but they're weaker
- **Major injury**: -2 to multiple stats. Basically useless until healed
- **Dead**: Gone forever. 14 becomes 13 becomes 12...
- **Fatigue**: Goblins who play consecutive matches get tired (-1 speed, -1 defense next match)

### Between Matches: Management Phase
This is where the strategy lives:

**Rotation**: Pick your 6 from the healthy roster. Rest tired goblins. Shield your stars.

**Healing**: Spend gold to heal injuries (minor = cheap, major = expensive). Can't heal dead.

**Recruitment**: Spend gold to recruit a replacement goblin from a random pool. They're worse than your starters but they're alive.

**Leveling**: Goblins who play well (goals, assists, tackles) earn XP. Level up = +1 to a stat. Survivors get stronger, creating attachment.

**Items**: Equip one item per goblin (stat boosts, injury resistance, special effects). Buy from shop between matches.

### Gold Economy
- Win = 100g, Draw = 50g, Loss = 25g
- Bonus gold for goals, clean sheets, goblin kills
- Healing: minor 30g, major 80g
- Recruitment: 60-120g (random quality)
- Items: 30-70g
- You can't afford everything. Choosing what to spend on IS the game.

### What Makes It a Roguelike
- **Permadeath**: Dead goblins are dead. Named, statted, leveled goblins you invested in - gone.
- **Escalating pressure**: Roster shrinks, opponents get harder, gold gets tighter
- **Build identity**: Your team composition evolves based on who survives, not who you planned
- **Run variance**: Different starting rosters, different shop offerings, different opponents

---

## SYSTEM 2: SPELL DECK (match-day agency)

### The Deck
- Build a deck of **8-10 spell cards** across the run
- Each match you draw a **hand of 5 cards**
- Cards cost **mana** (start with 5 mana per match, no regen)
- High-impact cards cost 3-4 mana (so you play 1-2 of those per match)
- Low-impact cards cost 1 mana (play 3-5 of those)
- **Cards are not consumed** - your deck persists across the run

### Spell Cards

| Card | Mana | Effect |
|------|------|--------|
| **Fireball** | 3 | AoE blast - kills/injures goblins in radius (both teams!) |
| **Haste** | 1 | +3 speed to one goblin for 15 seconds |
| **Dark Surge** | 1 | +3 shooting to one goblin for 15 seconds |
| **Shadow Wall** | 2 | +3 defense to all your defenders for 10 seconds |
| **Hex** | 2 | -2 all stats on one opponent for 30 seconds |
| **Blood Pact** | 3 | Double shooting for one goblin, but they take injury post-match |
| **Necromancy** | 4 | Revive a dead goblin at half stats, this match only |
| **Frenzy** | 3 | All goblins +2 speed +2 shooting -3 defense for rest of match |
| **Multiball** | 2 | 3 chaos balls on the pitch for 10 seconds |
| **Curse of the Post** | 1 | Opponent's next shot auto-misses |

### Deck Building (between matches)
- Shop offers 2-3 new spell cards after each match
- Buy cards to add to your deck (20-60g)
- Can't remove cards (deck grows, hand is random 5)
- Strategy: lean deck (few powerful cards, always draw them) vs wide deck (versatility but inconsistent)

### When You Cast
- Anytime during the match EXCEPT during committed actions (shots mid-flight, tackles mid-lunge)
- Click card, click target (goblin or pitch location)
- Mana spent immediately, no refund

---

## STAT SYSTEM

Six stats, 1-10 scale:

| Stat | What it does |
|------|-------------|
| **Shooting** | Goal conversion, accuracy, finishing |
| **Speed** | Movement speed, closing down, transitions |
| **Defense** | Tackling, interception, positioning |
| **Strength** | Physical duels, holding ball, injury dealing |
| **Health** | Injury resistance, fatigue resistance, durability |
| **Chaos** | Random factor - brilliant or terrible. Collision aggression. |

---

## POSITIONS

### Base (2 primary stats)
| Position | Stats | Zone |
|----------|-------|------|
| Striker | Shooting + Speed | Attack |
| Winger | Speed + Chaos | Attack |
| Midfielder | Defense + Speed | Midfield |
| Keeper | Strength + Defense | Goal |

### Hybrid (3 primary stats, found through recruitment/progression)
| Position | Stats | Identity |
|----------|-------|----------|
| False Nine | Shooting + Chaos + Strength | Drops deep, unpredictable |
| Attacking Mid | Shooting + Speed + Defense | Complete player |
| Sweeper | Defense + Strength + Speed | Last line interceptor |
| Target Man | Shooting + Strength + Health | Tank, holds ball up |
| Box-to-Box | Defense + Speed + Health | Tireless coverage |
| Playmaker | Chaos + Speed + Shooting | Creative genius/disaster |
| Enforcer | Defense + Strength + Chaos | Dirty tackles, kills opponents |
| Shadow Striker | Shooting + Chaos + Health | Lurks, appears from nowhere |
| Wing-Back | Speed + Defense + Health | Attacks and defends flank |
| Anchor | Defense + Strength + Health | Immovable wall |
| Poacher | Shooting + Strength + Chaos | Ugly goals, bulldozes keepers |
| Trequartista | Shooting + Speed + Chaos | Pure flair, zero defense |

---

## MATCH ENGINE (built, working)

- Headless simulation at 10 ticks/sec
- Zone-leash positioning (goblins clamped to position rectangles)
- Dribble-first AI (carry ball forward, pass when pressured)
- Violence system (tackles injure/kill, collision aggression)
- Visual layer reads state snapshots, lerps tokens smoothly
- 3 prototype spell cards working (Fireball, Haste, Multiball)

Key files:
- `scripts/match_simulation.gd` - Core engine
- `scripts/goblin_ai.gd` - Per-goblin decisions
- `scripts/ball.gd` - Ball state machine
- `scripts/team_coordinator.gd` - Role assignment
- `scripts/position_database.gd` - Zone rects per position
- `scenes/ui/animated_pitch.gd` - Pitch rendering
- `scenes/match_sim/match_sim_viewer.gd` - Match viewer

---

## WHAT EXISTS (already built)

### Working Systems
- **Match engine**: Headless sim, zone leashes, dribble AI, violence, visual viewer (`match_sim_viewer.gd`)
- **Tournament structure**: 32-team World Cup, groups + knockouts, standings, bracket (`scripts/tournament/`)
- **Run manager**: Gold tracking, match history, tournament state (`scripts/autoload/run_manager.gd`)
- **Game manager**: Match phase state, momentum, score (`scripts/autoload/game_manager.gd`)
- **Goblin data**: 6 stats, injury system (minor/major/dead), stat penalties (`resources/goblin_data.gd`)
- **Goblin database**: 10-player pool, 5-faction opponent generator (`scripts/goblin_database.gd`)
- **Tournament hub**: Group standings, bracket display, next opponent (`scenes/screens/tournament_hub.gd`)
- **Shop screen**: Card buy/remove UI (`scenes/screens/shop.gd`)
- **Reward screen**: 3-choice card picks post-match (`scenes/reward/reward.gd`)
- **Death/victory screens**: Narrative endings with stats (`scenes/screens/death_scene.gd`, `victory_scene.gd`)
- **3 prototype spells**: Fireball, Haste, Multiball (hardcoded in match_simulation.gd)

### Current Flow
```
Tournament Hub → match.tscn (OLD engine) → shop.tscn → Tournament Hub
```

### Gold Economy (current values - too low)
Win=5g, Draw=2g, Loss=1g, +1g/goal (cap 3)

---

## BUILD ORDER

### Phase 1: Wire New Match Engine into Run Loop
**What**: Replace `match.tscn` with `match_sim_viewer.tscn` in the tournament flow. Pass the player's formation and opponent's formation from RunManager into the sim viewer. Record results back.

**Changes**:
- `tournament_hub.gd`: Launch `match_sim_viewer.tscn` instead of `match.tscn`
- `match_sim_viewer.gd`: Accept formations from RunManager instead of hardcoded rosters. Call `RunManager.record_match_result()` on match end. Transition to shop/reward.
- Update gold economy to new values (Win=100g, Draw=50g, Loss=25g)

**Milestone**: Play a tournament using the new match engine, see results persist.

### Phase 2: Roster Management (Fatigue + Rotation)
**What**: Add fatigue system and a team selection screen between matches.

**Changes**:
- `goblin_data.gd`: Add fatigue (0-10 scale). Playing a match = +3 fatigue. Resting = -fatigue. High fatigue = -1 speed, -1 defense.
- New `scenes/screens/team_select.gd`: Pick 6 from your 14. Show health/fatigue/injury status. Drag to formation slots.
- Flow becomes: Tournament Hub → Team Select → Match → Shop → Tournament Hub

**Milestone**: Choose your squad, see fatigue build up, rotate players.

### Phase 3: Injury Persistence + Death + Healing
**What**: Injuries from matches carry over. Dead goblins removed from roster permanently. Shop offers healing.

**Changes**:
- `run_manager.gd`: Track full 14-goblin roster with persistent injury state across matches
- `shop.gd`: Add healing tab (minor heal 30g, major heal 80g)
- `match_sim_viewer.gd`: After match, apply injuries/deaths to RunManager roster
- Death removes goblin from roster array permanently

**Milestone**: Lose goblins across a run, feel the roster pressure, spend gold on healing.

### Phase 4: Recruitment + XP/Leveling
**What**: Buy replacement goblins when roster shrinks. Goblins earn XP from match performance.

**Changes**:
- `shop.gd`: Add recruitment tab (random goblins for 60-120g, worse than starters)
- `goblin_data.gd`: Add XP, level, stat growth on level-up (+1 to a stat)
- `match_sim_viewer.gd`: Award XP based on goals, assists, tackles, take-ons
- Show XP gains on reward/post-match screen

**Milestone**: Full roguelike loop - goblins die, you recruit replacements, survivors level up.

### Phase 5: Items
**What**: Equippable items (1 slot per goblin) that modify stats or give special effects.

**Changes**:
- `goblin_data.gd`: Equipment slot already exists, wire it to stat modifiers
- `shop.gd`: Add items tab (30-70g)
- `team_select.gd`: Show equipped items, allow equip/swap

**Milestone**: Gear up your goblins, make strategic equipment choices.

### Phase 6: Spell Deck System
**What**: Replace hardcoded spell buttons with proper mana + hand + deck system.

**Changes**:
- New `scripts/spell_data.gd`: Resource with name, mana cost, effect, target type
- New `scripts/spell_system.gd`: Deck (8-10 cards), hand draw (5 per match), mana pool (5, no regen)
- `match_sim_viewer.gd`: Replace 3 buttons with spell hand UI, mana bar, click-to-cast
- 10 spell cards from PLAN (Fireball, Haste, Dark Surge, Shadow Wall, Hex, Blood Pact, Necromancy, Frenzy, Multiball, Curse of the Post)

**Milestone**: Cast spells from a hand during matches, mana matters.

### Phase 7: Deck Building
**What**: Buy spell cards in the shop to grow your deck.

**Changes**:
- `shop.gd`: Spell card tab (2-3 offered per match, 20-60g)
- `run_manager.gd`: Track spell deck across run
- Cards persist (not consumed), deck grows, hand is random 5

**Milestone**: Build a spell collection across a run, strategy in lean vs wide decks.

### Phase 8: Content Generation
**What**: Procedural goblins and opponent scaling for run variety.

**Changes**:
- New `scripts/goblin_generator.gd`: Random names, stat distributions, personality
- Opponent difficulty scales with tournament stage (group = easy, final = hard)
- Starting roster randomized per run

**Milestone**: Every run feels different.

---

**Phase 1-4**: Playable roguelike loop (the game works).
**Phase 5**: Items (strategic depth).
**Phase 6-7**: Spell deck (match-day agency).
**Phase 8**: Content generation (replayability).
