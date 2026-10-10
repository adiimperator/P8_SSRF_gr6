## 0. Uruchomienie (sprawdź, że działa u Ciebie)

```powershell
cd \ssrf-lab\ssrf-lab
docker compose up --build
# w drugim oknie:
curl "http://localhost:8080/health"          # mode: vulnerable
powershell -ExecutionPolicy Bypass -File .\run-evidence.ps1
```

Wersja podatna daje dowody BEFORE w `evidence\vulnerable\` (T1, T2, T6 = trafienia).

---

## 1. Poprawka w kodzie  ←

Plik: **`app/app.py`**, funkcja **`is_url_allowed(url)`**. Teraz to placeholder `return True, None`.
Zwracasz `(True, None)` gdy URL bezpieczny, `(False, "powód")` gdy odrzucasz. Odrzucenie →
aplikacja zwróci HTTP 403 (obsługa już jest).

Minimum do zaimplementowania:

1. **Schematy** — dozwolone tylko `http` i `https` (blokuje `file://`, `gopher://`, `ftp://`).
2. **Allowlista hostów** — host musi być na `ALLOWED_HOSTS` (zmienna z compose).
3. **Rozwiązanie nazwy na IP** (`socket.getaddrinfo`) i odrzucenie:
   - loopback `127.0.0.0/8`, `::1`
   - prywatne `10/8`, `172.16/12`, `192.168/16`
   - link-local `169.254.0.0/16`  ← tu jest serwis metadanych
   (najprościej: `ipaddress.ip_address(ip).is_private / is_loopback / is_link_local`)
4. **Przekierowania** — `allow_redirects=False` i walidacja celu po każdym skoku (chroni przed T4).
5. **Timeout + limit rozmiaru** odpowiedzi.
): walidację rób na **rozwiązanym IP**, nie na samej nazwie


Przełącznik `VULNERABLE=0` w `docker-compose.yml` włącza Twoją walidację. Po zmianie: `docker compose up --build`.

---

## 2. Testy automatyczne (pytest)

Napisz `tests/test_ssrf.py` uruchamiany w obu trybach. Scenariusze (oczekiwania AFTER):

| Nr | URL | BEFORE | AFTER |
|----|-----|--------|-------|
| T1 | http://internal-api/admin | 200 | 403 |
| T2 | http://169.254.169.254/latest/meta-data/… | 200 | 403 |
| T3 | http://127.1/ | 502 | 403 |
| T4 | przekierowanie 302 na adres wewnętrzny | — | 403 |
| T5 | domena rozwiązywana na adres prywatny | — | 403 |
| T6 | file:///etc/passwd | 200 | 403 |
| T7 | legalny URL z allowlisty (kontrolny) | 502 | 200 |

**T4** wymaga małego serwera atakującego, który zwraca `302` z `Location:` na adres wewnętrzny
(np. dodatkowy kontener Flask albo endpoint w metadata-mock). **T5** wymaga nazwy, która
rozwiązuje się na adres prywatny (można przez lokalny wpis DNS / hosts w kontenerze).

---

## 3. Dowody AFTER

Po poprawce ustaw `VULNERABLE=0`, `docker compose up --build`, a potem:

```powershell
powershell -ExecutionPolicy Bypass -File .\run-evidence.ps1
```

Skrypt sam wykryje tryb i zapisze wyniki do **`evidence\hardened\`**. Zrób zrzuty — to dowód AFTER.
Potwierdź brak regresji: **T7 musi dać 200** (po ustaleniu realnego hosta na allowliście).

### Do ustalenia wspólnie
- jedna domena na `ALLOWED_HOSTS` do testu T7 (teraz placeholder `example-cdn.local`),
- jak symulujemy cel T4/T5 (dodatkowy kontener vs wpis DNS).

---

## 4. Do uzupelnienia w raporcie

Plik: **`P8_SSRF_raport_KOMPLETNY.docx`** — Miejsca są oznaczone żółtymi ramkami
„⟶ DO UZUPEŁNIENIA". Konkretnie:

- **5.1 Poprawka w kodzie** — opis logiki `is_url_allowed()`, fragment kodu, uzasadnienie reguł.
- **4** — dołączyć zrzuty BEFORE (T1,T2,T6) + log; dodać T4/T5.
- **6 Test ponowny** — uzupełnić kolumnę AFTER rzeczywistymi wynikami z `evidence\hardened\`.
- **9 Wnioski** — część implementacyjna (pułapki, np. DNS rebinding; ograniczenia).
- **10 / Załącznik A** — dołączyć `evidence\hardened\`, link do repo, zaktualizować status.


---

## 5. Definition of Done (bramki zaliczenia)

- [x] Legalny scope · [x] Reprodukowalność · [x] Dowód (BEFORE)
- [ ] Remediacja (Twoja poprawka) · [ ] Re-test (AFTER) · [x] Mapowanie + ryzyko
- [ ] Raport 8–12 str (złożenie) · [ ] Obrona (oboje rozumiemy całość)

Termin: karta v0.1 do 11.10, przegląd 18.10 (~40%), preferowane zaliczenie 25.10.
