if not HasTarget setTarget("t1").
//set gLkoAP to 90000.
m_waitForLaunchWindow().
set tgtPlane to getOrbitNormal(Target).
m_ascentLKO(tgtPlane).

//m_hohmannToTarget(-1).
//m_fastTransferToTarget().
//m_fineRdv().
m_fineRdv().
m_rendezvousDock().
