import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';

/// A full-screen centered circular loader with animated percentage counter
/// and a status message. Drop it anywhere with [CenteredLoader].
///
/// For indeterminate use (no percentage): omit [progress].
/// For determinate use: pass [progress] 0.0–1.0.
class CenteredLoader extends StatefulWidget {
  /// 0.0–1.0. If null, spins indefinitely.
  final double? progress;

  /// Primary message shown below the circle.
  final String message;

  /// Smaller sub-message shown below [message] (optional).
  final String? subMessage;

  /// Circle color. Defaults to AppTheme.primary.
  final Color? color;

  const CenteredLoader({
    super.key,
    this.progress,
    this.message = 'Please wait...',
    this.subMessage,
    this.color,
  });

  @override
  State<CenteredLoader> createState() => _CenteredLoaderState();
}

class _CenteredLoaderState extends State<CenteredLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _displayed; // smoothly animates to new progress
  double _target = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..addListener(() => setState(() {}));
    _target = widget.progress ?? 0;
    _displayed = Tween(begin: 0.0, end: _target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.progress != null) _ctrl.forward();
  }

  @override
  void didUpdateWidget(CenteredLoader old) {
    super.didUpdateWidget(old);
    if (widget.progress != null && widget.progress != old.progress) {
      final from = _displayed.value;
      _target = widget.progress!;
      _displayed = Tween(begin: from, end: _target).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      );
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primary;
    final pct   = widget.progress != null ? (_displayed.value * 100).round() : null;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100, height: 100,
            child: Stack(alignment: Alignment.center, children: [
              // Track
              SizedBox(
                width: 100, height: 100,
                child: CircularProgressIndicator(
                  value: widget.progress != null ? _displayed.value : null,
                  strokeWidth: 7,
                  backgroundColor: color.withOpacity(0.12),
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              // Percentage text
              if (pct != null)
                Text(
                  '$pct%',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 24),
          Text(
            widget.message,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.subMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.subMessage!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
