import 'dart:math' as math;
import 'dart:ui';

import '../models/shot_levels.dart';

const int kCols = 9;

/// Pure-Dart hex-grid board. Rows alternate between 9 and 8 eggs.
/// Even rows start at the left wall, odd rows are shifted half an egg right.
class EggBoard {
  final List<List<int>> rows = [];
  int shift = 0; // grows when a row is added on top (keeps parity of old rows)

  bool rowOdd(int r) => (r + shift).isOdd;
  int colsIn(int r) => rowOdd(r) ? kCols - 1 : kCols;

  static int key(int r, int c) => r * 16 + c;
  static int rowOf(int k) => k ~/ 16;
  static int colOf(int k) => k % 16;

  void ensureRows(int n) {
    while (rows.length < n) {
      rows.add(List<int>.filled(kCols, kEmpty));
    }
  }

  bool inside(int r, int c) =>
      r >= 0 && r < rows.length && c >= 0 && c < colsIn(r);

  int get(int r, int c) => inside(r, c) ? rows[r][c] : kEmpty;

  void set(int r, int c, int v) {
    ensureRows(r + 1);
    if (c >= 0 && c < colsIn(r)) rows[r][c] = v;
  }

  int getK(int k) => get(rowOf(k), colOf(k));
  void setK(int k, int v) => set(rowOf(k), colOf(k), v);

  List<int> neighbors(int r, int c) {
    final out = <int>[];
    void add(int nr, int nc) {
      if (nr < 0 || nc < 0) return;
      if (nc >= (((nr + shift).isOdd) ? kCols - 1 : kCols)) return;
      out.add(key(nr, nc));
    }

    add(r, c - 1);
    add(r, c + 1);
    for (final dr in const [-1, 1]) {
      final nr = r + dr;
      if (rowOdd(r)) {
        add(nr, c);
        add(nr, c + 1);
      } else {
        add(nr, c - 1);
        add(nr, c);
      }
    }
    return out;
  }

  Offset center(int r, int c, double d, double top) {
    final x = (c + 0.5 + (rowOdd(r) ? 0.5 : 0)) * d;
    final y = top + d * 0.5 + r * d * 0.866;
    return Offset(x, y);
  }

  /// Nearest free, attached cell to point [p].
  int? nearestEmpty(Offset p, double d, double top) {
    final r0 = ((p.dy - top - d * 0.5) / (d * 0.866)).round();
    int? best;
    var bestD = double.infinity;
    for (var r = math.max(0, r0 - 2); r <= r0 + 2; r++) {
      ensureRows(r + 1);
      for (var c = 0; c < colsIn(r); c++) {
        if (rows[r][c] != kEmpty) continue;
        var attached = r == 0;
        if (!attached) {
          for (final n in neighbors(r, c)) {
            if (getK(n) != kEmpty) {
              attached = true;
              break;
            }
          }
        }
        if (!attached) continue;
        final dist = (center(r, c, d, top) - p).distance;
        if (dist < bestD) {
          bestD = dist;
          best = key(r, c);
        }
      }
    }
    return best;
  }

  /// Same-colour connected group (colour eggs only).
  Set<int> cluster(int k) {
    final col = getK(k);
    final out = <int>{};
    if (col < 0 || col >= 100) return out;
    final q = <int>[k];
    out.add(k);
    while (q.isNotEmpty) {
      final cur = q.removeLast();
      for (final n in neighbors(rowOf(cur), colOf(cur))) {
        if (!out.contains(n) && getK(n) == col) {
          out.add(n);
          q.add(n);
        }
      }
    }
    return out;
  }

  /// Eggs not connected to the top row.
  Set<int> floating() {
    final seen = <int>{};
    final q = <int>[];
    if (rows.isNotEmpty) {
      for (var c = 0; c < colsIn(0); c++) {
        if (rows[0][c] != kEmpty) {
          seen.add(key(0, c));
          q.add(key(0, c));
        }
      }
    }
    while (q.isNotEmpty) {
      final cur = q.removeLast();
      for (final n in neighbors(rowOf(cur), colOf(cur))) {
        if (!seen.contains(n) && getK(n) != kEmpty) {
          seen.add(n);
          q.add(n);
        }
      }
    }
    final out = <int>{};
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < colsIn(r); c++) {
        if (rows[r][c] != kEmpty && !seen.contains(key(r, c))) {
          out.add(key(r, c));
        }
      }
    }
    return out;
  }

  /// Pushes everything down one row and adds a fresh row on top.
  void addRowTop(List<int> colors, math.Random rnd) {
    rows.insert(0, List<int>.filled(kCols, kEmpty));
    shift++;
    for (var c = 0; c < colsIn(0); c++) {
      rows[0][c] = colors[rnd.nextInt(colors.length)];
    }
  }

  Set<int> colorsOnBoard() {
    final s = <int>{};
    for (final row in rows) {
      for (final v in row) {
        if (v >= 0 && v < 100) s.add(v);
      }
    }
    return s;
  }

  int count() {
    var n = 0;
    for (final row in rows) {
      for (final v in row) {
        if (v != kEmpty) n++;
      }
    }
    return n;
  }

  int maxFilledRow() {
    for (var r = rows.length - 1; r >= 0; r--) {
      for (var c = 0; c < colsIn(r); c++) {
        if (rows[r][c] != kEmpty) return r;
      }
    }
    return -1;
  }

  /// Fills [n] rows at the top. Some same-colour clustering so matches exist.
  void fill(int n, int colorCount, math.Random rnd) {
    rows.clear();
    shift = 0;
    ensureRows(n);
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < colsIn(r); c++) {
        int v = rnd.nextInt(colorCount);
        if (rnd.nextDouble() < 0.55) {
          final cand = <int>[];
          if (c > 0 && rows[r][c - 1] >= 0) cand.add(rows[r][c - 1]);
          if (r > 0) {
            for (final nk in neighbors(r, c)) {
              if (rowOf(nk) == r - 1 && getK(nk) >= 0) cand.add(getK(nk));
            }
          }
          if (cand.isNotEmpty) v = cand[rnd.nextInt(cand.length)];
        }
        rows[r][c] = v;
      }
    }
  }
}
