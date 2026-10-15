import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens.dart';
import 'wallet.dart';

void main() => runApp(WalletApp(wallet: Wallet()));

class WalletApp extends StatelessWidget {
  const WalletApp({super.key, required this.wallet});
  final Wallet wallet;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E4F), brightness: b),
          useMaterial3: true,
        );
    return ChangeNotifierProvider.value(
      value: wallet,
      child: MaterialApp(
        title: 'NairaPay Wallet',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        home: Consumer<Wallet>(builder: (_, w, _) => w.unlocked ? const HomeScreen() : const LockScreen()),
      ),
    );
  }
}
