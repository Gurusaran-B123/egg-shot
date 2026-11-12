import 'package:shared_preferences/shared_preferences.dart';

/// Stars per level (0 = not finished). Level N+1 unlocks after level N.
class ShotProgress {
  ShotProgress(this.stars);
  final List<int> stars;

  bool unlocked(int i) => i == 0 || (i - 1 < stars.length && stars[i - 1] > 0);
  int get total => stars.fold(0, (a, b) => a + b);

  static Future<ShotProgress> load(int levels) async {
    final list = List<int>.filled(levels, 0);
    try {
      final p = await SharedPreferences.getInstance();
      for (var i = 0; i < levels; i++) {
        list[i] = p.getInt('shot_stars_$i') ?? 0;
      }
    } catch (_) {}
    return ShotProgress(list);
  }

  static Future<void> saveStars(int level, int stars) async {
    try {
      final p = await SharedPreferences.getInstance();
      final old = p.getInt('shot_stars_$level') ?? 0;
      if (stars > old) await p.setInt('shot_stars_$level', stars);
    } catch (_) {}
  }
}
