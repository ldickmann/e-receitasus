import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Callbacks
  void _handleLogin(BuildContext context) {
    // A Lógica de autenticação e navegação será implementada com Provider
    print('Ação de Login/Autenticação solicitada');
  }

  void _handleRegister(BuildContext context) {
    // A Lógica de registro e navegação será implementada
    print('Ação de Registro solicitada');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App E-ReceitaSUS'),
        // backgroundColor: Colors.blueAccent,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Título (Aplica UX/Usabilidade Inclusiva)
              Text(
                'Acesso do Paciente / Administrador',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary),
              ),

              const SizedBox(height: 25),

              // Campo de Email
              const TextField(
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail SUS',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),

              // Campo de Senha
              const TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 25),

              // Botão de Login
              ElevatedButton(
                onPressed: () => _handleLogin(context), // Callback
                // style: ElevatedButton.styleFrom(
                //  backgroundColor: Colors.blue,
                //  padding: const EdgeInsets.symmetric(vertical: 15),
                // ),
                child: const Text(
                  'Entrar',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 10),

              // Botão de Cadastro
              TextButton(
                onPressed: () => _handleRegister(context), // Callback
                child: const Text('Não tem conta? Cadastre-se'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
