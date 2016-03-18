// Assumptions
// * target orbit is equatorial and circular
run once librdv.
if (Ship:Name <> tgtVesselName) // can't do this when docked to target Vessel
  set Target to Vessel(tgtVesselName). 

m_waitForLaunchWindow().
m_ascentLKO().

m_hohmannToTarget().

m_fineRdv().

m_rendezvousDock().

m_askConfirmation("Next step is return to Kerbin").

if missionStep() {
    m_waitForDeorbitWindow().
}
if missionStep() {
    m_undock().
    set Target to "".
}

m_landFromLKO().
