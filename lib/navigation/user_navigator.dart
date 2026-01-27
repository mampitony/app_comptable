import 'package:flutter/material.dart';
import '../screens/revenu_screen.dart';
import '../screens/depense_screen.dart';
import '../screens/historique_screen.dart';

class UserDrawerNavigator extends StatelessWidget {
  final String userRole;
  final String userName;
  final String? profileImage;

  const UserDrawerNavigator({
    super.key,
    required this.userRole,
    required this.userName,
    this.profileImage,
  });

  @override
  Widget build(BuildContext context) {
    return _UserBottomNav(
      userRole: userRole,
      userName: userName,
      profileImage: profileImage,
    );
  }
}

class _UserBottomNav extends StatefulWidget {
  final String userRole;
  final String userName;
  final String? profileImage;

  const _UserBottomNav({
    super.key,
    required this.userRole,
    required this.userName,
    this.profileImage,
  });

  @override
  State<_UserBottomNav> createState() => _UserBottomNavState();
}

class _UserBottomNavState extends State<_UserBottomNav> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // 🔹 On définit ici les rôles autorisés à modifier
    final bool canEdit = widget.userRole == 'Tresorier' ||
        widget.userRole == 'Commissaire au compte';

    final List<Widget> screens = [
      RevenuScreen(
        canEdit: canEdit,
        userName: widget.userName,
        userRole: widget.userRole,
        profileImage: widget.profileImage,
      ),
      DepenseScreen(
        canEdit: canEdit,
        userName: widget.userName,
        userRole: widget.userRole,
        profileImage: widget.profileImage,
      ),
      const HistoriqueScreen(), // lecture seule
    ];

    final List<String> titles = [
      'Revenu',
      'Dépenses',
      'Historique',
    ];

    void onItemTapped(int index) {
      if (index == 3) {
        // 3 = Déconnexion
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      setState(() {
        _selectedIndex = index;
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        backgroundColor: const Color(0xFF0163D2),
        centerTitle: true,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF0163D2),
        unselectedItemColor: Colors.grey,
        onTap: onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Revenu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.money_off),
            label: 'Dépenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historique',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.logout),
            label: 'Déconnexion',
          ),
        ],
      ),
    );
  }
}