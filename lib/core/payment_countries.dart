/// MarzPay multi-country configuration.
///
/// All 12 live markets supported by MarzPay are defined here.
/// Uganda is the default (index 0) and is already fully tested.
///
/// Rules from MarzPay docs:
/// - Always send `country` on money-movement requests.
/// - For DRC also send `currency` (CDF default or USD).
/// - Phone numbers must be in E.164 format (+countryCode…).
/// - `method` defaults to `mobile_money` — no need to send it explicitly.
///
/// Source: https://wallet.wearemarz.com/documentation

class PaymentCountry {
  final String code;          // MarzPay country code e.g. 'UG'
  final String name;          // Display name
  final String flag;          // Emoji flag
  final String currency;      // Primary ISO currency code
  final List<String> currencies; // All supported currencies (DRC has CDF + USD)
  final String dialCode;      // E.164 prefix e.g. '+256'
  final int dialDigits;       // Total digits after dial code (local number length)
  final String phoneHint;     // Placeholder shown in UI
  final List<String> networks; // Mobile money networks for display
  final bool bankTransferSupported; // MarzPay bank-transfer API
  final bool phoneVerificationSupported; // MarzPay phone-verify API
  final int minAmount;        // Minimum transaction in local currency (raw int)
  final String currencySymbol; // Short symbol for display

  const PaymentCountry({
    required this.code,
    required this.name,
    required this.flag,
    required this.currency,
    required this.currencies,
    required this.dialCode,
    required this.dialDigits,
    required this.phoneHint,
    required this.networks,
    this.bankTransferSupported = false,
    this.phoneVerificationSupported = false,
    required this.minAmount,
    required this.currencySymbol,
  });

  /// Whether DRC dual-currency handling is needed.
  bool get isDualCurrency => currencies.length > 1;
}

class PaymentCountries {
  PaymentCountries._();

  // ─── All 12 MarzPay live markets ─────────────────────────────────────────

  static const PaymentCountry uganda = PaymentCountry(
    code: 'UG',
    name: 'Uganda',
    flag: '🇺🇬',
    currency: 'UGX',
    currencies: ['UGX'],
    dialCode: '+256',
    dialDigits: 9,
    phoneHint: '+256 7XX XXX XXX',
    networks: ['MTN', 'Airtel'],
    bankTransferSupported: true,
    phoneVerificationSupported: true,
    minAmount: 500,
    currencySymbol: 'UGX',
  );

