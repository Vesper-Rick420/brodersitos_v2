#!/usr/bin/env bash
# ==========================================================================
# backup_agent.sh — Agente de respaldo automatizado (SRE)
#
# Genera un dump SQL comprimido (.sql.gz) de la base de datos PostgreSQL
# que corre dentro del contenedor Docker "finflow-db", lo guarda en
# backups/ y valida que el archivo resultante pese más de 0 bytes.
#
# Uso manual:
#   ./backup_agent.sh
#
# Uso automatizado (cron, cada 6 horas por ejemplo):
#   0 */6 * * * /ruta/al/proyecto/backup_agent.sh >> /var/log/finflow_backup.log 2>&1
# ==========================================================================

set -euo pipefail

# --- Configuración ---
DB_CONTAINER="finflow-db"
DB_USER="finflow"
DB_NAME="finflow"
BACKUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/backups"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/finflow_backup_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=7

mkdir -p "${BACKUP_DIR}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando respaldo de '${DB_NAME}'..."

# --- 1. Verificar que el contenedor de la BD esté corriendo ---
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CONTAINER}$"; then
    echo "[ERROR] El contenedor '${DB_CONTAINER}' no está corriendo. Abortando."
    exit 1
fi

# --- 2. Generar el dump comprimido directamente desde el contenedor ---
if docker exec "${DB_CONTAINER}" pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip -9 > "${BACKUP_FILE}"; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] pg_dump ejecutado correctamente."
else
    echo "[ERROR] pg_dump falló."
    rm -f "${BACKUP_FILE}"
    exit 1
fi

# --- 3. Validar que el archivo exista y pese > 0 bytes ---
if [[ ! -s "${BACKUP_FILE}" ]]; then
    echo "[ERROR] El respaldo '${BACKUP_FILE}' está vacío o no se creó. Abortando."
    rm -f "${BACKUP_FILE}"
    exit 1
fi

SIZE_BYTES=$(stat -c%s "${BACKUP_FILE}" 2>/dev/null || stat -f%z "${BACKUP_FILE}")
SIZE_HUMAN=$(du -h "${BACKUP_FILE}" | cut -f1)
echo "[OK] Respaldo generado: ${BACKUP_FILE} (${SIZE_HUMAN} / ${SIZE_BYTES} bytes)"

# --- 4. Limpieza de respaldos antiguos (retención) ---
find "${BACKUP_DIR}" -name "finflow_backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Respaldo completado. Retención: ${RETENTION_DAYS} días."

exit 0
