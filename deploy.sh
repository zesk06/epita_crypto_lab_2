#!/usr/bin/env bash
# Simulated deployment: decrypt the database credentials with sops, then call a fake endpoint.
#   ./deploy.sh                              # uses secrets/prod/database.yaml
#   ./deploy.sh secrets/dev/database.yaml
# Expected content of the file, before encryption (step 3 of the lab):
#   postgres:
#     user: ...
#     password: ...
# The fake endpoint (httpbin.org/basic-auth/USER/PASSWORD) answers 200 only to the right
# credentials, so "deployment accepted" proves the secrets were decrypted correctly.
# The age private key comes from SOPS_AGE_KEY (CI secret), SOPS_AGE_KEY_FILE, or the
# sops default keys.txt. It is never read from the repository.
set -euo pipefail
set +x # never trace this script: a traced line would print the secrets

CONFIG=${1:-secrets/prod/database.yaml}
ENDPOINT=${DEPLOY_ENDPOINT:-https://httpbin.org/basic-auth}

[ -f "$CONFIG" ] || { echo "missing $CONFIG: create and encrypt it first (lab step 3)" >&2; exit 1; }
get() { sops decrypt --extract "$1" "$CONFIG"; }
user=$(get '["postgres"]["user"]')
password=$(get '["postgres"]["password"]')

# percent-encode, so any character is safe inside the URL path
urlencode() {
  local LC_ALL=C s=$1 out='' c i # byte by byte, so non-ASCII characters are UTF-8 encoded
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    case $c in [a-zA-Z0-9.~_-]) out+=$c ;; *) out+=$(printf '%%%02X' "'$c") ;; esac
  done
  printf '%s' "$out"
}

# escape \ and " for curl's config syntax
cfg() { local s=${1//\\/\\\\}; printf '%s' "${s//\"/\\\"}"; }

echo "deploying $(basename "$(dirname "$CONFIG")") to ${ENDPOINT}"

# The URL and the credentials reach curl on stdin (-K -), not on its command line:
# they do not appear in `ps`, in the CI log, or in shell history.
code=$(printf 'url = "%s/%s/%s"\nuser = "%s:%s"\n' \
  "$ENDPOINT" "$(urlencode "$user")" "$(urlencode "$password")" "$(cfg "$user")" "$(cfg "$password")" \
  | curl -sS -K - -o /dev/null -w '%{http_code}' --max-time 20)

if [ "$code" = 200 ]; then
  echo "deployment accepted (HTTP $code)"
else
  echo "deployment refused (HTTP $code)" >&2
  exit 1
fi
