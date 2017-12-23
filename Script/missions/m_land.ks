// spaceplane landing from LKO
if missionStep() { if (Ship:Status<>"ORBITING") shutDownCore(). }

if missionStep() if (Ship:Name="KSS") {
  print " transfer resources".
  transferResource("ExoticMinerals").
  transferResource("MonoPropellant", false).
  transferResource("LiquidFuel").
  transferResource("Oxidiser").

  // decouple
  findClosest(Ship:PartsDubbed(gShipType+"Decoupler"), Core:Part):geTModule("ModuleAnchoredDecoupler"):DoEvent("Decouple").
  wait 0.5.

  // controlFromHere
  KUniverse:ForceSetActiveVessel(Core:Vessel).
  wait 0.5.
  setControlPart().
  //askConfirmation().

  // warp to safe distance
  warpRails(Time:Seconds+15).
}
//m_askConfirmation("Please prepare the ship for landing").
//set gDoLog to 0.
if (Ship:AvailableThrust=0) stage.
m_landFromLKO(true).

if missionStep() {
    local lngErr is GeoPosition:Lng - gSpacePort:Lng.
    local newLandingPA is Round(gLandingPA -lngErr, 3).
    print "  optimalLandingPA=" +newLandingPA.
    switch to 0.
    log ("set gLandingPA to " +newLandingPA +".") to logFile.
}
