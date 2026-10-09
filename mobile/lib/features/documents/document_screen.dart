import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../constants/app_colors.dart';
import '../../core/errors/app_exception.dart';
import '../../core/formats.dart';
import '../../core/services/native_bridge.dart';
import '../../core/services/routes.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/pressable_opacity.dart';
import '../auth/providers/auth_providers.dart';
import '../import/data/import_models.dart';
import '../library/data/models/book.dart';
import '../library/data/services/download_service.dart';
import '../library/providers/download_providers.dart';
import '../library/providers/library_providers.dart';
import '../library/utils/relink.dart';
import '../reader/data/reader_server.dart';

enum _Phase { loading, ready, missing, error }

/// Opens everything that is not EPUB/PDF: Word, Excel, PowerPoint, text,
/// Markdown, HTML, CSV, FB2, ODT and comics are rendered on the phone; other
/// formats (MOBI, DOC, RTF, …) are handed to another app.
class DocumentScreen extends ConsumerStatefulWidget {
  const DocumentScreen({super.key, required this.bookId, this.book, this.local});

  final String bookId;
  final Book? book;
  final LocalReadRequest? local;

  @override
  ConsumerState<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends ConsumerState<DocumentScreen> {
  _Phase _phase = _Phase.loading;
  String _error = '';
  Book? _book;
  File? _file;
  String _format = '';
  String _title = '';
  double? _progress;

  ReaderServer? _server;
  WebViewController? _web;
  bool _rendered = false;

  late String _theme;
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(storageServiceProvider);
    _theme = storage.readerTheme;
    _fontSize = storage.readerFontSize;
    _open();
  }

  @override
  void dispose() {
    final s = _server;
    if (s != null) unawaited(s.close());
    super.dispose();
  }

