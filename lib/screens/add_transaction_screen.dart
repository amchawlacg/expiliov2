import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/transaction.dart';
import '../models/attachment.dart';

import '../services/transaction_service.dart';
import '../services/attachment_service.dart';

import '../constants/expense_categories.dart';
import '../constants/app_colors.dart';

import '../widgets/transaction_option_tile.dart';


class AddTransactionScreen extends StatefulWidget {

  final TransactionModel? transaction;
  final TransactionModel? draftTransaction;


  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.draftTransaction,
  });


  @override
  State<AddTransactionScreen> createState()
  => _AddTransactionScreenState();
}



class _AddTransactionScreenState
    extends State<AddTransactionScreen> {


  final amountController =
  TextEditingController();

  final noteController =
  TextEditingController();

  final merchantController =
  TextEditingController();

  final paymentNameController =
  TextEditingController();



  String selectedCategory = "Food";

  String selectedSubcategory =
      "Restaurant";


  String transactionType =
      "expense";

  String profileType =
      "personal";

  String paymentMethod =
      "cash";



  DateTime selectedDate =
  DateTime.now();



  File? selectedInvoice;


  List<AttachmentModel> attachments = [];



  final transactionService =
  TransactionService();


  final attachmentService =
  AttachmentService();



  @override
  void initState() {

    super.initState();


    final transaction =
        widget.transaction ??
            widget.draftTransaction;


    if (transaction != null) {


      amountController.text =
          transaction.amount.toString();


      selectedCategory =
          transaction.category ?? "Food";


      selectedSubcategory =
          transaction.subCategory ??
              "Restaurant";


      noteController.text =
          transaction.note ?? "";


      merchantController.text =
          transaction.merchant ?? "";


      paymentNameController.text =
          transaction.paymentName ?? "";


      paymentMethod =
          transaction.paymentMethod ??
              "cash";


      transactionType =
          transaction.transactionType;


      profileType =
          transaction.profileType;


      selectedDate =
          transaction.date;



      loadAttachments();

    }

  }




  Future<void> loadAttachments() async {


    if(widget.transaction == null) {
      return;
    }


    attachments =
    await attachmentService
        .getAttachments(
      widget.transaction!.id!,
    );


    setState((){});

  }





  Future<void> selectDate() async {


    final picked =
    await showDatePicker(

      context: context,

      initialDate:
      selectedDate,

      firstDate:
      DateTime(2000),

      lastDate:
      DateTime(2100),

    );



    if(picked != null){

      setState(() {

        selectedDate = picked;

      });

    }

  }


  Future<void> pickInvoice() async {


    final result =
    await FilePicker.platform.pickFiles();


    if(result == null) {
      return;
    }


    final dir =
    await getApplicationDocumentsDirectory();


    final invoiceDir =
    Directory(
      "${dir.path}/invoices",
    );



    if(!await invoiceDir.exists()){

      await invoiceDir.create();

    }



    selectedInvoice =
    await File(
      result.files.single.path!,
    ).copy(
      "${invoiceDir.path}/${result.files.single.name}",
    );



    setState((){});

  }






  Future<void> saveTransaction() async {


    if(amountController.text.trim().isEmpty){
      return;
    }


    final amount =
    double.tryParse(
      amountController.text.trim(),
    );


    if(amount == null){
      return;
    }


    final transaction =
    TransactionModel(

      id:
      widget.transaction?.id,


      userId:
      "local_user",


      amount:
      amount,


      transactionType:
      transactionType,


      profileType:
      profileType,


      category:
      selectedCategory,


      subCategory:
      selectedSubcategory,


      note:
      noteController.text,


      merchant:
      merchantController.text,


      paymentMethod:
      paymentMethod,


      paymentName:
      paymentNameController.text,


      date:
      selectedDate,


      source:
      "manual",


      createdAt:
      widget.transaction?.createdAt
          ??
          DateTime.now(),


      updatedAt:
      DateTime.now(),

    );



    if(widget.transaction == null){

      await transactionService
          .addTransaction(
        transaction,
      );

    }
    else{

      await transactionService
          .updateTransaction(
        transaction,
      );

    }



    if(mounted){

      Navigator.pop(context);

    }

  }






  @override
  Widget build(BuildContext context) {


    return Scaffold(


      backgroundColor:
      AppColors.background,



      appBar: AppBar(


        backgroundColor:
        AppColors.background,


        elevation: 0,


        iconTheme:
        const IconThemeData(
          color:
          AppColors.textPrimary,
        ),


        title: Text(

          widget.transaction == null
              ?
          "Add Transaction"
              :
          "Edit Transaction",


          style:
          const TextStyle(
            color:
            AppColors.textPrimary,
          ),

        ),


      ),





      body:

      Center(

      child:

      ConstrainedBox(


      constraints:

      const BoxConstraints(

      maxWidth: 430,

    ),



    child:

    SingleChildScrollView(


    physics:

    const BouncingScrollPhysics(),


    padding:

    const EdgeInsets.all(
    20,
    ),



    child:

    Column(


    crossAxisAlignment:
    CrossAxisAlignment.stretch,



    children: [




      TextField(

        controller:
        amountController,


        keyboardType:
        const TextInputType.numberWithOptions(
          decimal: true,
        ),


        inputFormatters: [

          FilteringTextInputFormatter.allow(
            RegExp(r'^\d*\.?\d{0,2}'),
          ),

        ],


        textAlign:
        TextAlign.center,



    style:

    const TextStyle(

    fontSize: 46,

    color:
    AppColors.textPrimary,


    fontWeight:
    FontWeight.bold,

    ),




    decoration:

    const InputDecoration(

    prefixText:
    "₹ ",


    prefixStyle:

    TextStyle(

    color:
    AppColors.textPrimary,

    ),


    hintText:
    "0",


    border:
    InputBorder.none,


    ),

    ),






    const SizedBox(
    height: 10,
    ),






    Row(


    children: [


    typeButton(
    "expense",
    ),


    typeButton(
    "income",
    ),


    typeButton(
    "transfer",
    ),


    ],

    ),




    const SizedBox(
    height: 25,
    ),






    TransactionOptionTile(

    icon:
    Icons.category,


    title:
    "Category",


    value:
    selectedCategory,


    onTap: (){


    showPicker(

    ExpenseCategories
        .categories
        .keys
        .toList(),


    (value){


    setState((){


    selectedCategory =
    value;


    selectedSubcategory =
    ExpenseCategories
        .categories[value]!
        .first;


    });


    },

    );


    },

    ),






    TransactionOptionTile(

    icon:
    Icons.list,


    title:
    "Subcategory",


    value:
    selectedSubcategory,


    onTap: (){


    showPicker(

    ExpenseCategories
        .categories[
    selectedCategory
    ]!,


    (value){


    setState((){


    selectedSubcategory =
    value;


    });


    },

    );


    },

    ),


      TransactionOptionTile(

        icon:
        Icons.payment,


        title:
        "Payment",


        value:
        paymentMethod,


        onTap: (){


          showPicker(

            [
              "cash",
              "credit_card",
              "debit_card",
              "upi",
              "bank"
            ],


                (value){

              setState((){

                paymentMethod =
                    value;

              });

            },

          );

        },

      ),








      TransactionOptionTile(

        icon:
        Icons.person,


        title:
        "Profile",


        value:
        profileType,


        onTap: (){


          showPicker(

            [
              "personal",
              "business",
            ],


                (value){


              setState((){


                profileType =
                    value;


              });

            },

          );


        },

      ),








      TransactionOptionTile(

        icon:
        Icons.calendar_month,


        title:
        "Date",


        value:
        "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}",


        onTap:
        selectDate,

      ),







      TransactionOptionTile(

        icon:
        Icons.attach_file,


        title:
        "Invoice",


        value:

        selectedInvoice == null
            ?
        "Add"
            :
        "Attached",



        onTap:
        pickInvoice,

      ),









      customInput(

        controller:
        merchantController,


        hint:
        "Merchant",

        icon:
        Icons.store,

      ),





      customInput(

        controller:
        paymentNameController,


        hint:
        "Payment name",

        icon:
        Icons.account_balance_wallet,

      ),






      customInput(

        controller:
        noteController,


        hint:
        "Note",

        icon:
        Icons.notes,

      ),







      const SizedBox(
        height: 25,
      ),








      SizedBox(


        height: 55,


        child:

        ElevatedButton(


          style:

          ElevatedButton.styleFrom(


            backgroundColor:

            Colors.green,


            shape:

            RoundedRectangleBorder(


              borderRadius:

              BorderRadius.circular(
                18,
              ),


            ),

          ),




          onPressed:
          saveTransaction,



          child:

          const Text(

            "Save Transaction",


            style:

            TextStyle(

              fontSize: 16,

              fontWeight:
              FontWeight.bold,

              color:
              Colors.white,

            ),

          ),


        ),

      ),



    ],

    ),

    ),

      ),

      ),

    );

  }









  Widget typeButton(
      String type,
      ){


    final selected =
        transactionType == type;



    return Expanded(

      child:

      GestureDetector(


        onTap: (){


          setState((){

            transactionType =
                type;

          });

        },



        child:

        Container(


          margin:

          const EdgeInsets.symmetric(
            horizontal: 4,
          ),



          padding:

          const EdgeInsets.symmetric(
            vertical: 13,
          ),




          decoration:

          BoxDecoration(


            color:

            selected
                ?
            AppColors.purple
                :
            AppColors.card,



            borderRadius:

            BorderRadius.circular(
              15,
            ),

          ),




          child:

          Center(

            child:

            Text(


              type.toUpperCase(),



              style:

              TextStyle(


                color:

                selected
                    ?
                Colors.white
                    :
                AppColors.textSecondary,


                fontWeight:
                FontWeight.bold,


              ),

            ),

          ),

        ),

      ),

    );

  }









  Widget customInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 4, // Keeps text perfectly centered with the circular icon
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(
          color: AppColors.textPrimary, // Forces white text on user input
          fontSize: 16,                 // Matches the Option Tile size exactly
          fontWeight: FontWeight.w600, // Matches the Option Tile thickness exactly
        ),
        decoration: InputDecoration(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black, // Pure black circle backdrop
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white, // Pure white icon color
              size: 20,
            ),
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textHint, // Keeps your soft placeholder color when empty
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }








  void showPicker(
      List<String> items,
      Function(String) selected,
      ) {

    showModalBottomSheet(

      context: context,

      backgroundColor:
      Colors.transparent,

      isScrollControlled:
      true,


      builder: (_) {


        return Center(

          child: ConstrainedBox(

            constraints:
            const BoxConstraints(
              maxWidth: 430,
            ),


            child: Container(


              margin:
              const EdgeInsets.only(
                bottom: 20,
              ),


              padding:
              const EdgeInsets.all(16),


              decoration:

              BoxDecoration(

                color:
                AppColors.card,


                borderRadius:
                BorderRadius.circular(28),

              ),



              child:

              Column(

                mainAxisSize:
                MainAxisSize.min,


                children: [


                  Container(

                    width: 45,

                    height: 5,


                    decoration:
                    BoxDecoration(

                      color:
                      AppColors.textSecondary,

                      borderRadius:
                      BorderRadius.circular(20),

                    ),

                  ),




                  const SizedBox(
                    height: 20,
                  ),






                  ...items.map((item){


                    return InkWell(


                      borderRadius:
                      BorderRadius.circular(16),


                      onTap: (){


                        selected(item);


                        Navigator.pop(context);

                      },



                      child:

                      Container(


                        margin:

                        const EdgeInsets.only(
                          bottom: 8,
                        ),



                        padding:

                        const EdgeInsets.symmetric(

                          horizontal: 16,

                          vertical: 14,

                        ),



                        decoration:

                        BoxDecoration(


                          color:
                          AppColors.cardLight,


                          borderRadius:
                          BorderRadius.circular(16),

                        ),




                        child:

                        Row(

                          children: [


                            Expanded(

                              child:

                              Text(

                                item.replaceAll(
                                    "_",
                                    " "
                                ),


                                style:

                                const TextStyle(

                                  color:
                                  AppColors.textPrimary,


                                  fontSize:
                                  16,


                                  fontWeight:
                                  FontWeight.w600,

                                ),

                              ),

                            ),



                            const Icon(

                              Icons.chevron_right,


                              color:
                              AppColors.textSecondary,

                            )


                          ],

                        ),

                      ),

                    );


                  }),


                ],

              ),

            ),

          ),

        );

      },

    );

  }




}
