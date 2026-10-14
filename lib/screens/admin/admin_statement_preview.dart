import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/theme.dart';

/// Full-screen, responsive PDF preview shown to admins before they
/// download / print a member's account statement.
class AdminStatementPreview extends StatefulWidget {
  final Uint8List pdfBytes;
  final String filename;
  final String memberName;
  final DateTime from;
  final DateTime to;
  /// When provided, the back button calls this instead of Navigator.maybePop.
  /// Use this when the widget is embedded inside the dashboard content panel.
  final VoidCallback? onBack;

  const AdminStatementPreview({
    super.key,
    required this.pdfBytes,
    required this.filename,
    required this.memberName,
    required this.from,
    required this.to,
    this.onBack,
  });

  @override
  State<AdminStatementPreview> createState() => _AdminStatementPreviewState();
}

class _AdminStatementPreviewState extends State<AdminStatementPreview> {
  static const double _compactMax = 600;
  static const double _wideMin = 1000;

  bool _busy = false;
  double _zoom = 1.0; // Zoom level (1.0 = 100%)
  static const double _minZoom = 0.5; // 50%
  static const double _maxZoom = 2.0; // 200%
  static const double _zoomStep = 0.1; // 10% per step

  final DateFormat _df = DateFormat('dd MMM yyyy');

  String get _period => '${_df.format(widget.from)} – ${_df.format(widget.to)}';

  String get _sizeLabel {
    final kb = widget.pdfBytes.lengthInBytes / 1024;
    return kb >= 1024
        ? '${(kb / 1024).toStringAsFixed(1)} MB'
        : '${kb.toStringAsFixed(0)} KB';
  }

  void _zoomIn() {
    if (_zoom < _maxZoom) {
      setState(() => _zoom = (_zoom + _zoomStep).clamp(_minZoom, _maxZoom));
    }
  }

  void _zoomOut() {
    if (_zoom > _minZoom) {
      setState(() => _zoom = (_zoom - _zoomStep).clamp(_minZoom, _maxZoom));
    }
  }

  void _resetZoom() {
    setState(() => _zoom = 1.0);
  }

  String get _zoomLabel => '${(_zoom * 100).round()}%';

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _run(Future<void> Function() action, String errorMsg) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          content: Text(errorMsg, style: GoogleFonts.poppins(fontSize: 13)),
        ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download() => _run(
        () => Printing.sharePdf(
            bytes: widget.pdfBytes, filename: widget.filename),
        'Could not download the statement. Please try again.',
      );

  Future<void> _print() => _run(
        () => Printing.layoutPdf(
          onLayout: (_) async => widget.pdfBytes,
          name: widget.filename,
        ),
        'Could not open the print dialog. Please try again.',
      );

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final compact = w < _compactMax;
      final wide = w >= _wideMin;

