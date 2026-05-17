# PS Club POS

PlayStation klubu üçün hibrid POS: saatlıq icarə + məhsul satışı.

## Struktur

- `backend/` — Slim 4 REST API + MariaDB
- `frontend/` — Flutter (admin + kassir)

## Laragon quraşdırması

1. MariaDB-də verilənlər bazası yaradın:
   ```sql
   CREATE DATABASE psclub CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   ```

2. Backend:
   ```bash
   cd backend
   copy .env.example .env
   composer install
   vendor\bin\phinx migrate
   vendor\bin\phinx seed:run -s DatabaseSeeder
   ```

3. Virtual host: `psclub.test` → `backend/public`

4. Demo hesablar:
   - Admin: `admin` / `admin`
   - Kassir: `kassir` / `kassir`

5. Flutter (Windows):
   ```powershell
   # Uzaq server (psapi.sayt.cam) — tövsiyə
   powershell -File .\scripts\run-windows.ps1

   # Lokal backend (Laragon)
   powershell -File .\scripts\run-windows-local.ps1

   # Əl ilə:
   cd frontend
   flutter pub get
   flutter run -d windows --dart-define-from-file=dart_defines.remote.json
   ```

   **Qeyd:** Windows ikonu dəyişdikdən sonra tam rebuild lazımdır (`flutter run` dayandırıb yenidən başladın).

API əsas URL (Flutter): `http://psclub.test/api` və ya `http://127.0.0.1/psclub/backend/public/api`

## DirectAdmin deploy (zip)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-deploy.ps1
```

Çıxış: `dist/psapi-backend.zip` və `dist/ps-frontend.zip` — `OXU-BUNU.txt` içində upload addımları.
Skriptdə server DB və domainlər dəyişdirilə bilər (`scripts/build-deploy.ps1` başı).

## API modulları

- `POST /api/auth/login`
- `GET /api/tables`, `GET /api/sessions/active`
- `POST /api/sessions`, `POST /api/sessions/{id}/close`
- Admin: `/api/users`, `/api/products`, `/api/stock`, `/api/reports`, `/api/audit-logs`
