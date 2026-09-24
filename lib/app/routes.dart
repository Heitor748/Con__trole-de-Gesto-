import 'package:flutter/material.dart';

import '../screens/home_screen.dart';
import '../screens/camera_screen.dart';
import '../screens/ocr_review_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/fechamento_screen.dart';
import '../screens/busca_screen.dart';
import '../screens/nota_detalhe_screen.dart';

/// Defines all named routes for the application.
class AppRoutes {
  AppRoutes._();

  static const String home = '/';
  static const String camera = '/camera';
  static const String ocrReview = '/ocr-review';
  static const String dashboard = '/dashboard';
  static const String fechamento = '/fechamento';
  static const String busca = '/busca';
  static const String notaDetalhe = '/nota-detalhe';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return _buildRoute(const HomeScreen(), settings);

      case camera:
        return _buildRoute(const CameraScreen(), settings);

      case ocrReview:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(OcrReviewScreen(arguments: args), settings);

      case dashboard:
        return _buildRoute(const DashboardScreen(), settings);

      case fechamento:
        return _buildRoute(const FechamentoScreen(), settings);

      case busca:
        return _buildRoute(const BuscaScreen(), settings);

      case notaDetalhe:
        final args = settings.arguments as Map<String, dynamic>?;
        return _buildRoute(NotaDetalheScreen(arguments: args), settings);

      default:
        return _buildRoute(
          Scaffold(
            appBar: AppBar(title: const Text('Página não encontrada')),
            body: Center(
              child: Text(
                'Rota "${settings.name}" não encontrada.',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          settings,
        );
    }
  }

  static MaterialPageRoute<dynamic> _buildRoute(
    Widget page,
    RouteSettings settings,
  ) {
    return MaterialPageRoute<dynamic>(
      builder: (_) => page,
      settings: settings,
    );
  }
}
