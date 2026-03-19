import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database.dart';
import '../auth_middleware.dart';

void registerStatsRoutes(Router router) {
  router.get('/api/stats/revenue', (Request request) async {
    final authError = requireAdmin(request);
    if (authError != null) return authError;

    try {
      final period = request.url.queryParameters['period'] ?? 'day';

      String groupExpr;
      if (period == 'month') {
        groupExpr = "strftime('%Y-%m', created_at)";
      } else if (period == 'year') {
        groupExpr = "strftime('%Y', created_at)";
      } else {
        groupExpr = "DATE(created_at)";
      }

      final rows = queryAll('''
        SELECT $groupExpr AS period,
               SUM(total) AS revenue,
               COUNT(*) AS order_count
        FROM orders
        WHERE status = 'da_hoan_thanh'
        GROUP BY $groupExpr
        ORDER BY period DESC
      ''');

      final summary = queryOne('''
        SELECT COALESCE(SUM(total), 0) AS total_revenue,
               COUNT(*) AS total_orders
        FROM orders
        WHERE status = 'da_hoan_thanh'
      ''')!;

      return jsonResponse({
        'period': period,
        'summary': {
          'total_revenue': summary['total_revenue'],
          'total_orders': summary['total_orders'],
        },
        'data': rows,
      });
    } catch (e) {
      return jsonResponse({'error': e.toString()}, statusCode: 500);
    }
  });
}
