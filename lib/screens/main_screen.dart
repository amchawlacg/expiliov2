import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

import 'chat_screen.dart';
import 'home_screen.dart';
import 'transaction_list_screen.dart';
import 'insights_screen.dart';
import 'calendar_screen.dart';

import 'package:flutter_svg/flutter_svg.dart';


class MainScreen extends StatefulWidget {

  const MainScreen({super.key});


  @override
  State<MainScreen> createState() => _MainScreenState();

}


class _MainScreenState extends State<MainScreen> {


  int selectedIndex = 1;


  final screens = const [

    HomeScreen(),

    ChatScreen(),

    TransactionListScreen(),

    InsightsScreen(),

    CalendarScreen(),

  ];


  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    return Scaffold(

      backgroundColor: colors.background,


      body: screens[selectedIndex],


      bottomNavigationBar: Container(

        height: 78,

        decoration: BoxDecoration(

          color: colors.card,

          border: Border(

            top: BorderSide(
              color: colors.cardLight,
              width: 1,
            ),

          ),

        ),


        child: Row(

          mainAxisAlignment: MainAxisAlignment.spaceAround,


          children: [

            _navItem(
              index: 0,
              icon: "lib/assets/icons/home.svg",
              selectedIcon: "lib/assets/icons/home_filled.svg",
              label: "Home",
            ),


            _navItem(
              index: 1,
              icon: "lib/assets/icons/chat.svg",
              selectedIcon: "lib/assets/icons/chat_filled.svg",
              label: "Chat",
            ),


            _navItem(
              index: 2,
              icon: "lib/assets/icons/spending.svg",
              selectedIcon: "lib/assets/icons/spending_filled.svg",
              label: "Spending",
            ),


            _navItem(
              index: 3,
              icon: "lib/assets/icons/insights.svg",
              selectedIcon: "lib/assets/icons/insights_filled.svg",
              label: "Insights",
            ),


            _navItem(
              index: 4,
              icon: "lib/assets/icons/profile.svg",
              selectedIcon: "lib/assets/icons/profile_filled.svg",
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


      onTap: () {

        setState(() {

          selectedIndex = index;

        });

      },


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

                selected
                    ? colors.textPrimary
                    : colors.textSecondary,

                BlendMode.srcIn,

              ),

            ),


            const SizedBox(height: 6),


            Text(

              label,

              overflow: TextOverflow.ellipsis,


              style: TextStyle(

                fontSize: 10,

                color: selected
                    ? colors.textPrimary
                    : colors.textSecondary,

              ),

            ),

          ],

        ),

      ),

    );

  }

}