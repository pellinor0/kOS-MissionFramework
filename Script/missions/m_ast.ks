// asteroid intercept
setTarget("Ast1").
//m_fillTanks(false).
//m_undock().

if missionStep() {
  local o is Target:Orbit.
  local oo is Target:Orbit:NextPatch.
  local t0 is Time:Seconds+o:NextPatchEta.
  local t1 is Time:Seconds+oo:NextPatchEta.
  print "  Eta:Transition="+Round(o:NextPatchEta/21600) + "d / " +Round(oo:NextPatchEta/21600) +"d".
  print "  PE="+Round(oo:Periapsis).
  print "  velPE=" +Round(VelocityAt(Target, (t0+t1)/2):Orbit:Mag).
  print "  excessVel=" +Round(VelocityAt(Target,t0+100):Orbit:Mag).

 if not HasNode{
  print " node in general direction". // assume start in near-equatorial circular orbit
  add Node(Time:Seconds + Orbit:Period, 0,0,1000).
  local p1 is PositionAt(Target, t0+100).
  local p2 is PositionAt(Ship, Time:Seconds+NextNode:Orbit:NextPatchEta-100).
  local lngDiff is Mod(Body:GeoPositionOf(p1):Lng -Body:GeoPositionOf(p2):Lng +360, 360).
  print "  p1="+vecToString(p1).
  print "  p2="+vecToString(p2).
  print "  lng1="+Round(Body:GeoPositionOf(p1):Lng,2).
  print "  lng2="+Round(Body:GeoPositionOf(p2):Lng,2).
  print "  lngDiff="+Round(lngDiff,2).
  print "  ang="+Vang(p1-Body:Position, p2-Body:Position).
  debugVecOff().
  debugVec(1, "p1", p1).
  debugVec(2, "p2", p2).
  set NextNode:Eta to NextNode:Eta + Obt:Period*lngDiff/360.
  set p1 to PositionAt(Target, t0+100).
  set p2 to PositionAt(Ship, Time:Seconds+NextNode:Orbit:NextPatchEta-100).
  print "  ang="+Vang(p1-Body:Position, p2-Body:Position).
  askConfirmation().
 }
  local rdvTime is Time:Seconds +Target:Orbit:NextPatchEta/2.
  local i is 0.
  until (i>=50) { refineRdvBruteForce(rdvTime). set i to i+1. print "i   =" +i at (38,0). }
  askConfirmation().

  execNode().
}

if missionStep() {
  add Node(Time:Seconds+6*3600).
  local rdvTime is Time:Seconds +Target:Orbit:NextPatchEta/2.
  refineRdvBruteForce(rdvTime).
  refineRdvBruteForce(rdvTime).
  refineRdvBruteForce(rdvTime).
  askConfirmation().

  execNode().
}

//if missionStep() {
//  print "  adjust plane".
//  local tAP is Time:Seconds+Eta:Apoapsis.
//  local tgtNormal is Vcrs(PositionAt(Ship,tAP)-Body:Position, PositionAt(Target,t0)-Body:Position).
//  add Node (tAP,0,0,0).
//  tweakNodeInclination(tgtNormal, -1).
//}
