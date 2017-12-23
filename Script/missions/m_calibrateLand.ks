set gDoLog to 1.
set gLandingPA to -40.
set gSpacePort to LatLng(0, 200). // Gael Ocean
set gSpacePortHeight to 0.
{ // separate context so we can have local variables
local logFile is "0:/logs/log_"+gShipType +".ks".

if (Status = "PRELAUNCH") askConfirmation().

if missionStep() {
    stage.
    print "Delete old logfile".
    switch to 0.
    log "" to logFile.
    DeletePath(logFile).
    //local controlPart is Ship:PartsDubbed(gShipType+"Control")[0].
    //set gGearHeight to Round(Vdot(controlPart:Position, Up:Vector)+Altitude
    //                              -GeoPosition:TerrainHeight, 2).
    //print "  gearHeight from control part:" +gGearHeight.
    //log "set gGearHeight to " +gGearHeight +"." to logFile.
}
//local launchTime is Time:Seconds.
//local launchLng is Ship:GeoPosition:Lng.

//m_askConfirmation("Please prepare the ship for landing").
m_landFromLKO(false).

if missionStep() {
    local lngErr is GeoPosition:Lng - gSpacePort:Lng.
    local newLandingPA is Round(gLandingPA -lngErr, 3).
    print "  optimalLandingPA=" +newLandingPA.
    switch to 0.
    log ("set gLandingPA to " +newLandingPA +".") to logFile.
}

}// end file context
