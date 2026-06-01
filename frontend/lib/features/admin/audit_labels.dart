import 'dart:convert';

import 'package:flutter/material.dart';

/// Texniki audit `action` (məs. `post:/api/sessions/5/close`) → istifadəçi dilində izah.
class AuditLabels {
  const AuditLabels._();

  static AuditEntry describe(Map<String, dynamic> log) {
    final action = log['action'] as String? ?? '';
    final parts = action.split(':');
    final method = parts.isNotEmpty ? parts.first.toLowerCase() : '';
    final path = parts.length > 1 ? parts.sublist(1).join(':') : action;

    final normalized = path
        .replaceFirst(RegExp(r'^/api'), '')
        .replaceAll(RegExp(r'/\d+'), '/{id}');

    final title = _titles['$method:$normalized'] ??
        _titles[method] ??
        _fallbackTitle(method, path);

    final category = _categories['$method:$normalized'] ?? _categoryFromPath(normalized);
    final detail = _payloadDetail(method, normalized, log['payload']);

    return AuditEntry(
      title: title,
      category: category,
      detail: detail,
      method: method,
    );
  }

  static const _titles = <String, String>{
    'post:/sessions': 'Yeni sessiya və ya kassa satışı açıldı',
    'post:/sessions/{id}/items': 'Sessiyaya məhsul əlavə edildi',
    'patch:/sessions/{id}/items/{id}': 'Sessiya sifarişində miqdar dəyişdirildi',
    'delete:/sessions/{id}/items/{id}': 'Sessiyadan məhsul silindi',
    'patch:/sessions/{id}/pause': 'Sessiya dayandırıldı (pause)',
    'patch:/sessions/{id}/resume': 'Sessiya davam etdirildi',
    'patch:/sessions/{id}/discount': 'Sessiyaya endirim tətbiq edildi',
    'patch:/sessions/{id}/customer': 'Sessiyaya müştəri təyin edildi',
    'delete:/sessions/{id}/discount': 'Sessiya endirimi ləğv edildi',
    'post:/sessions/{id}/apply-coupon': 'Kupon tətbiq edildi',
    'post:/sessions/{id}/close': 'Hesab bağlandı — ödəniş qəbul edildi',
    'post:/shifts/open': 'Günün növbəsi açıldı (kassa)',
    'post:/shifts/{id}/close': 'Növbə bağlandı (kassa yoxlaması)',
    'post:/shifts/{id}/movements': 'Kassadan pul çıxarıldı və ya əlavə edildi',
    'post:/cash-expenses': 'Xərc və ya kassa əməliyyatı qeydə alındı',
    'post:/products': 'Yeni məhsul əlavə edildi',
    'put:/products/{id}': 'Məhsul redaktə edildi',
    'delete:/products/{id}': 'Məhsul deaktiv edildi (silindi)',
    'post:/products/{id}/image': 'Məhsul şəkli yeniləndi',
    'post:/product-categories': 'Yeni məhsul kateqoriyası yaradıldı',
    'put:/product-categories/{id}': 'Məhsul kateqoriyası redaktə edildi',
    'delete:/product-categories/{id}': 'Məhsul kateqoriyası silindi',
    'post:/customers': 'Yeni müştəri qeydiyyatı',
    'put:/customers/{id}': 'Müştəri məlumatları yeniləndi',
    'delete:/customers/{id}': 'Müştəri silindi',
    'post:/tables': 'Yeni masa/stansiya əlavə edildi',
    'put:/tables/{id}': 'Masa/stansiya redaktə edildi',
    'delete:/tables/{id}': 'Masa/stansiya silindi',
    'post:/users': 'Yeni istifadəçi (işçi) yaradıldı',
    'put:/users/{id}': 'İstifadəçi redaktə edildi',
    'delete:/users/{id}': 'İstifadəçi silindi',
    'put:/settings': 'Müəssisə parametrləri dəyişdirildi',
    'post:/settings/logo': 'Müəssisə logosu yeniləndi',
    'post:/stock/movements': 'Anbar stok əməliyyatı',
    'post:/coupons': 'Yeni kupon yaradıldı',
    'put:/coupons/{id}': 'Kupon redaktə edildi',
    'delete:/coupons/{id}': 'Kupon silindi',
    'get:/promotions': 'Endirim paketləri siyahısı',
    'post:/promotions': 'Yeni endirim paketi',
    'put:/promotions/{id}': 'Endirim paketi redaktə edildi',
    'delete:/promotions/{id}': 'Endirim paketi silindi',
    'get:/customer-groups': 'Müştəri qrupları siyahısı',
    'post:/customer-groups': 'Yeni müştəri qrupu',
    'put:/customer-groups/{id}': 'Müştəri qrupu redaktə edildi',
    'delete:/customer-groups/{id}': 'Müştəri qrupu silindi',
    'post:/session-sets': 'Yeni paket (session set) yaradıldı',
    'put:/session-sets/{id}': 'Paket redaktə edildi',
    'delete:/session-sets/{id}': 'Paket silindi',
    'post:/reports/daily-close': 'Gün bağlandı (günlük hesabat)',
    'put:/orders/{id}/adjust': 'Bağlanmış sifarişdə düzəliş edildi',
    'post:/orders/{id}/refund': 'Sifarişə geri ödəmə (refund)',
  };

