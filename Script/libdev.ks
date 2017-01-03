@lazyglobal off.
print "  Loading libdev".

global gDebug is 0.
function deb {
    parameter str.
    //  if gDebug=0 set gDebug to Time:Seconds.
    // local rdvTime is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
    // local v0 is (VelocityAt(Ship, rdvTime):Orbit- VelocityAt(Target, rdvTime):Orbit):Mag.
    print "  deb "+str.
    //print "   warp=" +Warp +" " +WarpMode.
    print 1/0.
}

// ====  AutoStart =======
// debug hook: this code is called before the other libraries are loaded
switch to 0.
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
// =======================

function dynWarp {
    parameter errFactor is 1.
    //print "pErr="+Round(SteeringManager:PitchError, 2) at (38,16).
    //print "yErr="+Round(SteeringManager:YawError,   2) at (38,17).
    //print "angV="+Round(Ship:AngularVel:Mag,        2) at (38,18).
    //print "pI  ="+Round(SteeringManager:PitchPID:ErrorSum, 2) at (38,19).
    //print "yI  ="+Round(SteeringManager:YawPID:ErrorSum,   2) at (38,20).
    //print "pC  ="+Round(SteeringManager:PitchPID:ChangeRate, 2) at (38,21).
    //print "yC  ="+Round(SteeringManager:YawPID:ChangeRate,   2) at (38,22).
    local err is (Abs(SteeringManager:PitchPID:ChangeRate)
                + Abs(SteeringManager:YawPID:ChangeRate))/errFactor.
    //print "err ="+Round(err,3) at (38,23).
    set WarpMode to "PHYSICS".
    if (err>0.3) set Warp to 0.
    else if (err>0.1) set Warp to 1.
    else if (err>0.03) set Warp to 2.
    else set Warp to 3.
}
