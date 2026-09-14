import 'package:flutter/foundation.dart';

/// Represents a single item in the shopping cart
class CartItem {
  final String id;
  final String title;
  final String storeName;
  final double price;
  int quantity;
  final List<String> selectedAddons;
  final String? image;
  final String? notes;
  final String? spiceLevel;
  final List<String> exclusions;

  CartItem({
    required this.id,
    required this.title,
    required this.storeName,
    required this.price,
    this.quantity = 1,
    this.selectedAddons = const [],
    this.image,
    this.notes,
    this.spiceLevel,
    this.exclusions = const [],
  });

  double get total => price * quantity;

  String get formattedCustomizationText {
    final parts = <String>[];
    if (spiceLevel != null && spiceLevel!.isNotEmpty) {
      parts.add('🌶️ $spiceLevel');
    }
    if (exclusions.isNotEmpty) {
      parts.add('🚫 ${exclusions.join("، ")}');
    }
    final otherAddons = selectedAddons.where((a) => !a.contains('هريسة') && !a.startsWith('بدون')).toList();
    if (otherAddons.isNotEmpty) {
      parts.add('✨ ${otherAddons.join("، ")}');
    }
    if (notes != null && notes!.trim().isNotEmpty) {
      parts.add('📝 ${notes!.trim()}');
    }
    return parts.join(' • ');
  }

  CartItem copyWith({
    String? id,
    String? title,
    String? storeName,
    double? price,
    int? quantity,
    List<String>? selectedAddons,
    String? image,
    String? notes,
    String? spiceLevel,
    List<String>? exclusions,
  }) {
    return CartItem(
      id: id ?? this.id,
      title: title ?? this.title,
      storeName: storeName ?? this.storeName,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      image: image ?? this.image,
      notes: notes ?? this.notes,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      exclusions: exclusions ?? this.exclusions,
    );
  }
}

/// Centralized In-Memory Shopping Cart Service for Wasel Super-App
class CartService {
  static final List<CartItem> _items = [];

  /// Observable notifier for total items count (for badges and header icons)
  static final ValueNotifier<int> cartCountNotifier = ValueNotifier<int>(0);

  /// Get current cart items list
  static List<CartItem> get items => _items;

  /// Total count of all item quantities in the cart
  static int get count => _items.fold(0, (sum, item) => sum + item.quantity);

  /// Total price of all items in the cart
  static double get subtotal => _items.fold(0.0, (sum, item) => sum + item.total);

  /// Primary store name for items in the cart
  static String get storeName => _items.isNotEmpty ? _items.first.storeName : '';

  /// Set cart items directly
  static void setItems(List<CartItem> newItems) {
    if (identical(_items, newItems)) {
      _notifyUpdate();
      return;
    }
    final copy = List<CartItem>.from(newItems);
    _items.clear();
    _items.addAll(copy);
    _notifyUpdate();
  }

  /// Add item to cart or increment quantity if matching item & addons already exist
  static void addItem(CartItem newItem) {
    final existingIndex = _items.indexWhere(
      (item) =>
          item.id == newItem.id &&
          item.storeName == newItem.storeName &&
          listEquals(item.selectedAddons, newItem.selectedAddons),
    );

    if (existingIndex != -1) {
      _items[existingIndex].quantity += newItem.quantity;
    } else {
      _items.add(newItem);
    }
    _notifyUpdate();
  }

  /// Increment quantity of item at [index]
  static void incrementItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index].quantity++;
      _notifyUpdate();
    }
  }

  /// Decrement quantity or remove item if quantity drops to zero
  static void decrementItem(int index) {
    if (index >= 0 && index < _items.length) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      _notifyUpdate();
    }
  }

  /// Remove item at [index]
  static void removeItem(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      _notifyUpdate();
    }
  }

  /// Clear all items from cart
  static void clear() {
    _items.clear();
    _notifyUpdate();
  }

  static void _notifyUpdate() {
    cartCountNotifier.value = count;
  }
}
