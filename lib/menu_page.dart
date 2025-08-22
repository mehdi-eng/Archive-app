
import 'package:archive_app_new/insert_page.dart';
import 'package:archive_app_new/search_page.dart';
import 'package:flutter/material.dart';





class MenuPage extends StatelessWidget {
  const MenuPage({super.key, required this.categoryTitle, required this.logoUrl});
  final String categoryTitle;
  final String logoUrl; // New field for logo

  @override
  Widget build(BuildContext context) {
    // Colors
    const color1 = Color(0xFF7C4585);
    const color2 = Color(0xFF9B7EBD);
    const color3 = Color(0xFFF49BAB);
    const color4 = Color(0xFFFFE1E0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Menu — $categoryTitle'),
        backgroundColor: color1,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(
    color: Colors.white, // ← makes back arrow white
  ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [color4, color3, color2, color1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Logo at the top
            if (logoUrl.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 24),
                child: Image.network(
                  logoUrl,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 80,),
            // Buttons below
            MenuButton(
              text: 'Recherche',
              icon: Icons.search,
              gradientColors: [color3, color2],
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SearchPage(categoryTitle: categoryTitle),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            MenuButton(
              text: 'Ajouter',
              icon: Icons.add,
              gradientColors: [color2, color1],
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => InsertPage(categoryTitle: categoryTitle),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// MenuButton remains the same
class MenuButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onPressed;

  const MenuButton({
    super.key,
    required this.text,
    required this.icon,
    required this.gradientColors,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


