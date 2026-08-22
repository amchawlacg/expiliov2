import '../models/category_model.dart';

class DefaultCategories {
  static List<CategoryModel> get defaults => [
    CategoryModel(
      name: 'Food',
      subcategories: ['Restaurant', 'Groceries', 'Coffee', 'Other'],
    ),
    CategoryModel(
      name: 'Transport',
      subcategories: ['Fuel', 'Taxi', 'Public Transport', 'Other'],
    ),
    CategoryModel(
      name: 'Shopping',
      subcategories: ['Clothes', 'Electronics', 'Personal', 'Other'],
    ),
    CategoryModel(
      name: 'Bills',
      subcategories: ['Electricity', 'Internet', 'Phone', 'Other'],
    ),
    CategoryModel(
      name: 'Health',
      subcategories: ['Medicine', 'Doctor', 'Fitness', 'Other'],
    ),
    CategoryModel(
      name: 'Education',
      subcategories: ['Books', 'Courses', 'Fees', 'Other'],
    ),
    CategoryModel(
      name: 'Loan',
      subcategories: ['EMI', 'Credit Card Payment', 'Personal Loan', 'Other'],
    ),
    CategoryModel(
      name: 'Business',
      subcategories: ['Software', 'Equipment', 'Marketing', 'Office', 'Other'],
    ),
    CategoryModel(
      name: 'Other',
      subcategories: ['Other'],
    ),
  ];
}