  Future<void> _open() async {
    setState(() {
      _phase = _Phase.loading;
      _progress = null;
    });

    try {
      final local = widget.local;
      if (local != null) {
        _file = File(local.path);
        _format = local.format;
        _title = local.title;
      } else {
        var book = widget.book;
        if (book == null) {
          final res = await ref.read(libraryRepositoryProvider).getBook(widget.bookId);
          book = res.dataOrNull?.book;
          if (book == null) throw res.exceptionOrNull ?? const NotFoundException();
        }
        _book = book;
        _format = book.format;
        _title = book.title;
        _file = await ref.read(downloadServiceProvider).ensureLocal(
              book,
              onProgress: (p) {
                if (mounted) setState(() => _progress = p);
              },
            );
      }
      if (!mounted) return;

      final kind = kindOfFormat(_format);
      if (kind == ViewerKind.external) {
        setState(() => _phase = _Phase.ready);
        return;
      }
      await _startViewer();
      if (mounted) setState(() => _phase = _Phase.ready);
    } on MissingLocalFileException {
      if (mounted) setState(() => _phase = _Phase.missing);
    } on AppException catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _error = 'Could not open this file.';
        });
      }
    }
  }

  Future<void> _startViewer() async {
    final server = await ReaderServer.start(
      bookFile: _file!,
      config: {
        'format': normalizeFormat(_format),
        'title': _title,
        'theme': _theme,
        'fontSize': _fontSize.round(),
      },
    );
    if (!mounted) {
      await server.close();
      return;
    }
    _server = server;
    final web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(ReaderPalette.byName(_theme).bg)
      ..addJavaScriptChannel('ReadIn', onMessageReceived: _onMessage)
      ..setNavigationDelegate(
        NavigationDelegate(
          // External links are never opened inside the viewer.
          onNavigationRequest: (req) => req.url.startsWith(server.pageUrl.origin)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
        ),
      );
    await web.loadRequest(server.viewerUrl);
    _web = web;
  }

  void _onMessage(JavaScriptMessage m) {
    if (!mounted) return;
    try {
      final d = Map<String, dynamic>.from(jsonDecode(m.message) as Map);
      if (d['type'] == 'READY') setState(() => _rendered = true);
      if (d['type'] == 'ERROR') {
        setState(() {
          _rendered = true; // the page already shows the message
        });
      }
    } catch (_) {}
  }

  void _pushStyle() {
    _web?.runJavaScript(
      'viewerApi.setStyle(${jsonEncode(jsonEncode({'theme': _theme, 'fontSize': _fontSize.round()}))})',
    );
  }

  void _cycleTheme() {
    const order = ['dark', 'light', 'sepia'];
    final next = order[(order.indexOf(_theme) + 1) % order.length];
    setState(() => _theme = next);
    ref.read(storageServiceProvider).setReaderTheme(next);
    _web?.setBackgroundColor(ReaderPalette.byName(next).bg);
    _pushStyle();
  }

  void _size(double delta) {
    final v = (_fontSize + delta).clamp(12.0, 28.0).toDouble();
    setState(() => _fontSize = v);
    ref.read(storageServiceProvider).setReaderFontSize(v);
    _pushStyle();
  }

  Future<void> _openWith() async {
    final f = _file;
    if (f == null) return;
    final ok = await NativeFiles.openWith(f.path, mimeOfFormat(_format));
    if (!ok) AppToast.warning('No app on this phone can open this file.');
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.libraryTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ReaderPalette.byName(_theme);
    final top = MediaQuery.paddingOf(context).top;
    final kind = kindOfFormat(_format);
    final viewer = _phase == _Phase.ready && kind != ViewerKind.external && _web != null;

    return Scaffold(
      backgroundColor: viewer ? palette.bg : AppColors.background,
      body: Column(
        children: [
          // top bar
          Container(
            padding: EdgeInsets.fromLTRB(12, top + 8, 12, 10),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
            ),
            child: Row(
              children: [
                _IconBtn(icon: Ionicons.arrow_back, label: 'Back', onTap: _back),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _title.isEmpty ? 'Document' : _title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(size: 15, weight: FontWeight.w600),
                  ),
                ),
                if (viewer) ...[
                  _IconBtn(icon: Ionicons.remove_circle_outline, label: 'Smaller text', onTap: () => _size(-2)),
                  _IconBtn(icon: Ionicons.add_circle_outline, label: 'Larger text', onTap: () => _size(2)),
                  _IconBtn(icon: Ionicons.color_palette_outline, label: 'Change theme', onTap: _cycleTheme),
                ],
                if (_file != null)
                  _IconBtn(icon: Ionicons.open_outline, label: 'Open with another app', onTap: _openWith),
              ],
            ),
          ),
          Expanded(child: _body(viewer, kind)),
        ],
      ),
    );
  }

  Widget _body(bool viewer, ViewerKind kind) {
    switch (_phase) {
      case _Phase.loading:
        return _Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary500),
              ),
              const SizedBox(height: 12),
              Text(
                _progress == null ? 'Opening...' : 'Downloading... ${(_progress! * 100).round()}%',
                style: AppTypography.label(size: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      case _Phase.missing:
        final b = _book;
        return _Center(
          child: _Message(
            icon: Ionicons.document_attach_outline,
            title: 'File not on this phone',
            text:
                'This book was imported on another device. Choose the same file to read it here — your notes and progress stay in sync.',
            actionLabel: 'Choose the file',
            onAction: b == null
                ? null
                : () async {
                    if (await relinkBookFile(context, ref, b)) _open();
                  },
          ),
        );
      case _Phase.error:
        return _Center(
          child: _Message(
            icon: Ionicons.alert_circle_outline,
            title: 'Could not open this file',
            text: _error,
            actionLabel: 'Try again',
            onAction: _open,
          ),
        );
      case _Phase.ready:
        if (kind == ViewerKind.external) {
          return _Center(
            child: _Message(
              icon: Ionicons.open_outline,
              title: '${labelOfFormat(_format)} opens in another app',
              text:
                  'ReadIn cannot display this format itself yet. Open it with an app that supports it (Word, WPS, a Kindle reader…).',
              actionLabel: 'Open with…',
              onAction: _openWith,
            ),
          );
        }
        return Stack(
          children: [
            if (_web != null) WebViewWidget(controller: _web!),
            if (!_rendered)
              const ColoredBox(
                color: AppColors.background,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primary500),
                ),
              ),
          ],
        );
    }
  }
}

class _Center extends StatelessWidget {
  const _Center({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: child));
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String text;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 44, color: AppColors.textMuted),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: AppTypography.title20),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
        ),
        if (onAction != null) ...[
          const SizedBox(height: 20),
          PressableOpacity(
            pressedOpacity: 0.85,
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.primary500,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                actionLabel,
                style: AppTypography.label(size: 15, weight: FontWeight.w600, color: AppColors.white),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.7,
      semanticLabel: label,
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Icon(icon, size: 22, color: AppColors.textPrimary),
      ),
    );
  }
}
