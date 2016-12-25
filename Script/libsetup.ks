// functions that are only used on the first boot
@lazyglobal off.
//print "  Loading libsetup".

function copyParams {
    // params.ks
    //local fileList is List().
    local paraFile is "params_" +gShipType +".ks".
    //print "  "+paraFile.
    log "" to "1:/params.ks".
    DeletePath("1:/params.ks").
    CopyPath("0:params/"+paraFile, "1:/").
    MovePath("1:/"+paraFile, "1:/params.ks").
}

function doInitialSetup {
    parameter nameList.

    print "  Initial configuration".
    print "  shipType=" +gShipType.
    copyParams().
    set Core:Part:Tag to gShipType+" xx".
    log "switch to 0. run resume." to "1:/resume.ks".

    if (nameList:Length > 2) print "  WARNING: Core tag has more than 2 words!".
    if (nameList:Length > 1) {
        print "  Initial mission: "+nameList[1].
        RunOncePath("0:/libmission").
        prepareMission(nameList[1]).
    }
}
