#!/usr/bin/env bash
# Faz upload idempotente de element/connector templates (*.json em
# /templates) para um projeto no Web Modeler Self-Managed.
#
# O client OAuth m2m 'modeler-seeder' é provisionado pelo Camunda Identity
# (ver .identity/application.yaml — component-presets.webmodeler.applications).
#
# Variáveis de ambiente (com defaults):
#   KEYCLOAK_REALM             camunda-platform
#   MODELER_URL                http://web-modeler-restapi:8081
#   SEEDER_CLIENT_ID           modeler-seeder
#   SEEDER_CLIENT_SECRET       <obrigatório>
#   SEEDER_PROJECT_NAME        Bundled Templates
#   TEMPLATE_FILE_TYPE         CONNECTOR_TEMPLATE
#   TEMPLATES_DIR              /templates
#   SEEDER_SHARE_WITH_EMAILS   demo@example.org   (csv; cada um vira project_admin)

set -euo pipefail

: "${KEYCLOAK_REALM:=camunda-platform}"
: "${MODELER_URL:=http://web-modeler-restapi:8081}"
: "${SEEDER_CLIENT_ID:=modeler-seeder}"
: "${SEEDER_CLIENT_SECRET:?defina SEEDER_CLIENT_SECRET (mesmo valor de VALUES_KEYCLOAK_INIT_MODELER_SEEDER_SECRET)}"
: "${SEEDER_PROJECT_NAME:=Bundled Templates}"
: "${TEMPLATE_FILE_TYPE:=CONNECTOR_TEMPLATE}"
: "${TEMPLATES_DIR:=/templates}"
: "${SEEDER_SHARE_WITH_EMAILS:=demo@example.org}"

log() { printf '[seeder] %s\n' "$*" >&2; }
die() { log "ERRO: $*"; exit 1; }

