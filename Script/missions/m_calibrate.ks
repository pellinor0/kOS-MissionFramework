set gDoLog to 1.
set landingPA to -25.
set spacePort to LatLng(-0.04909, -74.697). // KSC runway 09
set spacePortHeight to 0.
{ // separate context so we can have local variables
local logFile is "logs/log_"+gShipType +".ks".

if missionStep() {
    print "Delete old logfile".
    switch to 0.
    log "" to logFile.
    delete logFile.
    local controlPart is Ship:PartsDubbed(gShipType+"Control")[0].
    set gGearHeight to Round(Vdot(controlPart:Position, Up:Vector)+Altitude 
                                  -GeoPosition:TerrainHeight, 2).
    print "  gearHeight from control part:" +gGearHeight.
    log "set gGearHeight to " +gGearHeight +"." to logFile.
}
local launchTime is Time:Seconds.
local launchLng is Ship:GeoPosition:Lng.
m_ascentLKO().

if missionStep() {
    local timeDiff is Time:Seconds - launchTime.
    local angleDiff is GeoPosition:Lng-launchLng.
    print "  launchDuration="+Round(timeDiff, 2).
    print "  launchAngle   ="+Round(angleDiff,2).
    switch to 0.
    log "set gLaunchDuration to "+Round(timeDiff, 2)+"." to logFile.
    log "set gLaunchAngle to "   +Round(angleDiff,2)+"." to logFile.
    printFuelLeft().
}

//m_askConfirmation("Please prepare the ship for landing").
m_landFromLKO().

if missionStep() {
    local lngErr is GeoPosition:Lng - spacePort:Lng.
    local newLandingPA is Round(landingPA -lngErr, 3).
    print "  optimalLandingPA=" +newLandingPA.
    log ("set landingPA to " +newLandingPA +".") to logFile.
}

}// end file context
