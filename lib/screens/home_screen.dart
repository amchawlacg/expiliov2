import 'package:flutter/material.dart';


class HomeScreen extends StatelessWidget {

  const HomeScreen({super.key});


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: const Text(
          "Expillio",
        ),

      ),


      body: Padding(

        padding: const EdgeInsets.all(16),


        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,


          children: [


            const Text(

              "Welcome back",

              style: TextStyle(
                fontSize: 18,
              ),

            ),



            const SizedBox(height: 20),



            Container(

              width: double.infinity,

              padding: const EdgeInsets.all(20),


              decoration: BoxDecoration(

                color: const Color(0xff1f1f1f),

                borderRadius: BorderRadius.circular(20),

              ),



              child: const Column(

                crossAxisAlignment: CrossAxisAlignment.start,


                children: [


                  Text(

                    "Total Balance",

                    style: TextStyle(
                      color: Colors.grey,
                    ),

                  ),


                  SizedBox(height: 10),



                  Text(

                    "₹0.00",

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 30,

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ],

              ),

            ),



            const SizedBox(height: 20),



            Row(

              children: [


                Expanded(

                  child: _SummaryCard(

                    title: "Income",

                    amount: "+₹0",

                    color: Colors.greenAccent,

                  ),

                ),


                SizedBox(width: 12),


                Expanded(

                  child: _SummaryCard(

                    title: "Expense",

                    amount: "-₹0",

                    color: Colors.redAccent,

                  ),

                ),


              ],

            ),




            const SizedBox(height: 30),




            const Text(

              "Recent Transactions",

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.bold,

              ),

            ),




            const SizedBox(height: 20),



            const Center(

              child: Text(

                "No transactions yet",

              ),

            ),


          ],

        ),

      ),

    );

  }

}




class _SummaryCard extends StatelessWidget {


  final String title;

  final String amount;

  final Color color;


  const _SummaryCard({

    required this.title,

    required this.amount,

    required this.color,

  });



  @override
  Widget build(BuildContext context) {


    return Container(

      padding: const EdgeInsets.all(16),


      decoration: BoxDecoration(

        color: const Color(0xff1f1f1f),

        borderRadius: BorderRadius.circular(16),

      ),



      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,


        children: [


          Text(

            title,

            style: const TextStyle(

              color: Colors.grey,

            ),

          ),



          const SizedBox(height: 8),



          Text(

            amount,


            style: TextStyle(

              color: color,

              fontWeight: FontWeight.bold,

              fontSize: 18,

            ),

          ),


        ],

      ),

    );

  }

}