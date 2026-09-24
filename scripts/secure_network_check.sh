#!/usr/bin/env bash

# Secure Network Check
# Syfte: kontrollera den egna Linux/WSL-miljön på ett säkert och reproducerbart sätt.
# Säkerhetsavgränsning: endast localhost och lokala systemobservationer används.
# Ingen extern portskanning eller ändring av brandvägg/SSH utförs.

PROJECT_DIR="$HOME/linux-uppgift"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/secure_network_check_$(date '+%Y%m%d_%H%M%S').log"

DNS_NAME="example.com"
TEST_PORT=8080
TEST_DIR="$PROJECT_DIR/.test_service"
TEST_PID=""

PASS_COUNT=0
FAIL_COUNT=0


# Skriver tidsstämplad status till terminal och loggfil.
log_msg() {
    local status="$1"
    shift
    local message="$*"

    printf '[%s] %s %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "$status" \
        "$message" | tee -a "$LOG_FILE"
}


# Kontrollerar att ett kommando finns i miljön.
check_command() {
    local command_name="$1"

    if [[ -z "$command_name" ]]; then
        log_msg "FAIL" "Inget kommandonamn angavs."
        return 2
    fi

    if command -v "$command_name" >/dev/null 2>&1; then
        log_msg "OK" "Kommandot '$command_name' finns."
        return 0
    else
        log_msg "FAIL" "Kommandot '$command_name' saknas."
        return 1
    fi
}


# Stoppar testtjänsten och tar bort temporära filer.
cleanup() {
    if [[ -n "$TEST_PID" ]] && kill -0 "$TEST_PID" 2>/dev/null; then
        kill "$TEST_PID" 2>/dev/null
        wait "$TEST_PID" 2>/dev/null
        log_msg "INFO" "Lokal testtjänst stoppad."
    fi

    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        log_msg "INFO" "Temporär testkatalog borttagen."
    fi
}


# Kör cleanup när skriptet avslutas.
trap cleanup EXIT


# Kontrollerar interface, adresser och default route.
environment_check() {
    log_msg "INFO" "=== Miljööversikt ==="

    if ! check_command "ip"; then
        return 1
    fi

    log_msg "INFO" "Interface och adresser:"
    ip addr | tee -a "$LOG_FILE"

    log_msg "INFO" "Default route:"

    if ip route | grep -q '^default '; then
        ip route | grep '^default ' | tee -a "$LOG_FILE"
        log_msg "OK" "Default route hittades."
        return 0
    else
        log_msg "WARN" "Ingen default route hittades."
        return 1
    fi
}


# Kontrollerar DNS-upplösning.
dns_check() {
    log_msg "INFO" "=== DNS-kontroll ==="

    if [[ -z "$DNS_NAME" ]]; then
        log_msg "FAIL" "DNS-namnet är tomt."
        return 1
    fi

    if [[ "$DNS_NAME" != "example.com" ]]; then
        log_msg "WARN" "DNS-namnet avviker från det godkända testnamnet."
    fi

    if ! check_command "getent"; then
        return 1
    fi

    if getent hosts "$DNS_NAME" >> "$LOG_FILE" 2>&1; then
        log_msg "OK" "DNS-uppslag för '$DNS_NAME' lyckades."
        return 0
    else
        log_msg "WARN" "DNS-uppslag för '$DNS_NAME' misslyckades."
        return 1
    fi
}


# Startar en tillfällig lokal webbserver på localhost.
start_local_service() {
    log_msg "INFO" "=== Lokal testtjänst ==="

    if ! check_command "python3"; then
        return 1
    fi

    mkdir -p "$TEST_DIR"

    printf '%s\n' \
        "Secure Network Check local test service" \
        > "$TEST_DIR/index.html"

    python3 -m http.server "$TEST_PORT" \
        --bind 127.0.0.1 \
        --directory "$TEST_DIR" \
        >/dev/null 2>&1 &

    TEST_PID="$!"

    sleep 1

    if kill -0 "$TEST_PID" 2>/dev/null; then
        log_msg "OK" "Lokal testtjänst startad på 127.0.0.1:$TEST_PORT."
        return 0
    else
        log_msg "FAIL" "Lokal testtjänst kunde inte startas."
        TEST_PID=""
        return 1
    fi
}


