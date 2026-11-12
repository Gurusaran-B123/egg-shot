import 'package:flutter/material.dart';

/// Egg colour names = image files assets/images/egg_<name>.png
const List<String> kPalette = [
  'red', 'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'teal',
];

/// Cell codes on the board.
const int kEmpty = -1;
const int kBomb = 100;
const int kSnake = 101;

class ShotTheme {
  const ShotTheme({
    required this.name,
    required this.bg,
    required this.baby,
    required this.hatchSfx,
    required this.bgm,
    required this.accent,
  });
  final String name;
  final String bg; // image name without .jpg
  final String baby; // image name without .png
  final String hatchSfx;
  final String bgm;
  final Color accent;
}

const List<ShotTheme> kThemes = [
  ShotTheme(name: 'Farm', bg: 'bg_farm', baby: 'chick', hatchSfx: 'hatch_chick', bgm: 'bgm_farm', accent: Color(0xFFFFB300)),
  ShotTheme(name: 'Forest', bg: 'bg_forest', baby: 'peacock', hatchSfx: 'hatch_peacock', bgm: 'bgm_forest', accent: Color(0xFF43A047)),
  ShotTheme(name: 'Ice Land', bg: 'bg_ice', baby: 'penguin', hatchSfx: 'hatch_penguin', bgm: 'bgm_ice', accent: Color(0xFF29B6F6)),
  ShotTheme(name: 'Meadow', bg: 'bg_meadow', baby: 'bunny', hatchSfx: 'hatch_bunny', bgm: 'bgm_meadow', accent: Color(0xFFEC407A)),
  ShotTheme(name: 'Dino Land', bg: 'bg_dino', baby: 'dino', hatchSfx: 'hatch_dino', bgm: 'bgm_dino', accent: Color(0xFF8D6E63)),
  ShotTheme(name: 'Rainbow', bg: 'bg_rainbow', baby: 'unicorn', hatchSfx: 'hatch_unicorn', bgm: 'bgm_rainbow', accent: Color(0xFFAB47BC)),
  ShotTheme(name: 'Volcano', bg: 'bg_volcano', baby: 'dragon', hatchSfx: 'hatch_dragon', bgm: 'bgm_volcano', accent: Color(0xFFEF6C00)),
];

class ShotLevel {
  const ShotLevel({
    required this.index,
    required this.theme,
    required this.colors,
    required this.rows,
    required this.missLimit,
    required this.bombs,
    required this.snakes,
  });
  final int index;
  final ShotTheme theme;
  final int colors; // number of egg colours
  final int rows; // starting rows
  final int missLimit; // misses before a new row drops
  final bool bombs;
  final bool snakes;

  int get number => index + 1;
  int get startEggs => rows * 9 - (rows ~/ 2);
  int get par => (startEggs * 0.5).ceil();

  int starsFor(int shots) {
    if (shots <= par) return 3;
    if (shots <= (par * 1.6).ceil()) return 2;
    return 1;
  }
}

const List<int> _themeOf = [0, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6];

final List<ShotLevel> kShotLevels = List.generate(_themeOf.length, (i) {
  return ShotLevel(
    index: i,
    theme: kThemes[_themeOf[i]],
    colors: 3 + (i ~/ 3),
    rows: 5 + (i ~/ 3),
    missLimit: 6 - (i ~/ 4),
    bombs: i >= 1,
    snakes: i >= 3,
  );
});
