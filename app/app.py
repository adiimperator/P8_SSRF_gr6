"""
Aplikacja z funkcja "pobierz zasob z URL" (podglad/import).
To jest serce projektu SSRF.

Podzial pracy:
  - Jakub  -> wersja PODATNA (VULNERABLE=1): endpoint pobiera dowolny URL bez kontroli.
  - Kolega -> wersja z POPRAWKA (VULNERABLE=0): uzupelnia funkcje is_url_allowed().

Dzieki przelacznikowi VULNERABLE ten sam kod obsluguje oba warianty,
wiec testy BEFORE/AFTER uruchamia sie bez zmiany aplikacji - tylko zmiana zmiennej.
"""
import os
import logging
import requests
from flask import Flask, request, jsonify

app = Flask(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("ssrf-app")

VULNERABLE = os.environ.get("VULNERABLE", "1") == "1"
ALLOWED_HOSTS = [h.strip() for h in os.environ.get("ALLOWED_HOSTS", "").split(",") if h.strip()]


def is_url_allowed(url: str):
    """
    Zwraca (True, None) gdy URL jest bezpieczny, albo (False, "powod") gdy nalezy odrzucic.

    === MIEJSCE PRACY KOLEGI (wersja z poprawka) ===
    Tutaj trafia remediacja. Minimum do zaimplementowania:
      1. tylko schematy http/https (blokada file://, gopher://, ftp:// itd.)
      2. host musi byc na ALLOWED_HOSTS (allowlista)
      3. rozwiaz nazwe hosta na adres IP i odrzuc adresy:
         - loopback (127.0.0.0/8, ::1)
         - prywatne (10/8, 172.16/12, 192.168/16)
         - link-local (169.254.0.0/16)  <- tu siedzi serwis metadanych
      4. kontrola przekierowan (allow_redirects=False i ponowna walidacja celu)
      5. timeout i limit rozmiaru odpowiedzi
    Na razie placeholder - przepuszcza wszystko:
    """
    return True, None  # TODO(kolega): zaimplementowac realna walidacje


@app.route("/health")
def health():
    return jsonify(status="ok", mode="vulnerable" if VULNERABLE else "hardened")


@app.route("/fetch")
def fetch():
    """GET /fetch?url=... -> serwer pobiera URL i zwraca tresc."""
    url = request.args.get("url", "")
    if not url:
        return jsonify(error="podaj parametr ?url="), 400

    if not VULNERABLE:
        ok, reason = is_url_allowed(url)
        if not ok:
            log.warning("ODRZUCONO fetch: url=%s powod=%s", url, reason)
            return jsonify(error="cel niedozwolony", reason=reason), 403

    try:
        # Naiwna obsluga schematu file:// - jak w aplikacjach uzywajacych urllib.
        # To celowy blad wersji podatnej: pozwala odczytac lokalny plik serwera.
        if url.lower().startswith("file://"):
            path = url[len("file://"):]
            with open(path, "r", errors="replace") as f:
                data = f.read(4096)   # limit, zeby nie wyrzucic ogromnego pliku
            log.info("fetch file url=%s -> 200 (odczyt lokalny)", url)
            return (data, 200, {"Content-Type": "text/plain; charset=utf-8"})

        # Wersja podatna: zadnej kontroli - serwer idzie, gdzie mu kaze uzytkownik.
        resp = requests.get(url, timeout=5, allow_redirects=True)
        log.info("fetch url=%s -> %s", url, resp.status_code)
        return (resp.text, resp.status_code, {"Content-Type": "text/plain; charset=utf-8"})
    except Exception as e:
        log.info("fetch url=%s -> blad: %s", url, e)
        return jsonify(error=str(e)), 502


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
