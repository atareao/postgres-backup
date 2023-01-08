#!/bin/sh
set -eo

HOOKS_DIR="/hooks"
BACKUP_DIR=${BACKUP_DIR:-/backup}
BACKUP_SUFFIX=${BACKUP_SUFFIX:-.sql.gz}
KEEP_MINS=${BACKUP_KEEP_MINS:-1440}
KEEP_DAYS=${BACKUP_KEEP_DAYS:-7}
BACKUP_KEEP_WEEKS=${BACKUP_KEEP_WEEKS:-4}
BACKUP_KEEP_MONTHS=${BACKUP_KEEP_MONTHS:-7}
POSTGRESQL_PORT=${POSTGRESQL_PORT:-5432}
if [ -d "${HOOKS_DIR}" ]; then
    on_error(){
      run-parts -a "error" "${HOOKS_DIR}"
    }
    trap 'on_error' ERR
fi

if [ -z "${POSTGRESQL_DB}" ]; then
    echo "You need to set the POSTGRESQL_DB."
    exit 1
fi

if [ -z "${POSTGRESQL_HOST}" ]; then
    echo "You need to set the POSTGRESQL_HOST environment variable."
    exit 1
fi

if [ -z "${POSTGRESQL_USER}" ]; then
    echo "You need to set the POSTGRESQL_USER."
    exit 1
fi

if [ -z "${POSTGRESQL_PASSWORD}" ]; then
    echo "You need to set the POSTGRESQL_PASSWORD environment variable or link to a container named POSTGRESQL."
    exit 1
fi

#Process vars
POSTGRESQL_DBS=$(echo "${POSTGRESQL_DB}" | tr , " ")

KEEP_MINS=${BACKUP_KEEP_MINS}
KEEP_DAYS=${BACKUP_KEEP_DAYS}
KEEP_WEEKS=$(((BACKUP_KEEP_WEEKS * 7) + 1))
KEEP_MONTHS=$(((BACKUP_KEEP_MONTHS * 31) + 1))

# Pre-backup hook
if [ -d "${HOOKS_DIR}" ]; then
  run-parts -a "pre-backup" --exit-on-error "${HOOKS_DIR}"
fi

#Initialize dirs
mkdir -p "${BACKUP_DIR}/last/" \
         "${BACKUP_DIR}/daily/" \
         "${BACKUP_DIR}/weekly/" \
         "${BACKUP_DIR}/monthly/"

#Loop all databases
for DB in ${POSTGRESQL_DBS}; do
    #Initialize filename vers
    LAST_FILENAME="${DB}-$(date +%Y%m%d-%H%M%S)${BACKUP_SUFFIX}"
    DAILY_FILENAME="${DB}-$(date +%Y%m%d)${BACKUP_SUFFIX}"
    WEEKLY_FILENAME="${DB}-$(date +%G%V)${BACKUP_SUFFIX}"
    MONTHY_FILENAME="${DB}-$(date +%Y%m)${BACKUP_SUFFIX}"
    FILE="${BACKUP_DIR}/last/${LAST_FILENAME}"
    DFILE="${BACKUP_DIR}/daily/${DAILY_FILENAME}"
    WFILE="${BACKUP_DIR}/weekly/${WEEKLY_FILENAME}"
    MFILE="${BACKUP_DIR}/monthly/${MONTHY_FILENAME}"
    #Create dump
    export PGPASSWORD="$POSTGRESQL_PASSWORD"
    echo "Creating cluster dump of ${DB} database from ${POSTGRESQL_HOST}..."
    pg_dump --host="$POSTGRESQL_HOST" \
            --port="$POSTGRESQL_PORT" \
            --username="$POSTGRESQL_USER" \
            --dbname="$DB" | gzip > "$FILE"
    #Copy (hardlink) for each entry
    if [ -d "${FILE}" ]; then
        DFILENEW="${DFILE}-new"
        WFILENEW="${WFILE}-new"
        MFILENEW="${MFILE}-new"
        rm -rf "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
        mkdir "${DFILENEW}" "${WFILENEW}" "${MFILENEW}"
        ln -f "${FILE}/"* "${DFILENEW}/"
        ln -f "${FILE}/"* "${WFILENEW}/"
        ln -f "${FILE}/"* "${MFILENEW}/"
        rm -rf "${DFILE}" "${WFILE}" "${MFILE}"
        echo "Replacing daily backup ${DFILE} folder this last backup..."
        mv "${DFILENEW}" "${DFILE}"
        echo "Replacing weekly backup ${WFILE} folder this last backup..."
        mv "${WFILENEW}" "${WFILE}"
        echo "Replacing monthly backup ${MFILE} folder this last backup..."
        mv "${MFILENEW}" "${MFILE}"
    else
        echo "Replacing daily backup ${DFILE} file this last backup..."
        ln -vf "${FILE}" "${DFILE}"
        echo "Replacing weekly backup ${WFILE} file this last backup..."
        ln -vf "${FILE}" "${WFILE}"
        echo "Replacing monthly backup ${MFILE} file this last backup..."
        ln -vf "${FILE}" "${MFILE}"
    fi
    # Update latest symlinks
    echo "Point last backup file to this last backup..."
    ln -svf "${LAST_FILENAME}" "${BACKUP_DIR}/last/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest daily backup to this last backup..."
    ln -svf "${DAILY_FILENAME}" "${BACKUP_DIR}/daily/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest weekly backup to this last backup..."
    ln -svf "${WEEKLY_FILENAME}" "${BACKUP_DIR}/weekly/${DB}-latest${BACKUP_SUFFIX}"
    echo "Point latest monthly backup to this last backup..."
    ln -svf "${MONTHY_FILENAME}" "${BACKUP_DIR}/monthly/${DB}-latest${BACKUP_SUFFIX}"
    #Clean old files
    echo "Cleaning older files for ${DB} database from ${POSTGRESQL_HOST}..."
    find "${BACKUP_DIR}/last" -maxdepth 1 -mmin "+${KEEP_MINS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/daily" -maxdepth 1 -mtime "+${KEEP_DAYS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/weekly" -maxdepth 1 -mtime "+${KEEP_WEEKS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
    find "${BACKUP_DIR}/monthly" -maxdepth 1 -mtime "+${KEEP_MONTHS}" -name "${DB}-*${BACKUP_SUFFIX}" -exec rm -rvf '{}' ';'
done

echo "SQL backup created successfully"

# Post-backup hook
if [ -d "${HOOKS_DIR}" ]; then
    run-parts -a "post-backup" --reverse --exit-on-error "${HOOKS_DIR}"
fi
