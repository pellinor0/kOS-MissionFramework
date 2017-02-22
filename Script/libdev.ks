@lazyglobal off.
print "  Loading libdev".
if (Ship:ElectricCharge<1) { Core:Deactivate. }
switch to 0.

// ====  AutoStart =======
// debug hook: this code is called before the other libraries are loaded

//until (not hasnode) remove nextnode.
//wait 1000.
//print "== refresh mission file ==". CopyPath("0:missions/m_moon.ks", "1:mission.ks").
//wait 1000.
//log "set pMissionCounter to pMissionCounter+1." to "1:/persistent.ks".


//print "  compiling libbasic".   compile libbasic.
//print "  compiling libatmo".    compile libatmo.
//print "  compiling liborbit".   compile liborbit.
//print "  compiling libnav".     compile libnav.
//print "  compiling libmission". compile libmission.
//print "  compiling librdv".     compile librdv.
//print "  compiling libsystem".  compile libsystem.
//print "  compiling libsetup".   compile libsetup.
//print "  compiling globals".    compile globals.
//print "  compiling boot".       compile "boot/boot.ks".
//print "  copying bootFile".     CopyPath("0:/boot/boot.ksm","1:/boot/").
// =======================

//run once libmission.
//setTarget("Ast1").
//print "Target: Ast1".
//local o is Target:Orbit.
//local oo is Target:Orbit:NextPatch.
//local t0 is Time:Seconds+o:NextPatchEta.
//local t1 is Time:Seconds+oo:NextPatchEta.
//print "  Eta:Transition="+Round(o:NextPatchEta/21600) + "d / " +Round(oo:NextPatchEta/21600) +"d".
//print "  PE="+Round(oo:Periapsis).
//print "  velPE=" +Round(VelocityAt(Target, (t0+t1)/2):Orbit:Mag).
//print "  excessVel=" +Round(VelocityAt(Target,t0+100):Orbit:Mag).
//Core:Deactivate.
