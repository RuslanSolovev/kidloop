class Item {
  final String itemId;
  final String ownerId;   // ← новое поле
  final String title;
  final String description;
  final int sv;
  final String imagePath;
  final String location;
  final String category;
  final String condition;
  final bool isMine;
  final String status;

  Item({
    required this.itemId,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.sv,
    required this.imagePath,
    required this.location,
    required this.category,
    required this.condition,
    this.isMine = false,
    this.status = 'available',
  });
}