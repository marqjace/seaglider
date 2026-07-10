#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

PYTHON="/home/server/hpc/grg/pixi_env/.pixi/envs/default/bin/python"
SCRIPT="/home/server/pi/homes/marqjace/grg/seaglider-raw/software/scripts/sg_to_IOOS.py"
BASE_DIR="/home/server/pi/homes/marqjace/grg/seaglider-raw"

FTP_URL="ftp://gliders.ioos.us/sg266-20260313T0916/"
LOG_FILE="/home/server/pi/homes/marqjace/grg/seaglider-raw/software/logs/sync.log"

for GLIDERDAC_DIR in "$BASE_DIR"/*_sg*/real-time/gliderdac; do
    LAST_SYNC="$GLIDERDAC_DIR/.last_sync" 

    # skip if no match
    [ -d "$GLIDERDAC_DIR" ] || continue

    COMPLETED_FILE="$(dirname "$GLIDERDAC_DIR")/.completed"

    if [[ ! -f "$COMPLETED_FILE" ]]; then
        continue
    fi

    last_sync_t=0
    if [[ -f "$LAST_SYNC" ]]; then
        last_sync_t=$(stat -c '%Y' "$LAST_SYNC")
    fi

    last_complete_t=$(stat -c '%Y' "$COMPLETED_FILE")

    if (( last_complete_t > last_sync_t )); then

        echo "Sync $(date -u +%Y%m%d%H%M%S)" >> "$LOG_FILE" 2>&1

        "$PYTHON" "$SCRIPT" -i "$GLIDERDAC_DIR" >> "$LOG_FILE" 2>&1

	
	
    PROC_DIR="$GLIDERDAC_DIR/gliderdac_proc"

    for f in "$PROC_DIR"/*.nc; do
      [ -e "$f" ] || continue

      file_t=$(stat -c '%Y' "$f")

      if (( file_t > last_sync_t )); then
        echo "Uploading $f" >> "$LOG_FILE"

        if curl --netrc \
                --ssl-reqd \
                --ftp-create-dirs \
                --fail --silent --show-error \
                --retry 3 --retry-delay 5 \
                -T "$f" "$FTP_URL"; then

          touch -d "@$file_t" "$LAST_SYNC"
          last_sync_t=$file_t

        fi
      fi
    done


    fi

done