  static const _categories = <String, AuditCategory>{
    'post:/sessions': AuditCategory.session,
    'post:/sessions/{id}/close': AuditCategory.payment,
    'post:/shifts/open': AuditCategory.cash,
    'post:/shifts/{id}/close': AuditCategory.cash,
    'post:/shifts/{id}/movements': AuditCategory.cash,
    'post:/cash-expenses': AuditCategory.cash,
    'post:/products': AuditCategory.catalog,
    'put:/products/{id}': AuditCategory.catalog,
    'post:/product-categories': AuditCategory.catalog,
    'put:/settings': AuditCategory.settings,
    'post:/settings/logo': AuditCategory.settings,
    'post:/users': AuditCategory.users,
    'put:/users/{id}': AuditCategory.users,
  };

  static String _fallbackTitle(String method, String path) {
    final verb = switch (method) {
      'post' => 'Yeni qeyd / əlavə',
      'put' || 'patch' => 'Dəyişiklik',
      'delete' => 'Silinmə',
      _ => 'Əməliyyat',
    };
    final short = path.replaceFirst('/api', '').replaceAll(RegExp(r'/\d+'), '/…');
    return '$verb: $short';
  }

  static AuditCategory _categoryFromPath(String path) {
    if (path.contains('/sessions') || path.contains('/orders')) return AuditCategory.session;
    if (path.contains('/shifts') || path.contains('/cash')) return AuditCategory.cash;
    if (path.contains('/products') || path.contains('/stock')) return AuditCategory.catalog;
    if (path.contains('/users')) return AuditCategory.users;
    if (path.contains('/settings')) return AuditCategory.settings;
    if (path.contains('/customers')) return AuditCategory.customers;
    return AuditCategory.other;
  }

  static String? _payloadDetail(String method, String path, dynamic rawPayload) {
    final payload = _parsePayload(rawPayload);
    if (payload == null || payload.isEmpty) return null;

    if (path.contains('/sessions') && path.endsWith('/close')) {
      final m = payload['method']?.toString();
      if (m != null) return 'Ödəniş növü: ${_payLabel(m)}';
      return 'Ödəniş tamamlandı';
    }

    if (path == '/shifts/open') {
      final v = payload['opening_cash'];
      if (v != null) return 'Başlanğıc kassa: $v AZN';
    }

    if (path.contains('/shifts') && path.endsWith('/close')) {
      final v = payload['closing_cash'];
      if (v != null) return 'Sayılan kassa: $v AZN';
    }

    if (path.contains('/movements') || path == '/cash-expenses') {
      final type = payload['type']?.toString();
      final amount = payload['amount'];
      if (type != null && amount != null) {
        return '${_movementType(type)}: $amount AZN';
      }
    }

    if (path == '/products' || path.contains('/products/')) {
      final name = payload['name'];
      if (name != null) return 'Məhsul: $name';
    }

    if (path.contains('/product-categories')) {
      final name = payload['name'];
      if (name != null) return 'Kateqoriya: $name';
    }

    if (path.contains('/customers')) {
      final name = payload['name'];
      final phone = payload['phone'];
      if (name != null) return 'Müştəri: $name${phone != null ? ' ($phone)' : ''}';
    }

    if (path.contains('/users')) {
      final u = payload['username'];
      if (u != null) return 'İstifadəçi: $u';
    }

    if (path == '/settings' && payload['business'] is Map) {
      return 'Müəssisə parametrləri yeniləndi';
    }

    final name = payload['name'];
    if (name != null) return name.toString();

    return null;
  }

  static Map<String, dynamic>? _parsePayload(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static String _payLabel(String method) {
    return switch (method) {
      'cash' => 'Nağd',
      'card' => 'Kart',
      'mixed' => 'Qarışıq (nağd + kart)',
      _ => method,
    };
  }

  static String _movementType(String type) {
    return switch (type) {
      'expense' => 'Xərc',
      'owner_withdrawal' => 'Sahibkarə verilmə',
      'pay_in' => 'Kassaya əlavə',
      _ => type,
    };
  }
}

class AuditEntry {
  const AuditEntry({
    required this.title,
    required this.category,
    this.detail,
    this.method = '',
  });

  final String title;
  final AuditCategory category;
  final String? detail;
  final String method;
}

enum AuditCategory { session, payment, cash, catalog, customers, users, settings, other }

extension AuditCategoryX on AuditCategory {
  IconData get icon => switch (this) {
        AuditCategory.session => Icons.sports_esports_outlined,
        AuditCategory.payment => Icons.payments_outlined,
        AuditCategory.cash => Icons.point_of_sale_outlined,
        AuditCategory.catalog => Icons.inventory_2_outlined,
        AuditCategory.customers => Icons.person_outline,
        AuditCategory.users => Icons.badge_outlined,
        AuditCategory.settings => Icons.tune_outlined,
        AuditCategory.other => Icons.history,
      };

  String get label => switch (this) {
        AuditCategory.session => 'Sessiya',
        AuditCategory.payment => 'Ödəniş',
        AuditCategory.cash => 'Kassa',
        AuditCategory.catalog => 'Kataloq',
        AuditCategory.customers => 'Müştəri',
        AuditCategory.users => 'İşçi',
        AuditCategory.settings => 'Parametr',
        AuditCategory.other => 'Digər',
      };
}
