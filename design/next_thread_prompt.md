# Paste this into a new Claude Code thread:

---

I'm building Goals & Goblins - a fantasy soccer roguelite deck builder in Godot 4.4. The game is at a prototype stage and I need to build a real-time coach mode prototype.

## Where the game is now (Sprint 5, committed and pushed):
- Desktop landscape (1280x720, Godot 4.4, GDScript)
- Sideways soccer pitch with goblin tokens as circles (your team left, opponent right)
- Two match modes on main menu: "NEW TOURNAMENT" (turn-based TPD card system) and "AUTO TEST" (autobattler buff cards)
- Tournament loop works: draft 6 goblins -> group stage -> knockout -> shop/rewards -> win/lose
- 10 goblins in roster, 5 factions with counter system
- TPD card system: Possession builds field control, Defense blocks opponent, Tempo attempts goals
- Opponent cards shown face-up before player commits
- 8 rounds per match, halftime at 4
- Goblin buff visuals on pitch tokens (green glow + stat overlay when buffed)

## What we decided to build next:
A REAL-TIME COACH MODE prototype. This replaces both existing match modes if it feels good. The concept:

1. Match runs on a clock (2-4 minute halves, real time or fast-forwardable)
2. The match engine generates events every 5-15 seconds ("Opponent breaks through midfield!", "Your winger has space!", "Corner kick!")
3. Each event has a brief response window (3-5 seconds) where you can play a card from your hand
4. If you play a card, it influences the outcome. If you don't, it auto-resolves based on goblin stats alone.
5. You're the coach on the sideline - watching and intervening at key moments

## Key design decisions made:
- Goblins are the heart of the game (collectible soccer player cards, parody footballers like "Gleon Messy")
- Goblins can DIE during a run, forcing roster rotation across a tournament
- 6 stats per goblin (D&D flavored): Pace, Power, Vision, Grit, Instinct, Chaos
- 20 total goblins planned (8 starters, 12 unlockable) - see design/goblin_roster.md
- Scoring chain: Possession battle -> Chance creation -> Shot -> Save -> Goal
- Visual feedback is critical - players need to SEE their decisions impacting goblins
- Opponent patterns should be learnable (scouting reports, visual cues), not random

## What the prototype needs (stripped-down, no animation yet):
- A match clock that ticks (real time, maybe 2 min per half to start)
- An event generator that creates soccer events at intervals
- A response window UI - event pops up, player has X seconds to play a card
- Cards in hand that can be played during response windows
- Auto-resolution when no card is played (based on goblin stats)
- Score tracking, basic pitch display (reuse existing)
- Just enough to test: "Is reacting under time pressure fun?"

## Files to check for context:
- design/goblin_roster.md - full 20-goblin roster design
- scenes/match/match.gd - current turn-based match flow
- scenes/match_auto/match_auto.gd - autobattler prototype
- scripts/auto_engine.gd - zone vs zone resolution math
- scenes/ui/pitch_display.gd - sideways pitch with goblin tokens
- resources/card_data.gd - card types enum
- scripts/autoload/game_manager.gd - match state management

Build it as a new scene (scenes/match_realtime/) so we don't break existing modes. Add a third button on main menu: "REALTIME TEST". Keep it scrappy - we're testing a feel, not shipping a feature.
