#!/bin/sh
# egress-rules.sh - zapora WYJSCIOWA (egress) dla kontenera 'app'.
# Wariant granularny, w stylu polityki egress na FortiGate: aplikacja moze wychodzic
# do publicznego internetu (allowlista w kodzie), ale ma ZABRONIONY ruch do adresow
# wewnetrznych, prywatnych i do serwisu metadanych chmury.
#
# To jest alternatywa / uzupelnienie dla separacji sieci z docker-compose.hardened.yml.
# Stosuje sie gdy aplikacja MUSI miec wyjscie na internet, a mimo to nie wolno jej
# siegac zasobow wewnetrznych (realny scenariusz produkcyjny).
#
# Wymaga uprawnienia NET_ADMIN i pakietu iptables w obrazie:
#   w compose dla uslugi app:  cap_add: ["NET_ADMIN"]
#   w Dockerfile:              RUN apt-get update && apt-get install -y iptables
# Skrypt uruchomic jako root PRZED startem aplikacji (entrypoint).
set -e

# 1. ruch lokalny aplikacji i polaczenia zwrotne
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 2. DNS (potrzebny do rozwiazywania hostow z allowlisty)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# 3. BLOKADA celow wewnetrznych - KLUCZOWA regula anty-SSRF
#    kolejnosc wazna: te REJECT musza byc PRZED zezwoleniem na 80/443
for net in 169.254.0.0/16 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16; do
    iptables -A OUTPUT -d "$net" -j REJECT --reject-with icmp-admin-prohibited
done

# 4. dozwolony ruch wychodzacy tylko HTTP/HTTPS do pozostalych (publicznych) celow
iptables -A OUTPUT -p tcp --dport 80  -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# 5. wszystko inne - odrzuc (domyslna odmowa)
iptables -A OUTPUT -j REJECT --reject-with icmp-admin-prohibited

echo "[egress] reguly zastosowane:"
iptables -L OUTPUT -n --line-numbers
