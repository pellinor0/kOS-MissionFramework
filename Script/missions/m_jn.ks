if missionStep() {
  fillTanksToDeltaV(2000).
}
m_undock().
if (Body<>Body("Jannah") and not HasTarget) setTarget(Body("Jannah")).
print "  body="+Body.
print "  hasTarget="+HasTarget.
if hastarget print "  target="+target.


m_hohmannToTarget(0.1).
m_nodeIncCorr().
m_waitForTransition("ENCOUNTER").
m_capture(20000).

//m_vacLand( Body:GeoPositionOf(Vessel("MinmusTarget"):Position +10*North:Vector) ).
setTarget("JannahBase").
m_vacLand().  //LatLng(4.9,180)). // no param => at TARGET
m_askConfirmation("next step is return to KSS").

// launch to useful orbit
m_vacLaunch(20000).
setTarget("KSS").

// return burn + inc change
m_returnFromMoon().
m_returnFromHighOrbit().
m_fineRdv().
m_fineRdv().
m_rendezvousDock().
