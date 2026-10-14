class CurrencyConstants {
  CurrencyConstants._();

  static const String defaultCurrency = 'USD';

  static const Map<String, String> currencySymbols = {
    'USD': r'$',
    'INR': '₹',
    'EUR': '€',
    'GBP': '£',
    'AED': 'د.إ',
    'CAD': r'C$',
    'AUD': r'A$',
    'JPY': '¥', // 👈 Added
  };

  static const Map<String, double> defaultRatesToUSD = {
    'USD': 1.0,
    'INR': 0.012,
    'EUR': 1.08,
    'GBP': 1.27,
    'AED': 0.27,
    'CAD': 0.73,
    'AUD': 0.65,
    'JPY': 0.0065, // 👈 Added (1 JPY ≈ 0.0065 USD)
  };

  static String getSymbol(String code) {
    return currencySymbols[code] ?? code;
  }

  static double getDefaultExchangeRate(String code) {
    return defaultRatesToUSD[code] ?? 1.0;
  }

  static List<String> get supportedCurrencies => currencySymbols.keys.toList();
}