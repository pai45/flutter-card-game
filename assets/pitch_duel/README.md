# Pitch Duel artwork

Original assets for the October 2026 football card update. Existing illustrated
football portraits are reused from `assets/player_images/`.

- `board_texture.png`: built-in ImageGen; overhead navy felt pitch and cloth,
  faint football linework, no text/UI/objects.
- `lobby_stadium.png`: built-in ImageGen; matte charcoal/navy field-level night
  stadium, subdued cyan rim lights and ample dark UI space, no text.
- `actions/act1.svg`–`act16.svg`: original football tactic illustrations.
- `scenarios/sc1.svg`–`sc7.svg`: original contextual football emblems.
- `affinities/*.svg`: six original affinity glyphs.

Vector source: `tool/generate_pitch_duel_vectors.py`. Run it to regenerate the
29 SVGs. Arrowheads are explicit paths for flutter_svg compatibility. Flutter
applies Cyber color tokens. Text, frames, rating badges and foil remain code.
No borrowed Balatro assets.

Generation mode: built-in ImageGen, two new opaque portrait assets. Prompts:

**Lobby:** Original premium mobile football card-game lobby background, portrait
1024 × 1536. Field-level night stadium, dark charcoal/navy, subdued cyan rim
lighting near the lower perimeter, tactile matte finish. Leave the upper two
thirds mostly dark and quiet for UI. Subtle field depth, restrained atmosphere.
No lettering, numbers, logos, UI, cards, people, lightning or bright neon.

**Board:** Original premium mobile football card-game tabletop background,
portrait 1024 × 1536. Overhead dark navy felt, fine pressed cloth texture, faint
football pitch linework, soft vignette. Matte and restrained, low contrast so
cards remain the focus. No text, UI, cards, objects, people, logos or bright neon.
