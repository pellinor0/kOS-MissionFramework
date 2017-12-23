// a short peek into the sun's SOI, starting from KSS
m_undock().

if missionStep() {
  print " Escape burn".
  if not HasNode nodeUnCircularize(Body:SoiRadius*1.2, Time:Seconds+500).
  execNode().
  print "  vel at escape: "+VelocityAt(Ship,Eta:Transition-10).
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
    add node(Time:Seconds+100,0,0,0).
    setNextNodeDV().
  }
  askConfirmation().
  if HasNode execNode().
}

// wait for intercept
m_waitForTransition("INTERCEPT").

// find back to KSS
