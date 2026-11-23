import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() => runApp(const AlgoTradeApp());

class AlgoTradeApp extends StatelessWidget {
  const AlgoTradeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Algo Trade Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF42D6A4),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0B1220),
          cardColor: const Color(0xFF151F30),
          useMaterial3: true,
        ),
        home: const TradingHome(),
      );
}

enum TradingMode { manual, semiAuto, automatic }

extension TradingModeLabel on TradingMode {
  String get label => switch (this) {
        TradingMode.manual => 'Manual',
        TradingMode.semiAuto => 'Semi-auto',
        TradingMode.automatic => 'Automatic',
      };
}

class PaperTrade {
  PaperTrade({
    required this.symbol,
    required this.side,
    required this.qty,
    required this.entry,
    required this.stopLoss,
    required this.target,
    required this.time,
  });
  final String symbol;
  final String side;
  final int qty;
  final double entry;
  final double stopLoss;
  final double target;
  final DateTime time;
  double get value => qty * entry;
  double get plannedRisk => (entry - stopLoss).abs() * qty;
}

class TradingHome extends StatefulWidget {
  const TradingHome({super.key});
  @override
  State<TradingHome> createState() => _TradingHomeState();
}

class _TradingHomeState extends State<TradingHome> {
  static const double initialCapital = 10000;
  static const double dailyMaxLoss = 300;
  static const double riskPercent = 1;

  double realizedPnl = 0;
  int selectedTab = 0;
  String strategy = 'ORB + VWAP';
  TradingMode mode = TradingMode.manual;
  bool autoTradingEnabled = false;
  final List<PaperTrade> trades = [];
  final Set<String> processedSignals = {};
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final List<Map<String, dynamic>> watchlist = [
    {'symbol': 'RELIANCE', 'name': 'Reliance Industries', 'price': 1284.50, 'change': 0.82},
    {'symbol': 'HDFCBANK', 'name': 'HDFC Bank', 'price': 968.25, 'change': -0.34},
    {'symbol': 'TCS', 'name': 'Tata Consultancy', 'price': 3128.00, 'change': 1.12},
    {'symbol': 'INFY', 'name': 'Infosys', 'price': 1542.70, 'change': -0.18},
  ];

  double get riskPerTrade => initialCapital * riskPercent / 100;
  double get availableCapital => initialCapital - trades.fold(0, (sum, t) => sum + t.value);
  bool get dailyLossLocked => realizedPnl <= -dailyMaxLoss;

  int quantityFor(double price) {
    // Demo sizing: stop is 1% away from entry; planned loss is capped at ₹100.
    final riskPerShare = price * 0.01;
    if (riskPerShare <= 0) return 0;
    final byRisk = (riskPerTrade / riskPerShare).floor();
    final byCash = (initialCapital / price).floor();
    return byRisk < byCash ? byRisk : byCash;
  }

