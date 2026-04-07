# Match Engine Polish Plan

## Current State (Sprint 3 complete)
The match simulation runs, connects to the visual layer, and produces watchable matches. But it doesn't look like soccer yet. The issues are well-understood:

### What works
- Headless simulation at 4 ticks/sec with state snapshots
- Visual layer with double-smoothed 60fps interpolation
- Zone rects per position (in/out of possession)
- Ball bounces off arena walls
- Smart pass targeting (forward + width + space scoring)
- Token flash effects for events
- Speed control (1x/2x/4x/8x)

### What doesn't work
1. **Swarming** - Multiple goblins pile on the ball instead of one pressing and others holding shape
2. **Yo-yo movement** - Goblins oscillate between targets as distances change each tick
3. **No visible dribbling** - Ball carrier doesn't visually run with the ball in a convincing way
4. **Narrow play** - Ball rarely reaches the flanks despite zone rects being wide
5. **Passive defending** - Goblins don't close down convincingly or make well-timed tackles
6. **No game phases** - Every moment looks the same; no build-up, no counter-attack, no sustained pressure

---

## Phase 1: Coordinated Team Roles (Anti-Swarm)

### Problem
Every goblin makes independent decisions. When the ball is loose, 4 goblins from the same team chase it. When defending, everyone presses instead of one pressing and others covering.

### Solution: Role Assignment System
Add a **team coordinator** that assigns one role per goblin each tick based on game state. Only ONE goblin per team gets each active role.

**File:** New `scripts/team_coordinator.gd` (RefCounted, called by MatchSimulation)

```
Roles (per team, assigned each tick):
  BALL_CARRIER  - has the ball (auto-assigned)
  PRESSER       - nearest to ball, actively closes down
  COVER_PRESSER - 2nd nearest, cuts off escape route
  LOOSE_CHASER  - nearest to loose ball (only 1 per team!)
  MARKER_1..3   - each marks a specific opponent
  HOLDER_1..N   - holds zone position (everyone else)
```

**How it works:**
1. Each tick, the coordinator scans game state and assigns roles
2. `GoblinAI.decide()` receives the role as part of Context
3. Role determines behavior, not position tendency strings
4. Only PRESSER chases the ball carrier. COVER_PRESSER positions behind PRESSER. Everyone else marks or holds.

**Key rule:** A goblin keeps their role for a minimum of 3-4 ticks (0.75-1.0s) unless the ball changes state (e.g., possession change, loose ball). This prevents yo-yoing.

### Files to modify
- `scripts/match_simulation.gd` - call coordinator before AI decisions
- `scripts/goblin_ai.gd` - receive role in Context, use it for decisions
- `scripts/goblin_ai.gd:Context` - add `role: String` field
- New: `scripts/team_coordinator.gd`

### Acceptance criteria
- Only 1 goblin per team chases a loose ball
- Only 1 goblin per team presses the ball carrier
- Other goblins visibly hold position or mark opponents
- No swarming visible when watching a match

---

## Phase 2: Increase Tick Rate + Sub-Tick Interpolation

### Problem
At 4 ticks/sec, goblins make decisions every 0.25s. This is too coarse for smooth-looking movement. A goblin can only change direction 4 times per second, making movement look robotic.

### Solution
Increase tick rate to **10 ticks/sec** (TICK_DELTA = 0.1s). This gives:
- Smoother position updates (10 per second instead of 4)
- More granular decision-making
- Ball travel looks more natural with smaller steps
- Tackles/dribbles resolve more gradually

Adjust all timing constants proportionally:
- MINUTES_PER_TICK: 0.5 -> 0.2 (still 90 match minutes total = 450 ticks)
- MOVEMENT_SPEED: scale down proportionally
- Cooldowns: keep in seconds, they'll naturally tick down faster
- READINESS_THRESHOLD: adjust so decision frequency stays similar

The visual layer (animated_pitch.gd) needs no changes - it already lerps at 60fps regardless of tick rate.

### Files to modify
- `scripts/match_simulation.gd` - change TICKS_PER_SECOND, adjust movement constants
- `scenes/match_sim/match_sim_viewer.gd` - tick accumulator uses new rate automatically

### Acceptance criteria
- Movement visibly smoother
- Match still takes ~45 seconds at 1x speed
- No performance issues (10 ticks/sec is still very cheap)

---

## Phase 3: Purposeful Off-Ball Runs

