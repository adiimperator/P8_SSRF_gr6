# Projekt P8 – SSRF i granica zaufania chmury

Środowisko laboratoryjne do przedmiotu *Bezpieczeństwo aplikacji internetowych* (AWSB, 2026).
Wszystkie dane są fikcyjne. Testy wyłącznie w tym środowisku na komputerach zespołu.

## Architektura

```
  użytkownik ──▶ [ app /fetch ]  ──▶  internal-api  (/admin)
                   public+internal     metadata-mock (169.254.169.254)
                                       (oba tylko w sieci internal)
```

- **app** – jedyny kontener wystawiony na zewnątrz (port 8080). Ma endpoint `/fetch?url=`,
  który po stronie serwera pobiera podany URL. Stoi w obu sieciach, więc jest mostem.
- **internal-api** – usługa wewnętrzna z panelem `/admin`. Niedostępna z zewnątrz.
- **metadata-mock** – udaje chmurowy serwis metadanych pod 169.254.169.254.
- **public** / **internal** – dwie sieci; `internal` ma `internal: true`, czyli brak wyjścia na świat.

## Uruchomienie

```bash
docker compose up --build
```

Sprawdzenie, w jakim trybie działa aplikacja:

```bash
curl "http://localhost:8080/health"
```

## Tryb podatny / tryb z poprawką

Przełącznik `VULNERABLE` w `docker-compose.yml`:

- `VULNERABLE=1` – wersja podatna (dowód BEFORE)
- `VULNERABLE=0` – wersja z poprawką (dowód AFTER); logika w `app/app.py` → `is_url_allowed()`

Po zmianie wartości: `docker compose up --build`.

## Szybki dowód, że granica działa (a SSRF ją obchodzi)

```bash
# Z zewnątrz NIE dosięgniesz usługi wewnętrznej – tak ma być:
curl "http://internal-api/admin"            # błąd: nazwa nieosiągalna z hosta

# Ale przez aplikację już tak (tryb VULNERABLE=1):
curl "http://localhost:8080/fetch?url=http://internal-api/admin"
```
