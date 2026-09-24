import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

import 'invoice_gallery_screen.dart';
import 'chat_screen.dart';
import 'transaction_list_screen.dart';
import 'insights_screen.dart';
import 'ProfileScreen.dart';

import 'package:flutter_svg/flutter_svg.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 0: Invoices, 1: Chat, 2: Spending, 3: Insights, 4: Profile
  int selectedIndex = 1; // 👈 Starts directly on Chat (or set to 0 for Invoices)

  // Tracks which tabs have been opened at least once to prevent cold-boot overload
  final Set<int> _loadedTabs = {1};

  final List<Widget Function()> _screenBuilders = [
    () => const InvoiceGalleryScreen(),
    () => const ChatScreen(),
    () => const TransactionListScreen(),
    () => const InsightsScreen(),
    () => const ProfileScreen(),
  ];

  late final List<Widget?> _initializedScreens;

  @override
  void initState() {
    super.initState();
    _initializedScreens = List<Widget?>.filled(_screenBuilders.length, null);
    _initializedScreens[selectedIndex] = _screenBuilders[selectedIndex]();
  }

  void _onTabSelected(int index) {
    setState(() {
      selectedIndex = index;
      if (!_loadedTabs.contains(index)) {
        _loadedTabs.add(index);
        _initializedScreens[index] = _screenBuilders[index]();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.background,
      body: IndexedStack(
        index: selectedIndex,
        children: List.generate(_screenBuilders.length, (index) {
          return _initializedScreens[index] ?? const SizedBox.shrink();
        }),
      ),
      bottomNavigationBar: Container(
        height: 78,
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.cardLight, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              index: 0,
              icon: "assets/icons/components/invoice.svg",
              selectedIcon: "assets/icons/components/invoice.svg",
              label: "Invoices",
            ),
            _navItem(
              index: 1,
              icon: "assets/icons/chat.svg",
              selectedIcon: "assets/icons/chat_filled.svg",
              label: "Chat",
            ),
            _navItem(
              index: 2,
              icon: "assets/icons/spending.svg",
              selectedIcon: "assets/icons/spending_filled.svg",
              label: "Spending",
            ),
            _navItem(
              index: 3,
              icon: "assets/icons/insights.svg",
              selectedIcon: "assets/icons/insights_filled.svg",
              label: "Insights",
            ),
            _navItem(
              index: 4,
              icon: "assets/icons/profile.svg",
              selectedIcon: "assets/icons/profile_filled.svg",
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required String icon,
    required String selectedIcon,
    required String label,
  }) {
    final bool selected = selectedIndex == index;
    final colors = context.colors;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabSelected(index),
      child: SizedBox(
        width: 55,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              selected ? selectedIcon : icon,
              height: 22,
              width: 22,
              colorFilter: ColorFilter.mode(
                selected ? colors.textPrimary : colors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: selected ? colors.textPrimary : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}