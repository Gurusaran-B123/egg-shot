import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stars per level (0 = not finished). Level N+1 unlocks after level N.
class ShotProgress {
  ShotProgress(this.stars);
  final List<int> stars;

  bool unlocked(int i) => i == 0 || (i - 1 < stars.length && stars[i - 1] > 0);
  int get total => stars.fold(0, (a, b) => a + b);

  /// First level that is unlocked but not finished yet.
  int get current {
    for (var i = 0; i < stars.length; i++) {
      if (stars[i] == 0) return i;
    }
    return stars.length - 1;
  }

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

/// Stars you earned minus stars you spent, plus the powers you own.
/// Powers: 0 = Bomb, 1 = Snake, 2 = Freeze.
class Wallet extends ChangeNotifier {
  Wallet._();
  static final Wallet instance = Wallet._();

  static const List<String> names = ['Bomb', 'Snake', 'Freeze'];
  static const List<int> costs = [3, 5, 4];
  static const List<String> info = [
    'Shoot it: blasts the eggs around it',
    'Shoot it: eats a whole colour of eggs',
    'Stops the timer and new rows for 10 seconds',
  ];

  int earned = 0;
  int spent = 0;
  final List<int> owned = [0, 0, 0];
  bool _loaded = false;

  int get balance => earned - spent;

  Future<void> refresh(int levels) async {
    try {
      final p = await SharedPreferences.getInstance();
      var sum = 0;
      for (var i = 0; i < levels; i++) {
        sum += p.getInt('shot_stars_$i') ?? 0;
      }
      earned = sum;
      if (!_loaded) {
        spent = p.getInt('shot_spent') ?? 0;
        for (var k = 0; k < 3; k++) {
          owned[k] = p.getInt('shot_power_$k') ?? 0;
        }
        _loaded = true;
        if (!(p.getBool('shot_gift') ?? false)) {
          // welcome gift: one of each power so you can try them
          for (var k = 0; k < 3; k++) {
            owned[k] += 1;
          }
          await p.setBool('shot_gift', true);
          _save();
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  bool buy(int k) {
    if (balance < costs[k]) return false;
    spent += costs[k];
    owned[k]++;
    _save();
    return true;
  }

  bool take(int k) {
    if (owned[k] <= 0) return false;
    owned[k]--;
    _save();
    return true;
  }

  void give(int k) {
    owned[k]++;
    _save();
  }

  Future<void> _save() async {
    Future.microtask(notifyListeners);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('shot_spent', spent);
      for (var k = 0; k < 3; k++) {
        await p.setInt('shot_power_$k', owned[k]);
      }
    } catch (_) {}
  }
}