  void _message(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  void placePaperTrade(String side, Map<String, dynamic> stock, {bool fromSignal = false}) {
    if (dailyLossLocked) {
      _message('Daily loss limit reached. New paper orders are blocked.');
      return;
    }
    final price = stock['price'] as double;
    final qty = quantityFor(price);
    if (qty < 1 || qty * price > availableCapital) {
      _message('Insufficient virtual capital for this risk-sized order.');
      return;
    }
    final stop = side == 'BUY' ? price * 0.99 : price * 1.01;
    final target = side == 'BUY' ? price * 1.02 : price * 0.98;
    setState(() => trades.insert(
          0,
          PaperTrade(
            symbol: stock['symbol'] as String,
            side: side,
            qty: qty,
            entry: price,
            stopLoss: stop,
            target: target,
            time: DateTime.now(),
          ),
        ));
    _message('Paper $side recorded: ${stock['symbol']} · $qty shares${fromSignal ? ' · signal' : ''}');
  }

  Future<void> handleSignal(Map<String, dynamic> stock, String side) async {
    final signalKey = '${stock['symbol']}-${DateTime.now().toIso8601String().substring(0, 10)}';
    if (processedSignals.contains(signalKey)) {
      _message('This demo signal was already processed today.');
      return;
    }
    if (mode == TradingMode.manual) {
      _message('Manual mode: use the BUY / SELL buttons on Dashboard.');
      return;
    }
    if (mode == TradingMode.semiAuto) {
      final approved = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Approve paper order?'),
              content: Text('${side.toUpperCase()} ${stock['symbol']}\nDemo price: ${currency.format(stock['price'])}\nRisk budget: ${currency.format(riskPerTrade)}'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Reject')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
              ],
            ),
          ) ??
          false;
      if (!approved || !mounted) return;
    }
    if (mode == TradingMode.automatic && !autoTradingEnabled) {
      _message('Automatic mode is selected but Auto Paper is OFF. Enable it in Settings.');
      return;
    }
    processedSignals.add(signalKey);
    placePaperTrade(side, stock, fromSignal: true);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_dashboard(), _signals(), _history(), _settings()];
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.auto_graph, color: Color(0xFF42D6A4)), SizedBox(width: 9), Text('ALGO TRADE PRO', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1))]),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Chip(avatar: const Icon(Icons.shield_outlined, size: 16), label: const Text('PAPER ONLY'), backgroundColor: const Color(0xFF173D37)))],
      ),
      body: SafeArea(child: pages[selectedTab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (v) => setState(() => selectedTab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt), label: 'Signals'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _dashboard() => ListView(padding: const EdgeInsets.all(16), children: [
        _sectionTitle('Portfolio overview', 'Virtual account'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _metric('Starting capital', currency.format(initialCapital), Icons.account_balance_wallet_outlined, const Color(0xFF7DA8FF))),
          const SizedBox(width: 10),
          Expanded(child: _metric('Available cash', currency.format(availableCapital), Icons.payments_outlined, const Color(0xFF42D6A4))),
        ]),
        const SizedBox(height: 10),
        _metric('Realized P&L', currency.format(realizedPnl), Icons.trending_up, realizedPnl >= 0 ? const Color(0xFF42D6A4) : Colors.redAccent),
        const SizedBox(height: 10),
        _riskSummary(),
        const SizedBox(height: 22),
        _sectionTitle('Trading mode', mode.label),
        const SizedBox(height: 10),
        _modeSelector(),
        const SizedBox(height: 22),
        _sectionTitle('Strategy engine', 'Choose a setup'),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: strategy, decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.tune)), items: ['ORB + VWAP', 'EMA 9 / EMA 21', 'Volume Breakout'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => strategy = v ?? strategy)),
        const SizedBox(height: 22),
        _sectionTitle('Watchlist', 'Demo prices · not live'),
        const SizedBox(height: 10),
        ...watchlist.map(_stockCard),
        const SizedBox(height: 12),
        _riskCard(),
      ]);

  Widget _signals() => ListView(padding: const EdgeInsets.all(16), children: [
        _sectionTitle('Trading signals', 'Simulated examples'),
        const SizedBox(height: 8),
        Text('Strategy: $strategy · Mode: ${mode.label}', style: TextStyle(color: Colors.white.withValues(alpha: .7))),
        const SizedBox(height: 12),
        _infoBox('Signal data is simulated for UI testing. This build has no live candles, ORB/VWAP calculation, or Upstox connection.'),
        const SizedBox(height: 14),
        ...watchlist.asMap().entries.map((entry) {
          final stock = entry.value;
          final side = entry.key.isEven ? 'BUY' : 'SELL';
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(stock['symbol'] as String, style: const TextStyle(fontWeight: FontWeight.bold))), Chip(label: Text('DEMO $side'), backgroundColor: side == 'BUY' ? const Color(0xFF174638) : const Color(0xFF512B32))]),
                Text('Demo LTP ${currency.format(stock['price'])} · ${stock['name']}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton.tonal(onPressed: () => handleSignal(stock, side), child: Text(mode == TradingMode.manual ? 'View signal (manual execution)' : mode == TradingMode.semiAuto ? 'Review & approve $side' : 'Process demo signal'))),
              ])));
        }),
      ]);

  Widget _history() => ListView(padding: const EdgeInsets.all(16), children: [
        _sectionTitle('Paper trade history', '${trades.length} orders'),
        const SizedBox(height: 8),
        _infoBox('Orders are simulated locally. No order is sent to Upstox or an exchange.'),
        const SizedBox(height: 12),
        if (trades.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 50), child: Center(child: Column(children: [Icon(Icons.receipt_long, size: 48, color: Colors.white38), SizedBox(height: 12), Text('No paper trades yet'), Text('Use Dashboard BUY / SELL or Signals to test.', style: TextStyle(color: Colors.white54))])))
        else
          ...trades.map((t) => Card(child: ListTile(
                leading: CircleAvatar(backgroundColor: t.side == 'BUY' ? const Color(0xFF174638) : const Color(0xFF512B32), child: Text(t.side == 'BUY' ? 'B' : 'S')),
                title: Text('${t.side} · ${t.symbol} · ${t.qty} qty'),
                subtitle: Text('${DateFormat('dd MMM, hh:mm a').format(t.time)}\nEntry ${currency.format(t.entry)}  |  SL ${currency.format(t.stopLoss)}  |  Target ${currency.format(t.target)}'),
                isThreeLine: true,
                trailing: Text('Risk\n${currency.format(t.plannedRisk)}', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold)),
              ))),
      ]);

  Widget _settings() => ListView(padding: const EdgeInsets.all(16), children: [
        _sectionTitle('Risk & execution settings', 'Paper account'),
        const SizedBox(height: 12),
        _metric('Daily maximum loss', currency.format(dailyMaxLoss), Icons.shield_outlined, Colors.orangeAccent),
        const SizedBox(height: 10),
        _metric('Risk per trade', '${currency.format(riskPerTrade)} (${riskPercent.toStringAsFixed(0)}%)', Icons.pie_chart_outline, const Color(0xFF7DA8FF)),
        const SizedBox(height: 18),
        _sectionTitle('Execution mode', 'Choose how signals are handled'),
        const SizedBox(height: 10),
        _modeSelector(),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('Enable Automatic Paper Trading'),
          subtitle: const Text('Only simulated orders; no broker orders are sent.'),
          value: autoTradingEnabled,
          onChanged: (v) => setState(() => autoTradingEnabled = v),
        ),
        _infoBox('Automatic mode is disabled by default. Turn this on only to let simulated demo signals create paper orders. Live automatic trading is not implemented.'),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: () => setState(() { trades.clear(); realizedPnl = 0; processedSignals.clear(); }), icon: const Icon(Icons.restart_alt), label: const Text('Reset paper account')),
      ]);

  Widget _modeSelector() => SegmentedButton<TradingMode>(
        segments: const [
          ButtonSegment(value: TradingMode.manual, label: Text('Manual'), icon: Icon(Icons.touch_app)),
          ButtonSegment(value: TradingMode.semiAuto, label: Text('Semi'), icon: Icon(Icons.fact_check_outlined)),
          ButtonSegment(value: TradingMode.automatic, label: Text('Auto'), icon: Icon(Icons.smart_toy_outlined)),
        ],
        selected: {mode},
        onSelectionChanged: (selection) => setState(() => mode = selection.first),
      );

  Widget _stockCard(Map<String, dynamic> stock) {
    final change = stock['change'] as double;
    final positive = change >= 0;
    return Card(margin: const EdgeInsets.only(bottom: 9), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(stock['symbol'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(stock['name'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(currency.format(stock['price']), style: const TextStyle(fontWeight: FontWeight.bold)), Text('${positive ? '+' : ''}${change.toStringAsFixed(2)}%', style: TextStyle(color: positive ? const Color(0xFF42D6A4) : Colors.redAccent))])]),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => placePaperTrade('BUY', stock), icon: const Icon(Icons.add, size: 16), label: const Text('Paper Buy'), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF42D6A4)))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => placePaperTrade('SELL', stock), icon: const Icon(Icons.remove, size: 16), label: const Text('Paper Sell'), style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent)))])
        ])));
  }

  Widget _riskSummary() => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF302718), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.orangeAccent.withValues(alpha: .25))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.security, color: Colors.orangeAccent), SizedBox(width: 8), Text('Risk guardrails', style: TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        Text('Daily max loss: ${currency.format(dailyMaxLoss)}  ·  Risk / trade: ${currency.format(riskPerTrade)}'),
        Text('Sizing model: 1% demo stop distance; quantity is capped by virtual cash.', style: const TextStyle(color: Colors.white60, fontSize: 11)),
        if (dailyLossLocked) const Text('DAILY LOSS LIMIT HIT — new orders blocked', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
      ]));

  Widget _riskCard() => _infoBox('Risk controls are demo guardrails. This prototype does not yet calculate real-time mark-to-market P&L or enforce a true exchange-side daily loss limit.');
  Widget _infoBox(String text) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFF17263A), borderRadius: BorderRadius.circular(14)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline, color: Color(0xFF7DA8FF)), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)))]));
  Widget _metric(String label, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF151F30), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 12), Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(height: 4), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))]));
  Widget _sectionTitle(String title, String subtitle) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11))]);
}
