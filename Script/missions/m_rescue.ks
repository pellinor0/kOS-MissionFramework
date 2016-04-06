// Assumptions
// * target orbit is equatorial and circular
set gTgtVesselName to "rescue".
if (Ship:Name <> gTgtVesselName) // can't do this when docked to target Vessel
  set Target to Vessel(gTgtVesselName).

m_waitForLaunchWindow().
m_ascentLKO().

m_hohmannToTarget().

m_fineRdv().

wait 1000.
m_rendezvousDock().

m_askConfirmation("Next step is return to Kerbin").
set Target to "".
