# Przekazanie dla drugiej osoby (część: poprawka + testy)

Masz gotowe, uruchamialne środowisko. Twoja robota to **jedna funkcja** z poprawką
oraz **testy BEFORE/AFTER**. Reszty (sieci, kontenery, cele ataku) nie ruszaj.

## Jak odpalić

```bash
docker compose up --build
curl "http://localhost:8080/health"     # pokaże tryb: vulnerable / hardened
```

## Kontrakt – to się NIE zmieni, możesz na tym polegać

- Endpoint: **`GET /fetch?url=<URL>`** na `http://localhost:8080`
- `VULNERABLE=1` → aplikacja pobiera dowolny URL (stan BEFORE, mój)
- `VULNERABLE=0` → aplikacja woła `is_url_allowed(url)` zanim cokolwiek pobierze (stan AFTER, Twój)
- Odrzucenie ma zwracać **HTTP 403** + JSON `{"error": "...", "reason": "..."}`
- Przepuszczenie legalnego URL ma dalej działać (test kontrolny T7)

## Twoje jedyne miejsce w kodzie

Plik `app/app.py`, funkcja **`is_url_allowed(url)`**. Teraz to placeholder `return True, None`.
Masz ją uzupełnić. Minimum:

1. tylko schematy `http` / `https` (blokada `file://`, `gopher://`, `ftp://`)
2. host musi być na **allowliście** (zmienna `ALLOWED_HOSTS` w compose)
3. **rozwiąż nazwę hosta na IP** i odrzuć: loopback `127/8`+`::1`, prywatne `10/8`,
   `172.16/12`, `192.168/16`, link-local `169.254/16` (tam siedzi serwis metadanych)
4. przekierowania: `allow_redirects=False` i ponowna walidacja celu po każdym skoku
5. `timeout` + limit rozmiaru odpowiedzi

Zwracasz `(True, None)` gdy OK, albo `(False, "powód")` gdy odrzucasz.

## Testy do napisania (pytest) – te same uruchamiane w obu trybach

| Nr | Co | BEFORE (vuln) | AFTER (fix) |
|----|----|----|----|
| T1 | `url=http://internal-api/admin` | 200 + sekret | 403 |
| T2 | `url=http://169.254.169.254/latest/meta-data/...` | 200 + token | 403 |
| T3 | zapis adresu: `127.1`, `0x7f000001`, `2130706433`, `[::1]` | 200 | 403 |
| T4 | przekierowanie 302 z dozwolonej domeny na adres wewnętrzny | 200 | 403 |
| T5 | domena rozwiązywana na adres prywatny (DNS) | 200 | 403 |
| T6 | `url=file:///etc/passwd`, `gopher://...` | błąd/treść | 403 |
| T7 | legalny URL z allowlisty (kontrolny) | 200 | 200 |

Dowody zbierasz z `curl`/Burp + logi kontenera `app` (`docker compose logs app`).

## Co musimy ustalić wspólnie

- jedna domena na allowliście do testu T7 (proponuję `example-cdn.local` – już wpisana w compose)
- kto pisze którą część raportu (podział jest w karcie projektu)
