// Assumptions
// * target orbit is equatorial and circular
print "m_kssTest".
if (Ship:Name <> gTgtVesselName) // can't do this when docked to target Vessel
  set Target to Vessel(gTgtVesselName).

m_waitForLaunchWindow().
m_ascentLKO().

m_hohmannToTarget().
m_fineRdv().
m_rendezvousDock().

m_askConfirmation("Next step is return to Kerbin").
m_undock().
m_landFromLKO().
