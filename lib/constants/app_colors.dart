import 'package:flutter/material.dart';

@immutable
class AppColorScheme extends ThemeExtension<AppColorScheme> {
  // Backgrounds & Surfaces
  final Color background;
  final Color card;
  final Color cardLight;

  // Accents & Brand
  final Color primary;
  final Color purple;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;

  // Borders & Dividers
  final Color border;
  final Color divider;
  final Color borderHover;

  // Icons
  final Color iconCircle;
  final Color iconBackground;

  // Chips
  final Color chipBackground;
  final Color chipBorder;

  // Transaction Types
  final Color income;
  final Color expense;
  final Color transfer;
  final Color incomeBackground;
  final Color expenseBackground;
  final Color transferBackground;

  // Shadows
  final Color shadow;

  const AppColorScheme({
    required this.background,
    required this.card,
    required this.cardLight,
    required this.primary,
    required this.purple,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.border,
    required this.divider,
    required this.borderHover,
    required this.iconCircle,
    required this.iconBackground,
    required this.chipBackground,
    required this.chipBorder,
    required this.income,
    required this.expense,
    required this.transfer,
    required this.incomeBackground,
    required this.expenseBackground,
    required this.transferBackground,
    required this.shadow,
  });

  // ===========================================================================
  // 🌙 DARK THEME PALETTE
  // ===========================================================================
  static const dark = AppColorScheme(
    background: Color(0xff121212),
    card: Color(0xff1e1e1e),
    cardLight: Color(0xff2a2a2a),
    primary: Color(0xff7BC000),
    purple: Color(0xffC8A8FF),
    textPrimary: Colors.white,
    textSecondary: Color(0xffA8A8A8),
    textHint: Color(0xff7D7D7D),
    border: Color(0xff413A39),
    divider: Color(0xff3B3534),
    borderHover: Color(0xff57504F),
    iconCircle: Color(0xff2D2538),
    iconBackground: Color(0xff363130),
    chipBackground: Color(0xff35302F),
    chipBorder: Color(0xff47403F),
    income: Color(0xff69F0AE),
    expense: Color(0xffFF5252),
    transfer: Color(0xff64B5F6),
    incomeBackground: Color(0xff173827),
    expenseBackground: Color(0xff401F22),
    transferBackground: Color(0xff1C3448),
    shadow: Color(0x33000000),
  );

  // ===========================================================================
  // ☀️ LIGHT THEME PALETTE
  // ===========================================================================
  static const light = AppColorScheme(
    background: Color.fromARGB(255, 255, 146, 146),
    card: Color(0xffFFFFFF),
    cardLight: Color(0xffF1F3F5),
    primary: Color(0xff5C940D),
    purple: Color(0xff7048E8),
    textPrimary: Color(0xff212529),
    textSecondary: Color(0xff6C757D),
    textHint: Color(0xffADB5BD),
    border: Color(0xffDEE2E6),
    divider: Color(0xffE9ECEF),
    borderHover: Color(0xffCED4DA),
    iconCircle: Color(0xffEDE9FE),
    iconBackground: Color(0xffF1F3F5),
    chipBackground: Color(0xffE9ECEF),
    chipBorder: Color(0xffCED4DA),
    income: Color(0xff2B8A3E),
    expense: Color(0xffE03131),
    transfer: Color(0xff1971C2),
    incomeBackground: Color(0xffD3F9D8),
    expenseBackground: Color(0xffFFE3E3),
    transferBackground: Color(0xffD0EBFF),
    shadow: Color(0x1A000000),
  );

  @override
  AppColorScheme copyWith({
    Color? background,
    Color? card,
    Color? cardLight,
    Color? primary,
    Color? purple,
    Color? textPrimary,
    Color? textSecondary,
    Color? textHint,
    Color? border,
    Color? divider,
    Color? borderHover,
    Color? iconCircle,
    Color? iconBackground,
    Color? chipBackground,
    Color? chipBorder,
    Color? income,
    Color? expense,
    Color? transfer,
    Color? incomeBackground,
    Color? expenseBackground,
    Color? transferBackground,
    Color? shadow,
  }) {
    return AppColorScheme(
      background: background ?? this.background,
      card: card ?? this.card,
      cardLight: cardLight ?? this.cardLight,
      primary: primary ?? this.primary,
      purple: purple ?? this.purple,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textHint: textHint ?? this.textHint,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      borderHover: borderHover ?? this.borderHover,
      iconCircle: iconCircle ?? this.iconCircle,
      iconBackground: iconBackground ?? this.iconBackground,
      chipBackground: chipBackground ?? this.chipBackground,
      chipBorder: chipBorder ?? this.chipBorder,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      incomeBackground: incomeBackground ?? this.incomeBackground,
      expenseBackground: expenseBackground ?? this.expenseBackground,
      transferBackground: transferBackground ?? this.transferBackground,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppColorScheme lerp(ThemeExtension<AppColorScheme>? other, double t) {
    if (other is! AppColorScheme) return this;
    return AppColorScheme(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardLight: Color.lerp(cardLight, other.cardLight, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textHint: Color.lerp(textHint, other.textHint, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      borderHover: Color.lerp(borderHover, other.borderHover, t)!,
      iconCircle: Color.lerp(iconCircle, other.iconCircle, t)!,
      iconBackground: Color.lerp(iconBackground, other.iconBackground, t)!,
      chipBackground: Color.lerp(chipBackground, other.chipBackground, t)!,
      chipBorder: Color.lerp(chipBorder, other.chipBorder, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      incomeBackground: Color.lerp(incomeBackground, other.incomeBackground, t)!,
      expenseBackground: Color.lerp(expenseBackground, other.expenseBackground, t)!,
      transferBackground: Color.lerp(transferBackground, other.transferBackground, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

// =============================================================================
// 🎨 SHARED / STATIC CONSTANTS (Theme-Independent)
// =============================================================================
class AppColors {
  // Category Colors
  static const food = Color(0xffF2994A);
  static const shopping = Color(0xff4A90E2);
  static const travel = Color(0xff56CCF2);
  static const entertainment = Color(0xffBB6BD9);
  static const business = Color(0xff9B51E0);
  static const salary = Color(0xff27AE60);
  static const fuel = Color(0xffF2C94C);
  static const health = Color(0xffEB5757);
  static const groceries = Color(0xff26A69A);
  static const education = Color(0xff5C6BC0);
  static const bills = Color(0xffFF7043);
  static const investments = Color(0xff26C6DA);
  static const gifts = Color(0xffEC407A);
  static const transport = Color(0xff42A5F5);
  static const rent = Color(0xff8D6E63);
  static const defaultCategory = Color(0xff5C5C5C);

  // Status Colors
  static const synced = Color(0xff4CAF50);
  static const pending = Color(0xffFFB300);
  static const deleted = Color(0xffEF5350);
}

// =============================================================================
// 💡 CONTEXT EXTENSION HELPER
// =============================================================================
extension AppThemeContext on BuildContext {
  AppColorScheme get colors =>
      Theme.of(this).extension<AppColorScheme>() ?? AppColorScheme.dark;
}