import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naira_wallet/main.dart';
import 'package:naira_wallet/wallet.dart';

void main() {
  testWidgets('unlock with PIN then buy airtime', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    final w = Wallet();
    await tester.pumpWidget(WalletApp(wallet: w));
    for (final k in ['1', '2', '3', '4']) {
      await tester.tap(find.text(k));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Wallet balance'), findsOneWidget);
    final before = w.balance;
    await tester.tap(find.byTooltip('Airtime'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '200');
    await tester.enterText(find.byKey(const Key('pin')), '1234');
    await tester.tap(find.text('Buy now'));
    await tester.pumpAndSettle();
    expect(w.balance, before - 20000);
    expect(find.text('Airtime purchased'), findsOneWidget);
  });

  testWidgets('fingerprint unlocks', (tester) async {
    await tester.pumpWidget(WalletApp(wallet: Wallet()));
    await tester.tap(find.byTooltip('Use fingerprint'));
    await tester.pumpAndSettle();
    expect(find.text('NairaPay'), findsOneWidget);
  });
}
