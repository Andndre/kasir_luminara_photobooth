import 'package:sqflite/sqflite.dart';

import '../../domain/product.dart';
import '../db.dart';
import '../result.dart';

/// The only place that touches the `products` table.
class ProductRepository {
  const ProductRepository();

  Future<Result<List<Product>>> all() =>
      runCatching('Gagal memuat produk', () async {
        final db = await getDatabase();
        final rows = await db.query('products', orderBy: 'id ASC');
        return rows.map(Product.fromMap).toList();
      });

  /// Returns the new row id.
  Future<Result<int>> create(Product product) =>
      runCatching('Gagal menyimpan produk', () async {
        final db = await getDatabase();
        return db.insert(
          'products',
          product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });

  Future<Result<void>> update(Product product) =>
      runCatching('Gagal memperbarui produk', () async {
        final id = product.id;
        if (id == null) {
          throw ArgumentError('Produk tanpa id tidak bisa diperbarui');
        }
        final db = await getDatabase();
        final updated = await db.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [id],
        );
        // Zero rows means the product was deleted elsewhere; reporting success
        // would leave the edit screen claiming it saved.
        if (updated == 0) throw StateError('Produk tidak ditemukan');
      });

  Future<Result<void>> delete(int id) =>
      runCatching('Gagal menghapus produk', () async {
        final db = await getDatabase();
        await db.delete('products', where: 'id = ?', whereArgs: [id]);
      });
}
