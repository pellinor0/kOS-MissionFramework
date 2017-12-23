print "m_kss".
local tgtPlane is V(0,0,0).
if (Ship:Name <> gTgtVesselName) // can't do this when docked to target Vessel
{
  setTarget(gTgtVesselName).
  set tgtPlane to getOrbitNormal(Target).
  Brakes On. Wait 0.8.
}
m_waitForLaunchWindow().
if (HasTarget) set tgtPlane to getOrbitNormal(Target).
m_ascentLKO(tgtPlane).

m_hohmannToTarget().
m_fineRdv().
m_rendezvousDock().

//m_askConfirmation("Next step is return to Kerbin").
//m_undock().
//m_landFromLKO().
