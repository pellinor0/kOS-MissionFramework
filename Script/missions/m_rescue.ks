// Assumptions
// * target orbit is roughly equatorial and circular
m_fillTanks(true, 120).
m_undock().

findRescueTarget().
if not HasTarget {
  print " no target => skip rescue and return home".
  set gMissionCounter to gMissionCounter+5.
}
m_fastTransferToTarget().
m_fineRdv().
m_fineRdv().
m_rendezvousDock().
//m_grabWithClaw(V(0,1,0)). // for ranger modules
m_grabWithClaw().

//m_askConfirmation("Next step is return to KSS").
setTarget("KSS").
m_fastTransferToTarget().
m_fineRdv().
m_fineRdv().
m_rendezvousDock().
