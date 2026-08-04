import 'package:flutter/material.dart';
import 'package:luminara_photobooth/core/core.dart';

/// Add and edit were two near-identical dialogs; this is the one form for both.
/// Pass [existing] to edit, omit it to create.
///
/// Returns the filled-in [Product] on save, or null if dismissed. It does not
/// persist anything itself — that stays with the cubit.
class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({super.key, this.existing});

  final Product? existing;

  static Future<Product?> show(BuildContext context, {Product? existing}) =>
      showDialog<Product>(
        context: context,
        builder: (_) => ProductFormDialog(existing: existing),
      );

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _price = TextEditingController(
      text: widget.existing == null ? '' : '${widget.existing!.price}',
    );
  }

  @override
  void dispose() {
    // These leaked before: controllers were created inline in the dialog
    // builder and never disposed.
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      Product(
        id: widget.existing?.id,
        name: _name.text.trim(),
        price: Currency.parse(_price.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Paket' : 'Tambah Paket Baru'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama Paket'),
              textInputAction: TextInputAction.next,
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Nama paket wajib diisi'
                  : null,
            ),
            TextFormField(
              controller: _price,
              decoration: const InputDecoration(labelText: 'Harga (Rp)'),
              keyboardType: TextInputType.number,
              onFieldSubmitted: (_) => _submit(),
              // `int.parse` on raw input used to throw and kill the dialog when
              // the field held anything non-numeric.
              validator: (value) {
                final parsed = Currency.parse(value ?? '');
                if (parsed == null) return 'Harga wajib diisi angka';
                if (parsed <= 0) return 'Harga harus lebih dari 0';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Simpan Perubahan' : 'Simpan'),
        ),
      ],
    );
  }
}
