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

5. Flutter:
   ```bash
   cd frontend
   flutter pub get
   dart run flutter_launcher_icons   # tətbiq ikonu (assets/icons/)
   flutter run -d windows
   ```

   **Qeyd:** Windows ikonu dəyişdikdən sonra tam rebuild lazımdır (`flutter run` dayandırıb yenidən başladın).

API əsas URL (Flutter): `http://psclub.test/api` və ya `http://127.0.0.1/psclub/backend/public/api`

## API modulları

- `POST /api/auth/login`
- `GET /api/tables`, `GET /api/sessions/active`
- `POST /api/sessions`, `POST /api/sessions/{id}/close`
- Admin: `/api/users`, `/api/products`, `/api/stock`, `/api/reports`, `/api/audit-logs`
