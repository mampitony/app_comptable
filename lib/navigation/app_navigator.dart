import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/home_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/admin_screen.dart';
import '../screens/user_screen.dart';
import '../screens/debug_screen.dart';
import '../screens/acceuil_screen.dart';

class AppNavigator extends StatefulWidget {
  const AppNavigator({super.key});

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  int _selectedIndex = 0; 
  GlobalKey<_ConnexionStackState> _connexionStackKey = GlobalKey<_ConnexionStackState>();
  bool _isInSubScreen = false; 

  Future<bool> _onWillPop() async {
    if (_selectedIndex == 1) {
      final connexionStack = _connexionStackKey.currentState;
      if (connexionStack != null && connexionStack.canPop()) {
        connexionStack.pop();
        return false;
      }
    }
    
    if (_selectedIndex == 0) {
      return await _showExitConfirmation();
    } else {
      setState(() {
        _selectedIndex = 0;
        _isInSubScreen = false;
      });
      return false;
    }
  }

  Future<bool> _showExitConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitter l\'application'),
        content: const Text('Voulez-vous vraiment quitter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Oui')),
        ],
      ),
    ) ?? false;
  }

  void _onSubScreenChanged(bool isInSubScreen) {
    if (_isInSubScreen != isInSubScreen) {
      setState(() {
        _isInSubScreen = isInSubScreen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) SystemNavigator.pop();
      },
      child: Scaffold(
        // 🔥 L'AppBar a été supprimée d'ici pour être mise dans chaque écran
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            AcceuilScreen(
              onNavigateToConnexion: () {
                setState(() {
                  _connexionStackKey = GlobalKey<_ConnexionStackState>();
                  _selectedIndex = 1;
                  _isInSubScreen = false;
                });
              },
            ),
            _ConnexionStack(
              key: _connexionStackKey,
              onNavigationChanged: () => setState(() {}),
              onSubScreenChanged: _onSubScreenChanged,
            ),
          ],
        ),
        bottomNavigationBar: !_isInSubScreen
            ? BottomNavigationBar(
                currentIndex: _selectedIndex,
                selectedItemColor: const Color(0xFF0163D2),
                unselectedItemColor: Colors.grey,
                onTap: (index) {
                  setState(() {
                    if (index == 1 && _selectedIndex != 1) {
                      _connexionStackKey = GlobalKey<_ConnexionStackState>();
                    }
                    _selectedIndex = index;
                    _isInSubScreen = false;
                  });
                },
                items: const [
                  BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
                  BottomNavigationBarItem(icon: Icon(Icons.login), label: 'Connexion'),
                ],
              )
            : null,
      ),
    );
  }
}

class _ConnexionStack extends StatefulWidget {
  final VoidCallback onNavigationChanged;
  final Function(bool) onSubScreenChanged;
  const _ConnexionStack({super.key, required this.onNavigationChanged, required this.onSubScreenChanged});
  @override
  State<_ConnexionStack> createState() => _ConnexionStackState();
}

class _ConnexionStackState extends State<_ConnexionStack> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool canPop() => _navigatorKey.currentState?.canPop() ?? false;
  void pop() => _navigatorKey.currentState?.pop();

  void _checkSubScreen(String route) {
    final isSubScreen = route == '/admin' || route == '/user' || route == '/debug';
    widget.onSubScreenChanged(isSubScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      // 🔥 CORRIGÉ : un seul écran de connexion commun — on ne passe plus
      // par HomeScreen (le sélecteur de portail Admin/Membre/Outils).
      // HomeScreen reste disponible en tant qu'écran (non supprimé),
      // simplement plus utilisée dans ce parcours.
      initialRoute: '/auth',
      onPopPage: (route, result) {
        if (!route.didPop(result)) return false;
        widget.onNavigationChanged();
        return true;
      },
      onGenerateRoute: (settings) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkSubScreen(settings.name ?? ''));
        Widget page;
        switch (settings.name) {
          case '/home': page = HomeScreen(onNavigateToAuth: (type) => _navigatorKey.currentState!.pushNamed('/auth'), onNavigateToDebug: () => _navigatorKey.currentState!.pushNamed('/debug')); break;
          case '/auth': page = AuthScreen(onLoginAsAdmin: (u) => _navigatorKey.currentState!.pushNamed('/admin', arguments: u), onLoginAsUser: (u) => _navigatorKey.currentState!.pushNamed('/user', arguments: u)); break;
          case '/admin':
            final args = settings.arguments as Map<String, dynamic>?;
            page = AdminScreen(
              userRole: args?['role']?.toString() ?? 'admin_principal_membre',
              userData: args,
            );
            break;
          case '/user': page = const UserScreen(); break;
          case '/debug': page = const DebugScreen(); break;
          default: page = const AcceuilScreen();
        }
        return MaterialPageRoute(builder: (_) => page, settings: settings);
      },
    );
  }
}