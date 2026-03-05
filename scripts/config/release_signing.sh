#!/bin/bash
# Shared release signing configuration for local and CI packaging workflows.

MA_RELEASE_SIGNING_MODE="${MA_RELEASE_SIGNING_MODE:-adhoc}"
MA_RELEASE_CODE_SIGN_IDENTITY="${MA_RELEASE_CODE_SIGN_IDENTITY:-Prisma Local Code Signing}"

ma_validate_release_signing_mode() {
  case "${MA_RELEASE_SIGNING_MODE}" in
    adhoc|self-signed)
      return 0
      ;;
    *)
      echo "Invalid MA_RELEASE_SIGNING_MODE='${MA_RELEASE_SIGNING_MODE}'. Use 'adhoc' or 'self-signed'." >&2
      return 1
      ;;
  esac
}

ma_release_signing_description() {
  if [ "${MA_RELEASE_SIGNING_MODE}" = "self-signed" ]; then
    printf 'self-signed (%s)' "${MA_RELEASE_CODE_SIGN_IDENTITY}"
  else
    printf 'adhoc'
  fi
}

ma_release_effective_identity() {
  if [ "${MA_RELEASE_SIGNING_MODE}" = "self-signed" ]; then
    printf '%s' "${MA_RELEASE_CODE_SIGN_IDENTITY}"
  else
    printf '%s' "-"
  fi
}

ma_codesign_identity_exists() {
  local identity="$1"
  local login_keychain="${HOME}/Library/Keychains/login.keychain-db"
  local keychains=("${login_keychain}")
  local keychain_entry=""

  while IFS= read -r keychain_entry; do
    keychain_entry="${keychain_entry//\"/}"
    keychain_entry="$(printf '%s' "${keychain_entry}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -n "${keychain_entry}" ]; then
      keychains+=("${keychain_entry}")
    fi
  done < <(security list-keychains -d user 2>/dev/null || true)

  local kc=""
  for kc in "${keychains[@]}"; do
    if security find-identity -v -p codesigning "${kc}" 2>/dev/null \
      | awk -F'"' '/"/ { print $2 }' \
      | grep -Fx "${identity}" >/dev/null 2>&1; then
      return 0
    fi
  done

  return 1
}

ma_require_self_signed_identity() {
  if [ "${MA_RELEASE_SIGNING_MODE}" != "self-signed" ]; then
    return 0
  fi

  if ma_codesign_identity_exists "${MA_RELEASE_CODE_SIGN_IDENTITY}"; then
    return 0
  fi

  cat >&2 <<EOF
Missing code signing identity '${MA_RELEASE_CODE_SIGN_IDENTITY}' in keychain.

Create it with:
  ./scripts/setup-self-signed-cert.sh --name "${MA_RELEASE_CODE_SIGN_IDENTITY}"

Or list available identities:
  security find-identity -v -p codesigning
EOF
  return 1
}
