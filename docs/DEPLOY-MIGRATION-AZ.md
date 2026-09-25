# PS Club — Server deploy və DB migration (Azərbaycan)

Bu təlimat **DirectAdmin / FTP** ilə `psapi.sayt.cam` API serverinə yeniləmə üçündür.

---

## 1. Zip-ləri hazırlamaq (lokal PC)

Layihə kökündə `build-deploy.bat` işlədin. Fayl yoxdursa konfiqurasiyanı özü yaradır; `ServerDbPassword` doldurulmalıdır. Lokal MySQL və Flutter işləməlidir: skript müvəqqəti baza, `install.sql` və production `.env` yaradıb zip-ə qoyur.

```bat
build-deploy.bat
build-deploy.bat backend
```

### Konfiqurasiya (bir dəfə, bat özü də köçürür)

```powershell
copy scripts\deploy-config.example.ps1 scripts\deploy-config.local.ps1
# deploy-config.local.ps1 — DB şifrəsi və MIGRATE_KEY doldurun
```

### Variant A — Tam backend (tövsiyə olunur)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-backend-deploy.ps1
```

**Nəticə:** `dist\psapi-backend.zip`

### Variant B — Backend + veb admin (Flutter web)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-deploy.ps1
```

**Nəticə:**
- `dist\psapi-backend.zip`
- `dist\ps-frontend.zip` → `ps.sayt.cam` public_html

### Variant C — Yalnız kod hotfix (kiçik yeniləmə)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\pack-server-hotfix.ps1
```

**Nəticə:** `dist\server-hotfix.zip` (src + patches, vendor yoxdur)

### Variant D — Windows kassir proqramı

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-windows-installer.ps1
```

**Nəticə:** `dist\PSClubPOS-Setup.exe` (Inno Setup lazımdır)

---

## 2. Serverə faylları yükləmək

### Tam backend zip (`psapi-backend.zip`)

Zip içində `OXU-BUNU.txt` oxuyun. Qısa:

**DirectAdmin — 2 qovluq (tövsiyə):**
| Zip qovluğu | Server yolu |
|-------------|-------------|
| `site-root/` | `domains/psapi.sayt.cam/` (public_html-dən **yuxarı**) |
| `public_html/` | `domains/psapi.sayt.cam/public_html/` |

**Və ya asan:** `public_html_FULL/` içindəkilərin hamısını → `public_html/`

> ⚠️ Köhnə DirectAdmin `index.html` ("Something amazing") **silin**.

**Vacib:**
- Yeni server: zip-dəki `site-root/.env` və `database/install.sql` boş bazaya import üçündür.
- Mövcud server: `.env`-i əvəz etməyin və `install.sql` import etməyin (cədvəlləri silir). Yalnız kodu və `database/patches` yeniləyin.
- `storage/` yazıla bilən olmalıdır (chmod 775).
- PHP **8.2+** seçin.

### Hotfix zip (`server-hotfix.zip`)

Yalnız dəyişən faylları eyni yollara köçürün:
- `backend/public/server-setup.php` → `public_html/`
- `backend/src/...` → `site-root/src/...`
- `backend/database/patches/*.sql` → `site-root/database/patches/`

---

## 3. DB migration — addım-addım

### 3.1 `.env`-ə migration açarı

Serverdə `site-root/.env` faylına **əlavə edin** (öz gizli acarınız):

```env
MIGRATE_KEY=uzun-gizli-acar-buraya
```

Bu acarı heç kimlə paylaşmayın. Hotfix/migrate URL-də istifadə olunacaq.

### 3.2 Status yoxlaması (açar lazım deyil)

Brauzerdə açın:

```
https://psapi.sayt.cam/server-setup.php?action=status
```

**Gözlənilən (yaxşı):**
```json
{
  "ok": true,
  "checks": {
    "billing_columns_ok": true,
    "discounts_schema_ok": true,
    "public_config_query_ok": true,
    "tables_query_ok": true,
    "db_tables_count": 26
  }
}
```

**Əgər `ok: false` və ya `discounts_schema_ok: false`:**
- Patch-lər tətbiq olunmayıb → 3.3-ə keçin.

