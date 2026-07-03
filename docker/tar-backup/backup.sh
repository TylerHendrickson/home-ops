#!/usr/bin/env bash
#
# backup.sh — dated, rotating tar.gz snapshots of a directory to an rclone remote.
# -----------------------------------------------------------------------------
# Transport-agnostic (whatever rclone is configured to talk to — SMB, S3, B2,
# WebDAV, ...), environment-agnostic (bare metal or container, it does not know
# or care which), and self-contained: each archive is a standard gzip-compressed
# tar with numeric ownership, permissions, symlinks and xattrs preserved, so it
# restores faithfully onto a fresh host with nothing but `tar -xzf`.
#
# The exit code is the contract: 0 only after a verified, atomically-published
# upload; non-zero on any problem, including lock contention. Whatever runs this
# — cron, supercronic, a CI job, a human — observes that code. No metrics are
# emitted here; a metrics-capable scheduler derives success/failure from the
# exit code. An optional external heartbeat ping (PING_URL) gives a dead-man's-
# switch independent of any metrics pipeline.
#
# Every sensitive variable also accepts a "<NAME>_FILE" form pointing at a file
# whose contents become the value (e.g. PING_URL_FILE=/run/secrets/ping_url),
# so tokens can live in secrets rather than the environment.
# -----------------------------------------------------------------------------

set -euo pipefail
umask 077

