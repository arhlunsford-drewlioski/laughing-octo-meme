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
Tournament Hub → Team Select (pick 6) → match_sim_viewer.tscn → shop.tscn → Tournament Hub
```

### Gold Economy
Win=100g, Draw=50g, Loss=25g, +10g/goal (cap 5)

---

## BUILD ORDER

### Phase 1: Wire New Match Engine into Run Loop [DONE]
**What**: Replace `match.tscn` with `match_sim_viewer.tscn` in the tournament flow. Pass the player's formation and opponent's formation from RunManager into the sim viewer. Record results back.

**Completed**:
- `tournament_hub.gd`: Launches `team_select.tscn` (pick 6 from alive roster)
- `team_select.gd`: New screen - shows all alive goblins with stats/injuries, pick 6, sets `GameManager.selected_roster`
- `match_sim_viewer.gd`: Reads formations from RunManager. Records score + injuries/deaths via `RunManager.record_match_result()`. Transitions to shop.
- `run_manager.gd`: `record_match_result()` now tracks injuries and deaths in match history. Added `get_player_roster()` and `get_alive_roster()` helpers.
- Gold economy updated (Win=100g, Draw=50g, Loss=25g, +10g/goal cap 5)

**Milestone**: Play a tournament using the new match engine, see results persist.

### Phase 2: Roster Management (Fatigue + Rotation) [DONE]
**What**: Add fatigue system to the existing team selection screen.

**Completed**:
- `goblin_data.gd`: Fatigue 0-10 scale. +3 per match played, -2 per match rested. At fatigue >= 5: -1 speed, -1 defense (applied via `get_stat()`).
- `run_manager.gd`: `record_match_result()` applies fatigue to played goblins and rests bench goblins.
- `team_select.gd`: Shows fatigue bar on cards, orange "TIRED" warning at threshold, stats shown in orange when penalized.

**Milestone**: See fatigue build up across matches, rotate players to manage it.

### Phase 3: Injury Persistence + Death + Healing [DONE]
**What**: Injuries from matches carry over. Dead goblins removed from roster permanently. Shop offers healing.

**Completed**:
- `run_manager.gd`: Dead goblins pruned from roster after `record_match_result()`. Added `HEAL_MINOR_COST=30`, `HEAL_MAJOR_COST=80`, `MIN_ROSTER_SIZE=6`. `is_eliminated()` checks alive roster < 6.
- `shop.gd`: Healing tab shows injured goblins with severity, stat penalties, and HEAL button. Auto-hides when nobody is injured.
- Death removes goblin from roster array permanently. Roster < 6 alive triggers game over via `is_eliminated()`.

**Milestone**: Lose goblins across a run, feel the roster pressure, spend gold on healing.

### Phase 4: Recruitment + XP/Leveling [DONE]
**What**: Buy replacement goblins when roster shrinks. Goblins earn XP from match performance.

**Completed**:
- `goblin_data.gd`: XP/level system. XP needed = 100 * level. Level up gives +1 to a stat (weighted toward position primary stats).
- `match_sim_viewer.gd`: Tracks per-goblin performance (goals, assists, tackles, take_ons, interceptions, saves). Awards XP post-match (10 base + 30/goal + 20/assist + 5/tackle + 5/take_on + 10/interception + 10/save). Logs XP gains and level-ups.
- `goblin_database.gd`: `generate_recruit()` creates random goblins with stats 2-5 (weaker than starters), fun names/personalities.
- `shop.gd`: Recruitment tab shows 3 random recruits (60-120g each) with stats, position, faction, personality. Purchased recruits added to roster.
- `team_select.gd`: Shows level on goblin cards when level > 1.

**Milestone**: Full roguelike loop - goblins die, you recruit replacements, survivors level up.

### Phase 5: Items [DONE]
**What**: Equippable items (1 slot per goblin) that modify stats or give special effects.

**Completed**:
- `resources/item_data.gd`: ItemData resource with name, description, rarity (Common/Uncommon/Rare), stat_bonuses dictionary, special_effect. Pricing by rarity (30g/50g/70g).
- `scripts/item_database.gd`: 24 items across 3 rarity tiers (8 each). `generate_shop_items()` with weighted rarity rolls (55% common, 30% uncommon, 15% rare).
- `goblin_data.gd`: `get_stat()` now includes item bonuses via `_get_item_bonus()`. Added `equip_item()`, `unequip_item()`, `has_item()` helpers.
- `shop.gd` + `shop.tscn`: Equipment section shows 3 random items per shop visit. Buy flow: purchase item, then pick a goblin to equip it on (replaces existing item).
- `team_select.gd`: Shows equipped item name + stat bonuses on goblin cards with rarity-colored text.

**Milestone**: Gear up your goblins, make strategic equipment choices.

### Phase 6: Spell Deck System [DONE]
**What**: Replace hardcoded spell buttons with proper mana + hand + deck system.

**Completed**:
- `resources/spell_data.gd`: Already existed with name, mana cost, stat modifiers, target type, special effect, rarity, shop cost.
- `scripts/spell_database.gd`: All 10 spell definitions (Fireball 3, Haste 1, Dark Surge 1, Shadow Wall 2, Hex 2, Blood Pact 3, Necromancy 4, Frenzy 3, Multiball 2, Curse of the Post 1). Starter deck of 5 spells. Shop pool for deck building.
- `scripts/spell_system.gd`: Deck management, random hand draw (5 per match), mana pool (5, no regen). Blood Pact post-match injury tracking. Curse charge tracking.
- `scripts/match_simulation.gd`: Generic buff system (`_active_buffs` with timed expiry). New cast methods: `cast_dark_surge()`, `cast_shadow_wall()`, `cast_hex()`, `cast_blood_pact()`, `cast_frenzy()`, `cast_curse_of_post()`. Curse of the Post hooks into shot resolution to auto-miss.
- `match_sim_viewer.gd`: Replaced 3 hardcoded spell buttons with dynamic spell hand UI. Mana crystal display. Click-to-cast with targeting modes (pitch click for Fireball, ally click for Dark Surge/Blood Pact, enemy click for Hex). ESC/right-click to cancel targeting.
- `run_manager.gd`: `run_spell_deck` persists across matches. Initialized with starter deck on tournament start.

**Milestone**: Cast spells from a hand during matches, mana matters.

### Phase 7: Deck Building [DONE]
**What**: Buy spell cards in the shop to grow your deck.

**Completed**:
- `shop.gd` + `shop.tscn`: Spells section shows 3 random spell cards from the shop pool each visit. Displays name, mana cost, rarity, description, stat modifiers, and price (20-60g). Shows current deck size. Rarity-colored borders (Common blue, Uncommon green, Rare purple).
- `run_manager.gd`: `add_spell_card()` and `remove_spell_card()` helpers. `run_spell_deck` persists across matches, initialized with starter deck.
- `scripts/spell_database.gd`: `shop_pool()` returns purchasable spells (Hex, Blood Pact, Necromancy, Frenzy, Curse of the Post, plus duplicate copies of Dark Surge, Shadow Wall, Haste).
- Cards persist (not consumed), deck grows, hand is random 5 drawn per match.

**Milestone**: Build a spell collection across a run, strategy in lean vs wide decks.

### Phase 8: Content Generation [DONE]
**What**: Procedural goblins and opponent scaling for run variety.

**Completed**:
- `scripts/goblin_generator.gd`: Procedural goblin generation. Names = goblin first name + famous footballer surname (Thordak Materazzi, Skullcrusher Smith-Rowe, etc.). 60 first names, 60 footballer surnames, 30 personalities. Positionally balanced draft pool generation (guaranteed 2 ATK, 2 MID, 2 DEF, 1 GK). Difficulty-scaled opponent generation with stat ranges that increase with tournament progression.
- `scripts/tournament/team_generator.gd`: Difficulty now scales with team index (0.0 to 1.0 range with variance). Early teams are weaker (stats 2-6), late teams are stronger (stats 4-9 with primary stat bonuses).
- `scenes/draft/draft.gd`: Draft pool now uses `GoblinGenerator.generate_draft_pool(10)` instead of fixed roster. Every run starts with different goblins.
- `scripts/goblin_database.gd`: Fixed roster and recruit names updated to footballer-surname style. Recruits use cult-hero/meme footballer names (Grot Lingard, Sniv Bendtner, etc.).

**Milestone**: Every run feels different.

---

**Phase 1-4**: Playable roguelike loop (the game works).
**Phase 5**: Items (strategic depth).
**Phase 6-7**: Spell deck (match-day agency).
**Phase 8**: Content generation (replayability).
