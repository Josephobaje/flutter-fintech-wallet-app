import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'wallet.dart';

int toKobo(String naira) => ((double.tryParse(naira.replaceAll(',', '')) ?? 0) * 100).round();

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String pin = '';
  String? error;

  void _key(String k) {
    final w = context.read<Wallet>();
    setState(() {
      error = null;
      if (k == '<') {
        if (pin.isNotEmpty) pin = pin.substring(0, pin.length - 1);
        return;
      }
      if (pin.length < 4) pin += k;
      if (pin.length == 4) {
        try {
          if (!w.unlockWithPin(pin)) {
            error = 'Wrong PIN. ${Wallet.maxPinAttempts - w.failedAttempts} attempts left';
          }
        } on WalletException catch (e) {
          error = e.message;
        }
        pin = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 48),
          CircleAvatar(radius: 34, backgroundColor: c.primary, child: Icon(Icons.account_balance_wallet, color: c.onPrimary, size: 34)),
          const SizedBox(height: 16),
          Text('Welcome back, Joseph', style: Theme.of(context).textTheme.titleLarge),
          const Text('Enter your 4-digit PIN (demo: 1234)'),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 4; i++)
              Container(
                margin: const EdgeInsets.all(8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(shape: BoxShape.circle, color: i < pin.length ? c.primary : c.surfaceContainerHighest),
              ),
          ]),
          SizedBox(height: 24, child: error == null ? null : Text(error!, style: TextStyle(color: c.error))),
          const Spacer(),
          for (final row in const [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['bio', '0', '<'],
          ])
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final k in row)
                SizedBox(
                  width: 80,
                  height: 72,
                  child: k == 'bio'
                      ? IconButton(
                          tooltip: 'Use fingerprint',
                          icon: const Icon(Icons.fingerprint, size: 36),
                          onPressed: () => context.read<Wallet>().unlockWithBiometrics(),
                        )
                      : TextButton(
                          onPressed: () => _key(k),
                          child: k == '<' ? const Icon(Icons.backspace_outlined) : Text(k, style: const TextStyle(fontSize: 26)),
                        ),
                ),
            ]),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final w = context.watch<Wallet>();
    final c = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NairaPay'),
        actions: [IconButton(tooltip: 'Lock', onPressed: w.lock, icon: const Icon(Icons.lock_outline))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: [c.primary, c.tertiary]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Wallet balance', style: TextStyle(color: c.onPrimary)),
              IconButton(
                tooltip: 'Hide balance',
                onPressed: w.toggleHide,
                icon: Icon(w.hideBalance ? Icons.visibility_off : Icons.visibility, color: c.onPrimary, size: 18),
              ),
            ]),
            Text(w.hideBalance ? '₦ ••••••' : naira(w.balance),
                style: TextStyle(color: c.onPrimary, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Account 9012345678 · NairaPay MFB', style: TextStyle(color: c.onPrimary.withValues(alpha: 0.85))),
          ]),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _action(context, Icons.add_card, 'Fund', const FundSheet()),
          _action(context, Icons.send, 'Transfer', const TransferSheet()),
          _action(context, Icons.phone_android, 'Airtime', const BillSheet(data: false)),
          _action(context, Icons.wifi, 'Data', const BillSheet(data: true)),
        ]),
        const SizedBox(height: 16),
        Text('Recent transactions', style: Theme.of(context).textTheme.titleMedium),
        const HistoryList(),
      ]),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label, Widget sheet) => Column(children: [
        IconButton.filledTonal(
          iconSize: 28,
          tooltip: label,
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => Padding(padding: MediaQuery.viewInsetsOf(context), child: sheet),
          ),
          icon: Icon(icon),
        ),
        Text(label),
      ]);
}

class HistoryList extends StatefulWidget {
  const HistoryList({super.key});
  @override
  State<HistoryList> createState() => _HistoryListState();
}

class _HistoryListState extends State<HistoryList> {
  TxType? filter;
  static const icons = {
    TxType.funding: Icons.south_west,
    TxType.transfer: Icons.north_east,
    TxType.airtime: Icons.phone_android,
    TxType.data: Icons.wifi,
  };

