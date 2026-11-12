# Egg Shot

A cute bubble-shooter. Shoot eggs, match 3+ of the same colour, they crack open and a baby chick / peacock / penguin / bunny / dino / unicorn / dragon hatches.

## How it plays
- Drag to aim (dotted line shows bounces), release to shoot. Tap NEXT to swap eggs.
- 3+ same-colour eggs touching = they crack, a baby hatches. Eggs left hanging fall for bonus.
- Every few misses (dots at top) a new row drops. Eggs touching the red line = you lose.
- **Bomb egg** (dark, skull): blasts every egg around where it lands.
- **Snake egg** (green): a snake slithers in and eats the colour of eggs it touches (up to 14).
- 12 levels in 7 themes. Stars (1-3) depend on how few shots you use. Level N+1 unlocks after N.

## Build
```
bash setup.sh
flutter run
flutter build apk --release
```
Or push to GitHub: `.github/workflows/build.yml` builds the APK (same signing secrets as Deplo Hatch).

## Your own images / sounds
Replace files in `assets/images` and `assets/audio` with the SAME names.
- Eggs: egg_red, egg_blue, egg_green, egg_yellow, egg_purple, egg_orange, egg_pink, egg_teal, egg_bomb, egg_snake (.png, about 220x270)
- Babies: animal_chick / peacock / penguin / bunny / dino / unicorn / dragon .png
- Backgrounds: bg_*.jpg. Sounds: pop, wrong, crack, click, win, lose, star, combo, fire, hatch_*, bgm_*.

## Tuning
`lib/models/shot_levels.dart`: colours, rows, misses-before-new-row, where bombs/snakes appear.
Speed: `_moveShot` in `lib/screens/shot_screen.dart` (`d * 28`).
