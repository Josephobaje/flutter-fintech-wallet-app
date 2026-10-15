import 'package:flutter/foundation.dart';

/// Formats kobo (minor units) as Naira, e.g. 1234550 -> ₦12,345.50
String naira(int kobo, {bool decimals = true}) {
  final neg = kobo < 0;
  final abs = kobo.abs();
  final whole = (abs ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  final frac = decimals ? '.${(abs % 100).toString().padLeft(2, '0')}' : '';
  return '${neg ? '-' : ''}₦$buf$frac';
}

enum TxType { funding, transfer, airtime, data }

class Tx {
  Tx({required this.id, required this.type, required this.amount, required this.title, required this.date});
  final String id;
  final TxType type;

  /// Signed amount in kobo (credit positive, debit negative).
  final int amount;
  final String title;
  final DateTime date;
}

class WalletException implements Exception {
  WalletException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DataPlan {
  const DataPlan(this.name, this.kobo);
  final String name;
  final int kobo;
}

const networks = ['MTN', 'Airtel', 'Glo', '9mobile'];
const dataPlans = [
  DataPlan('1GB · 1 day', 35000),
  DataPlan('2GB · 7 days', 100000),
  DataPlan('10GB · 30 days', 450000),
];
const banks = ['Access Bank', 'GTBank', 'First Bank', 'Zenith Bank', 'UBA', 'Kuda', 'Opay', 'Moniepoint'];

/// Mocked biometric check. Swap for local_auth in a real build.
abstract class BiometricAuth {
  Future<bool> authenticate();
}

class MockBiometric implements BiometricAuth {
  MockBiometric({this.succeed = true});
  bool succeed;
  @override
  Future<bool> authenticate() async => succeed;
}

class Wallet extends ChangeNotifier {
  Wallet({String pin = '1234', BiometricAuth? biometric, DateTime Function()? clock})
      : _currentPin = pin,
        biometric = biometric ?? MockBiometric(),
        _clock = clock ?? DateTime.now {
    _seed();
  }

  String _currentPin;
  final BiometricAuth biometric;
  final DateTime Function() _clock;
  static const maxPinAttempts = 3;
  static const dailyTransferLimit = 50000000; // ₦500,000

  int balance = 0;
  bool unlocked = false;
  bool hideBalance = false;
  int failedAttempts = 0;
  final List<Tx> history = [];
  int _seq = 0;

  bool get lockedOut => failedAttempts >= maxPinAttempts;

  void _seed() {
    final now = _clock();
    _record(TxType.funding, 25000000, 'Card funding (Paystack test)', now.subtract(const Duration(days: 3)));
    _record(TxType.transfer, -1250000, 'To Aisha Bello · GTBank', now.subtract(const Duration(days: 2)));
    _record(TxType.airtime, -100000, 'MTN airtime 0803***4567', now.subtract(const Duration(days: 1)));
  }

  void _record(TxType type, int amount, String title, [DateTime? at]) {
    balance += amount;
    history.insert(0, Tx(id: 'TX${(++_seq).toString().padLeft(4, '0')}', type: type, amount: amount, title: title, date: at ?? _clock()));
  }

  bool unlockWithPin(String pin) {
    if (lockedOut) throw WalletException('Too many attempts. Use biometrics or reset your PIN.');
    if (pin == _currentPin) {
      unlocked = true;
      failedAttempts = 0;
    } else {
      failedAttempts++;
    }
    notifyListeners();
    return unlocked;
  }

  Future<bool> unlockWithBiometrics() async {
    final ok = await biometric.authenticate();
    if (ok) {
      unlocked = true;
      failedAttempts = 0;
      notifyListeners();
    }
    return ok;
  }

  void lock() {
    unlocked = false;
    notifyListeners();
  }

  void toggleHide() {
    hideBalance = !hideBalance;
    notifyListeners();
  }

  void changePin(String oldPin, String newPin) {
    if (oldPin != _currentPin) throw WalletException('Current PIN is wrong');
    if (!RegExp(r'^\d{4}$').hasMatch(newPin)) throw WalletException('PIN must be 4 digits');
    _currentPin = newPin;
  }

  void _guard(int kobo, String pin) {
    if (!unlocked) throw WalletException('Wallet is locked');
    if (pin != _currentPin) throw WalletException('Incorrect PIN');
    if (kobo <= 0) throw WalletException('Enter an amount');
    if (kobo > balance) throw WalletException('Insufficient balance');
  }

  /// Mock of a Paystack card funding flow (test mode).
  void fund(int kobo) {
    if (kobo < 10000) throw WalletException('Minimum funding is ₦100');
    _record(TxType.funding, kobo, 'Card funding (Paystack test)');
    notifyListeners();
  }

  int get transferredToday {
    final now = _clock();
    return history
        .where((t) => t.type == TxType.transfer && t.date.year == now.year && t.date.month == now.month && t.date.day == now.day)
        .fold(0, (s, t) => s - t.amount);
  }

  static bool validAccount(String nuban) => RegExp(r'^\d{10}$').hasMatch(nuban);
  static bool validPhone(String p) => RegExp(r'^0[789][01]\d{8}$').hasMatch(p);

  void transfer({required String bank, required String account, required String name, required int kobo, required String pin}) {
    if (!validAccount(account)) throw WalletException('Account number must be 10 digits');
    _guard(kobo, pin);
    if (transferredToday + kobo > dailyTransferLimit) throw WalletException('Daily limit of ₦500,000 reached');
    _record(TxType.transfer, -kobo, 'To $name · $bank');
    notifyListeners();
  }

  void buyAirtime({required String network, required String phone, required int kobo, required String pin}) {
    if (!validPhone(phone)) throw WalletException('Enter a valid Nigerian phone number');
    if (kobo < 5000) throw WalletException('Minimum airtime is ₦50');
    _guard(kobo, pin);
    _record(TxType.airtime, -kobo, '$network airtime ${_mask(phone)}');
    notifyListeners();
  }

  void buyData({required String network, required String phone, required DataPlan plan, required String pin}) {
    if (!validPhone(phone)) throw WalletException('Enter a valid Nigerian phone number');
    _guard(plan.kobo, pin);
    _record(TxType.data, -plan.kobo, '$network ${plan.name.split(' ').first} data ${_mask(phone)}');
    notifyListeners();
  }

  String _mask(String p) => '${p.substring(0, 4)}***${p.substring(7)}';

  List<Tx> filtered(TxType? type) => type == null ? history : history.where((t) => t.type == type).toList();
}
