import 'package:luminara_photobooth/core/data/db.dart';
import 'package:sqflite/sqflite.dart';

class Produk {
  final int? id;
  final String name;
  final int price;

  Produk({
    this.id,
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  factory Produk.fromMap(Map<String, dynamic> map) {
    return Produk(
      id: map['id'],
      name: map['name'],
      price: map['price'],
    );
  }

  static Future<int> createProduk(Produk produk) async {
    final db = await getDatabase();
    return await db.insert(
      'products',
      produk.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Produk>> getAllProduk() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('products');
    return List.generate(maps.length, (i) {
      return Produk.fromMap(maps[i]);
    });
  }

  static Future<int> updateProduk(Produk produk) async {
    final db = await getDatabase();
    return await db.update(
      'products',
      produk.toMap(),
      where: 'id = ?',
      whereArgs: [produk.id],
    );
  }

  static Future<int> deleteProduk(int id) async {
    final db = await getDatabase();
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Map<String, dynamic>>> searchProdukByName(String query) async {
    final db = await getDatabase();
    return await db.query(
      'products',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
    );
  }
}