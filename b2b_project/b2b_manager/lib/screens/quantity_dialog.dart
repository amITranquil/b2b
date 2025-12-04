import 'package:flutter/material.dart';
import '../models/product.dart';

class QuantityInputDialog extends StatefulWidget {
  final Product product;

  const QuantityInputDialog({
    super.key,
    required this.product,
  });

  @override
  QuantityInputDialogState createState() => QuantityInputDialogState();
}

class QuantityInputDialogState extends State<QuantityInputDialog> {
  final _quantityController = TextEditingController(text: '1');
  String _selectedUnit = 'adet';

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Miktar',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedUnit,
            items: ['adet', 'metre', 'kg']
                .map((unit) => DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedUnit = value!;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Birim',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: () {
            final quantity = double.tryParse(_quantityController.text);
            if (quantity != null && quantity > 0) {
              Navigator.pop(context, quantity);
            }
          },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