shopt -s nullglob
templates=("$TEMPLATES_DIR"/*.json)
if [[ ${#templates[@]} -eq 0 ]]; then
  log "Nenhum *.json em $TEMPLATES_DIR — nada a fazer."
  exit 0
fi

# O Web Modeler valida o claim 'iss' contra RESTAPI_OAUTH2_TOKEN_ISSUER
# (http://localhost:18080/auth/realms/...). Como dentro da rede docker
# 'localhost' é o próprio container, forçamos o curl a abrir TCP no
# host-gateway (onde o port mapping 18080:18080 expõe o Keycloak) e a
# mandar Host: localhost — assim o Keycloak emite o iss correto.
gateway_ip=$(awk '/[[:space:]]host\.docker\.internal/ {print $1; exit}' /etc/hosts)
[[ -n "$gateway_ip" ]] || die "host.docker.internal ausente no /etc/hosts (extra_hosts faltando?)"

log "Pegando service-account token..."
sa_token=$(curl -fsS \
  --resolve "localhost:18080:${gateway_ip}" \
  -d "grant_type=client_credentials" \
  -d "client_id=${SEEDER_CLIENT_ID}" \
  -d "client_secret=${SEEDER_CLIENT_SECRET}" \
  "http://localhost:18080/auth/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" \
  | jq -r '.access_token')
[[ -n "$sa_token" && "$sa_token" != "null" ]] || die "service-account token vazio (Identity já provisionou o client?)"

jwt_payload() {
  printf '%s' "$1" | awk -F. '{print $2}' \
    | tr '_-' '/+' \
    | { read -r p; pad=$(( (4 - ${#p} % 4) % 4 )); printf '%s%*s' "$p" "$pad" '' | tr ' ' '='; } \
    | base64 -d 2>/dev/null
}
log "Claims: $(jwt_payload "$sa_token" | jq -c '{iss, aud, azp, preferred_username, scope}' 2>/dev/null || echo '<decode falhou>')"

modeler_api() {
  local m="$1" p="$2" body="${3:-}"
  local resp http_code
  resp=$(mktemp)
  if [[ -n "$body" ]]; then
    http_code=$(curl -sS -o "$resp" -w '%{http_code}' -X "$m" \
      -H "Authorization: Bearer ${sa_token}" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -d "$body" "${MODELER_URL}/api/v1${p}")
  else
    http_code=$(curl -sS -o "$resp" -w '%{http_code}' -X "$m" \
      -H "Authorization: Bearer ${sa_token}" \
      -H "Accept: application/json" "${MODELER_URL}/api/v1${p}")
  fi
  if [[ "$http_code" =~ ^2 ]]; then
    cat "$resp"; rm -f "$resp"; return 0
  fi
  log "Web Modeler ${m} ${p} → HTTP ${http_code}"
  log "Response body:"; cat "$resp" >&2; echo >&2
  rm -f "$resp"; return 1
}

# Templates só são resolvidos em diagramas de projetos onde o usuário
# é collaborator. Compartilhamos 'Bundled Templates' com cada e-mail
# em SEEDER_SHARE_WITH_EMAILS como project_admin (PUT é idempotente).
share_project() {
  local project_id="$1" email="$2"
  local body http_code
  body=$(jq -n --arg p "$project_id" --arg e "$email" \
    '{projectId:$p, email:$e, role:"project_admin"}')
  http_code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT \
    -H "Authorization: Bearer ${sa_token}" \
    -H "Content-Type: application/json" \
    -d "$body" "${MODELER_URL}/api/v1/collaborators")
  if [[ "$http_code" =~ ^2 ]]; then
    log "compartilhado com ${email} (project_admin)"
  else
    log "AVISO: PUT /collaborators ${email} → HTTP ${http_code}"
  fi
}

log "Procurando projeto '${SEEDER_PROJECT_NAME}'..."
search_resp=$(modeler_api POST "/projects/search" \
  "$(jq -n --arg n "$SEEDER_PROJECT_NAME" '{filter:{name:$n}, page:0, size:1}')") \
  || die "search projects falhou"
project_id=$(printf '%s' "$search_resp" | jq -r '.items[0].id // empty')

if [[ -z "$project_id" ]]; then
  log "Criando projeto '${SEEDER_PROJECT_NAME}'..."
  create_resp=$(modeler_api POST "/projects" \
    "$(jq -n --arg n "$SEEDER_PROJECT_NAME" '{name:$n}')") \
    || die "create project falhou"
  project_id=$(printf '%s' "$create_resp" | jq -r '.id // empty')
  if [[ -z "$project_id" ]]; then
    log "Response sem .id:"; printf '%s\n' "$create_resp" >&2
    die "projeto sem id"
  fi
fi
log "Projeto id=${project_id}"

if [[ -n "$SEEDER_SHARE_WITH_EMAILS" ]]; then
  IFS=',' read -r -a _emails <<<"$SEEDER_SHARE_WITH_EMAILS"
  for e in "${_emails[@]}"; do
    e="${e// /}"
    [[ -n "$e" ]] && share_project "$project_id" "$e"
  done
fi

for f in "${templates[@]}"; do
  # O Modeler já anexa .json a connector templates, então mandar
  # 'foo.json' resulta em simplePath 'foo.json.json'. Mandamos sem ext.
  name="$(basename "$f" .json)"
  exists=$(modeler_api POST "/files/search" \
    "$(jq -n --arg p "$project_id" --arg n "$name" \
        '{filter:{projectId:$p, name:$n}, page:0, size:1}')" \
    | jq -r '.items[0].id // empty')
  if [[ -n "$exists" ]]; then
    log "skip (já existe): ${name}"
    continue
  fi
  log "upload: ${name}"
  payload=$(jq -n \
    --arg name "$name" \
    --arg projectId "$project_id" \
    --arg fileType "$TEMPLATE_FILE_TYPE" \
    --rawfile content "$f" \
    '{name:$name, projectId:$projectId, fileType:$fileType, content:$content}')
  modeler_api POST "/files" "$payload" >/dev/null \
    || die "falha no upload de ${name}"
done

log "OK — todos os templates aplicados."
