import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../constants/app_colors.dart';
import '../../core/api/api_endpoints.dart';
import '../../theme/app_typography.dart';
import '../../widgets/pressable_opacity.dart';
import 'billing_models.dart';

/// Paystack's secure payment page inside the app. The card / bank details are
/// typed on Paystack's page only — ReadIn never sees them.
///
/// Pops with the payment reference once Paystack sends the customer back to our
/// return page (`/payment/callback`), or with `null` if the user closes it.
class PaystackCheckoutScreen extends StatefulWidget {
  const PaystackCheckoutScreen({super.key, required this.url, required this.reference, required this.title});

  final String url;
  final String reference;
  final String title;

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _web;
  bool _loading = true;
  bool _failed = false;
  bool _done = false;

  void _finish(String? reference) {
    if (_done || !mounted) return;
    _done = true;
    Navigator.of(context).pop(reference);
  }

  @override
  void initState() {
    super.initState();
    final apiBase = Uri.parse(ApiEndpoints.baseUrl);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            // Paystack sent the customer back → we are done here.
            final ref = paymentCallbackReference(uri, apiBase);
            if (ref != null) {
              _finish(ref.isEmpty ? widget.reference : ref);
              return NavigationDecision.prevent;
            }
            // Only normal web pages (no intent:// or market:// jumps out of the app).
            return (uri.scheme == 'https' || uri.scheme == 'http')
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (e) {
            if (e.isForMainFrame == true && mounted) setState(() => _failed = true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _confirmClose() async {
    final close = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevated,
        title: Text('Leave the payment?', style: AppTypography.section17),
        content: Text(
          'If you already paid, do not worry — we will confirm it and activate Premium. If not, nothing is charged.',
          style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 20),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Leave')),
        ],
      ),
    );
    return close ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmClose()) _finish(widget.reference); // the app verifies it afterwards
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                child: Row(
                  children: [
                    PressableOpacity(
                      pressedOpacity: 0.7,
                      semanticLabel: 'Close payment',
                      onTap: () async {
                        if (await _confirmClose()) _finish(widget.reference);
                      },
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Ionicons.close, color: AppColors.textPrimary),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: AppTypography.label(size: 16, weight: FontWeight.w600)),
                          Row(
                            children: [
                              const Icon(Ionicons.lock_closed_outline, size: 12, color: AppColors.success500),
                              const SizedBox(width: 4),
                              Text(
                                'Secure payment by Paystack',
                                style: AppTypography.label(size: 11, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2, color: AppColors.primary500),
              Expanded(
                child: _failed
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Ionicons.wifi_outline, size: 40, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text('Could not load the payment page', style: AppTypography.label(size: 16, weight: FontWeight.w600)),
                              const SizedBox(height: 6),
                              Text(
                                'Check your internet connection and try again.',
                                textAlign: TextAlign.center,
                                style: AppTypography.label(size: 13, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _failed = false;
                                    _loading = true;
                                  });
                                  _web.loadRequest(Uri.parse(widget.url));
                                },
                                child: const Text('Try again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : WebViewWidget(controller: _web),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
