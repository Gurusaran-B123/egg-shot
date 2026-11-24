import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Egg colour names = image files assets/images/egg_<name>.png
const List<String> kPalette = [
  'red', 'blue', 'green', 'yellow', 'purple', 'orange', 'pink', 'teal',
];

/// Cell codes on the board.
const int kEmpty = -1;
const int kBomb = 100; // power shot (bought with stars)
const int kSnake = 101; // power shot (bought with stars)

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
    required this.timeLimit,
    required this.shotLimit,
  });
  final int index;
  final ShotTheme theme;
  final int colors; // number of egg colours
  final int rows; // starting rows
  final int missLimit; // misses before a new row drops
  final int timeLimit; // seconds, 0 = no timer
  final int shotLimit; // eggs you may shoot, 0 = unlimited

  int get number => index + 1;
  int get startEggs => rows * 9 - (rows ~/ 2);
  int get par => (startEggs * 0.5).ceil();

  int starsFor(int shots) {
    if (shots <= par) return 3;
    if (shots <= (par * 1.6).ceil()) return 2;
    return 1;
  }
}

const int kLevelCount = 500;

/// 500 levels. More colours and more starting rows as you go higher.
/// Timer starts at level 10, limited eggs at level 15.
final List<ShotLevel> kShotLevels = List.generate(kLevelCount, (i) {
  final rows = 4 + math.min<int>(8, i ~/ 40); // 4..12 (the screen caps it)
  final startEggs = rows * 9 - (rows ~/ 2);
  final timer = i >= 9 && i % 3 != 0;
  final limited = i >= 14 && i % 2 == 1;
  return ShotLevel(
    index: i,
    theme: kThemes[(i ~/ 4) % kThemes.length],
    colors: 3 + math.min<int>(5, i ~/ 40), // 3..8
    rows: rows,
    missLimit: math.max<int>(3, 6 - i ~/ 100),
    timeLimit: timer ? math.max<int>(60, (startEggs * 2.2).round() - i ~/ 10) : 0,
    shotLimit: limited ? (startEggs / 3 * 2.0).ceil() + 6 - math.min<int>(10, i ~/ 50) : 0,
  );
});
