// signup_admin_screen.dart
import 'package:flutter/material.dart';

class SignupAdminScreen extends StatefulWidget {
  final String userType;
  const SignupAdminScreen({Key? key, this.userType = 'user'}) : super(key: key);

  @override
  _SignupAdminScreenState createState() => _SignupAdminScreenState();
}

class _SignupAdminScreenState extends State<SignupAdminScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController motcleController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  void handleLogin() async {
    final email = emailController.text.trim();
    final motcle = motcleController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (email.isEmpty || motcle.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erreur'),
          content: const Text('Veuillez remplir tous les champs'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erreur'),
          content: const Text('Les mots de passe ne correspondent pas'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    // Ici, tu peux ajouter la logique pour vérifier l'utilisateur dans la base de données
    // et vérifier le rôle de l'utilisateur, similaire à getUserByEmail et hashPassword
    // Pour l'exemple, nous faisons juste la navigation.

    if (widget.userType == 'admin') {
      Navigator.pushNamed(context, '/adminScreen');
    } else {
      Navigator.pushNamed(context, '/userScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.userType == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text('Connexion ${isAdmin ? "Administrateur" : "Utilisateur"}'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: motcleController,
                decoration: const InputDecoration(
                  labelText: 'Mot clé d\'administrateur',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: handleLogin,
                  child: const Text('Se connecter', style: TextStyle(fontSize: 18)),
                ),
              ),
              if (isAdmin)
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/adminSignup');
                  },
                  child: const Text('Créer un compte administrateur'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
