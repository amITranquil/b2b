// lib/screens/products_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/product.dart';
import '../services/api_service.dart';
import 'payment_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ApiService _apiService = ApiService();
  final numberFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  List<Product> _products = [];
  final Map<String, CartItem> _cart = {}; // productCode -> CartItem
  bool _isLoading = false;
  String _searchQuery = '';
  String _error = '';
  bool _speechEnabled = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (error) {
        debugPrint('Speech recognition error: $error');
      },
      onStatus: (status) {
        debugPrint('Speech recognition status: $status');
      },
    );
    setState(() {});
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _addToCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.productCode)) {
        _cart[product.productCode]!.quantity++;
      } else {
        _cart[product.productCode] = CartItem(
          product: product,
          quantity: 1,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} sepete eklendi'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeFromCart(String productCode) {
    setState(() {
      _cart.remove(productCode);
    });
  }

  void _updateQuantity(String productCode, double quantity) {
    if (quantity <= 0) {
      _removeFromCart(productCode);
      return;
    }

    setState(() {
      _cart[productCode]!.quantity = quantity;
    });
  }

  double get _cartTotal {
    return _cart.values.fold(0, (sum, item) => sum + item.total);
  }

  int get _cartItemCount {
    return _cart.values.fold(0, (sum, item) => sum + item.quantity.toInt());
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesli arama desteklenmiyor veya izin verilmedi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _searchQuery = result.recognizedWords;
          _isListening = false;
        });
      },
      localeId: 'tr_TR',
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
      ),
    );

    setState(() {
      _isListening = true;
    });
  }

  Future<void> _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
  }

  void _showCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildCartSheet(),
    );
  }

  void _proceedToPayment() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sepet boş!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context); // Close cart sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          cartItems: _cart.values.toList(),
        ),
      ),
    ).then((saleCompleted) {
      if (saleCompleted == true) {
        // Satış tamamlandı, sepeti temizle
        setState(() {
          _cart.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((product) {
      final search = _searchQuery.toLowerCase();
      return product.name.toLowerCase().contains(search) ||
          product.productCode.toLowerCase().contains(search);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ürünler'),
        actions: [
          // Sepet badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: _showCart,
              ),
              if (_cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      '$_cartItemCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: TextEditingController(text: _searchQuery)
                ..selection = TextSelection.fromPosition(
                  TextPosition(offset: _searchQuery.length),
                ),
              decoration: InputDecoration(
                labelText: 'Ürün Ara',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mikrofon butonu
                    if (_speechEnabled)
                      IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : null,
                        ),
                        tooltip: 'Sesli Ara',
                        onPressed:
                            _isListening ? _stopListening : _startListening,
                      ),
                    // Temizle butonu
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                  ],
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Products list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Hata: $_error'),
                            ElevatedButton(
                              onPressed: _loadProducts,
                              child: const Text('Tekrar Dene'),
                            ),
                          ],
                        ),
                      )
                    : filteredProducts.isEmpty
                        ? const Center(child: Text('Ürün bulunamadı'))
                        : ListView.builder(
                            itemCount: filteredProducts.length,
                            padding: const EdgeInsets.all(8),
                            itemBuilder: (context, index) {
                              final product = filteredProducts[index];
                              return _buildProductCard(product);
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: _cart.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _showCart,
              icon: const Icon(Icons.shopping_cart),
              label: Text(numberFormat.format(_cartTotal)),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  Widget _buildProductCard(Product product) {
    final isInCart = _cart.containsKey(product.productCode);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: product.localImagePath != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    'https://b2bapi.urlateknik.com:5000/${product.localImagePath}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image),
                  ),
                )
              : const Icon(Icons.inventory_2),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(product.productCode),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              numberFormat.format(product.salePrice),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            if (isInCart)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_cart[product.productCode]!.quantity.toInt()}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => _addToCart(product),
      ),
    );
  }

  Widget _buildCartSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sepet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Cart items
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final cartItem = _cart.values.elementAt(index);
                        return _buildCartItem(cartItem, setModalState);
                      },
                    ),
                  ),

                  // Total and checkout
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Toplam:',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              numberFormat.format(_cartTotal),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _proceedToPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            child: const Text('Ödemeye Geç'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartItem(CartItem cartItem, StateSetter setModalState) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Product info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    numberFormat.format(cartItem.product.salePrice),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Quantity and Unit controls
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () {
                      setState(() {
                        _updateQuantity(
                          cartItem.product.productCode,
                          cartItem.quantity - 1,
                        );
                      });
                      setModalState(() {});
                    },
                  ),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      controller: TextEditingController(
                          text: cartItem.quantity % 1 == 0
                              ? cartItem.quantity.toInt().toString()
                              : cartItem.quantity.toString())
                        ..selection = TextSelection.fromPosition(TextPosition(
                            offset: (cartItem.quantity % 1 == 0
                                    ? cartItem.quantity.toInt().toString()
                                    : cartItem.quantity.toString())
                                .length)),
                      onChanged: (value) {
                        final newQuantity = double.tryParse(value);
                        if (newQuantity != null) {
                          setState(() {
                            _updateQuantity(
                                cartItem.product.productCode, newQuantity);
                          });
                          setModalState(() {});
                        }
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      setState(() {
                        _updateQuantity(
                          cartItem.product.productCode,
                          cartItem.quantity + 1,
                        );
                      });
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: cartItem.unit,
                    underline: Container(),
                    items: ['adet', 'metre', 'litre', 'kg', 'paket', 'kutu']
                        .map((unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          cartItem.unit = value;
                        });
                        setModalState(() {});
                      }
                    },
                  ),
                ],
              ),
            ),

            // Total and Delete
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    numberFormat.format(cartItem.total),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _removeFromCart(cartItem.product.productCode);
                      });
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Cart Item Model
class CartItem {
  final Product product;
  double quantity;
  String unit;

  CartItem({
    required this.product,
    required this.quantity,
    this.unit = 'adet',
  });

  double get total => product.salePrice * quantity;
}
