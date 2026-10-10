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
    widget.store.lastThanks.addListener(_onThanks);
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
