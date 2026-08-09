import 'package:flutter/material.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'add_transaction_screen.dart';
import 'chat_screen.dart';
import 'calendar_screen.dart';
import 'insights_screen.dart';
import '../widgets/transaction_card.dart';
import '../constants/app_colors.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});


  @override
  State<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}


class _TransactionListScreenState
    extends State<TransactionListScreen> {


  final TransactionService transactionService =
  TransactionService();


  List<TransactionModel> transactions = [];


  @override
  void initState() {
    super.initState();

    loadTransactions();
  }


  Future<void> loadTransactions() async {

    final data =
    await transactionService.getTransactions();


    setState(() {
      transactions = data;
    });

  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
      AppColors.background,


      appBar: AppBar(

        backgroundColor:
        AppColors.background,


        elevation:
        0,


        iconTheme:
        const IconThemeData(
          color:
          AppColors.textPrimary,
        ),


        title: const Text(

          "Transactions",

          style:
          TextStyle(
            color:
            AppColors.textPrimary,
          ),

        ),

        actions: [

          // 1. NEW INSIGHTS BUTTON
          IconButton(

            icon:
            const Icon(
              Icons.bar_chart,
              color:
              AppColors.textSecondary,
            ),
            tooltip: "Insights",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InsightsScreen(),
                ),
              );
              // Refreshing data when returning just in case
              loadTransactions();
            },
          ),

          // Existing Chat Button
          IconButton(

            icon:
            const Icon(
              Icons.chat,
              color:
              AppColors.textSecondary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatScreen()),
              );
            },
          ),

          // Existing Calendar Button
          IconButton(

            icon:
            const Icon(
              Icons.calendar_month,
              color:
              AppColors.textSecondary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),

        ],

      ),


      body: ListView.builder(

        padding: const EdgeInsets.only(
          top: 8,
          bottom: 80,
        ),

        itemCount: transactions.length,


        itemBuilder: (context, index) {

          final transaction =
          transactions[index];


          return TransactionCard(

            transaction: transaction,


            onTap: () async {

              await Navigator.push(

                context,

                MaterialPageRoute(

                  builder: (context) =>
                      AddTransactionScreen(
                        transaction: transaction,
                      ),

                ),

              );


              loadTransactions();

            },



            onDelete: () async {

              await transactionService.deleteTransaction(
                transaction.id!,
              );


              loadTransactions();

            },

          );

        },

      ),

      floatingActionButton: FloatingActionButton(

        backgroundColor:
        AppColors.purple,


        child:
        const Icon(

          Icons.add,

          color:
          AppColors.background,

        ),

        onPressed: () async {

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
              const AddTransactionScreen(),
            ),
          );


          loadTransactions();

        },

      ),

    );

  }
}