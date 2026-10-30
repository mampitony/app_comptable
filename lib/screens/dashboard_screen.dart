// lib/screens/dashboard_screen.dart
//
// Tableau de bord : revenus et dépenses par catégorie, par mois ou par année.
// - Données en temps réel (Firestore `revenus` et `depenses`).
// - Graphiques dessinés avec CustomPainter : aucune dépendance à ajouter.
import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

// ───────────────────────── Couleurs ─────────────────────────
const Color _bg = Color(0xFF0F172A);
const Color _card = Color(0xFF1E293B);
const Color _muted = Color(0xFF94A3B8);
const Color _revColor = Color(0xFF2DD4BF);
const Color _depColor = Color(0xFFFB923C);

const List<String> _monthNames = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];
const List<String> _monthShort = [
  'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
  'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
];

// ───────────────────────── Catégories ─────────────────────────
class _Cat {
  final String label;
  final Color color;
  const _Cat(this.label, this.color);
}

// La dernière catégorie ("Autre") reçoit aussi tout type non reconnu.
const List<_Cat> _revCats = [
  _Cat('Cotisation', Color(0xFF22D3EE)),
  _Cat('Don', Color(0xFFA78BFA)),
  _Cat('Subvention', Color(0xFF34D399)),
  _Cat('Activité', Color(0xFFFBBF24)),
  _Cat('Autre', Color(0xFFF472B6)),
];

const List<_Cat> _depCats = [
  _Cat('Déplacement', Color(0xFFFB923C)),
  _Cat('Achat', Color(0xFFF472B6)),
  _Cat('Communication', Color(0xFF60A5FA)),
  _Cat('Activités', Color(0xFFA78BFA)),
  _Cat('Autre', Color(0xFF94A3B8)),
];

class _Entry {
  final DateTime date;
  final String cat;
  final double amount;
  const _Entry(this.date, this.cat, this.amount);
}

class _Series {
  final List<double> rev;
  final List<double> dep;
  const _Series(this.rev, this.dep);
}

enum _Period { month, year }

// ───────────────────────── Utilitaires ─────────────────────────
String _norm(String s) {
  var t = s.trim().toLowerCase();
  if (t.endsWith('s')) t = t.substring(0, t.length - 1);
  return t;
}

String _catLabel(dynamic type, List<_Cat> cats) {
  final t = _norm('${type ?? ''}');
  for (final c in cats) {
    if (_norm(c.label) == t) return c.label;
  }
  return cats.last.label;
}

// Les dates sont stockées en texte : "dd/MM/yyyy" (revenus) ou "yyyy-MM-dd"
// (dépenses). On accepte les deux, plus les Timestamp Firestore.
DateTime? _parseDate(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  final s = '${raw ?? ''}'.trim();
  if (s.isEmpty) return null;
  try {
    final base = s.split('T').first.split(' ').first;
    if (base.contains('/')) {
      final p = base.split('/');
      if (p.length == 3) {
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
    }
    if (base.contains('-')) {
      final p = base.split('-');
      if (p.length == 3) {
        if (p[0].length == 4) {
          return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
        }
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
    }
  } catch (_) {}
  return null;
}

double _parseAmount(dynamic raw) {
  if (raw is num) return raw.toDouble();
  final s = '${raw ?? ''}'.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.');
  return double.tryParse(s) ?? 0;
}

String _money(double v) {
  final n = v.round();
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$buf Ar';
}

String _trimNum(double x) =>
    x == x.roundToDouble() ? x.toStringAsFixed(0) : x.toStringAsFixed(1);

String _compact(double v) {
  if (v >= 1000000) return '${_trimNum(v / 1000000)}M';
  if (v >= 1000) return '${_trimNum(v / 1000)}k';
  return v.toStringAsFixed(0);
}

double _niceMax(double v) {
  if (v <= 0) return 1000;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final f = v / exp;
  final nf = f <= 1 ? 1.0 : (f <= 2 ? 2.0 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5.0 : 10.0)));
  return nf * exp;
}

