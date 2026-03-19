import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/order_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/product/product_detail_screen.dart';
import 'screens/cart/cart_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/admin/admin_products_screen.dart';
import 'screens/admin/admin_product_form_screen.dart';
import 'screens/admin/admin_orders_screen.dart';
import 'screens/admin/admin_order_form_screen.dart';
import 'screens/admin/admin_revenue_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(prefs)),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final router = GoRouter(
      refreshListenable: auth,
      initialLocation: '/',
      redirect: (context, state) {
        final loggedIn = auth.isLoggedIn;
        final path = state.matchedLocation;

        if (loggedIn && (path == '/login' || path == '/register')) return '/';
        if (!loggedIn && path == '/cart') return '/login';
        if (path.startsWith('/admin') && (!loggedIn || !auth.isAdmin)) {
          return loggedIn ? '/' : '/login';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(
            path: '/product/:id',
            builder: (_, state) =>
                ProductDetailScreen(id: int.parse(state.pathParameters['id']!))),
        GoRoute(path: '/cart', builder: (_, __) => const CartScreen()),
        GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
        GoRoute(path: '/admin/products', builder: (_, __) => const AdminProductsScreen()),
        GoRoute(path: '/admin/products/new', builder: (_, __) => const AdminProductFormScreen()),
        GoRoute(
            path: '/admin/products/:id/edit',
            builder: (_, state) => AdminProductFormScreen(
                productId: int.tryParse(state.pathParameters['id'] ?? ''))),
        GoRoute(path: '/admin/orders', builder: (_, __) => const AdminOrdersScreen()),
        GoRoute(path: '/admin/orders/new', builder: (_, __) => const AdminOrderFormScreen()),
        GoRoute(
            path: '/admin/orders/:id/edit',
            builder: (_, state) => AdminOrderFormScreen(
                orderId: int.tryParse(state.pathParameters['id'] ?? ''))),
        GoRoute(path: '/admin/revenue', builder: (_, __) => const AdminRevenueScreen()),
      ],
    );

    return MaterialApp.router(
      title: 'E-Commerce Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF40BFFF),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF40BFFF),
          primary: const Color(0xFF40BFFF),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF40BFFF),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF40BFFF),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      routerConfig: router,
    );
  }
}
