import '../database/database_helper.dart';
import '../models/category_model.dart';
import '../constants/expense_categories.dart'; // Ensure filename matches

class CategoryService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<CategoryModel>> getAllCategories() async {
    final rawList = await _db.getCategories();

    // First time launch: seed defaults if database table is empty
    if (rawList.isEmpty) {
      await _seedDefaults();
      final freshList = await _db.getCategories();
      return freshList.map((m) => CategoryModel.fromMap(m)).toList();
    }

    return rawList.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<void> _seedDefaults() async {
    final List<Map<String, dynamic>> defaultData =
        DefaultCategories.defaults.map((category) => category.toMap()).toList();

    await _db.seedInitialCategories(defaultData);
  }

  Future<int> addCategory(String name, {List<String>? subcategories, String? iconName}) async {
    final newCategory = CategoryModel(
      name: name.trim(),
      subcategories: subcategories ?? ["Other"],
      iconName: iconName,
      isCustom: true,
    );
    return await _db.insertCategory(newCategory.toMap());
  }

  Future<void> addSubcategory(CategoryModel category, String subcategoryName) async {
    final trimmed = subcategoryName.trim();
    if (category.subcategories.contains(trimmed)) return;

    final updatedList = List<String>.from(category.subcategories)..add(trimmed);
    final updatedCategory = category.copyWith(subcategories: updatedList);

    if (category.id != null) {
      await _db.updateCategory(category.id!, updatedCategory.toMap());
    }
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
  }
}