### Problem
Off-ball goblins move to a static point in their zone rect and stop. Real soccer has:
- Strikers making diagonal runs behind the defense
- Wingers overlapping the ball carrier
- Midfielders checking to the ball (moving toward carrier to offer a pass)
- Defenders pushing up into midfield during possession

### Solution: Run Triggers
When certain conditions are met, a goblin starts a **run** - a committed movement to a specific destination over 1-2 seconds.

**Run types:**
| Run | Trigger | Who | Target |
|-----|---------|-----|--------|
| **Forward run** | Team has ball in midfield | Strikers, attacking mids | Sprint toward goal, behind defensive line |
| **Overlap** | Ball carrier is on the flank | Wing-backs, wingers | Sprint past carrier on the outside |
| **Check to ball** | Carrier under pressure | Nearest midfielder | Move toward carrier to offer short pass |
| **Drop deep** | Team has ball, no options ahead | False nine, target man | Move back toward midfield to receive |
| **Recovery run** | Lost possession | Attackers | Sprint back toward own half |

**Implementation:**
- Add `_active_run: Dictionary` to goblin state: `{type, target_x, target_y, ticks_remaining}`
- When a run is active, it overrides zone rect positioning
- Runs last 8-15 ticks (0.8-1.5s at 10 ticks/sec) then expire
- Run trigger logic lives in `_set_offball_movement()` - check conditions, assign run if none active
- Max 2 goblins per team on active runs at once (others hold shape)

### Files to modify
- `scripts/match_simulation.gd` - run trigger logic in `_set_offball_movement()`, run state in `goblin_states`

