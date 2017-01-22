// functions that are only used on the first boot
@lazyglobal off.
//print "  Loading libsetup".

function copyParams {
    print "  Initial configuration".
    print "  shipType=" +gShipType.
    local paraFile is "params_" +gShipType +".ks".
    if Exists("1:/params.ks") {
      DeletePath("1:/params.ks").
    }
    CopyPath("0:params/"+paraFile, "1:/").
    MovePath("1:/"+paraFile, "1:/params.ks").
}

function setupMission {
    parameter nameList.

    set Core:Part:Tag to gShipType.
    if (nameList:Length > 2) print "  WARNING: Core tag has more than 2 words!".
    if (nameList:Length > 1) {
        print "  Starting mission: "+nameList[1].
        RunOncePath("0:/libmission").
        prepareMission(nameList[1]).
    }
}
