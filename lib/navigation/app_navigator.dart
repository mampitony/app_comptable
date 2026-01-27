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
  int _selectedIndex = 0; // 0 = Accueil, 1 = Connexion
  GlobalKey<_ConnexionStackState> _connexionStackKey = GlobalKey<_ConnexionStackState>();
  bool _isInSubScreen = false; // ✅ NOUVEAU : Track si on est dans Admin/User/Debug

  // Gérer le bouton retour Android
  Future<bool> _onWillPop() async {
    if (_selectedIndex == 1) {
      final connexionStack = _connexionStackKey.currentState;
      if (connexionStack != null && connexionStack.canPop()) {
        connexionStack.pop();
        return false;
      }
    }
    
    if (_selectedIndex == 0) {
      final shouldExit = await _showExitConfirmation();
      return shouldExit;
    } else {
      setState(() {
        _selectedIndex = 0;
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oui'),
          ),
        ],
      ),
    ) ?? false;
  }

  // ✅ NOUVEAU : Callback pour savoir quand on entre/sort des sub-screens
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
        if (shouldPop && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        // ✅ AppBar visible UNIQUEMENT si pas dans sub-screen
        appBar: !_isInSubScreen
            ? AppBar(
                backgroundColor: const Color(0xFF0163D2),
                centerTitle: true,
                title: Text(
                  _selectedIndex == 0 ? 'Accueil' : 'Connexion',
                  style: const TextStyle(color: Colors.white),
                ),
                leading: _selectedIndex == 1
                    ? IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          final connexionStack = _connexionStackKey.currentState;
                          if (connexionStack != null && connexionStack.canPop()) {
                            connexionStack.pop();
                            setState(() {});
                          } else {
                            setState(() {
                              _selectedIndex = 0;
                            });
                          }
                        },
                      )
                    : null,
              )
            : null,
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
              onNavigationChanged: () {
                setState(() {});
              },
              onSubScreenChanged: _onSubScreenChanged, // ✅ NOUVEAU
            ),
          ],
        ),
        // ✅ BottomNavigationBar visible UNIQUEMENT si pas dans sub-screen
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
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home),
                    label: 'Accueil',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.login),
                    label: 'Connexion',
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

/// -----------------------------------------------------------------------------
/// STACK INTERNE : Home → Auth → Admin/User/Debug
/// -----------------------------------------------------------------------------
class _ConnexionStack extends StatefulWidget {
  final VoidCallback onNavigationChanged;
  final Function(bool) onSubScreenChanged; // ✅ NOUVEAU

  const _ConnexionStack({
    super.key,
    required this.onNavigationChanged,
    required this.onSubScreenChanged,
  });

  @override
  State<_ConnexionStack> createState() => _ConnexionStackState();
}

class _ConnexionStackState extends State<_ConnexionStack> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String _currentRoute = '/home'; // ✅ NOUVEAU : Track la route actuelle

  bool canPop() {
    final navigatorState = _navigatorKey.currentState;
    return navigatorState != null && navigatorState.canPop();
  }

  void pop() {
    final navigatorState = _navigatorKey.currentState;
    if (navigatorState != null && navigatorState.canPop()) {
      navigatorState.pop();
    }
  }

  // ✅ NOUVEAU : Vérifier si on est dans un sub-screen
  void _checkSubScreen(String route) {
    final isSubScreen = route == '/admin' || route == '/user' || route == '/debug';
    widget.onSubScreenChanged(isSubScreen);
    _currentRoute = route;
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      initialRoute: '/home',
      onPopPage: (route, result) {
        if (!route.didPop(result)) {
          return false;
        }
        widget.onNavigationChanged();
        // ✅ Vérifier la route après le pop
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentRoute = _navigatorKey.currentState?.widget.pages.last.name ?? '/home';
          _checkSubScreen(currentRoute);
        });
        return true;
      },
      onGenerateRoute: (RouteSettings settings) {
        // ✅ Notifier du changement de route
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkSubScreen(settings.name ?? '/home');
        });

        Widget page;

        switch (settings.name) {
          case '/home':
            page = HomeScreen(
              onNavigateToAuth: (String userType) {
                _navigatorKey.currentState!.pushNamed(
                  '/auth',
                  arguments: {'userType': userType},
                ).then((_) {
                  widget.onNavigationChanged();
                });
              },
              onNavigateToDebug: () {
                _navigatorKey.currentState!.pushNamed('/debug').then((_) {
                  widget.onNavigationChanged();
                });
              },
            );
            break;

          case '/auth':
            final args = settings.arguments as Map<String, dynamic>? ?? {};
            final userType = args['userType'] as String? ?? 'user';

            page = _AuthScreenWrapper(
              userType: userType,
              onLoginAsAdmin: (user) {
                _navigatorKey.currentState!.pushNamed(
                  '/admin',
                  arguments: user,
                ).then((_) {
                  widget.onNavigationChanged();
                });
              },
              onLoginAsUser: (user) {
                _navigatorKey.currentState!.pushNamed(
                  '/user',
                  arguments: user,
                ).then((_) {
                  widget.onNavigationChanged();
                });
              },
            );
            break;

          case '/admin':
            page = const AdminScreen();
            break;

          case '/user':
            page = const UserScreen();
            break;

          case '/debug':
            page = const DebugScreen();
            break;

          default:
            page = const AcceuilScreen();
        }

        return MaterialPageRoute(
          builder: (_) => page,
          settings: settings,
        );
      },
    );
  }
}

/// -----------------------------------------------------------------------------
/// Wrapper pour AuthScreen qui force la recréation à chaque affichage
/// -----------------------------------------------------------------------------
class _AuthScreenWrapper extends StatefulWidget {
  final String userType;
  final Function(dynamic) onLoginAsAdmin;
  final Function(dynamic) onLoginAsUser;

  const _AuthScreenWrapper({
    required this.userType,
    required this.onLoginAsAdmin,
    required this.onLoginAsUser,
  });

  @override
  State<_AuthScreenWrapper> createState() => _AuthScreenWrapperState();
}

class _AuthScreenWrapperState extends State<_AuthScreenWrapper> {
  late Key _authKey;

  @override
  void initState() {
    super.initState();
    _authKey = UniqueKey();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreen(
      key: _authKey,
      userType: widget.userType,
      onLoginAsAdmin: widget.onLoginAsAdmin,
      onLoginAsUser: widget.onLoginAsUser,
    );
  }
}