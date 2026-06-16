import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';
import '../data/database_service.dart';

class BodyMapScreen extends StatefulWidget {
  const BodyMapScreen({super.key});

  @override
  State<BodyMapScreen> createState() => _BodyMapScreenState();
}

class _BodyMapScreenState extends State<BodyMapScreen> with SingleTickerProviderStateMixin {
  bool _showFront = true;
  String? _selectedMuscle;
  Map<String, double> _muscleVolumes = {};
  double _maxVolume = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _calculateVolumes();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnim = Tween<double>(begin: 3.0, end: 12.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _calculateVolumes() {
    final workouts = DatabaseService.getAllWorkouts();
    // Calcoliamo i volumi degli ultimi 30 giorni
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = workouts.where((w) => w.date.isAfter(cutoff)).toList();

    final Map<String, double> volumes = {
      'Petto': 0.0,
      'Schiena': 0.0,
      'Spalle': 0.0,
      'Gambe': 0.0,
      'Glutei': 0.0,
      'Braccia': 0.0,
      'Core': 0.0,
    };

    for (final w in recent) {
      for (final ex in w.exercises) {
        final group = (ex.gruppoMuscolare != null && ex.gruppoMuscolare!.isNotEmpty)
            ? ex.gruppoMuscolare!
            : 'Altro';
        double vol = 0.0;
        for (final s in ex.sets) {
          vol += s.weight * s.reps;
        }

        if (volumes.containsKey(group)) {
          volumes[group] = volumes[group]! + vol;
        } else if (group == 'Altro') {
          // accumula altrove o ignora per la mappa
        }
      }
    }

    double maxVol = 0.0;
    volumes.forEach((k, v) {
      if (v > maxVol) maxVol = v;
    });

    setState(() {
      _muscleVolumes = volumes;
      _maxVolume = maxVol;
    });
  }

  Color _getMuscleColor(String muscle, {bool isStroke = false, double opacity = 1.0}) {
    final vol = _muscleVolumes[muscle] ?? 0.0;
    if (vol == 0) {
      return isStroke ? Colors.white24 : Colors.white.withValues(alpha: 0.04);
    }

    final intensity = _maxVolume > 0 ? (vol / _maxVolume) : 0.0;
    // Sfumatura neon da viola (volume basso) a ciano (volume alto)
    final baseColor = Color.lerp(AppTheme.vividPurple, AppTheme.cyan, intensity)!;

    if (isStroke) {
      return baseColor.withValues(alpha: opacity);
    }
    return baseColor.withValues(alpha: 0.25 + (intensity * 0.45)); // riempimento neon semitrasparente
  }

  String _getMuscleMotivation(String muscle) {
    final vol = _muscleVolumes[muscle] ?? 0.0;
    if (vol == 0) {
      return "Ancora nessun volume registrato nell'ultimo mese. Dai energia a questo distretto!";
    }
    
    final intensity = _maxVolume > 0 ? (vol / _maxVolume) : 0.0;
    if (intensity > 0.75) {
      return "Intensità eccezionale! Stai martellando questo distretto con carichi ottimali. Continua a recuperare bene.";
    } else if (intensity > 0.4) {
      return "Ottimo stimolo. Il volume è bilanciato ed equilibrato. Mantieni questa costanza per favorire l'ipertrofia.";
    } else {
      return "Stimolo leggero. Considera di aggiungere una sessione o qualche serie extra se desideri dare priorità a questo gruppo.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppTheme.buildBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Cyber Body Map', style: TextStyle(color: AppTheme.textPrimary)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text(
                'HEATMAP MUSCOLARE (30g)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Switch Anteriore / Posteriore Premium
              Center(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildViewTab(true, 'ANTERIORE'),
                      _buildViewTab(false, 'POSTERIORE'),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: Row(
                  children: [
                    // Area interattiva per la silhouette
                    Expanded(
                      flex: 6,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, child) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final height = constraints.maxHeight;
                              return GestureDetector(
                                onTapDown: (details) {
                                  _handleTap(details.localPosition, width, height);
                                },
                                child: CustomPaint(
                                  size: Size(width, height),
                                  painter: BodyMapPainter(
                                    showFront: _showFront,
                                    selectedMuscle: _selectedMuscle,
                                    pulseRadius: _pulseAnim.value,
                                    getFillColor: (m) => _getMuscleColor(m, isStroke: false),
                                    getStrokeColor: (m, op) => _getMuscleColor(m, isStroke: true, opacity: op),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Legenda dei volumi a lato
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendDot(AppTheme.cyan, 'Alto'),
                          const SizedBox(height: 12),
                          _buildLegendDot(Color.lerp(AppTheme.vividPurple, AppTheme.cyan, 0.5)!, 'Medio'),
                          const SizedBox(height: 12),
                          _buildLegendDot(AppTheme.vividPurple, 'Basso'),
                          const SizedBox(height: 12),
                          _buildLegendDot(Colors.white24, 'Nullo'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Pannello informativo del muscolo selezionato
              _buildInfoPanel().animate(target: _selectedMuscle != null ? 1 : 0).fadeIn().slideY(begin: 0.2, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewTab(bool front, String label) {
    final active = _showFront == front;
    return GestureDetector(
      onTap: () {
        setState(() {
          _showFront = front;
          _selectedMuscle = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.cyan : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.cyan.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
            boxShadow: [
              if (color != Colors.white24)
                BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 0.5)
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildInfoPanel() {
    if (_selectedMuscle == null) {
      return Container(
        height: 140,
        margin: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Tocca un distretto muscolare per vedere i dettagli',
            style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 13, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    final m = _selectedMuscle!;
    final vol = _muscleVolumes[m] ?? 0.0;

    return AppTheme.glassContainer(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      borderColor: _getMuscleColor(m, isStroke: true, opacity: 0.6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                m.toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _getMuscleColor(m, isStroke: true),
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getMuscleColor(m, isStroke: true).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getMuscleColor(m, isStroke: true).withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Vol: ${vol.toStringAsFixed(0)} kg',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _getMuscleColor(m, isStroke: true),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _getMuscleMotivation(m),
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  void _handleTap(Offset pos, double w, double h) {
    final x = pos.dx / w * 100;
    final y = pos.dy / h * 100;

    // Definiamo delle regioni di tap semplici approssimate in percentuale (0-100)
    // per intercettare i distretti muscolari sulla silhouette centrata.
    // La silhouette è disegnata centrata orizzontalmente nel CustomPainter (offset X ~ 25..75%).

    String? tapped;
    if (_showFront) {
      // ANTERIORE
      if (y >= 15 && y <= 35 && x >= 30 && x <= 70) {
        // Spalle o Petto
        if (y < 23) {
          if (x < 43 || x > 57) {
            tapped = 'Spalle';
          } else {
            tapped = 'Petto'; // zona sterno/collo basso
          }
        } else {
          if (x >= 38 && x <= 62) {
            tapped = 'Petto';
          } else {
            tapped = 'Braccia'; // Bicipiti/Spalla esterna
          }
        }
      } else if (y > 35 && y <= 50 && x >= 38 && x <= 62) {
        tapped = 'Core'; // Addome
      } else if (y > 35 && y <= 55 && (x < 38 || x > 62) && x >= 28 && x <= 72) {
        tapped = 'Braccia'; // Avambracci / mani
      } else if (y > 50 && y <= 80 && x >= 32 && x <= 68) {
        tapped = 'Gambe'; // Quadricipiti
      }
    } else {
      // POSTERIORE
      if (y >= 15 && y <= 35 && x >= 30 && x <= 70) {
        // Spalle o Schiena
        if (y < 23) {
          if (x < 42 || x > 58) {
            tapped = 'Spalle';
          } else {
            tapped = 'Schiena'; // Trapezio alto
          }
        } else {
          if (x >= 40 && x <= 60) {
            tapped = 'Schiena'; // Dorsali
          } else {
            tapped = 'Braccia'; // Tricipiti
          }
        }
      } else if (y > 35 && y <= 50 && (x < 38 || x > 62) && x >= 28 && x <= 72) {
        tapped = 'Braccia'; // Avambracci
      } else if (y > 50 && y <= 62 && x >= 35 && x <= 65) {
        tapped = 'Glutei';
      } else if (y > 62 && y <= 90 && x >= 30 && x <= 70) {
        tapped = 'Gambe'; // Femorali / Polpacci
      }
    }

    setState(() {
      _selectedMuscle = tapped;
    });
  }
}

class BodyMapPainter extends CustomPainter {
  final bool showFront;
  final String? selectedMuscle;
  final double pulseRadius;
  final Color Function(String) getFillColor;
  final Color Function(String, double) getStrokeColor;

  const BodyMapPainter({
    required this.showFront,
    required this.selectedMuscle,
    required this.pulseRadius,
    required this.getFillColor,
    required this.getStrokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Centriamo la silhouette in scala proporzionale
    final double scale = h / 100.0;
    final double offsetX = (w - (45.0 * scale)) / 2.0;

    // Helper per convertire coordinate relative % in coordinate reali
    Offset pt(double rx, double ry) {
      // la silhouette teorica occupa x da 27.5 a 72.5 (larghezza 45) in una griglia 0..100
      final double realX = offsetX + (rx - 27.5) * scale;
      final double realY = ry * scale;
      return Offset(realX, realY);
    }

    // --- DISEGNO DELLA SAGOMA GENERALE (WIRE-BODY) ---
    final bodyPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    
    final bodyBorder = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Testa
    canvas.drawOval(
      Rect.fromCenter(center: pt(50, 10), width: 8 * scale, height: 10 * scale),
      bodyPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: pt(50, 10), width: 8 * scale, height: 10 * scale),
      bodyBorder,
    );

    // Collo
    final neck = Path()
      ..moveTo(pt(47, 14).dx, pt(47, 14).dy)
      ..lineTo(pt(53, 14).dx, pt(53, 14).dy)
      ..lineTo(pt(54, 17).dx, pt(54, 17).dy)
      ..lineTo(pt(46, 17).dx, pt(46, 17).dy)
      ..close();
    canvas.drawPath(neck, bodyPaint);
    canvas.drawPath(neck, bodyBorder);

    // Disegniamo i singoli distretti muscolari
    if (showFront) {
      // --------------------------------------------------
      // VISTA ANTERIORE
      // --------------------------------------------------

      // 1. PETTO
      _drawMusclePath(canvas, 'Petto', [
        [pt(50, 18), pt(58, 19), pt(59, 26), pt(50, 27)], // Sinistro
        [pt(50, 18), pt(42, 19), pt(41, 26), pt(50, 27)], // Destro
      ]);

      // 2. SPALLE
      _drawMusclePath(canvas, 'Spalle', [
        [pt(59, 19), pt(65, 20), pt(63, 26), pt(59, 26)], // Spalla Sinistra
        [pt(41, 19), pt(35, 20), pt(37, 26), pt(41, 26)], // Spalla Destra
      ]);

      // 3. BRACCIA (Bicipiti / Avambracci Anteriore)
      _drawMusclePath(canvas, 'Braccia', [
        [pt(63, 26), pt(67, 30), pt(65, 42), pt(61, 38), pt(60, 26)], // Braccio Sinistro
        [pt(37, 26), pt(33, 30), pt(35, 42), pt(39, 38), pt(40, 26)], // Braccio Destro
      ]);

      // 4. CORE (Addominali)
      _drawMusclePath(canvas, 'Core', [
        [pt(44, 28), pt(56, 28), pt(55, 47), pt(45, 47)],
      ]);

      // 5. GAMBE (Quadricipiti Anteriore)
      _drawMusclePath(canvas, 'Gambe', [
        [pt(40, 48), pt(49, 48), pt(47, 72), pt(42, 72)], // Coscia Destra
        [pt(51, 48), pt(60, 48), pt(58, 72), pt(53, 72)], // Coscia Sinistra
        [pt(42, 73), pt(46, 73), pt(45, 92), pt(41, 92)], // Tibiale Destro (Sotto-Gamba)
        [pt(54, 73), pt(58, 73), pt(59, 92), pt(55, 92)], // Tibiale Sinistro
      ]);

    } else {
      // --------------------------------------------------
      // VISTA POSTERIORE
      // --------------------------------------------------

      // 1. SCHIENA (Trapezio / Dorsali)
      _drawMusclePath(canvas, 'Schiena', [
        [pt(50, 17), pt(58, 19), pt(56, 32), pt(50, 36)], // Dorsale Sinistro
        [pt(50, 17), pt(42, 19), pt(44, 32), pt(50, 36)], // Dorsale Destro
        [pt(45, 33), pt(55, 33), pt(54, 46), pt(46, 46)], // Zona Lombare
      ]);

      // 2. SPALLE (Posteriore)
      _drawMusclePath(canvas, 'Spalle', [
        [pt(59, 19), pt(64, 21), pt(62, 26), pt(59, 25)],
        [pt(41, 19), pt(36, 21), pt(38, 26), pt(41, 25)],
      ]);

      // 3. BRACCIA (Tricipiti Posteriore)
      _drawMusclePath(canvas, 'Braccia', [
        [pt(62, 26), pt(66, 30), pt(64, 42), pt(60, 36)],
        [pt(38, 26), pt(34, 30), pt(36, 42), pt(40, 36)],
      ]);

      // 4. GLUTEI
      _drawMusclePath(canvas, 'Glutei', [
        [pt(38, 47), pt(50, 47), pt(49, 58), pt(39, 57)], // Gluteo Destro
        [pt(50, 47), pt(62, 47), pt(61, 57), pt(51, 58)], // Gluteo Sinistro
      ]);

      // 5. GAMBE (Femorali / Polpacci Posteriore)
      _drawMusclePath(canvas, 'Gambe', [
        [pt(39, 58), pt(49, 59), pt(47, 73), pt(41, 73)], // Femorale Destro
        [pt(51, 59), pt(61, 58), pt(59, 73), pt(53, 73)], // Femorale Sinistro
        [pt(41, 74), pt(46, 74), pt(44, 91), pt(42, 91)], // Polpaccio Destro
        [pt(54, 74), pt(59, 74), pt(58, 91), pt(56, 91)], // Polpaccio Sinistro
      ]);
    }
  }

  void _drawMusclePath(Canvas canvas, String group, List<List<Offset>> coordinatesList) {
    final isSelected = selectedMuscle == group;
    final fillColor = getFillColor(group);

    // Definiamo il paint del riempimento
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Disegniamo ciascuna area del gruppo muscolare
    for (final coords in coordinatesList) {
      if (coords.isEmpty) continue;
      
      final path = Path()..moveTo(coords.first.dx, coords.first.dy);
      for (int i = 1; i < coords.length; i++) {
        path.lineTo(coords[i].dx, coords[i].dy);
      }
      path.close();

      // Disegna riempimento muscolo
      canvas.drawPath(path, fillPaint);

      // Disegna bordo neon con glow
      if (fillColor != Colors.white.withValues(alpha: 0.04)) {
        final strokeColor = getStrokeColor(group, 1.0);
        
        // Effetto Glow sfocato sotto il bordo principale
        final glowPaint = Paint()
          ..color = strokeColor.withValues(alpha: isSelected ? 0.8 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 3.5 : 2.0
          ..imageFilter = ImageFilter.blur(
            sigmaX: isSelected ? pulseRadius * 0.7 : 4.0,
            sigmaY: isSelected ? pulseRadius * 0.7 : 4.0,
          );
        canvas.drawPath(path, glowPaint);

        // Bordo neon solido
        final strokePaint = Paint()
          ..color = isSelected ? Colors.white : strokeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.0 : 1.2;
        canvas.drawPath(path, strokePaint);
      } else {
        // Muscolo non allenato (wireframe neutro)
        final strokePaint = Paint()
          ..color = Colors.white10
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BodyMapPainter oldDelegate) {
    return oldDelegate.showFront != showFront ||
        oldDelegate.selectedMuscle != selectedMuscle ||
        oldDelegate.pulseRadius != pulseRadius;
  }
}

