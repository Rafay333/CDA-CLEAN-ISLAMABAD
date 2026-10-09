# CDA-Clean Islamabad

Residents report a cleanliness problem with a photo and a map pin. The sector’s sanitation office accepts it, assigns a crew, and the crew closes it with an after photo.

- Flutter app: `app/` (Android, iOS, and web)
- Node.js API: `server/`
- Full product and technical document: `docs/CDA-Clean-Islamabad-Full-App-Document.md`

The API stores data in a local PostgreSQL-compatible database, so you do not need to install Postgres to try the app. `docker-compose.yml` is there if you later want a standalone Postgres server (`DATABASE_URL`).

## Run the API

```powershell
cd server
npm install
npm test
npm run dev
```

The API listens on http://localhost:4000.

In development the SMS code is always `123456`. These accounts are created on first launch:

| Who | Sign in |
| --- | --- |
| Resident Ayesha Khan | `03001112233` and code `123456` |
| Zone supervisor, Zone G | `SUP-G10` / `Clean@123` |
| Field officer, Zone G | `OFF-G10` / `Clean@123` |
| Directorate | `ADM-CDA` / `Clean@123` |

Ayesha already has one open report in G-10, so the supervisor inbox is not empty.

## Run the app

```powershell
cd app
flutter pub get
flutter run
```

On a phone emulator the API is not `localhost`. Android emulator:

```powershell
flutter run --dart-define=API_BASE=http://10.0.2.2:4000
```

Chrome on this computer can use the default `http://localhost:4000`. App screens are not in the project yet.

## What the first version does

- Resident: phone code sign-in, report with photo and pin, my reports, sector map, collection days, confirm or reopen
- Field officer: job list, start, resolve only after an after photo
- Zone supervisor: accept, reject, duplicate, assign
- Directorate: city counts, recent reports, staff accounts
- English and Urdu