  static const PaymentCountry kenya = PaymentCountry(
    code: 'KE',
    name: 'Kenya',
    flag: '🇰🇪',
    currency: 'KES',
    currencies: ['KES'],
    dialCode: '+254',
    dialDigits: 9,
    phoneHint: '+254 7XX XXX XXX',
    networks: ['M-Pesa'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 10,
    currencySymbol: 'KES',
  );

  static const PaymentCountry rwanda = PaymentCountry(
    code: 'RW',
    name: 'Rwanda',
    flag: '🇷🇼',
    currency: 'RWF',
    currencies: ['RWF'],
    dialCode: '+250',
    dialDigits: 9,
    phoneHint: '+250 7XX XXX XXX',
    networks: ['MTN', 'Airtel'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 100,
    currencySymbol: 'RWF',
  );

  static const PaymentCountry drc = PaymentCountry(
    code: 'CD',
    name: 'DR Congo',
    flag: '🇨🇩',
    currency: 'CDF',
    currencies: ['CDF', 'USD'],
    dialCode: '+243',
    dialDigits: 9,
    phoneHint: '+243 8XX XXX XXX',
    networks: ['Vodacom', 'Airtel', 'Orange'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 500,
    currencySymbol: 'CDF',
  );

  static const PaymentCountry zambia = PaymentCountry(
    code: 'ZM',
    name: 'Zambia',
    flag: '🇿🇲',
    currency: 'ZMW',
    currencies: ['ZMW'],
    dialCode: '+260',
    dialDigits: 9,
    phoneHint: '+260 9XX XXX XXX',
    networks: ['MTN', 'Airtel', 'Zamtel'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 5,
    currencySymbol: 'ZMW',
  );

  static const PaymentCountry cameroon = PaymentCountry(
    code: 'CM',
    name: 'Cameroon',
    flag: '🇨🇲',
    currency: 'XAF',
    currencies: ['XAF'],
    dialCode: '+237',
    dialDigits: 9,
    phoneHint: '+237 6XX XXX XXX',
    networks: ['MTN', 'Orange'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 100,
    currencySymbol: 'FCFA',
  );

  static const PaymentCountry benin = PaymentCountry(
    code: 'BJ',
    name: 'Benin',
    flag: '🇧🇯',
    currency: 'XOF',
    currencies: ['XOF'],
    dialCode: '+229',
    dialDigits: 8,
    phoneHint: '+229 XXXX XXXX',
    networks: ['MTN', 'Moov'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 100,
    currencySymbol: 'CFA',
  );

  static const PaymentCountry coteDivoire = PaymentCountry(
    code: 'CI',
    name: "Côte d'Ivoire",
    flag: '🇨🇮',
    currency: 'XOF',
    currencies: ['XOF'],
    dialCode: '+225',
    dialDigits: 10,
    phoneHint: '+225 07 XX XX XX XX',
    networks: ['MTN', 'Orange'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 100,
    currencySymbol: 'CFA',
  );

  static const PaymentCountry gabon = PaymentCountry(
    code: 'GA',
    name: 'Gabon',
    flag: '🇬🇦',
    currency: 'XAF',
    currencies: ['XAF'],
    dialCode: '+241',
    dialDigits: 7,
    phoneHint: '+241 07 XX XX XX',
    networks: ['Airtel'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 100,
    currencySymbol: 'FCFA',
  );

  static const PaymentCountry congoBrazzaville = PaymentCountry(
    code: 'CG',
    name: 'Congo-Brazzaville',
    flag: '🇨🇬',
    currency: 'XAF',
    currencies: ['XAF'],
    dialCode: '+242',
    dialDigits: 9,
    phoneHint: '+242 06 XXX XXXX',
    networks: ['MTN', 'Airtel'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 100,
    currencySymbol: 'FCFA',
  );

  static const PaymentCountry senegal = PaymentCountry(
    code: 'SN',
    name: 'Senegal',
    flag: '🇸🇳',
    currency: 'XOF',
    currencies: ['XOF'],
    dialCode: '+221',
    dialDigits: 9,
    phoneHint: '+221 7X XXX XXXX',
    networks: ['Orange', 'Free'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 100,
    currencySymbol: 'CFA',
  );

  static const PaymentCountry sierraLeone = PaymentCountry(
    code: 'SL',
    name: 'Sierra Leone',
    flag: '🇸🇱',
    currency: 'SLE',
    currencies: ['SLE'],
    dialCode: '+232',
    dialDigits: 8,
    phoneHint: '+232 XX XXX XXX',
    networks: ['Orange'],
    bankTransferSupported: false,
    phoneVerificationSupported: false,
    minAmount: 1,
    currencySymbol: 'SLE',
  );

  // ─── Ordered list: Uganda first (default), then alphabetically ──────────

  static const List<PaymentCountry> all = [
    uganda,
    benin,
    cameroon,
    congoBrazzaville,
    coteDivoire,
    drc,
    gabon,
    kenya,
    rwanda,
    senegal,
    sierraLeone,
    zambia,
  ];

  // ─── Lookup helpers ──────────────────────────────────────────────────────

  /// Get country by MarzPay code. Returns Uganda if not found.
  static PaymentCountry byCode(String code) {
    return all.firstWhere(
      (c) => c.code == code,
      orElse: () => uganda,
    );
  }

  /// Get country by dial code prefix.
  static PaymentCountry? byDialCode(String dialCode) {
    try {
      return all.firstWhere((c) => c.dialCode == dialCode);
    } catch (_) {
      return null;
    }
  }

  /// Format a raw phone number to E.164 for the given country.
  /// Strips leading 0 and prepends the country dial code if needed.
  static String formatPhone(String raw, PaymentCountry country) {
    raw = raw.replaceAll(RegExp(r'\s+'), '').replaceAll('+', '');
    final codeDigits = country.dialCode.replaceAll('+', '');
    if (raw.startsWith('0')) raw = '$codeDigits${raw.substring(1)}';
    if (!raw.startsWith(codeDigits)) raw = '$codeDigits$raw';
    return '+$raw';
  }

  /// Validate that the phone number looks correct for the given country.
  /// Basic E.164 length check — not operator-specific.
  static bool isValidPhone(String phone, PaymentCountry country) {
    final e164 = phone.startsWith('+') ? phone : '+$phone';
    if (!e164.startsWith(country.dialCode)) return false;
    final digits = e164.replaceAll('+', '').replaceAll(country.dialCode.replaceAll('+', ''), '');
    // Allow slight variance ±1 for countries with variable length numbers
    return digits.length >= country.dialDigits - 1 &&
           digits.length <= country.dialDigits + 1;
  }

  /// Returns the currency to use for a given country and optional override.
  /// Relevant for DRC which supports both CDF and USD.
  static String resolveCurrency(PaymentCountry country, {String? currencyOverride}) {
    if (currencyOverride != null && country.currencies.contains(currencyOverride)) {
      return currencyOverride;
    }
    return country.currency;
  }
}
