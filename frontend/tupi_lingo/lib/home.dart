// 1. Importação obrigatória: Traz todas as ferramentas visuais do Flutter.
import 'package:flutter/material.dart';

// 2. O ponto de entrada da aplicação. É o que faz o app ligar!
void main() {
  runApp(const MyApp()); // Chama o nosso widget raiz
}

// ================================================
// A) WIDGET RAIZ: MATERIAL APP (Configurações globais do App)
// Usamos StatelessWidget porque ele não precisa mudar de estado, só configurar a aparência.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 🍎 MaterialApp é o widget que dá ao Flutter todo o "estilo" do Google/Material Design.
      title: 'TupiLingo App', // Título que aparece no gerenciador de tarefas
      theme: ThemeData(
        // Permite definir cores padrão para todos os widgets (ex: Cor primária)
        primarySwatch: Colors.amber,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // A propriedade 'home' define qual tela será carregada quando o app abrir.
      home: const HomeScreen(),
    );
  }
}

// ================================================
// B) O WIDGET DA TELA (A "Página"):
// Este é um StatelessWidget porque ele não gerencia estado interno (sem cálculos ou interações complexas).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // O Scaffold é o esqueleto da sua página. Ele fornece a estrutura básica (App Bar, Body, etc.).
      appBar: AppBar(
        title: const Text(
          'Bem-vindo a tela de Home!',
        ), // Conteúdo do cabeçalho fixo
        backgroundColor: Colors.amber,
      ),

      // O corpo da página onde o conteúdo principal vai.
      body: const Center(
        // Centraliza tudo no meio da tela
        child: Column(
          // Permite que os widgets fiquem empilhados verticalmente (verticalmente é padrão)
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Widget de Exemplo 1: Um texto simples
            Text(
              'Olá! Bem-vindo ao seu novo app.',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 30), // Espaço vazio entre widgets
            // Widget de Exemplo 2: Um botão que pode ser clicado
            ElevatedButton(
              onPressed: null, // Passamos 'null' porque ainda não há lógica.
              child: Text('Começar'),
            ),
          ],
        ),
      ),

      // Opcional: Adiciona um botão flutuante de ação rápida (FAB)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Coloque aqui a lógica para a ação secundária, como iniciar o login.
        },
        child: const Icon(Icons.add),
      ),
    ); // Fechando o Scaffold
  }
}
