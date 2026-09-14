#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

compose() {
    env -u LAB_SEED -u APP_PORT -u DB_PASSWORD -u DATABASE_URL \
        -u REGISTRATION_CODE -u MAX_PUBLIC_ACCOUNTS -u STORE_INITIAL_BALANCE \
        -u COMPOSE_FILE -u COMPOSE_PROFILES -u COMPOSE_ENV_FILES \
        docker compose --env-file .env -f docker-compose.yml --project-name nexo-lab "$@"
}

ajuda() {
    echo 'Uso: ./lab.sh {subir|parar|estado|doutor|reiniciar|resetar|logs|apagar}'
}

saude() {
    compose exec -T app python - <<'PY'
import sys
import urllib.request
for port in (8000, 8088, 9203):
    try:
        with urllib.request.urlopen(f'http://127.0.0.1:{port}/health', timeout=3) as response:
            if response.status != 200:
                sys.exit(1)
    except Exception:
        sys.exit(1)
PY
}

subir() {
    for img in nexo-lab/app:1.1 nexo-lab/internal:1.1 postgres:16-alpine; do
        if ! docker image inspect "$img" >/dev/null 2>&1; then
            echo 'Carregue as imagens primeiro: docker load -i imagens.tar.gz' >&2
            return 1
        fi
    done
    compose down
    compose up -d --pull never
    echo 'Aguardando os serviços...'
    for ((i=0; i<60; i++)); do
        if saude >/dev/null 2>&1; then
            echo 'Laboratório pronto. Endereço publicado:'
            compose port app 8000
            return 0
        fi
        sleep 2
    done
    echo 'Os serviços não responderam a tempo. Consulte ./lab.sh logs' >&2
    return 1
}

case "${1:-}" in
    subir|reiniciar) subir ;;
    parar) compose down ;;
    estado) compose ps ;;
    doutor) if saude; then echo 'Serviços disponíveis.'; else echo 'Serviço indisponível. Execute ./lab.sh reiniciar.' >&2; exit 1; fi ;;
    resetar)
        read -r -p 'Apagar os dados e restaurar o cenário? [s/N] ' resposta
        [[ "$resposta" == [sS] ]] || exit 1
        compose exec -T app python -m nexo.cli reset-lab --yes ;;
    logs) compose logs -f --tail 100 ;;
    apagar)
        read -r -p 'Remover o laboratório e todos os seus dados? [s/N] ' resposta
        [[ "$resposta" == [sS] ]] || exit 1
        compose down -v ;;
    *) ajuda; exit 1 ;;
esac