// ───────────────────────── Écran ─────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<QuerySnapshot>? _revSub;
  StreamSubscription<QuerySnapshot>? _depSub;

  List<Map<String, dynamic>> _revenus = [];
  List<Map<String, dynamic>> _depenses = [];
  bool _loadedRev = false;
  bool _loadedDep = false;
  String? _error;

  _Period _period = _Period.month;
  late int _year;
  late int _month;
  int? _selectedBar;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _listen();
  }

  void _listen() {
    final fb = FirebaseService.instance;
    _revSub = fb.revenus.snapshots().listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _revenus = snap.docs
              .map((d) => (d.data() as Map<String, dynamic>?) ?? <String, dynamic>{})
              .toList();
          _loadedRev = true;
        });
      },
      onError: (e) {
        if (mounted) setState(() => _error = '$e');
      },
    );
    _depSub = fb.depenses.snapshots().listen(
      (snap) {
        if (!mounted) return;
        setState(() {
          _depenses = snap.docs
              .map((d) => (d.data() as Map<String, dynamic>?) ?? <String, dynamic>{})
              .toList();
          _loadedDep = true;
        });
      },
      onError: (e) {
        if (mounted) setState(() => _error = '$e');
      },
    );
  }

  @override
  void dispose() {
    _revSub?.cancel();
    _depSub?.cancel();
    super.dispose();
  }

  // ───────── Calculs ─────────
  List<_Entry> _toEntries(List<Map<String, dynamic>> raw, List<_Cat> cats) {
    final out = <_Entry>[];
    for (final m in raw) {
      final date = _parseDate(m['date']) ?? _parseDate(m['createdAt']);
      final amount = _parseAmount(m['montant']);
      if (date == null || amount <= 0) continue;
      out.add(_Entry(date, _catLabel(m['type'], cats), amount));
    }
    return out;
  }

  bool _inPeriod(_Entry e) =>
      e.date.year == _year &&
      (_period == _Period.year || e.date.month == _month);

  Map<String, double> _sumByCat(List<_Entry> entries, List<_Cat> cats) {
    final totals = <String, double>{for (final c in cats) c.label: 0.0};
    for (final e in entries) {
      totals[e.cat] = (totals[e.cat] ?? 0) + e.amount;
    }
    return totals;
  }

  _Series _series(List<_Entry> rev, List<_Entry> dep) {
    final isYear = _period == _Period.year;
    final n = isYear ? 12 : DateTime(_year, _month + 1, 0).day;
    final r = List<double>.filled(n, 0);
    final d = List<double>.filled(n, 0);
    for (final e in rev) {
      final i = isYear ? e.date.month - 1 : e.date.day - 1;
      if (i >= 0 && i < n) r[i] += e.amount;
    }
    for (final e in dep) {
      final i = isYear ? e.date.month - 1 : e.date.day - 1;
      if (i >= 0 && i < n) d[i] += e.amount;
    }
    return _Series(r, d);
  }

  List<String> _labels(int n) => List<String>.generate(n, (i) {
        if (_period == _Period.year) return _monthShort[i];
        final day = i + 1;
        return (day == 1 || day % 5 == 0) ? '$day' : '';
      });

  String _bucketTitle(int i) => _period == _Period.year
      ? '${_monthNames[i]} $_year'
      : '${i + 1} ${_monthNames[_month - 1]} $_year';

  String get _periodLabel => _period == _Period.year
      ? '$_year'
      : '${_monthNames[_month - 1]} $_year';

  DateTime _earliest(List<_Entry> a, List<_Entry> b) {
    var min = DateTime.now();
    for (final e in a) {
      if (e.date.isBefore(min)) min = e.date;
    }
    for (final e in b) {
      if (e.date.isBefore(min)) min = e.date;
    }
    return min;
  }

  bool _canPrev(DateTime earliest) {
    if (_period == _Period.year) return _year > earliest.year;
    return _year > earliest.year ||
        (_year == earliest.year && _month > earliest.month);
  }

  bool get _canNext {
    final now = DateTime.now();
    if (_period == _Period.year) return _year < now.year;
    return _year < now.year || (_year == now.year && _month < now.month);
  }

  void _prev() {
    setState(() {
      _selectedBar = null;
      if (_period == _Period.year) {
        _year--;
      } else if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _next() {
    setState(() {
      _selectedBar = null;
      if (_period == _Period.year) {
        _year++;
      } else if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  void _setPeriod(_Period p) {
    if (_period == p) return;
    setState(() {
      _period = p;
      _selectedBar = null;
    });
  }

  // ───────── Interface ─────────
  @override
  Widget build(BuildContext context) {
    return Container(color: _bg, child: _body());
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Impossible de charger les données.\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (!_loadedRev || !_loadedDep) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final revAll = _toEntries(_revenus, _revCats);
    final depAll = _toEntries(_depenses, _depCats);
    final rev = revAll.where(_inPeriod).toList();
    final dep = depAll.where(_inPeriod).toList();

    final revTotals = _sumByCat(rev, _revCats);
    final depTotals = _sumByCat(dep, _depCats);
    final totalRev = revTotals.values.fold(0.0, (a, b) => a + b);
    final totalDep = depTotals.values.fold(0.0, (a, b) => a + b);
    final solde = totalRev - totalDep;
    final series = _series(rev, dep);
    final earliest = _earliest(revAll, depAll);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _periodControls(earliest),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('Revenus', totalRev, Icons.south_west_rounded, _revColor),
            const SizedBox(width: 12),
            _kpi('Dépenses', totalDep, Icons.north_east_rounded, _depColor),
          ],
        ),
        const SizedBox(height: 12),
        _soldeCard(solde, totalRev, totalDep),
        const SizedBox(height: 16),
        _evolutionCard(series),
        const SizedBox(height: 16),
        _donutCard(
          title: 'Revenus par catégorie',
          icon: Icons.account_balance_wallet_rounded,
          cats: _revCats,
          totals: revTotals,
        ),
        const SizedBox(height: 16),
        _donutCard(
          title: 'Dépenses par catégorie',
          icon: Icons.shopping_cart_checkout_rounded,
          cats: _depCats,
          totals: depTotals,
        ),
      ],
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      );

  Widget _periodControls(DateTime earliest) {
    final canPrev = _canPrev(earliest);
    final canNext = _canNext;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _toggle('Par mois', _period == _Period.month,
                    () => _setPeriod(_Period.month)),
                _toggle('Par année', _period == _Period.year,
                    () => _setPeriod(_Period.year)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: canPrev ? _prev : null,
                icon: const Icon(Icons.chevron_left_rounded),
                color: Colors.white,
                disabledColor: Colors.white24,
              ),
              Expanded(
                child: Text(
                  _periodLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: canNext ? _next : null,
                icon: const Icon(Icons.chevron_right_rounded),
                color: Colors.white,
                disabledColor: Colors.white24,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0163D2) : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : _muted,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpi(String label, double value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(color: _muted, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _money(value),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _soldeCard(double solde, double totalRev, double totalDep) {
    final positive = solde >= 0;
    final color = positive ? const Color(0xFF34D399) : const Color(0xFFF87171);
    final ratio = totalRev > 0 ? (totalDep / totalRev * 100).round() : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.22), _card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Solde de la période',
                    style: TextStyle(color: _muted, fontSize: 13)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${positive ? '+' : ''}${_money(solde)}',
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (ratio != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$ratio % des revenus ont été dépensés',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      ],
    );
  }

  Widget _evolutionCard(_Series s) {
    final n = s.rev.length;
    final maxRev = s.rev.fold<double>(0.0, (a, b) => math.max(a, b));
    final maxDep = s.dep.fold<double>(0.0, (a, b) => math.max(a, b));
    final maxV = _niceMax(math.max(maxRev, maxDep));
    final labels = _labels(n);
    final sel = (_selectedBar != null && _selectedBar! < n) ? _selectedBar : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            _period == _Period.year ? 'Évolution mensuelle' : 'Évolution journalière',
            Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _legendDot(_revColor, 'Revenus'),
              const SizedBox(width: 16),
              _legendDot(_depColor, 'Dépenses'),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, cons) {
              final w = cons.maxWidth;
              return GestureDetector(
                onTapDown: (d) {
                  final chartW =
                      w - _BarChartPainter.leftPad - _BarChartPainter.rightPad;
                  final idx =
                      ((d.localPosition.dx - _BarChartPainter.leftPad) / (chartW / n))
                          .floor();
                  setState(() {
                    _selectedBar = (idx < 0 || idx >= n || idx == _selectedBar)
                        ? null
                        : idx;
                  });
                },
                child: CustomPaint(
                  size: Size(w, 210),
                  painter: _BarChartPainter(
                    rev: s.rev,
                    dep: s.dep,
                    labels: labels,
                    selected: sel,
                    maxV: maxV,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: sel == null
                ? const Text(
                    'Touchez une barre pour voir le détail.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _bucketTitle(sel),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Revenus : ${_money(s.rev[sel])}',
                          style: const TextStyle(color: _revColor, fontSize: 13)),
                      Text('Dépenses : ${_money(s.dep[sel])}',
                          style: const TextStyle(color: _depColor, fontSize: 13)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _donutCard({
    required String title,
    required IconData icon,
    required List<_Cat> cats,
    required Map<String, double> totals,
  }) {
    final total = totals.values.fold(0.0, (a, b) => a + b);
    final values = cats.map((c) => totals[c.label] ?? 0.0).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(title, icon),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 170,
              height: 170,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(170, 170),
                    painter: _DonutPainter(
                      values: values,
                      colors: cats.map((c) => c.color).toList(),
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('TOTAL',
                            style: TextStyle(
                                color: _muted, fontSize: 11, letterSpacing: 1.2)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            total > 0 ? _money(total) : 'Aucune donnée',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < cats.length; i++) ...[
            _legendRow(cats[i], values[i], total),
            if (i < cats.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _legendRow(_Cat cat, double value, double total) {
    final pct = total > 0 ? value / total * 100 : 0.0;
    final pctText = '${pct.toStringAsFixed(pct >= 10 || pct == 0 ? 0 : 1)} %';
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                cat.label,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            Text(
              _money(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              width: 52,
              child: Text(
                pctText,
                textAlign: TextAlign.right,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (pct / 100).clamp(0.0, 1.0),
            minHeight: 4,
            color: cat.color,
            backgroundColor: Colors.white.withOpacity(0.06),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Graphiques ─────────────────────────
void _drawText(
  Canvas canvas,
  String text,
  Offset anchor, {
  TextAlign align = TextAlign.center,
  double size = 10,
  Color color = _muted,
  bool vCenter = false,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  var dx = anchor.dx;
  if (align == TextAlign.center) {
    dx -= tp.width / 2;
  } else if (align == TextAlign.right) {
    dx -= tp.width;
  }
  final dy = vCenter ? anchor.dy - tp.height / 2 : anchor.dy;
  tp.paint(canvas, Offset(dx, dy));
}

class _BarChartPainter extends CustomPainter {
  static const double leftPad = 40;
  static const double rightPad = 4;
  static const double topPad = 10;
  static const double bottomPad = 22;

  final List<double> rev;
  final List<double> dep;
  final List<String> labels;
  final int? selected;
  final double maxV;

  _BarChartPainter({
    required this.rev,
    required this.dep,
    required this.labels,
    required this.selected,
    required this.maxV,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Rect.fromLTRB(
      leftPad,
      topPad,
      size.width - rightPad,
      size.height - bottomPad,
    );

    final grid = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _drawText(
        canvas,
        _compact(maxV * i / 4),
        Offset(leftPad - 6, y),
        align: TextAlign.right,
        vCenter: true,
      );
    }

    final n = rev.length;
    if (n == 0) return;
    final slot = chart.width / n;
    final groupW = slot * 0.72;
    final barW = (groupW - 2) / 2;

    for (var i = 0; i < n; i++) {
      final slotLeft = chart.left + slot * i;
      final gx = slotLeft + (slot - groupW) / 2;

      if (selected == i) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(slotLeft, chart.top, slot, chart.height),
            const Radius.circular(6),
          ),
          Paint()..color = Colors.white.withOpacity(0.08),
        );
      }

      _bar(canvas, chart, gx, barW, rev[i], _revColor, const Color(0xFF0EA5E9));
      _bar(canvas, chart, gx + barW + 2, barW, dep[i], _depColor,
          const Color(0xFFEC4899));

      if (labels[i].isNotEmpty) {
        _drawText(
          canvas,
          labels[i],
          Offset(slotLeft + slot / 2, chart.bottom + 6),
        );
      }
    }
  }

  void _bar(Canvas canvas, Rect chart, double x, double w, double v,
      Color top, Color bottom) {
    if (v <= 0 || maxV <= 0) return;
    final h = math.max(chart.height * v / maxV, 2.0);
    final rect = Rect.fromLTWH(x, chart.bottom - h, w, h);
    final rr = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter old) => true;
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  _DonutPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final stroke = size.width * 0.14;
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withOpacity(0.06),
    );

    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;

    final nonZero = values.where((v) => v > 0).length;
    final gap = nonZero > 1 ? 0.04 : 0.0;
    var start = -math.pi / 2;

    for (var i = 0; i < values.length; i++) {
      if (values[i] <= 0) continue;
      final sweep = values[i] / total * 2 * math.pi;
      canvas.drawArc(
        rect,
        start + gap / 2,
        math.max(sweep - gap, 0.001),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}
