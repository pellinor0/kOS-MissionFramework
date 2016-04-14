@lazyglobal off.
//print "  Loading libsystem".

function loadPersistent {
    log "" to persistent.ks.
    run persistent.ks.
}

function writePersistent {
    log "" to "persistent.ks".
    delete "persistent.ks".
    log "set pMissionCounter to " +pMissionCounter +"." to persistent.ks.
}

function runFile {
    parameter path.
    parameter fileName.

    switch to 0.
    copy path+fileName to 1.
    switch to 1.
    rename fileName to tmp.ks.
    run tmp.ks.
    delete tmp.ks.
}