# Optional env file for bare-metal use; containers normally inject real env vars.
if [[ -n "${BACKUP_ENV_FILE:-}" && -f "${BACKUP_ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  . "${BACKUP_ENV_FILE}"
fi

# =============================================================================
# Configuration (all env-overridable)
# =============================================================================
# --- Source ---
: "${BACKUP_SOURCE:?set BACKUP_SOURCE to the directory to back up}"
# --- Destination (rclone) ---
: "${RCLONE_REMOTE:?set RCLONE_REMOTE to a configured rclone remote name}"
: "${REMOTE_PATH:=}"                  # path within the remote (e.g. a share or bucket subpath)
: "${RCLONE_CONTIMEOUT:=30s}"
: "${RCLONE_TIMEOUT:=120s}"
: "${RCLONE_RETRIES:=2}"
: "${RCLONE_EXTRA_FLAGS:=}"
# --- Naming ---
: "${BACKUP_PREFIX:=}"                # defaults to the source dir's own name (set below)
# --- Retention ---
: "${RETENTION_COUNT:=10}"            # keep newest N; 0 = keep all
# --- Behavior ---
: "${VERIFY_CHECKSUM:=true}"          # read the upload back and compare sha256
: "${COMPRESS_PROG:=}"                # empty => gzip (tar -z); or e.g. "pigz"
: "${STAGING_DIR:=${TMPDIR:-/tmp}}"   # holds only the archive (not a copy of the source)
: "${LOCK_FILE:=}"                    # defaults under STAGING/TMP (set below)
: "${LOG_FILE:=}"                     # empty => stderr only
# --- Optional pre/post hooks (generic; e.g. quiesce an app around the read) ---
: "${PRE_HOOK:=}"                     # shell run before the archive step
: "${POST_HOOK:=}"                    # shell run after it (always runs, even on failure)
# --- Optional external heartbeat ping (dead-man's-switch) ---
: "${PING_URL:=}"                     # GET on success
: "${PING_URL_START:=}"               # GET when the run starts
: "${PING_URL_FAILURE:=}"             # GET on failure
: "${PING_TIMEOUT:=10}"

# Resolve "<NAME>_FILE" indirection for secret-bearing values. A direct env var,
# if non-empty, takes precedence over its _FILE counterpart.
load_file_secret() {
  local var="$1" fvar="${1}_FILE" path
  path="${!fvar:-}"
  [[ -n "$path" ]] || return 0
  [[ -r "$path" ]] || { printf 'ERROR: %s=%s is not readable\n' "$fvar" "$path" >&2; exit 1; }
  [[ -n "${!var:-}" ]] && return 0
  printf -v "$var" '%s' "$(< "$path")"
}
for _v in PING_URL PING_URL_START PING_URL_FAILURE REMOTE_PATH; do
  load_file_secret "$_v"
done

# =============================================================================
# Derived values + state (do not edit)
# =============================================================================
BACKUP_SOURCE="${BACKUP_SOURCE%/}"
SOURCE_PARENT="$(dirname -- "$BACKUP_SOURCE")"
SOURCE_NAME="$(basename -- "$BACKUP_SOURCE")"   # == top-level dir inside the archive
: "${BACKUP_PREFIX:=$SOURCE_NAME}"
: "${LOCK_FILE:=${STAGING_DIR%/}/backup-${BACKUP_PREFIX}.lock}"

TIMESTAMP="$(date +%Y-%m-%d_%H%M%S)"
ARCHIVE_NAME="${BACKUP_PREFIX}_${TIMESTAMP}.tar.gz"
LOCAL_ARCHIVE="${STAGING_DIR%/}/${ARCHIVE_NAME}"

if [[ -n "$REMOTE_PATH" ]]; then
  REMOTE_DIR="${RCLONE_REMOTE}:${REMOTE_PATH%/}"
else
  REMOTE_DIR="${RCLONE_REMOTE}:"
fi
REMOTE_PARTIAL="${REMOTE_DIR%/}/${ARCHIVE_NAME}.partial"
REMOTE_FINAL="${REMOTE_DIR%/}/${ARCHIVE_NAME}"

if [[ -n "$COMPRESS_PROG" ]]; then
  TAR_COMPRESS=(--use-compress-program "$COMPRESS_PROG")
else
  TAR_COMPRESS=(-z)
fi

RCLONE_FLAGS=(--contimeout "$RCLONE_CONTIMEOUT" --timeout "$RCLONE_TIMEOUT" \
              --retries "$RCLONE_RETRIES" --low-level-retries 3)
if [[ -n "$RCLONE_EXTRA_FLAGS" ]]; then
  read -r -a _extra <<<"$RCLONE_EXTRA_FLAGS"
  RCLONE_FLAGS+=("${_extra[@]}")
fi

POST_PENDING=0
UPLOADED_PARTIAL=0
RUN_OK=0

# =============================================================================
# Helpers
# =============================================================================
log() {
  local m="[$(date '+%F %T')] $*"
  printf '%s\n' "$m" >&2
  [[ -n "$LOG_FILE" ]] && printf '%s\n' "$m" >>"$LOG_FILE" 2>/dev/null || true
}
die() { log "ERROR: $*"; exit 1; }
rc()  { rclone "${RCLONE_FLAGS[@]}" "$@"; }

run_hook() {
  local name="$1" cmd="$2"
  [[ -n "$cmd" ]] || return 0
  log "Running ${name}-hook"
  bash -c "$cmd"
}

# Best-effort HTTP GET; never alters the backup's outcome. The URL is not logged
# (it may carry a secret token); only a labelled outcome is.
http_get() {
  local url="$1" label="$2"
  [[ -n "$url" ]] || return 0
  if command -v curl >/dev/null 2>&1; then
    curl -fsS -m "$PING_TIMEOUT" -o /dev/null "$url" || log "WARN: ${label} ping failed"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T "$PING_TIMEOUT" -O /dev/null "$url" || log "WARN: ${label} ping failed"
  else
    log "WARN: ${label} ping configured but no curl/wget present; skipping"
  fi
  return 0
}

# Fail if anything tar must read is unreadable by THIS process (effective
# uid/gid + supplementary groups — tar's own view): regular files lacking read,
# directories lacking read OR traverse. Symlinks/special files are archived by
# metadata only, so they're not tested. An unreadable path would be silently
# dropped from the archive yet still pass checksum verification, so it's a hard
# stop here rather than a partial backup discovered at restore time.
preflight_readable() {
  command -v find >/dev/null 2>&1 || die "find not found; cannot run the readability pre-flight"
  log "Pre-flight: verifying every path under ${BACKUP_SOURCE} is readable"
  local -a unreadable
  local p
  mapfile -d '' -t unreadable < <(
    find "$BACKUP_SOURCE" \
      \( \( -type f ! -readable \) \
         -o \( -type d \( ! -readable -o ! -executable \) \) \) \
      -print0 2>/dev/null
  )
  if (( ${#unreadable[@]} > 0 )); then
    log "There are ${#unreadable[@]} path(s) under ${BACKUP_SOURCE} that the backup user cannot read (uid=$(id -u) gid=$(id -g) groups=$(id -G)):"
    for p in "${unreadable[@]}"; do log "  unreadable: ${p}"; done
    die "unreadable paths in the backup tree — refusing to create an incomplete archive"
  fi
  log "Pre-flight OK: everything under ${BACKUP_SOURCE} is readable"
}

prune_old() {
  [[ "$RETENTION_COUNT" -gt 0 ]] || { log "Retention disabled; keeping all archives"; return 0; }
  local -a archives=()
  # Files only; ".partial" uploads don't match *.tar.gz, so they're never counted.
  mapfile -t archives < <(rc lsf "$REMOTE_DIR" --include "${BACKUP_PREFIX}_*.tar.gz" 2>/dev/null | LC_ALL=C sort)
  local count=${#archives[@]}
  if (( count > RETENTION_COUNT )); then
    local remove=$(( count - RETENTION_COUNT )) f
    log "Pruning ${remove} old archive(s) (keeping newest ${RETENTION_COUNT} of ${count})"
    for f in "${archives[@]:0:remove}"; do
      f="${f%/}"
      log "  removing ${f}"
      rc deletefile "${REMOTE_DIR%/}/${f}"
    done
  else
    log "No pruning needed (${count} <= ${RETENTION_COUNT})"
  fi
}

finalize() {
  local code=$?
  [[ -n "${FINALIZED:-}" ]] && return
  FINALIZED=1

  # Make sure a post-hook (e.g. "restart the app we quiesced") runs even on failure.
  if [[ "$POST_PENDING" -eq 1 ]]; then
    run_hook "post" "$POST_HOOK" || log "WARN: post-hook failed during cleanup"
    POST_PENDING=0
  fi

  if [[ "$UPLOADED_PARTIAL" -eq 1 ]]; then
    rc deletefile "$REMOTE_PARTIAL" 2>/dev/null || log "WARN: could not remove leftover .partial"
  fi
  rm -f -- "$LOCAL_ARCHIVE" 2>/dev/null || true

  if [[ "$RUN_OK" -eq 1 ]]; then
    log "Backup OK (${ARCHIVE_NAME})"
    http_get "$PING_URL" "success"
    exit 0
  fi
  log "Backup FAILED (rc=${code})"
  http_get "$PING_URL_FAILURE" "failure"
  exit $(( code == 0 ? 1 : code ))
}
trap finalize EXIT
trap 'exit 143' TERM INT   # a per-run timeout (SIGTERM) routes through finalize for cleanup

# =============================================================================
# Main
# =============================================================================
main() {
  log "=== backup starting: ${BACKUP_SOURCE} -> ${REMOTE_FINAL} ==="
  command -v rclone >/dev/null 2>&1 || die "rclone not found"
  command -v tar    >/dev/null 2>&1 || die "tar not found"
  [[ -d "$BACKUP_SOURCE" ]] || die "source is not a directory: ${BACKUP_SOURCE}"

  # Single-instance lock. Contention == ERROR by design: at a daily cadence a
  # still-running prior instance means the previous run is stuck, which should
  # alert (non-zero exit), not be silently skipped.
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "another run holds ${LOCK_FILE} — previous backup appears stuck"

  mkdir -p -- "$STAGING_DIR"
  http_get "$PING_URL_START" "start"

  # Optional quiesce; the matching release is guaranteed by POST_PENDING/finalize.
  if [[ -n "$PRE_HOOK" ]]; then run_hook "pre" "$PRE_HOOK"; POST_PENDING=1; fi

  # Validate that everything in the backup source tree is readable, or fail
  preflight_readable

  # Archive the source directly. --numeric-owner records uid/gid from stat (no
  # chown needed), so ownership restores faithfully on a fresh host.
  log "Archiving ${SOURCE_NAME} -> ${ARCHIVE_NAME}"
  set +e
  tar --numeric-owner -p --acls --xattrs "${TAR_COMPRESS[@]}" \
      -cf "$LOCAL_ARCHIVE" -C "$SOURCE_PARENT" "$SOURCE_NAME"
  local trc=$?
  set -e
  # tar rc=1 = "a file changed as we read it" (live data); archive still usable.
  # rc>=2 is a real error.
  if [[ "$trc" -ge 2 ]]; then die "tar failed (rc=${trc})"; fi
  [[ "$trc" -eq 1 ]] && log "tar rc=1 (a file changed while reading) — tolerated; archive is usable"

  # Release the quiesce as soon as the read is done.
  if [[ "$POST_PENDING" -eq 1 ]]; then run_hook "post" "$POST_HOOK"; POST_PENDING=0; fi

  log "Validating archive"
  if [[ -n "$COMPRESS_PROG" ]]; then
    "$COMPRESS_PROG" -t "$LOCAL_ARCHIVE" || die "compression integrity check failed"
  else
    gzip -t "$LOCAL_ARCHIVE" || die "gzip integrity check failed"
  fi
  tar -tf "$LOCAL_ARCHIVE" >/dev/null || die "archive listing failed (corrupt)"
  log "Archive OK ($(stat -c %s "$LOCAL_ARCHIVE") bytes)"

  # Upload as .partial first; rclone copyto verifies size on completion.
  log "Uploading ${ARCHIVE_NAME}.partial"
  rc copyto "$LOCAL_ARCHIVE" "$REMOTE_PARTIAL"
  UPLOADED_PARTIAL=1

  if [[ "$VERIFY_CHECKSUM" == "true" ]]; then
    log "Verifying sha256 (reads the file back from the remote)"
    local lsum rsum
    read -r lsum _ < <(sha256sum "$LOCAL_ARCHIVE")
    rsum="$(rc cat "$REMOTE_PARTIAL" | sha256sum)"; rsum="${rsum%% *}"
    [[ "$lsum" == "$rsum" ]] || die "checksum mismatch after upload"
    log "Checksum verified"
  fi

  # Publish atomically: server-side rename where the backend supports it.
  log "Publishing (atomic rename)"
  rc moveto "$REMOTE_PARTIAL" "$REMOTE_FINAL"
  UPLOADED_PARTIAL=0
  rc lsf "$REMOTE_DIR" --include "$ARCHIVE_NAME" | grep -q . || die "final archive missing after publish"
  log "Published ${ARCHIVE_NAME}"

  prune_old
  RUN_OK=1   # finalize() now removes the local copy and sends the success ping
}

main "$@"
