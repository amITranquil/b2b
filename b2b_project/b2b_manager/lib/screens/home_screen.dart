// lib/screens/home_screen.dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'B2B Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? 'Açık Tema' : 'Koyu Tema',
            onPressed: onToggleTheme,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    const Color(0xFF1E1E1E),
                    const Color(0xFF121212),
                  ]
                : [
                    Colors.blue[50]!,
                    Colors.white,
                  ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Icon
                  Icon(
                    Icons.business_center,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'HOŞGELDİNİZ',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'B2B Teklif Yönetim Sistemi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 48),

                  // Menu Cards
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Ürünler Kartı
                          Expanded(
                            child: _MenuCard(
                              icon: Icons.inventory_2,
                              title: 'Ürünler',
                              subtitle: 'Ürün Listesi',
                              color: Colors.blue,
                              isDarkMode: isDarkMode,
                              onTap: () {
                                Navigator.pushNamed(context, '/products');
                              },
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Manuel Ürünler Kartı
                          Expanded(
                            child: _MenuCard(
                              icon: Icons.add_box,
                              title: 'Manuel Ürünler',
                              subtitle: 'Eklenmiş Ürünler',
                              color: Colors.orange,
                              isDarkMode: isDarkMode,
                              onTap: () {
                                Navigator.pushNamed(context, '/manual-products');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Teklifler Kartı
                      SizedBox(
                        width: double.infinity,
                        child: _MenuCard(
                          icon: Icons.description,
                          title: 'Teklifler',
                          subtitle: 'Teklif Yönetimi',
                          color: Colors.green,
                          isDarkMode: isDarkMode,
                          onTap: () {
                            Navigator.pushNamed(context, '/quotes');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Footer
                  Text(
                    'URLA TEKNİK © 2026',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Menu Card Widget
class _MenuCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
        child: Card(
          elevation: _isHovered ? 12 : 4,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.color.withValues(alpha: 0.1),
                    widget.color.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 64,
                    color: widget.color,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
