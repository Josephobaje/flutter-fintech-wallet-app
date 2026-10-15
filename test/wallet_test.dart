import 'package:flutter_test/flutter_test.dart';
import 'package:naira_wallet/wallet.dart';

void main() {
  late Wallet w;
  setUp(() {
    w = Wallet(clock: () => DateTime(2026, 10, 15, 12));
    w.unlockWithPin('1234');
  });

  test('naira formatting', () {
    expect(naira(0), '₦0.00');
    expect(naira(1234550), '₦12,345.50');
    expect(naira(-100000), '-₦1,000.00');
    expect(naira(100000000, decimals: false), '₦1,000,000');
  });

  test('seeded balance', () => expect(w.balance, 25000000 - 1250000 - 100000));

  test('PIN lockout after 3 failures, biometrics unlock', () async {
    w.lock();
    expect(w.unlockWithPin('0000'), isFalse);
    w.unlockWithPin('1111');
    w.unlockWithPin('2222');
    expect(w.lockedOut, isTrue);
    expect(() => w.unlockWithPin('1234'), throwsA(isA<WalletException>()));
    expect(await w.unlockWithBiometrics(), isTrue);
    expect(w.failedAttempts, 0);
  });

  test('failed biometrics keeps wallet locked', () async {
    final m = MockBiometric(succeed: false);
    final w2 = Wallet(biometric: m);
    expect(await w2.unlockWithBiometrics(), isFalse);
    expect(w2.unlocked, isFalse);
  });

  test('funding', () {
    final before = w.balance;
    w.fund(500000);
    expect(w.balance, before + 500000);
    expect(() => w.fund(50), throwsA(isA<WalletException>()));
  });

  test('transfer validation and success', () {
    final before = w.balance;
    expect(() => w.transfer(bank: 'GTBank', account: '123', name: 'X', kobo: 100, pin: '1234'), throwsA(isA<WalletException>()));
    expect(() => w.transfer(bank: 'GTBank', account: '0123456789', name: 'X', kobo: 100, pin: '9999'), throwsA(isA<WalletException>()));
    expect(() => w.transfer(bank: 'GTBank', account: '0123456789', name: 'X', kobo: before + 1, pin: '1234'), throwsA(isA<WalletException>()));
    w.transfer(bank: 'GTBank', account: '0123456789', name: 'Chidi', kobo: 500000, pin: '1234');
    expect(w.balance, before - 500000);
    expect(w.history.first.type, TxType.transfer);
  });

  test('daily transfer limit', () {
    w.fund(100000000);
    w.transfer(bank: 'UBA', account: '0123456789', name: 'A', kobo: 40000000, pin: '1234');
    expect(() => w.transfer(bank: 'UBA', account: '0123456789', name: 'A', kobo: 20000000, pin: '1234'),
        throwsA(isA<WalletException>()));
  });

  test('airtime and data', () {
    expect(Wallet.validPhone('08031234567'), isTrue);
    expect(Wallet.validPhone('0803123'), isFalse);
    w.buyAirtime(network: 'MTN', phone: '08031234567', kobo: 20000, pin: '1234');
    expect(w.history.first.title, 'MTN airtime 0803***4567');
    w.buyData(network: 'Glo', phone: '08051234567', plan: dataPlans[1], pin: '1234');
    expect(w.history.first.amount, -100000);
    expect(w.filtered(TxType.data), hasLength(1));
  });

  test('locked wallet rejects payments', () {
    w.lock();
    expect(() => w.buyAirtime(network: 'MTN', phone: '08031234567', kobo: 20000, pin: '1234'), throwsA(isA<WalletException>()));
  });

  test('change PIN', () {
    expect(() => w.changePin('0000', '5555'), throwsA(isA<WalletException>()));
    expect(() => w.changePin('1234', '55'), throwsA(isA<WalletException>()));
    w.changePin('1234', '5555');
    w.lock();
    expect(w.unlockWithPin('5555'), isTrue);
  });
}