  @override
  Widget build(BuildContext context) {
    final w = context.watch<Wallet>();
    final c = Theme.of(context).colorScheme;
    return Column(children: [
      Wrap(spacing: 6, children: [
        ChoiceChip(label: const Text('All'), selected: filter == null, onSelected: (_) => setState(() => filter = null)),
        for (final t in TxType.values)
          ChoiceChip(label: Text(t.name[0].toUpperCase() + t.name.substring(1)), selected: filter == t, onSelected: (_) => setState(() => filter = t)),
      ]),
      for (final t in w.filtered(filter))
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(child: Icon(icons[t.type])),
          title: Text(t.title),
          subtitle: Text('${t.date.day}/${t.date.month}/${t.date.year} · ${t.id}'),
          trailing: Text(
            '${t.amount > 0 ? '+' : ''}${naira(t.amount)}',
            style: TextStyle(color: t.amount > 0 ? Colors.green.shade700 : c.error, fontWeight: FontWeight.w600),
          ),
        ),
    ]);
  }
}

abstract class _SheetState<T extends StatefulWidget> extends State<T> {
  final amount = TextEditingController();
  final pin = TextEditingController();
  String? error;

  void run(VoidCallback action, String success) {
    try {
      action();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
    } on WalletException catch (e) {
      setState(() => error = e.message);
    }
  }

  Widget field(TextEditingController c, String label, {bool obscure = false, String? key}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: key == null ? null : Key(key),
          controller: c,
          obscureText: obscure,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );

  Widget sheet(String title, List<Widget> children) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ...children,
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      );

  @override
  void dispose() {
    amount.dispose();
    pin.dispose();
    super.dispose();
  }
}

class FundSheet extends StatefulWidget {
  const FundSheet({super.key});
  @override
  State<FundSheet> createState() => _FundSheetState();
}

class _FundSheetState extends _SheetState<FundSheet> {
  @override
  Widget build(BuildContext context) => sheet('Fund wallet', [
        field(amount, 'Amount (₦)', key: 'amount'),
        const Text('Paystack test mode: use card 4084 0840 8408 4081'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => run(() => context.read<Wallet>().fund(toKobo(amount.text)), 'Wallet funded'),
          child: const Text('Pay with Paystack'),
        ),
      ]);
}

class TransferSheet extends StatefulWidget {
  const TransferSheet({super.key});
  @override
  State<TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends _SheetState<TransferSheet> {
  final account = TextEditingController();
  String bank = banks.first;
  @override
  void dispose() {
    account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => sheet('Send money', [
        DropdownButtonFormField<String>(
          initialValue: bank,
          decoration: const InputDecoration(labelText: 'Bank', border: OutlineInputBorder()),
          items: [for (final b in banks) DropdownMenuItem(value: b, child: Text(b))],
          onChanged: (v) => setState(() => bank = v!),
        ),
        const SizedBox(height: 12),
        field(account, 'Account number', key: 'account'),
        if (Wallet.validAccount(account.text)) const Text('Account name: CHIDI OKAFOR (demo lookup)'),
        field(amount, 'Amount (₦)', key: 'amount'),
        field(pin, 'PIN', obscure: true, key: 'pin'),
        FilledButton(
          onPressed: () => run(
              () => context.read<Wallet>().transfer(bank: bank, account: account.text, name: 'Chidi Okafor', kobo: toKobo(amount.text), pin: pin.text),
              'Transfer successful'),
          child: const Text('Send'),
        ),
      ]);
}

class BillSheet extends StatefulWidget {
  const BillSheet({super.key, required this.data});
  final bool data;
  @override
  State<BillSheet> createState() => _BillSheetState();
}

class _BillSheetState extends _SheetState<BillSheet> {
  final phone = TextEditingController(text: '08031234567');
  String network = networks.first;
  DataPlan plan = dataPlans.first;
  @override
  void dispose() {
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => sheet(widget.data ? 'Buy data' : 'Buy airtime', [
        SegmentedButton<String>(
          segments: [for (final n in networks) ButtonSegment(value: n, label: Text(n))],
          selected: {network},
          onSelectionChanged: (v) => setState(() => network = v.first),
        ),
        const SizedBox(height: 12),
        field(phone, 'Phone number'),
        if (widget.data)
          Wrap(spacing: 6, children: [
            for (final p in dataPlans)
              ChoiceChip(label: Text('${p.name} · ${naira(p.kobo, decimals: false)}'), selected: plan == p, onSelected: (_) => setState(() => plan = p)),
          ])
        else
          field(amount, 'Amount (₦)', key: 'amount'),
        const SizedBox(height: 12),
        field(pin, 'PIN', obscure: true, key: 'pin'),
        FilledButton(
          onPressed: () => run(() {
            final w = context.read<Wallet>();
            widget.data
                ? w.buyData(network: network, phone: phone.text, plan: plan, pin: pin.text)
                : w.buyAirtime(network: network, phone: phone.text, kobo: toKobo(amount.text), pin: pin.text);
          }, widget.data ? 'Data purchased' : 'Airtime purchased'),
          child: const Text('Buy now'),
        ),
      ]);
}
