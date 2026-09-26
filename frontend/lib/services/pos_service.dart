import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/api_client.dart';
import '../core/utils/json_parse.dart';
import '../core/utils/session_datetime.dart';

final posServiceProvider = Provider<PosService>((ref) => PosService(ref.read(apiClientProvider)));

/// Kassir panelində məhsul kataloqu — sessiyadan asılı olmayaraq yüklənir.
final productsProvider = FutureProvider<List<dynamic>>((ref) async {
  return ref.read(posServiceProvider).getProducts();
});

final sessionSetsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.read(posServiceProvider).getSessionSets();
});

/// Kassir — masa açarkən göstəriləcək aktiv endirim paketləri.
final activePromotionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final raw = await ref.read(posServiceProvider).getActivePromotions();
  return raw.cast<Map<String, dynamic>>();
});

class PosService {
  PosService(this._api);
  final ApiClient _api;

  Future<List<dynamic>> getTables() async {
    final res = await _api.get('/tables');
    final data = res['data'];
    if (data is Map<String, dynamic>) {
      SessionClock.sync(data['server_now'] as String?);
      final tables = data['tables'];
      if (tables is List<dynamic>) return tables;
    }
    if (data is List<dynamic>) return data;
    return [];
  }

  Future<List<dynamic>> getProducts() async {
    final res = await _api.get('/products');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getProductCategories() async {
    final res = await _api.get('/product-categories');
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createProductCategory(String name, {int sortOrder = 0}) async {
    final res = await _api.post('/product-categories', data: {
      'name': name,
      'sort_order': sortOrder,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProductCategory(int id, Map<String, dynamic> data) async {
    final res = await _api.put('/product-categories/$id', data: data);
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> deleteProductCategory(int id) async {
    await _api.delete('/product-categories/$id');
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
    String discountAppliesTo = 'time_only',
  }) async {
    final res = await _api.patch('/sessions/$sessionId/discount', data: {
      'discount_type': discountType,
      'discount_value': discountValue,
      'discount_applies_to': discountAppliesTo,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assignSessionCustomer(int sessionId, {int? customerId}) async {
    final res = await _api.patch('/sessions/$sessionId/customer', data: {
      'customer_id': customerId,
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

  Future<List<dynamic>> searchCustomers(
    String query, {
    String filter = 'all',
  }) async {
    final queryParams = <String, String>{};
    if (query.isNotEmpty) queryParams['q'] = query;
    if (filter != 'all') queryParams['filter'] = filter;
    final res = await _api.get('/customers', query: queryParams.isEmpty ? null : queryParams);
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final res = await _api.post('/customers', data: data);
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomerProfile(int id) async {
    final res = await _api.get('/customers/$id');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> grantCustomerLoyalty(
    int id, {
    required String kind,
    required double value,
    String? note,
  }) async {
    final res = await _api.post('/customers/$id/loyalty/grant', data: {
      'kind': kind,
      'value': value,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> adjustCustomerLoyalty(
    int id, {
    required String kind,
    required double delta,
    required String note,
  }) async {
    final res = await _api.post('/customers/$id/loyalty/adjust', data: {
      'kind': kind,
      'delta': delta,
      'note': note,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getGroupMembers(int groupId) async {
    final res = await _api.get('/customer-groups/$groupId/members');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> changeGroupMembers(
    int groupId, {
    List<int> add = const [],
    List<int> remove = const [],
  }) async {
    final res = await _api.post('/customer-groups/$groupId/members', data: {
      'add': add,
      'remove': remove,
    });
    final data = res['data'] as Map<String, dynamic>;
    return data['members'] as List<dynamic>? ?? [];
  }

  Future<List<dynamic>> getSpendDiscountRules() async {
    final res = await _api.get('/spend-discount-rules');
    return res['data'] as List<dynamic>;
  }

  Future<void> createSpendDiscountRule(Map<String, dynamic> data) async {
    await _api.post('/spend-discount-rules', data: data);
  }

  Future<void> updateSpendDiscountRule(int id, Map<String, dynamic> data) async {
    await _api.put('/spend-discount-rules/$id', data: data);
  }

  Future<void> deleteSpendDiscountRule(int id) async {
    await _api.delete('/spend-discount-rules/$id');
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

  Future<List<dynamic>> getPromotions() async {
    final res = await _api.get('/promotions');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getActivePromotions() async {
    final res = await _api.get('/promotions/active');
    return res['data'] as List<dynamic>;
  }

  Future<void> createPromotion(Map<String, dynamic> data) async {
    await _api.post('/promotions', data: data);
  }

  Future<void> updatePromotion(int id, Map<String, dynamic> data) async {
    await _api.put('/promotions/$id', data: data);
  }

  Future<void> deletePromotion(int id) async {
    await _api.delete('/promotions/$id');
  }

  Future<List<dynamic>> getCustomerGroups() async {
    final res = await _api.get('/customer-groups');
    return res['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getActiveCustomerGroups() async {
    final res = await _api.get('/customer-groups/active');
    return res['data'] as List<dynamic>;
  }

  Future<void> createCustomerGroup(Map<String, dynamic> data) async {
    await _api.post('/customer-groups', data: data);
  }

  Future<void> updateCustomerGroup(int id, Map<String, dynamic> data) async {
    await _api.put('/customer-groups/$id', data: data);
  }

  Future<void> deleteCustomerGroup(int id) async {
    await _api.delete('/customer-groups/$id');
  }

  Future<Map<String, dynamic>> getSession(int id) async {
    final res = await _api.get('/sessions/$id');
    return _unwrapSessionPayload(res['data']);
  }

  /// API bəzən `{ server_now, session }`, bəzən birbaşa sessiya qaytarır.
  Map<String, dynamic> _unwrapSessionPayload(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw StateError('Invalid session response');
    }
    if (data['session'] is Map<String, dynamic>) {
      SessionClock.sync(data['server_now'] as String?);
      return data['session'] as Map<String, dynamic>;
    }
    return data;
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

  Future<Map<String, dynamic>> extendSession(int id, {int? addMinutes}) async {
    final res = await _api.patch('/sessions/$id/extend', data: {
      if (addMinutes != null) 'add_minutes': addMinutes,
    });
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
    double redeemBonusWallet = 0,
    int redeemBonusMinutes = 0,
    String? giftNote,
  }) async {
    final res = await _api.post('/sessions/$id/close', data: {
      'method': method,
      'cash_amount': cashAmount,
      'card_amount': cardAmount,
      if (redeemBonusWallet > 0) 'redeem_bonus_wallet': redeemBonusWallet,
      if (redeemBonusMinutes > 0) 'redeem_bonus_minutes': redeemBonusMinutes,
      if (giftNote != null && giftNote.trim().isNotEmpty) 'gift_note': giftNote.trim(),
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

  Future<String> uploadProductImageMultipart(int productId, MultipartFile file) async {
    final form = FormData.fromMap({'image': file});
    final res = await _api.postMultipart('/products/$productId/image', form);
    return (res['data'] as Map<String, dynamic>)['image_url'] as String;
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

  Future<void> updateUser(int id, Map<String, dynamic> data) async {
    await _api.put('/users/$id', data: data);
  }

  Future<void> deleteUser(int id) async {
    await _api.delete('/users/$id');
  }

  /// Giriş ekranı — JWT lazım deyil.
  Future<Map<String, dynamic>> getPublicConfig() async {
    final res = await _api.get('/public/config');
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSettings() async {
    final res = await _api.get('/settings');
    return res['data'] as Map<String, dynamic>;
  }

  Future<void> updateSettings(Map<String, dynamic> data) async {
    await _api.put('/settings', data: data);
  }

  Future<String> uploadBusinessLogoMultipart(MultipartFile logoFile) async {
    final form = FormData.fromMap({'logo': logoFile});
    final res = await _api.postMultipart('/settings/logo', form);
    return (res['data'] as Map<String, dynamic>)['logo_url'] as String;
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

  Future<Map<String, dynamic>> deleteOrder(int id, Map<String, dynamic> data) async {
    final res = await _api.delete('/orders/$id', data: data);
    return res['data'] as Map<String, dynamic>;
  }

  // Növbə / kassa
  Future<Map<String, dynamic>?> getCurrentShift() async {
    final res = await _api.get('/shifts/current');
    final data = res['data'];
    if (data is! Map<String, dynamic>) return null;
    if (data['open'] == false) return null;
    if (data.containsKey('id')) return data;
    return null;
  }

  Future<Map<String, dynamic>> openShift(double openingCash) async {
    final res = await _api.post('/shifts/open', data: {'opening_cash': openingCash});
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeShift(int id, {required double closingCash, String? notes}) async {
    final res = await _api.post('/shifts/$id/close', data: {
      'closing_cash': closingCash,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addShiftMovement(
    int shiftId, {
    required String type,
    required double amount,
    String? category,
    String? description,
  }) async {
    final res = await _api.post('/shifts/$shiftId/movements', data: {
      'type': type,
      'amount': amount,
      if (category != null) 'category': category,
      if (description != null && description.isNotEmpty) 'description': description,
    });
    return res['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getShiftCategories() async {
    final res = await _api.get('/shifts/categories');
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getShifts({String? from, String? to, String? status}) async {
    final res = await _api.get('/shifts', query: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      if (status != null) 'status': status,
    });
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getShift(int id) async {
    final res = await _api.get('/shifts/$id');
    return res['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCashMovements({String? from, String? to}) async {
    final res = await _api.get('/cash-movements', query: {
      if (from != null) 'from': from,
      if (to != null) 'to': to,
    });
    return res['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> addAdminExpense({
    required String type,
    required double amount,
    String? category,
    String? description,
    int? shiftId,
  }) async {
    final res = await _api.post('/cash-expenses', data: {
      'type': type,
      'amount': amount,
      if (category != null) 'category': category,
      if (description != null && description.isNotEmpty) 'description': description,
      if (shiftId != null) 'shift_id': shiftId,
    });
    return res['data'] as Map<String, dynamic>;
  }
}
