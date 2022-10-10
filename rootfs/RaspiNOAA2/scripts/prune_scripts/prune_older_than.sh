#!/bin/bash
#
# Purpose: Prunes (removes) all captures older than $PRUNE_OLDER_THAN days old, including
#          database records and associated images/files on disk.

# import common lib and settings
source "$NOAA_HOME/.noaa-v2.conf"
source "$NOAA_HOME/scripts/common.sh"

#Generate date since epoch in seconds - days
let prunedate=$(date +%s)-$PRUNE_OLDER_THAN*24*60*60

log "Pruning captures..." "INFO"
for img_path in $(sqlite3 ${DB_FILE} "select file_path from decoded_passes where pass_start < $prunedate;"); do
    find "${IMAGE_OUTPUT}/" -maxdepth 1 -type f -name '${img_path}*.jpg' -exec rm -f {} \;
    find "${IMAGE_OUTPUT}/thumb/" -maxdepth 1 -type f -name '${img_path}*.jpg' -exec rm -f {} \;
    log "  ${img_path} file pruned" "INFO"
    sqlite3 "${DB_FILE}" "delete from decoded_passes where file_path = \"$img_path\";"
    log "  Database entry pruned" "INFO"
done

log "Pruning recordings, if any..." "INFO"
find "${NOAA_AUDIO_OUTPUT}/"  -maxdepth 1 -mtime +$PRUNE_OLDER_THAN -exec rm {} \;
find "${METEOR_AUDIO_OUTPUT}/"  -maxdepth 1 -mtime +$PRUNE_OLDER_THAN -exec rm {} \;

# the pruning of images should already have been done in the "for" loop above, but sometimes it doesn't work...
# consider the following 2 command "safety overrides" that will make sure that the system is really cleaned up.
find "${IMAGE_OUTPUT}/" -maxdepth 1 -type f -mtime +$PRUNE_OLDER_THAN -exec rm -f {} \;
find "${IMAGE_OUTPUT}/thumb/" -maxdepth 1 -type f -mtime +$PRUNE_OLDER_THAN -exec rm -f {} \;
log "Done pruning recordings" "INFO"