### 3.3 Migration işlətmək

Brauzerdə (öz `MIGRATE_KEY` ilə):

```
https://psapi.sayt.cam/server-setup.php?action=migrate&key=uzun-gizli-acar-buraya
```

**Uğurlu cavab:**
```json
{
  "ok": true,
  "applied": ["20260601120000_promotions.sql", "20260601130000_customer_groups.sql", ...],
  "skipped": ["artıq tətbiq olunmuş patch-lər"],
  "after": { "discounts_schema_ok": true, ... }
}
```

### 3.4 Yenidən status

```
https://psapi.sayt.cam/server-setup.php?action=status
```

`ok: true` olmalıdır.

### 3.5 Təhlükəsizlik — faylları silin

Migration uğurlu olduqdan sonra **mütləq silin:**
- `public_html/server-setup.php`
- `public_html/run-migrate.php`

### Alternativ: bir dəfəlik açarsız migrate

1. FTP ilə boş fayl yaradın: `site-root/storage/allow-migrate-once`
2. Brauzer: `https://psapi.sayt.cam/server-setup.php?action=migrate&once=1`
3. Fayl avtomatik silinir.

---

## 4. Lokal PC-dən migration (PowerShell)

`deploy-config.local.ps1`-də `$ServerMigrateKey` doldurulubsa:

```powershell
# Status
powershell -File scripts\invoke-server-setup.ps1 -Action status

# Migration
powershell -File scripts\invoke-server-setup.ps1 -Action migrate
```

---

## 5. Yoxlama (deploy sonrası)

| Test | URL / əməliyyat |
|------|-----------------|
| Ping | `https://psapi.sayt.cam/ping.php` → `"status":"ok"` |
| Public config | `https://psapi.sayt.cam/api/public/config` |
| Admin panel | Endirimlər → paketlər və qruplar açılır |
| Kassir app | Giriş → növbə aç → masa aç (endirimli qiymət görünür) |

---

## 6. Hansı patch-lər nə edir?

| Patch | Məzmun |
|-------|--------|
| `20260517120000_billing_timing_rules.sql` | Billing vaxt qaydaları |
| `20260522120000_billing_grace_minutes.sql` | Grace dəqiqələri |
| `20260601120000_promotions.sql` | Endirim paketləri cədvəli |
| `20260601120100_sessions_promotion_columns.sql` | Sessiya + promotion sütunları |
| `20260601130000_customer_groups.sql` | Müştəri qrupları (VIP, tələbə və s.) |

Artıq tətbiq olunmuş patch-lər **təkrar işlədilmir** (skipped).

---

## 7. Tez-tez soruşulanlar

**S: Köhnə `.env` silinirmi?**  
C: Zip-də yeni server üçün `.env` var. Mövcud serverdə köhnə `.env`-in üstünə yazmayın. DB şifrəsi və JWT köhnə qalmalıdır.

**S: phpMyAdmin ilə import?**  
C: Olar, amma `database/patches/` sırası ilə və yalnız **tətbiq olunmamış** faylları. `server-setup.php` avtomatik edir.

**S: Yeni quraşdırma (boş DB)?**  
C: `database/install.sql` import — bütün cədvəllər bir dəfədə.

**S: Prod-da 25 cədvəl, lokalda 26?**  
C: `customer_groups` migrasiyası işləməyib — 3.3 addımını edin.

---

## 8. Fayl xülasəsi

| Skript | Çıxış |
|--------|-------|
| `build-deploy.bat` | `dist/psapi-backend.zip` + `dist/ps-frontend.zip` |
| `build-deploy.bat backend` | yalnız `dist/psapi-backend.zip` |
| `scripts/build-backend-deploy.ps1` | `dist/psapi-backend.zip` |
| `scripts/build-deploy.ps1` | backend + `dist/ps-frontend.zip` |
| `scripts/pack-server-hotfix.ps1` | `dist/server-hotfix.zip` |
| `scripts/build-windows-installer.ps1` | `dist/PSClubPOS-Setup.exe` |
| `scripts/invoke-server-setup.ps1` | Uzaqdan status/migrate |
