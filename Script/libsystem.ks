@lazyglobal off.
//print "  Loading libsystem".

function loadPersistent {
    log "" to "1:/persistent.ks".
    RunPath("1:/persistent.ks").
}

function writePersistent {
    log "" to "1:/persistent.ks".
    DeletePath("1:/persistent.ks").
    log "set pMissionCounter to " +pMissionCounter +"." to "1:/persistent.ks".
}

function runFile {
    parameter path.
    parameter fileName.

    CopyPath(path+fileName, "1:/").
    local tgtFile is "1:/tmp.ks".
    MovePath("1:/"+fileName, tgtFile).
    RunPath(tgtFile).
    DeletePath(tgtFile).
}
