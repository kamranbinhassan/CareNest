# CareNest — Medicine Adherence Monitoring

CareNest has two deliberately separate modes:

- **Local demo:** family, medicine, dose events, analytics, and appearance preferences stay in this device's secure local storage.
- **Backend account:** registration/sign-in connects to FastAPI and PostgreSQL. This screen displays and changes server responses only. Local records are never uploaded automatically.

The FastAPI backend provides authenticated family and medicine data. It does not provide cloud hosting, password reset, email verification, or production medical-record compliance. Use synthetic demonstration records until deployment security has been reviewed.

## Flutter

Run the local demo with:

```sh
flutter pub get
flutter run
```

The development default targets the configured physical-phone/Kali address, `http://10.27.120.70:8000/api/v1`. For an Android emulator, override it because emulators use `10.0.2.2` to reach the host computer:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For a different physical-device network, pass `--dart-define=API_BASE_URL=http://<KALI_LAN_IP>:8000/api/v1`. Debug builds allow this local HTTP development traffic; release builds retain Android's normal HTTPS trust policy. Use the trusted local TLS instructions below for private health data beyond a controlled demo network.

The debug Android manifest permits local cleartext testing and trusts user-installed certificates; release builds retain Android's normal HTTPS trust policy. For a physical-phone demonstration, use a private Wi-Fi network and a short-lived local TLS certificate. Find the development computer's private Wi-Fi IP, set `LAN_IP` below to that address, install the generated certificate on the test phone (Android Settings → Security → install a CA certificate; wording varies), and use the same private IP for the API URL:

```sh
LAN_IP=192.168.1.23
openssl req -x509 -nodes -days 14 -newkey rsa:2048 \
  -keyout /tmp/carenest-dev.key -out /tmp/carenest-dev.crt \
  -subj "/CN=${LAN_IP}" \
  -addext "subjectAltName=IP:${LAN_IP}" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,digitalSignature,keyCertSign,cRLSign"
adb push /tmp/carenest-dev.crt /sdcard/Download/carenest-dev.crt
```

Run the API with TLS, bind only while on the trusted private network, and restrict the host firewall to the phone and local subnet:

```sh
cd backend
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 \
  --ssl-keyfile /tmp/carenest-dev.key --ssl-certfile /tmp/carenest-dev.crt
```

Then run the Flutter debug app with:

```sh
flutter run --dart-define=API_BASE_URL=https://${LAN_IP}:8000/api/v1
```

This demo CA is only for a test device and synthetic data; never reuse it in production. Stop the server after the demonstration. Keep PostgreSQL bound to localhost and do not expose its port to the phone or public internet. The release app does not trust user-installed CAs by default.

## FastAPI + PostgreSQL development setup

Requires Python 3.11+ and a PostgreSQL server installed separately. From the repository root:

```sh
cd backend
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt
python3 scripts/initialize_local_env.py
```

`initialize_local_env.py` creates the ignored local file once, using a random URL-safe PostgreSQL password and a separate random JWT secret. It never overwrites an existing `.env`. This file is loaded automatically by both application startup and Alembic, regardless of the current working directory. In local development it overrides stale exported settings; production deployments should omit `.env` and set `APP_ENV=production` to use process environment variables. The local file is configured for `medicine_app` / `medicine_adherence` and has mode `600`.

For this existing development database, synchronize the role password from the ignored `.env` by running:

```sh
cd backend
python3 scripts/set_local_role_password.py
```

The helper may prompt for local administrator privilege. It compares the local socket cluster to the process listening on TCP port 5432, then runs a fixed `ALTER ROLE medicine_app` operation as the `postgres` OS account using system Python (not the project virtual environment). The password is read from `.env`, passed only over stdin, and safely quoted by psycopg; it is never placed in a command argument or printed. The helper then verifies that same decoded credential through SQLAlchemy over TCP. It does not alter or recreate the database.

For a fresh development installation only, create the role and database through the PostgreSQL administrator:

```sql
CREATE ROLE medicine_app LOGIN;
CREATE DATABASE medicine_adherence OWNER medicine_app;
```

The local connection URL format is:

```text
postgresql+psycopg://medicine_app:<64-hex-password>@127.0.0.1:5432/medicine_adherence
```

Before production deployment, replace exactly these two values in `backend/.env`: the password portion of `DATABASE_URL` and `JWT_SECRET_KEY`. Use a new database credential and a separate randomly generated JWT secret from a production secret manager. Do not reuse local development values or commit `.env`.

Keep PostgreSQL listening on localhost for local development. The application uses SQLAlchemy and Alembic. Migration `0001_initial_schema` creates missing tables only; its downgrade intentionally refuses to drop data. Run:

```sh
alembic upgrade head
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

The API health endpoint is `GET /health`; it reports `503` until the database is reachable. OpenAPI docs are at `/docs` while the server runs. For an Android emulator, `10.0.2.2` reaches host loopback; physical phones must use the computer's LAN IP. Physical-device TLS steps are above. Plain HTTP does not encrypt passwords or health records.

## API overview

All application routes are under `/api/v1`. Registration and login return a short-lived bearer token; private endpoints require `Authorization: Bearer <token>`.

| Method | Endpoint | Purpose |
| --- | --- | --- |
| POST | `/auth/register` | Create account and issue token |
| POST | `/auth/login` | Authenticate and issue token |
| GET | `/auth/me` | Current account |
| GET, POST | `/families` | List or create caller's family |
| GET, POST | `/families/{family_id}/members` | List or add a family member |
| GET, POST | `/members/{member_id}/medicines` | List or create a medication plan with schedule |
| GET, PATCH, DELETE | `/medicines/{medicine_id}` | View, edit descriptive fields, or archive a plan |
| GET | `/members/{member_id}/occurrences?from_date=YYYY-MM-DD&through_date=YYYY-MM-DD` | Generate/load persisted expected doses |
| POST, PUT | `/occurrences/{occurrence_id}/events` | Record a due dose or correct its existing event |
| GET | `/families/{family_id}/adherence?from_date=...&through_date=...` | Family summary with per-medicine counts |
| GET | `/`, `/health` | Service and database checks |

Occurrence status is `pending`, `overdue`, `taken`, or `missed`. A unique database constraint permits one event per occurrence. Repeating an identical POST is idempotent; changing an event uses PUT and preserves its event ID. Future occurrences cannot be recorded. Archiving a medicine preserves its schedule and past dose history.

## Verification

Backend tests use isolated SQLite databases and do not need PostgreSQL:

```sh
cd backend
python -m pytest -q
```

Flutter analysis/tests/build can be run from the root using `flutter analyze`, `flutter test`, and `flutter build apk --debug`.
