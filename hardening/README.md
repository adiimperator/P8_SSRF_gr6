# Hardening sieci (warstwa egress) — część Jakuba

Remediacja SSRF powinna być **warstwowa**. Sama poprawka w kodzie (allowlista) może zostać
obejść błędem implementacji, dlatego dokładamy niezależne kontrole na warstwie sieci.

## Trzy warstwy obrony (defense-in-depth)

| Warstwa | Kontrola | Właściciel | Co blokuje |
|--------|----------|-----------|------------|
| 1. Kod | `is_url_allowed()` – allowlista schematów, hostów, walidacja IP, kontrola przekierowań | kolega | wszystkie wektory, u źódła |
| 2. Topologia sieci | `app` poza siecią `internal` (`docker-compose.hardened.yml`) | Jakub | dostęp do usług wewnętrznych i metadanych |
| 3. Zapora egress | reguły iptables DROP do adresów prywatnych/metadanych (`egress-rules.sh`) | Jakub | wyjście do RFC1918/169.254 nawet przy wyjściu na internet |

Kluczowa myśl do raportu: **warstwa 2 i 3 działają nawet wtedy, gdy kod jest nadal podatny.**
To pozwala zademonstrować wkład sieciowy niezależnie od poprawki w kodzie.

## Jak zademonstrować (warstwa 2 — topologia)

```bash
# z głównego folderu projektu:
docker compose -f hardening/docker-compose.hardened.yml up --build
# w drugim oknie:
powershell -ExecutionPolicy Bypass -File .\run-evidence.ps1
```

Mimo że aplikacja wciąż ma `VULNERABLE=1`:

- **T1** `http://internal-api/admin` → błąd (host nieosiągalny z sieci `public`)
- **T2** `http://169.254.169.254/...` → błąd (brak trasy)
- **T6** `file:///etc/passwd` → **nadal działa** — to warstwa kodu, nie sieci (naprawia ją allowlista schematów kolegi)

To ostatnie jest celowe i pokazuje granicę odpowiedzialności: egress chroni przed ruchem
do sieci wewnętrznej, ale nie przed odczytem pliku lokalnego — stąd potrzeba obu warstw.

## Warstwa 3 — zapora egress (opcjonalna, styl FortiGate)

`egress-rules.sh` to granularna polityka wyjściowa dla scenariusza, w którym aplikacja
MUSI miec internet, ale nie wolno jej siegać zasobów wewnętrznych. Aby ją uruchomić,
usługa `app` potrzebuje `cap_add: ["NET_ADMIN"]`, pakietu `iptables` w obrazie i wywołania
skryptu w entrypoint przed startem aplikacji (szczegóły w nagłówku skryptu).

## Mapowanie na standardy

- **OWASP ASVS** — kontrola SSRF: allowlista protokołów, domen, ścieżek i portów (warstwa 1)
  oraz kontrola komunikacji wychodzącej (warstwy 2–3).
- **OWASP Top 10:2025 A01 Broken Access Control** — SSRF został wcielony do tej kategorii.
- **OWASP WSTG-INPV-19** — Testing for Server-Side Request Forgery (metodyka testów T1–T7).