### Acceptance criteria
- Visible forward runs by strikers when team builds up
- Wingers overlap on the flank
- Midfielders move toward ball carrier
- Runs are committed (goblin doesn't change direction mid-run)
- At most 2 runners at a time, rest hold

---

## Phase 4: Ball Physics Polish

### Problem
- Ball teleports on passes (lerp makes it curve weirdly)
- No distinction between ground pass, lofted ball, through ball
- Ball doesn't slow down or have momentum
- Crosses don't arc

### Solution: Ball Velocity Model
Replace the simple TRAVELLING state with velocity-based movement:

```gdscript
# Ball state additions:
var vx: float = 0.0  # velocity x
var vy: float = 0.0  # velocity y
var friction: float = 0.97  # per-tick velocity decay

# Pass types set different velocities:
# Ground pass: moderate speed, high friction (slows quickly)
# Through ball: fast, low friction (runs into space)
# Cross: moderate speed, target is in the box
# Shot: fast, aimed at goal
# Clearance: fast, high arc (low friction)
```

**Visual layer change:** Ball position updates directly from velocity each tick. The visual lerp only smooths between ticks, not between start/end points. This makes passes look like straight lines with deceleration.

### Files to modify
- `scripts/ball.gd` - add velocity, friction, update method
- `scripts/match_simulation.gd` - set ball velocity on pass/shot/cross instead of set_travelling()
- `scenes/ui/animated_pitch.gd` - ball lerp already works, may need speed adjustment

### Acceptance criteria
- Passes travel in straight lines and slow down
- Through balls run ahead of the receiver
- Crosses go wide then toward goal
- Ball gradually decelerates when loose

---

## Phase 5: Contextual With-Ball Decisions

### Problem
Ball carrier AI is too simple: shoot if close, pass if pressured, dribble if open. Real decisions depend on:
- What runs are being made by teammates
- Where space is on the pitch
- Whether this is a counter-attack or sustained possession

### Solution: Weighted Decision Matrix
Instead of if/else chains, score all options and pick the best:

```
Options for ball carrier:
  SHOOT    - score: shooting_stat * (1/dist_to_goal) * clear_sight_bonus
  PASS_FWD - score: teammate_forward_run_bonus + space_around_target
  PASS_WIDE- score: width_change_bonus + winger_in_space
  DRIBBLE  - score: open_space_ahead * speed_stat - opponent_proximity
  CROSS    - score: wide_position * teammates_in_box
  HOLD     - score: no_options_available * strength_stat
```

Pick highest score with small random variance (chaos stat increases variance). This produces natural-looking decision-making where the "right" choice depends on game state.

### Files to modify
- `scripts/goblin_ai.gd` - replace `_decide_with_ball()` with scoring system

### Acceptance criteria
- Ball carrier makes different decisions in different contexts
- Counter-attacks produce fast forward passes
- Sustained possession produces patient buildup
- Wingers cross when teammates are in the box
- High-chaos goblins occasionally make wild decisions

---

## Phase 6: Defending Improvements

### Problem
Defending is just "run at the ball." Real defending is:
- Jockeying (slowing down near attacker, not diving in)
- Covering (positioning to block passing lanes)
- Stepping up (moving forward to compress space)
- Last-ditch tackles (desperate slide from behind)

### Solution
Modify tackle behavior based on distance to attacker:

| Distance | Behavior |
|----------|----------|
| > 0.20 | Close down: move toward ball carrier at 80% speed |
| 0.10-0.20 | Jockey: slow down, match carrier's y position, wait for mistake |
| < 0.10 | Tackle: commit to winning the ball |
| Attacker past defender | Recovery tackle: chase from behind, higher foul chance |

The PRESSER (from Phase 1) does the actual pressing. COVER_PRESSER positions behind to catch through balls if PRESSER is beaten.

### Files to modify
- `scripts/goblin_ai.gd` - nuanced defending in `_decide_opponent_ball()`
- `scripts/match_simulation.gd` - jockey movement (slower, lateral matching)

### Acceptance criteria
- Defenders close down at controlled speed
- No diving-in from 0.3 away
- Covering defender visible behind the presser
- Fouls happen on desperate tackles

---

## Phase 7: Match Flow & Events

### Problem
Every moment of the match looks the same. Real soccer has distinct phases.

### Solution: Track match "temperature" and flow:

```
MATCH_TEMPO enum:
  BUILD_UP     - team patiently passing in own half
  TRANSITION   - ball just changed hands, both teams repositioning
  ATTACK       - ball carrier past midfield, moving toward goal
  COUNTER      - won ball back, opponents out of position
  SET_PIECE    - after foul, near goal (arena mode: just a free possession)
```

Tempo affects:
- Movement speed (COUNTER = everyone sprints, BUILD_UP = walking pace)
- AI decisions (COUNTER = first-time forward passes, BUILD_UP = safe sideways passes)
- Visual feedback (tempo indicator on UI, commentary text)

### Files to modify
- `scripts/match_simulation.gd` - track tempo, influence tick behavior
- `scenes/match_sim/match_sim_viewer.gd` - display tempo

### Acceptance criteria
- Visible difference between slow buildup and fast counter-attack
- Tempo changes feel natural (buildup -> attack -> lose ball -> transition -> defend)

---

## Implementation Order & Dependencies

```
Phase 1 (Team Coordinator)  -- HIGHEST PRIORITY, fixes swarming
    |
Phase 2 (Tick Rate)  -- independent, do anytime
    |
Phase 3 (Off-Ball Runs)  -- depends on Phase 1 (roles)
    |
Phase 4 (Ball Physics)  -- independent, do anytime
    |
Phase 5 (With-Ball AI)  -- depends on Phase 3 (knows about runs)
    |
Phase 6 (Defending)  -- depends on Phase 1 (presser/cover roles)
    |
Phase 7 (Match Flow)  -- depends on everything above
```

**Recommended thread breakdown:**
- **Thread A:** Phases 1 + 3 + 6 (team coordination, runs, defending)
- **Thread B:** Phases 2 + 4 (tick rate, ball physics)
- **Thread C:** Phases 5 + 7 (with-ball AI, match flow)

Thread A is the most impactful and should go first. Threads B and C can happen in parallel after A.

---

## Key Files Reference

| File | Purpose | Lines |
|------|---------|-------|
| `scripts/match_simulation.gd` | Core tick loop, movement, off-ball system | ~620 |
| `scripts/goblin_ai.gd` | Per-goblin decision making | ~260 |
| `scripts/ball.gd` | Ball state machine | ~100 |
| `scripts/position_database.gd` | Position definitions + zone rects | ~280 |
| `scenes/ui/animated_pitch.gd` | Visual layer, snapshot lerp | ~390 |
| `scenes/ui/goblin_token.gd` | Token rendering + flash effects | ~105 |
| `scenes/match_sim/match_sim_viewer.gd` | Match viewer controller | ~120 |

## Testing
Launch game -> Main Menu -> WATCH MATCH. Use speed button to cycle 1x/2x/4x/8x. ESC to return. Event log at bottom shows play-by-play. After each phase, watch 3-5 full matches at 1x speed to evaluate quality.
