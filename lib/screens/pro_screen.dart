import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/runner_themes.dart';
import 'widgets.dart';

/// Dash Runner PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
/// The store instance is owned by the menu; this screen never disposes it.
class ProScreen extends StatefulWidget {
  final DashAudio audio;
  final DashSettings settings;
  final StoreService store;

  const ProScreen(
      {super.key,
      required this.audio,
      required this.settings,
      required this.store});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  RunnerThemeDef get _t => widget.settings.theme;

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.newBest();
      showTrailSnack(context, 'PRO unlocked — the whole trail is yours!', _t);
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.newBest();
    showTrailSnack(context, msg, _t);
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      backgroundColor: const Color(0xFF241A10),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.audio.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('Dash Runner PRO', style: display(22, t)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            child: Column(
              children: [
                _ComparisonCard(theme: t, isPro: s.isPro),
                const SizedBox(height: 16),
                _BuyCard(
                    theme: t, settings: s, store: store, audio: widget.audio),
                const SizedBox(height: 16),
                _TipsCard(theme: t, store: store, audio: widget.audio),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final RunnerThemeDef theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['Trail themes', '4', 'All 13'],
      ['Runner gear styles', '4', 'All 8'],
      ['Obstacle styles', '4', 'All 8'],
      ['Custom theme creator', '—', '✓'],
      ['Extreme Dash mode', '—', '✓'],
      ['Score Attack mode', '✓', '✓'],
      ['Full game, no ads', '✓', '✓'],
    ];
    return WoodCard(
      theme: theme,
      child: Column(
        children: [
          Text('FREE vs PRO', style: display(20, theme)),
          const SizedBox(height: 10),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                children: [
                  const SizedBox(),
                  Center(
                      child: Text('FREE',
                          style: body(13, theme,
                              color: Colors.white60,
                              weight: FontWeight.w800))),
                  Center(
                      child: Text('PRO',
                          style: body(13, theme,
                              color: const Color(0xFFD4A017),
                              weight: FontWeight.w800))),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(r[0],
                          style: body(14, theme, color: Colors.white80)),
                    ),
                    Center(
                        child: Text(r[1],
                            style: body(14, theme,
                                color: Colors.white60))),
                    Center(
                        child: Text(r[2],
                            style: body(14, theme,
                                color: const Color(0xFFD4A017),
                                weight: FontWeight.w800))),
                  ],
                ),
            ],
          ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text('⭐ You are PRO — everything is unlocked!',
                  style: body(14, theme,
                      color: const Color(0xFFD4A017),
                      weight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }
}

class _BuyCard extends StatelessWidget {
  final RunnerThemeDef theme;
  final DashSettings settings;
  final StoreService store;
  final DashAudio audio;
  const _BuyCard(
      {required this.theme,
      required this.settings,
      required this.store,
      required this.audio});

  @override
  Widget build(BuildContext context) {
    final product = store.proProduct;
    return WoodCard(
      theme: theme,
      child: Column(
        children: [
          Text('Unlock PRO forever', style: display(18, theme)),
          const SizedBox(height: 6),
          Text('One payment. Yours on every device.',
              style: body(13, theme, color: Colors.white60)),
          const SizedBox(height: 12),
          if (settings.isPro)
            Text('Already unlocked — enjoy the trail!',
                style: body(15, theme,
                    color: const Color(0xFFD4A017),
                    weight: FontWeight.w800))
          else if (!store.storeReady)
            Text(
              'Purchases will appear here once the store listing is set up. '
              '(${store.error ?? 'Not ready yet'})',
              textAlign: TextAlign.center,
              style: body(14, theme, color: Colors.white60),
            )
          else if (product == null)
            Text('PRO product not configured yet — check back soon!',
                textAlign: TextAlign.center,
                style: body(14, theme, color: Colors.white60))
          else
            TrailButton(
              label: 'GET PRO — ${product.price}',
              icon: Icons.workspace_premium,
              theme: theme,
              onPressed: () {
                audio.click();
                store.buyPro();
              },
            ),
          ValueListenableBuilder<String?>(
            valueListenable: store.purchaseError,
            builder: (_, err, _) => err == null
                ? const SizedBox()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(err,
                        style: body(13, theme,
                            color: const Color(0xFFFF8A7A))),
                  ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: store.purchaseInProgress,
            builder: (_, busy, _) => busy
                ? const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: CircularProgressIndicator(),
                  )
                : const SizedBox(),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              audio.click();
              store.restore();
              showTrailSnack(context,
                  'Checking your past purchases…', theme);
            },
            child: Text('Restore purchases',
                style: body(14, theme,
                    color: theme.accent, weight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  final RunnerThemeDef theme;
  final StoreService store;
  final DashAudio audio;
  const _TipsCard(
      {required this.theme, required this.store, required this.audio});

  @override
  Widget build(BuildContext context) {
    return WoodCard(
      theme: theme,
      child: Column(
        children: [
          Text('☕ Tip jar', style: display(18, theme)),
          const SizedBox(height: 6),
          Text('Dash Runner is made by one indie maker. Tips keep the trail dusty!',
              textAlign: TextAlign.center,
              style: body(13, theme, color: Colors.white60)),
          const SizedBox(height: 12),
          if (!store.storeReady)
            Text(
                'Tips will appear here once the store listing is set up.',
                textAlign: TextAlign.center,
                style: body(14, theme, color: Colors.white60))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _tipButton(context, store.coffeeProduct, '☕ Coffee'),
                const SizedBox(width: 12),
                _tipButton(
                    context, store.chocolateProduct, '🍫 Chocolate'),
              ],
            ),
        ],
      ),
    );
  }

  Widget _tipButton(
      BuildContext context, ProductDetails? product, String label) {
    if (product == null) return const SizedBox();
    return TrailButton(
      label: '$label — ${product.price}',
      theme: theme,
      small: true,
      onPressed: () {
        audio.click();
        store.buyTip(product);
      },
    );
  }
}
