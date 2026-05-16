import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/utils/json_parse.dart';

final posServiceProvider = Provider<PosService>((ref) => PosService(ref.read(apiClientProvider)));

/// Kassir panelində məhsul kataloqu — sessiyadan asılı olmayaraq yüklənir.
final productsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(posServiceProvider).getProducts();
});

final sessionSetsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.read(posServiceProvider).getSessionSets();
});

class PosService {
  PosService(this._api);
  final ApiClient _api;

  Future<List<dynamic>> getTables() async {
    final res = await _api.get('/tables');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getProducts() async {
    final res = await _api.get('/products');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getProductCategories() async {
    final res = await _api.get('/product-categories');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getActiveSessions() async {
    final res = await _api.get('/sessions/active');
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> openSession(
    int tableId, {
    int? plannedMinutes,
    int? customerId,
    int? tariffId,
    int? setId,
  }) async {
    final res = await _api.post('/sessions', data: {
      'table_id': tableId,
      if (plannedMinutes != null && plannedMinutes > 0) 'planned_minutes': plannedMinutes,
      if (customerId != null) 'customer_id': customerId,
      if (tariffId != null) 'tariff_id': tariffId,
      if (setId != null) 'set_id': setId,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSessionSets() async {
    final res = await _api.get('/session-sets');
    return res['data'] as List<dynamic>;
  }

  Future<int> createSessionSet(Map<String, dynamic> data) async {
    final res = await _api.post('/session-sets', data: data);
    return jsonToInt((res['data'] as Map<String, dynamic>)['id']);
  }

  Future<void> updateSessionSet(int id, Map<String, dynamic> data) async {
    await _api.put('/session-sets/$id', data: data);
  }

  Future<void> deleteSessionSet(int id) async {
    await _api.delete('/session-sets/$id');
  }

  Future<Map<String, dynamic>> openCounterSale({int? customerId}) async {
    final res = await _api.post('/sessions', data: {
      'session_type': 'counter',
      if (customerId != null) 'customer_id': customerId,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setSessionDiscount(
    int sessionId, {
    required String discountType,
    double discountValue = 0,
  }) async {
    final res = await _api.patch('/sessions/$sessionId/discount', data: {
      'discount_type': discountType,
      'discount_value': discountValue,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applyCoupon(int sessionId, String code) async {
    final res = await _api.post('/sessions/$sessionId/apply-coupon', data: {'code': code});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> clearSessionDiscount(int sessionId) async {
    final res = await _api.delete('/sessions/$sessionId/discount');
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> searchCustomers(String query) async {
    final res = await _api.get('/customers', query: query.isEmpty ? null : {'q': query});
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final res = await _api.post('/customers', data: data);
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> updateCustomer(int id, Map<String, dynamic> data) async {
    await _api.put('/customers/$id', data: data);
  }

  Future<void> deleteCustomer(int id) async {
    await _api.delete('/customers/$id');
  }

  Future<List<dynamic>> getCoupons() async {
    final res = await _api.get('/coupons');
    return res['data'] as List<dynamic>;
  }

  Future<void> createCoupon(Map<String, dynamic> data) async {
    await _api.post('/coupons', data: data);
  }

  Future<void> updateCoupon(int id, Map<String, dynamic> data) async {
    await _api.put('/coupons/$id', data: data);
  }

  Future<void> deleteCoupon(int id) async {
    await _api.delete('/coupons/$id');
  }

  Future<Map<String, dynamic>> getSession(int id) async {
    final res = await _api.get('/sessions/$id');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addItem(int sessionId, int productId, int qty) async {
    final res = await _api.post('/sessions/$sessionId/items', data: {
      'product_id': productId,
      'quantity': qty,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateItemQuantity(int sessionId, int itemId, int quantity) async {
    final res = await _api.patch('/sessions/$sessionId/items/$itemId', data: {'quantity': quantity});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeItem(int sessionId, int itemId) async {
    final res = await _api.delete('/sessions/$sessionId/items/$itemId');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> pauseSession(int id) async {
    final res = await _api.patch('/sessions/$id/pause');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resumeSession(int id) async {
    final res = await _api.patch('/sessions/$id/resume');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> previewBill(int id) async {
    final res = await _api.get('/sessions/$id/preview');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeSession(
    int id, {
    required String method,
    double cashAmount = 0,
    double cardAmount = 0,
  }) async {
    final res = await _api.post('/sessions/$id/close', data: {
      'method': method,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
    });
    return res['data'] as Map<String, dynamic>;
  }

  // Admin
  Future<void> createTable(
    String name, {
    required List<Map<String, dynamic>> tariffs,
    int sortOrder = 0,
  }) async {
    await _api.post('/tables', data: {
      'name': name,
      'sort_order': sortOrder,
      'tariffs': tariffs,
    });
  }

  Future<void> updateTable(int id, Map<String, dynamic> data) async {
    await _api.put('/tables/$id', data: data);
  }

  Future<void> deleteTable(int id) async {
    await _api.delete('/tables/$id');
  }

  Future<void> deleteProduct(int id) async {
    await _api.delete('/products/$id');
  }

  Future<int> createProduct(Map<String, dynamic> data) async {
    final res = await _api.post('/products', data: data);
    return jsonToInt((res['data'] as Map<String, dynamic>)['id']);
  }

  Future<void> updateProduct(int id, Map<String, dynamic> data) async {
    await _api.put('/products/$id', data: data);
  }

  Future<String> uploadProductImage(int productId, String filePath) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    final res = await _api.postMultipart('/products/$productId/image', form);
    return (res['data'] as Map<String, dynamic>)['image_url'] as String;
  }

  Future<List<dynamic>> getStockMovements() async {
    final res = await _api.get('/stock/movements');
    return res['data'] as List<dynamic>;
  }

  Future<void> addStockMovement(int productId, String type, int qty, {String? note}) async {
    await _api.post('/stock/movements', data: {
      'product_id': productId,
      'type': type,
      'quantity': qty,
      if (note != null) 'note': note,
    });
  }

  Future<List<dynamic>> getStockAlerts() async {
    final res = await _api.get('/stock/alerts');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getUsers() async {
    final res = await _api.get('/users');
    return res['data'] as List<dynamic>;
  }

  Future<void> createUser(Map<String, dynamic> data) async {
    await _api.post('/users', data: data);
  }

  Future<Map<String, dynamic>> getSettings() async {
    final res = await _api.get('/settings');
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> updateSettings(Map<String, dynamic> data) async {
    await _api.put('/settings', data: data);
  }

  Future<String> uploadBusinessLogo(String filePath) async {
    final form = FormData.fromMap({
      'logo': await MultipartFile.fromFile(filePath),
    });
    final res = await _api.postMultipart('/settings/logo', form);
    return (res['data'] as Map<String, dynamic>)['logo_url'] as String;
  }

  Future<Map<String, dynamic>> getDailyReport(String date) async {
    final res = await _api.get('/reports/daily', query: {'date': date});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDashboard({String? from, String? to}) async {
    final res = await _api.get('/reports/dashboard', query: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> dailyClose(String date) async {
    await _api.post('/reports/daily-close', data: {'date': date});
  }

  Future<List<dynamic>> getAuditLogs() async {
    final res = await _api.get('/audit-logs');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getOrders({
    required String from,
    required String to,
    String? orderState,
  }) async {
    final res = await _api.get('/orders', query: {
      'from': from,
      'to': to,
      if (orderState != null && orderState.isNotEmpty) 'order_state': orderState,
    });
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getOrder(int id) async {
    final res = await _api.get('/orders/$id');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adjustOrder(int id, Map<String, dynamic> data) async {
    final res = await _api.put('/orders/$id/adjust', data: data);
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> refundOrder(int id, Map<String, dynamic> data) async {
    final res = await _api.post('/orders/$id/refund', data: data);
    return res['data'] as Map<String, dynamic>;
  }
}
