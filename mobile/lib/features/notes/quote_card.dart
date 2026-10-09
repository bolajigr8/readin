import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

import '../../constants/app_colors.dart';
import '../../core/services/native_bridge.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/bottom_sheet_scaffold.dart';
import '../../widgets/pressable_opacity.dart';

class _CardStyle {
  const _CardStyle(this.name, this.colors, this.fg, this.accent, this.serif);
  final String name;
  final List<Color> colors;
  final Color fg;
  final Color accent;
  final bool serif;
}

const List<_CardStyle> _styles = [
  _CardStyle('Sunset', [Color(0xFFF97316), Color(0xFFDC2626)], Color(0xFFFFFFFF), Color(0xFFFFE3CC), true),
  _CardStyle('Midnight', [Color(0xFF0F172A), Color(0xFF1E293B)], Color(0xFFF1F5F9), Color(0xFFFB923C), true),
  _CardStyle('Paper', [Color(0xFFF5E6C8), Color(0xFFEBD9B4)], Color(0xFF3D2B1F), Color(0xFFB45309), true),
  _CardStyle('Forest', [Color(0xFF14532D), Color(0xFF166534)], Color(0xFFF0FDF4), Color(0xFFFDE68A), true),
  _CardStyle('Clean', [Color(0xFFFFFFFF), Color(0xFFF4F4F5)], Color(0xFF18181B), Color(0xFFF97316), false),
];

/// Font size by quote length, so short quotes are big and long ones still fit.
double quoteFontSize(String quote) {
  final n = quote.length;
  if (n <= 80) return 28;
  if (n <= 160) return 23;
  if (n <= 280) return 19;
  return 16;
}

String shortenQuote(String quote, {int max = 420}) {
  final q = quote.trim().replaceAll(RegExp(r'\s+'), ' ');
  return q.length <= max ? q : '${q.substring(0, max - 1).trimRight()}…';
}

/// Bottom sheet: preview of the quote card, choose a style, share as an image.
Future<void> showQuoteCardSheet(
  BuildContext context, {
  required String quote,
  required String bookTitle,
  String author = '',
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (_) => _QuoteCardSheet(quote: shortenQuote(quote), title: bookTitle, author: author),
  );
}

class _QuoteCardSheet extends StatefulWidget {
  const _QuoteCardSheet({required this.quote, required this.title, required this.author});

  final String quote;
  final String title;
  final String author;

  @override
  State<_QuoteCardSheet> createState() => _QuoteCardSheetState();
}

class _QuoteCardSheetState extends State<_QuoteCardSheet> {
  final GlobalKey _boundary = GlobalKey();
  int _style = 0;
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ro = _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (ro == null) throw StateError('card not ready');
      final image = await ro.toImage(pixelRatio: 3.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no image data');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}${Platform.pathSeparator}readin_quote_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      final ok = await NativeFiles.share(
        file.path,
        'image/png',
        text: '“${widget.quote}” — ${widget.title}${widget.author.isEmpty ? '' : ', ${widget.author}'} · ReadIn',
      );
      if (!ok) AppToast.warning('Could not open the share sheet.');
    } catch (_) {
      AppToast.error('Could not create the image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _styles[_style];
    final byline = [widget.title, if (widget.author.trim().isNotEmpty) widget.author.trim()].join(' · ');

    return BottomSheetScaffold(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Share this quote', style: AppTypography.section17),
          const SizedBox(height: 14),
          Center(
            child: SizedBox(
              width: 280,
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: RepaintBoundary(
                  key: _boundary,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: s.colors,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('“', style: TextStyle(fontSize: 54, height: 0.9, color: s.accent, fontWeight: FontWeight.w700)),
                        Expanded(
                          child: Center(
                            child: Text(
                              widget.quote,
                              style: TextStyle(
                                fontFamily: s.serif ? 'serif' : null,
                                fontSize: quoteFontSize(widget.quote) * (280 / 360),
                                height: 1.4,
                                color: s.fg,
                                fontStyle: s.serif ? FontStyle.italic : FontStyle.normal,
                                fontWeight: s.serif ? FontWeight.w400 : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Container(width: 36, height: 3, color: s.accent),
                        const SizedBox(height: 10),
                        Text(
                          byline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: s.fg),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Read with ReadIn',
                          style: TextStyle(fontSize: 10, letterSpacing: 0.6, color: s.fg.withValues(alpha: 0.65)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < _styles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PressableOpacity(
                      pressedOpacity: 0.8,
                      semanticLabel: _styles[i].name,
                      onTap: () => setState(() => _style = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: _styles[i].colors),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: i == _style ? AppColors.primary500 : AppColors.borderLight,
                            width: i == _style ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          _styles[i].name,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _styles[i].fg),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PressableOpacity(
            pressedOpacity: 0.85,
            onTap: _busy ? null : _share,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary500,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _busy ? 'Creating image...' : 'Share image',
                style: AppTypography.label(size: 15, weight: FontWeight.w600, color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