      return Scaffold(
        backgroundColor: const Color(0xFFE8EAEE),
        appBar: _buildAppBar(compact),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(children: [
            if (!wide) _InfoStrip(compact: compact, period: _period,
                member: widget.memberName),
            Expanded(
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _buildPreview(maxWidth: 820)),
                      _buildSidePanel(),
                    ])
                  : _buildPreview(maxWidth: 820),
            ),
            if (compact) _buildBottomBar(),
          ]),
        ),
      );
    });
  }

  PreferredSizeWidget _buildAppBar(bool compact) {
    return AppBar(
      backgroundColor: AppTheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: widget.onBack ?? () => Navigator.maybePop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Account Statement',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: compact ? 15 : 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            widget.memberName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
      actions: compact
          ? null // actions live in the bottom bar on phones
          : [
              // Zoom controls
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Zoom out',
                    icon: const Icon(Icons.remove, size: 18),
                    onPressed: _zoom > _minZoom ? _zoomOut : null,
                    color: Colors.white,
                    disabledColor: Colors.white38,
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 50),
                    alignment: Alignment.center,
                    child: Text(
                      _zoomLabel,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Zoom in',
                    icon: const Icon(Icons.add, size: 18),
                    onPressed: _zoom < _maxZoom ? _zoomIn : null,
                    color: Colors.white,
                    disabledColor: Colors.white38,
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              _AppBarAction(
                icon: Icons.download_rounded,
                label: 'Download',
                onPressed: _busy ? null : _download,
              ),
              const SizedBox(width: 4),
              _AppBarAction(
                icon: Icons.print_rounded,
                label: 'Print',
                onPressed: _busy ? null : _print,
              ),
              const SizedBox(width: 12),
            ],
      bottom: _busy
          ? const PreferredSize(
              preferredSize: Size.fromHeight(3),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Colors.transparent,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  Widget _buildPreview({required double maxWidth}) {
    // Apply zoom to the max width
    final zoomedWidth = maxWidth * _zoom;
    
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: zoomedWidth),
        child: PdfPreview(
          build: (_) async => widget.pdfBytes,
          pdfFileName: widget.filename,
          // We provide our own actions, so hide the built-in toolbar.
          useActions: false,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowSharing: false,
          allowPrinting: false,
          maxPageWidth: zoomedWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          scrollViewDecoration: const BoxDecoration(color: Color(0xFFE8EAEE)),
          pdfPreviewPageDecoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          loadingWidget: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          onError: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline_rounded,
                    size: 40, color: Colors.red.shade400),
                const SizedBox(height: 12),
                Text(
                  'Unable to render the statement preview.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: AppTheme.textSecondary),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom action bar – phones only.
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Zoom controls row
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(
                tooltip: 'Zoom out',
                icon: const Icon(Icons.remove_circle_outline, size: 24),
                onPressed: _zoom > _minZoom ? _zoomOut : null,
                color: AppTheme.primary,
                disabledColor: Colors.grey,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _zoomLabel,
                  style: GoogleFonts.poppins(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Zoom in',
                icon: const Icon(Icons.add_circle_outline, size: 24),
                onPressed: _zoom < _maxZoom ? _zoomIn : null,
                color: AppTheme.primary,
                disabledColor: Colors.grey,
              ),
            ]),
            const SizedBox(height: 8),
            // Action buttons row
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _print,
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: Text('Print',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _download,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text('Download',
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  /// Details side panel – large screens only.
  Widget _buildSidePanel() {
    return Container(
      width: 320,
      margin: const EdgeInsets.fromLTRB(0, 12, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statement Details',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary)),
          const SizedBox(height: 16),
          _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Member',
              value: widget.memberName),
          _DetailRow(
              icon: Icons.date_range_rounded,
              label: 'Period',
              value: _period),
          _DetailRow(
              icon: Icons.description_outlined,
              label: 'File',
              value: widget.filename),
          _DetailRow(
              icon: Icons.sd_storage_outlined,
              label: 'Size',
              value: _sizeLabel),
          const Divider(height: 28),
          Text(
            'This is a preview. Use Download or Print to get the final copy.',
            style: GoogleFonts.poppins(
                fontSize: 11.5, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _download,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('Download PDF',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _print,
              icon: const Icon(Icons.print_rounded, size: 18),
              label: Text('Print',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: BorderSide(color: AppTheme.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small private widgets
// ─────────────────────────────────────────────────────────────────────────────

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _AppBarAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.white.withOpacity(0.12),
      ),
    );
  }
}

/// Slim strip under the AppBar (phones/tablets).
class _InfoStrip extends StatelessWidget {
  final bool compact;
  final String period;
  final String member;

  const _InfoStrip({
    required this.compact,
    required this.period,
    required this.member,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 24, vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Chip(icon: Icons.date_range_rounded, text: period),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.info_outline_rounded,
                size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Preview only — use Download or Print for the final copy.',
                style: GoogleFonts.poppins(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(text,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary)),
      ]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 10.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, fontWeight: FontWeight.w600),
                softWrap: true),
          ]),
        ),
      ]),
    );
  }
}