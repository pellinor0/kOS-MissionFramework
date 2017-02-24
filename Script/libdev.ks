@lazyglobal off.
print "  Loading libdev".
if (Ship:ElectricCharge<1) { Core:Deactivate. }
switch to 0.

// ====  AutoStart =======
// debug hook: this code is called before the other libraries are loaded

//until (not hasnode) remove nextnode.
//if HasNode remove NextNode.
//print "== refresh mission file ==". CopyPath("0:missions/m_ast.ks", "1:mission.ks").
//log "set pMissionCounter to pMissionCounter+1." to "1:/persistent.ks".
//log "set pMissionCounter to 5." to "1:/persistent.ks".
//wait 1000.


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
