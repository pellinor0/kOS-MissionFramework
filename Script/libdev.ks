@lazyglobal off.
print "  Loading libdev".
if (Ship:ElectricCharge<1) { Core:Deactivate. }
switch to 0.

// ====  AutoStart =======
// debug hook: this code is called before the other libraries are loaded


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
