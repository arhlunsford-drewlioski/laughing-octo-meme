# Goals & Goblins - Sorcerer Duel Redesign

## Core Fantasy
You're a dark sorcerer coaching a team of idiot goblins through a World Cup.
The other team has a sorcerer too. The football is the backdrop.
The GAME is the spell battle happening on top of it.

## Core Loop (30 seconds)
Watch match -> See opponent wind up a spell -> Decide: counter it, cast your own, or save mana -> Something dramatic and visible happens -> React to the chaos

## The Spell Battle

### Mana System
- Mana bar fills over time (like a cast bar / cooldown)
- Starts at 0, regens to max 10 over the course of the match
- Regen rate: ~1 mana per 9 match-minutes (so ~10 mana total per match)
- Cheap spells (1-2 mana): cast 4-5 per match
- Expensive spells (3-4 mana): cast 2-3 per match
- You CAN'T cast everything. Choosing what to cast IS the game.

### Casting Mechanic (Uncertainty)
Spells are NOT point-and-click precise. You aim with a "flick" mechanic:
- Tap spell card to start casting
- A targeting reticle appears - it WOBBLES/drifts
- You tap/release to lock the target
- The wobble means you might miss your target or hit your own guys
- Higher-tier spells wobble MORE (powerful = harder to aim)
- Some spells are area-of-effect (easier to land), some are single-target (harder)
- This is the skill expression. Good players learn the wobble timing.

### Opponent AI Sorcerers (8-10 archetypes)

Each AI opponent has a spell loadout and casting personality:

1. **The Pyromaniac** - All fire spells. Fireballs constantly. Doesn't care about friendly fire. Chaotic matches.
2. **The Protector** - Shield Dome, Heal, Fortify. Good team, plays defensive. Hard to kill their goblins.
3. **The Necromancer** - Revives dead goblins, drains life. Long matches, attrition-based.
4. **The Trickster** - Teleport, Clone, Swap. Unpredictable. Moves goblins around the pitch randomly.
5. **The Berserker** - Rage Potion, Blood Pact, Frenzy. Buffs their team to insane stats but they take damage.
6. **The Controller** - Mind Control, Slow, Hex. Takes over your goblins, debuffs everything.
7. **The Storm Caller** - Lightning Bolt, Earthquake, Wind Gust. Precision kills and pitch disruption.
8. **The Blood Mage** - Sacrifices their own goblins for massive power spells. Desperate and dangerous.
9. **The Tactician** - Haste, Shadow Wall, Counter Spell. Subtle but effective. Uses counters.
10. **The Chaos God** - Random spell from the entire pool every cast. Could be anything. Wild card.

### AI Casting Behavior
- AI has the same mana bar, same regen rate
- AI has a "wind-up" visual: you see their spell charging for 1-2 seconds before it fires
- Wind-up shows the SPELL TYPE (icon/color) but not the exact target
- This gives you time to react: cast Counter Spell, move your goblins (can you?), or cast your own spell first
- AI personality determines: aggression (how fast they spend mana), target preference (your best player vs ball carrier), counter-play (do they save mana for counters?)

### Spell List (Draft - 15-20 spells)

**Offensive (damage/kill)**
- Fireball (2 mana) - AoE blast, kills/injures anyone in radius. Both teams. The classic.
- Lightning Bolt (3 mana) - Single target, guaranteed kill. Precise but small wobble.
- Earthquake (2 mana) - Everyone stumbles, ball goes loose. No damage but total disruption.
- Meteor (4 mana) - HUGE AoE, massive damage. Biggest wobble. Miss = waste 4 mana.

**Defensive (protect/heal)**
- Shield Dome (2 mana) - One goblin is invincible for 20 seconds. Visible bubble.
- Heal (1 mana) - Cure one goblin's injury mid-match.
- Fortify (2 mana) - All your goblins get +3 defense for 15 seconds.
- Counter Spell (1 mana) - Cancel the opponent's currently-winding-up spell. Timing-based.

**Chaos (weird/fun)**
- Clone (3 mana) - Duplicate one goblin. Temporary 7v6. Clone dies at end of match.
- Mind Control (3 mana) - Enemy goblin plays for you for 30 seconds.
- Teleport (1 mana) - Move any goblin to any spot on pitch instantly.
- Rage Potion (2 mana) - One goblin goes +5 all stats but attacks EVERYONE including teammates.
- Swap (1 mana) - Switch positions of any two goblins on the pitch.

**Buffs/Debuffs (subtle but useful)**
- Haste (1 mana) - +3 speed to one goblin, 15 seconds.
- Hex (2 mana) - -2 all stats on one enemy, 30 seconds.
- Dark Surge (1 mana) - +3 shooting to one goblin, 15 seconds.

### Counter-Spell System
- When opponent starts casting, you see a 1.5 second wind-up
- During wind-up: spell icon glows on opponent's side of screen
- You can cast Counter Spell (1 mana) to cancel it
- Counter Spell has NO wobble - it's a simple button press during the window
- If you counter, their mana is still spent. Huge swing.
- Opponent AI can also counter YOUR spells (Tactician archetype does this a lot)

### Visual Wind-Up (Opponent Casting)
- Opponent side of screen: a spell circle/glyph appears and starts spinning
- Color indicates spell type: red = offensive, blue = defensive, purple = chaos
- The glyph gets brighter/bigger as the cast completes
- At full charge: spell fires at target
- Player has ~1.5 seconds to read and react
- This is the "turn" structure hidden inside real-time play

## Spell Deck Building (Roguelike Layer)

### Before the Tournament
- Start with 4 basic spells (Fireball, Shield Dome, Haste, Hex)
- Deck holds 8-10 spells max
- Each match: draw hand of 5 from your deck

### Between Matches (Shop)
- Buy new spells (20-60g)
- Sell/remove spells from deck
- Different spells available based on tournament stage
- Legendary spells only appear in knockout stages

### Opponent Spell Preview
- Before each match, you see the opponent sorcerer's archetype
- "You face THE PYROMANIAC" with their spell loadout shown
- This lets you build/adjust your deck to counter them
- Maybe swap 1-2 spells before the match (sideboard)

## What Stays From Current Build
- Match simulation engine (pure lerp positioning, proximity tackles)
- Tournament structure (32 teams, group + knockouts)
- Goblin data model (stats, injuries, fatigue, XP, items)
- Roster management (draft 10, pick 6, rotation, healing)
- Gold economy
- Visual pitch + tokens

## What Changes
- Spell system: completely rebuilt around dramatic effects + wobble aiming
- AI opponent: needs spell-casting AI with wind-up visualization
- Mana: regen over time instead of flat 5
- UI: need opponent spell bar, wind-up indicator, counter-spell button
- Spell effects: need BIG visual effects (explosions, shields, lightning)
- Deck building: restructured around the new spell pool

## What's New
- Wobble/flick aiming mechanic
- Opponent AI sorcerer with visible casting
- Counter-spell timing window
- 8-10 sorcerer archetypes with distinct loadouts
- Spell wind-up visualization

## MVP for Testing
Build the minimum to test if the core loop is fun:
1. Bring back Fireball with wobble aiming
2. Add Shield Dome (protect one goblin)
3. Add mana regen bar
4. Add AI opponent that casts Fireball back at you with wind-up
5. Play one match. Is the spell battle fun? If yes, build the rest.
