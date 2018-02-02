// a short peek into the sun's SOI, starting from KSS
m_fillTanks(true, 700).
m_undock().

if missionStep() {
  print " Escape burn".
  if not HasNode nodeUnCircularize(Body:SoiRadius*1.2, Time:Seconds+500).
  execNode().
  print "  vel at escape: "+VecToString(VelocityAt(Ship,Eta:Transition-10):Orbit).
}
m_waitForTransition("ESCAPE").
if missionStep() {
  print " Arrived at parent SOI".
  askConfirmation().
}
// burn back
if missionStep() {
  print "burn back".
  if not HasNode {
    add node(Time:Seconds+100,0,0,0). wait 0.
    local homeDir is (Body("Gael"):Position-Ship:Position):Normalized.
    //debugVec(1, "homeDir", homeDir*10000).
    local dV is Body("Gael"):Velocity:Orbit-Ship:Velocity:Orbit.
    //print "  v1="+Body("Gael"):Velocity:Orbit:Mag.
    //print "  v2="+Ship:Velocity:Orbit:Mag.
    //print "  dV="+dV:Mag.
    //debugVec(2, "dV", dV:Normalized*10000).
    setNextNodeDV( -getOrbitFacing(Ship, Time:Seconds+100)*(2*Vdot(dV,homeDir)*homeDir) ).
  }
  askConfirmation().
  if HasNode execNode().
}

// wait for intercept
m_waitForTransition("Encounter").

// find back to KSS
setTarget("KSS").
m_matchPlane().
m_returnFromHighOrbit().
m_fineRdv().
m_fineRdv().
m_rendezvousDock().
