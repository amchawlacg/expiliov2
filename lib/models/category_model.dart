import 'dart:convert';

class CategoryModel {
  final int? id;
  final String name;
  final List<String> subcategories;
  final String? iconName;
  final bool isCustom;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    this.id,
    required this.name,
    required this.subcategories,
    this.iconName,
    this.isCustom = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'subcategories': jsonEncode(subcategories),
        'icon_name': iconName,
        'is_custom': isCustom ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CategoryModel.fromMap(Map<String, dynamic> map) => CategoryModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        subcategories: List<String>.from(jsonDecode(map['subcategories'] as String)),
        iconName: map['icon_name'] as String?,
        isCustom: (map['is_custom'] as int?) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  CategoryModel copyWith({
    int? id,
    String? name,
    List<String>? subcategories,
    String? iconName,
    bool? isCustom,
  }) =>
      CategoryModel(
        id: id ?? this.id,
        name: name ?? this.name,
        subcategories: subcategories ?? this.subcategories,
        iconName: iconName ?? this.iconName,
        isCustom: isCustom ?? this.isCustom,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}