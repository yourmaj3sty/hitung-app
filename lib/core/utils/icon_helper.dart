import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class IconHelper {
  static const Map<String, IconData> _iconMap = {
    // Categories
    'utensils': LucideIcons.utensils,
    'car': LucideIcons.car,
    'shopping-bag': LucideIcons.shoppingBag,
    'receipt': LucideIcons.receipt,
    'gamepad-2': LucideIcons.gamepad2,
    'heart-pulse': LucideIcons.heartPulse,
    'graduation-cap': LucideIcons.graduationCap,
    'more-horizontal': LucideIcons.moreHorizontal,
    'wallet': LucideIcons.wallet,
    'banknote': LucideIcons.banknote,
    'trending-up': LucideIcons.trendingUp,
    'gift': LucideIcons.gift,
    'coffee': LucideIcons.coffee,
    'home': LucideIcons.home,
    'bus': LucideIcons.bus,
    'film': LucideIcons.film,
    'shirt': LucideIcons.shirt,
    'plane': LucideIcons.plane,
    'wrench': LucideIcons.wrench,

    // Wallets
    'credit-card': LucideIcons.creditCard,
    'landmark': LucideIcons.landmark,
    'smartphone': LucideIcons.smartphone,
    'coins': LucideIcons.coins,
    'piggy-bank': LucideIcons.piggyBank,
    'safe': LucideIcons.shieldCheck,
  };

  static IconData getIcon(String iconName) {
    return _iconMap[iconName] ?? LucideIcons.circleDollarSign;
  }

  static List<String> get availableCategoryIcons => [
    'utensils',
    'car',
    'shopping-bag',
    'receipt',
    'gamepad-2',
    'heart-pulse',
    'graduation-cap',
    'coffee',
    'home',
    'gift',
    'trending-up',
    'more-horizontal',
  ];

  static List<String> get availableWalletIcons => [
    'wallet',
    'landmark',
    'credit-card',
    'smartphone',
    'coins',
    'piggy-bank',
  ];
}
