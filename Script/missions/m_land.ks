// spaceplane landing from LKO
if missionStep() { if (Ship:Status<>"ORBITING") shutDownCore(). }

if missionStep() if (Ship:Name="KSS") {
  print " transfer resources".
  transferResource("ExoticMinerals").
  transferResource("MonoPropellant", false).
  transferResource("LiquidFuel").
  transferResource("Oxidizer").

  // decouple
  findClosest(Ship:PartsDubbed(gShipType+"Decoupler"), Core:Part):geTModule("ModuleAnchoredDecoupler"):DoEvent("Decouple").
  wait 0.5.

  // controlFromHere
  KUniverse:ForceSetActiveVessel(Core:Vessel).
  wait 0.5.
  setControlPart().
  if Ship:PartsDubbed(gShipType+"Tank")[0]:HasModule("ModuleReactionWheel"){
    print "  turn down reaction wheel".
    Ship:PartsDubbed(gShipType+"Tank")[0]:GetModule("ModuleReactionWheel"):SetField("wheel authority", 25).
  }

  // warp to safe distance
  SET SHIP:CONTROL:PITCH TO -1.
  wait 2.
  SET SHIP:CONTROL:NEUTRALIZE to True.
  warpRails(Time:Seconds+30).

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
