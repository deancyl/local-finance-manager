import '../models/category.dart';

/// Repository interface for category operations.
abstract class CategoryRepository {
  /// Gets all categories.
  Future<List<Category>> getAll();

  /// Gets a category by ID.
  Future<Category?> getById(String id);

  /// Gets categories by parent ID.
  Future<List<Category>> getByParent(String? parentId);

  /// Gets income categories.
  Future<List<Category>> getIncomeCategories();

  /// Gets expense categories.
  Future<List<Category>> getExpenseCategories();

  /// Creates a new category.
  Future<Category> create(Category category);

  /// Updates an existing category.
  Future<Category> update(Category category);

  /// Deletes a category.
  Future<void> delete(String id);

  /// Gets the category hierarchy as a tree structure.
  Future<List<CategoryNode>> getHierarchy();
}

/// Node in the category hierarchy tree.
class CategoryNode {
  final Category category;
  final List<CategoryNode> children;

  CategoryNode({required this.category, this.children = const []});

  /// Returns true if this node has children.
  bool get hasChildren => children.isNotEmpty;
}