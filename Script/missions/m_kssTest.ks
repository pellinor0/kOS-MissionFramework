// Assumptions
// * target orbit is equatorial and circular
print "m_kssTest".
local tgtPlane is V(0,0,0).
if (Ship:Name <> gTgtVesselName) // can't do this when docked to target Vessel
{
  setTarget(gTgtVesselName).
  //set Target to Vessel(gTgtVesselName).
  //wait 0.
  if (not HasTarget) { deb("m_kssTest:9").}
  set tgtPlane to getOrbitNormal(Target).
}
Brakes On. Wait 0.8.
m_waitForLaunchWindow().
if (HasTarget) set tgtPlane to getOrbitNormal(Target).
m_ascentLKO(tgtPlane).

m_hohmannToTarget().
m_fineRdv().
m_rendezvousDock().

m_askConfirmation("Next step is return to Kerbin").
m_undock().
m_landFromLKO().
