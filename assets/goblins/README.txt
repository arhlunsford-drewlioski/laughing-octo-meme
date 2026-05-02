Goblin sprite drop folder
=========================

Drop PNG files in this folder, named:

    <position>_<NN>.png        e.g. striker_01.png, winger_03.png
    _generic_<NN>.png          fallback used by any position with no match

Recognized position keys (from PositionDatabase):
  keeper, sweeper, anchor, enforcer, wing_back,
  playmaker, attacking_mid, trequartista,
  winger, shadow_striker, target_man, false_nine, poacher, striker

Image specs
-----------
- 1024x1024 source, transparent background (PNG alpha)
- Top-down 3/4 view, character centered
- Anything outside a roughly 80% center circle gets clipped on render
- Goblin will be drawn at ~56px on the pitch, so don't sweat fine detail

If no PNG exists for a position, the goblin falls back to the colored
circle. You can ship art incrementally - one position at a time.

The rings (ball glow, highlight, charge, targeting) and the name/position
labels stay overlaid on top of the sprite, so don't burn UI into the art.

AI prompt that works well in Gemini / Imagen
--------------------------------------------
Top-down 2D game sprite of a goblin <ROLE> soccer player, vector art
style with bold outlines and flat colors. Centered, viewed from a
3/4 top-down angle. Solid bright magenta (#FF00FF) background.
1024x1024. No shadow, no text, no UI, no extra goblins.
Cute but menacing, small fangs, pointed ears, team jersey visible.

Then key out the magenta with any image tool (or remove.bg) to get
a transparent PNG before dropping it here.