# Kontrollerar att den lokala testtjänsten svarar.
local_service_check() {
    log_msg "INFO" "Kontrollerar localhost på port $TEST_PORT."

    if ! check_command "curl"; then
        return 1
    fi

    if curl -fsS --max-time 3 \
        "http://127.0.0.1:$TEST_PORT/" \
        >> "$LOG_FILE" 2>&1; then

        log_msg "OK" "Lokal testtjänst svarar på port $TEST_PORT."
        return 0
    else
        log_msg "FAIL" "Lokal testtjänst svarar inte på port $TEST_PORT."
        return 1
    fi
}


# Visar lokalt lyssnande TCP- och UDP-portar.
port_overview() {
    log_msg "INFO" "=== Portöversikt ==="

    if ! check_command "ss"; then
        return 1
    fi

    log_msg "INFO" "Lokalt lyssnande TCP/UDP-portar:"
    ss -tuln | tee -a "$LOG_FILE"

    if ss -tuln | grep -q ":$TEST_PORT"; then
        log_msg "OK" "Testport $TEST_PORT lyssnar lokalt."
        return 0
    else
        log_msg "WARN" "Testport $TEST_PORT hittades inte i portöversikten."
        return 1
    fi
}


# Kontrollerar att processinformation kan läsas.
process_check() {
    log_msg "INFO" "=== Processkontroll ==="

    if ! check_command "ps"; then
        return 1
    fi

    if ps -ef | head -n 8 >> "$LOG_FILE" 2>&1; then
        log_msg "OK" "Processinformation kunde läsas."
        return 0
    else
        log_msg "FAIL" "Processinformation kunde inte läsas."
        return 1
    fi
}


# Kör en kontroll och räknar resultatet.
run_check() {
    local check_name="$1"
    local check_function="$2"

    if [[ -z "$check_name" || -z "$check_function" ]]; then
        log_msg "FAIL" "Kontrollnamn eller kontrollfunktion saknas."
        ((FAIL_COUNT++))
        return 2
    fi

    log_msg "INFO" "Startar kontroll: $check_name"

    if "$check_function"; then
        ((PASS_COUNT++))
        log_msg "OK" "$check_name lyckades."
        return 0
    else
        ((FAIL_COUNT++))
        log_msg "FAIL" "$check_name misslyckades eller gav varning."
        return 1
    fi
}


# Huvudfunktion.
main() {
    mkdir -p "$LOG_DIR"

    log_msg "INFO" "========================================"
    log_msg "INFO" "Secure Network Check startar"
    log_msg "INFO" "Logg: $LOG_FILE"
    log_msg "INFO" "========================================"

    # Liten, uttryckligen definierad lista över säkra lokala kontroller.
    local checks=(
        "Miljööversikt:environment_check"
        "DNS:dns_check"
        "Lokal tjänst:start_local_service"
        "Localhost-test:local_service_check"
        "Portöversikt:port_overview"
        "Processkontroll:process_check"
    )

    local item
    local check_name
    local check_function

    # Kör varje kontroll i listan.
    for item in "${checks[@]}"; do
        check_name="${item%%:*}"
        check_function="${item#*:}"

        run_check "$check_name" "$check_function"
    done

    # Slutsammanfattning kommer efter alla kontroller.
    log_msg "INFO" "========================================"
    log_msg "INFO" "SLUTSAMMANFATTNING"
    log_msg "INFO" "Lyckade kontroller: $PASS_COUNT"
    log_msg "INFO" "Misslyckade kontroller: $FAIL_COUNT"
    log_msg "INFO" "Loggfil: $LOG_FILE"
    log_msg "INFO" "========================================"

    if [[ "$FAIL_COUNT" -eq 0 ]]; then
        log_msg "OK" "Alla kontroller lyckades."
        return 0
    elif [[ "$PASS_COUNT" -gt 0 ]]; then
        log_msg "WARN" "Vissa kontroller lyckades men minst en misslyckades."
        return 1
    else
        log_msg "FAIL" "Inga kontroller lyckades."
        return 2
    fi
}


# Starta programmet.
main "$@"
