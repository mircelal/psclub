# QA hesabatı — PS Club POS

**Tarix:** 2026-05-24  
**Mühit:** Windows, yerli API `http://127.0.0.1:8080`, DB `psclub_qa` (təmiz seed)  
**Skript:** `scripts/run-qa-suite.ps1`

## Nəticə: PASS

| Kateqoriya | Nəticə |
|------------|--------|
| PHP BillingCalculator | PASS |
| PHP RefundCalculator | PASS |
| Flutter billing unit | PASS |
| Flutter login widget | PASS |
| API smoke (30 yoxlama) | PASS |

## Tapılan və düzəldilən xətalar

1. **ReportsController PHP sintaksis** — SQL string birləşməsində səhv dırnaqlar; `dashboard` endpoint 500 verirdi. Düzəldildi: `NOT_REFUNDED` sabiti və düzgün string bağlanması.
2. **Widget test** — köhnə `PS Club POS` mətni; login ekranı `Daxil ol` ilə yeniləndi.
3. **Stok `type` enum** — əvvəlki sessiyada `return` tipi (silmə 400); `StockController` map edir.
4. **QA DB seçimi** — API `.env` ilə `psclub_deploy_test` qalırdı; `backend/.qa-db` faylı ilə QA rejimi əlavə olundu.

## API smoke əhatəsi

- Auth (admin, kassir), növbə aç/bağla
- Masa sessiyası: aç → məhsul → preview → nağd bağla
- Kassa satışı
- Sifariş silmə (stok bərpa, növbə kassası, jurnal `order_deleted`)
- Qaytarma
- Növbə xərci
- Kassir `DELETE /orders` → 403
- Admin: tables, products, users, shifts, orders, dashboard
- Növbə olmadan sessiya bloklanması

## Manual UI yoxlaması (Windows)

Avtomatlaşdırılmayıb; işə buraxmadan əvvəl kassir/admin UI-də bir dəfə yoxlayın:

### Kassir
- [ ] Giriş `kassir/kassir`, növbə açılış dialoqu
- [ ] Masa pause/resume, plan uzatma, endirim/kupon
- [ ] Nağd/kart/qarışıq ödəniş dialoqu
- [ ] Kassa birbaşa satış
- [ ] Növbə rail ~3s yenilənməsi
- [ ] Kassaya daxil / xərc / sahib çıxarışı

### Admin
- [ ] Sifarişlər: düzəliş, qaytarma, silmə UI
- [ ] Növbə jurnalı: rəngli ikonlar (satış, silmə, xərc)
- [ ] Parametrlər: billing_mode, grace
- [ ] CRUD: masa, məhsul, istifadəçi

## İşə buraxılış

1. Prod DB-də bütün migration-lar (`phinx migrate` və ya patch faylları).
2. `billing_mode = min_1h_then_30` (lazımdırsa).
3. `backend/.qa-db` faylının **olmaması** (yalnız QA üçündür).
4. `scripts/run-qa-suite.ps1` PASS.

## Əmrlər

```powershell
# Tam QA
powershell -File scripts/run-qa-suite.ps1

# Yalnız təmiz DB
php backend/scripts/setup_qa_database.php

# API QA DB ilə (run-qa-suite .qa-db yaradır; əl ilə: echo psclub_qa > backend/.qa-db)
powershell -File scripts/run-api-qa.ps1
```
