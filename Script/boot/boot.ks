Core:DoEvent("open terminal").
clearscreen.
set Terminal:Height to 68.
set Terminal:Width to 55.
switch to 0.
print "Boot".

run once libdev.

run once globals.
run once libsystem.

local tmp is Core:Part:Tag:Split(" ").
set gShipType to tmp[0].
if(not Exists("1:/params.ks")) {
    run once libsetup. copyParams().
}
if(tmp:Length>1){
    run once libsetup. setupMission(tmp).
}

RunPath("1:/params.ks").
loadPersistent().
writePersistent().

if (pMissionCounter > 0) {
    setControlPart().
    run once libmission.
    resumeMission().
} else {
    print "  No active mission".
    shutDownCore().
}
