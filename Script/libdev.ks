@lazyglobal off.
print "  Loading libdev".

function nodeDeorbit {
    parameter tgtPos. // GeoCoord
    parameter tgtHeight.
    parameter tgtPE.
    // Make a node with tgtPE such that my altitude at tgtPos is tgtHeight
    // Assumption: start in circular orbit
    
    //print " nodeDeorbit".
    nodeUnCircularize(tgtPE,Time:Seconds).
    wait 0.01.
    //print "  HasNode="+HasNode.
    //print "  eta="+Round(NextNode:Eta, 2).
    //print "  dv ="+Round(NextNode:DeltaV:Mag, 2).
    
    local synPeriod is 1/ (1/Obt:Period - 1/Body:RotationPeriod).
    //set synPeriod to 2*Orbit:Period -synPeriod.  // correction if Retrograde
    //print "  period   ="+Round(Obt:Period).
    //print "  synPeriod="+Round(synPeriod).
    //print "  rotPeriod="+Round(Body:RotationPeriod).
    local lngErr is 1000.
    local t2 is 0.
    local counter is 0.
    until Abs(lngErr)<0.1 or counter>6 {
        //print " Iteration".
        set t2 to timeToAltitude2(tgtHeight, 
                                    Time:Seconds+NextNode:Eta,
                                    Time:Seconds+NextNode:Eta+NextNode:Orbit:Period/2).
        local lng1 is Body:GeoPositionOf(PositionAt(Ship,t2)):Lng.
        local lng2 is tgtPos:lng +360*(t2-Time:Seconds)/Body:RotationPeriod.
        set lngErr to lng1-lng2.
        if (lngErr < -180) set lngErr to lngErr+360.
        local dt is -(lngErr/360)*synPeriod.
        //print "  t2="+Round(t2-Time:Seconds).
        //print "  lngErr="+Round(lngErr, 2).
        //print "  lngDelta="+Round(360*(t2-Time:Seconds)/Body:RotationPeriod).
        //print "  dt=" +Round(dt).
        set NextNode:Eta to NextNode:Eta +dt.
        if NextNode:Eta<0 
          set NextNode:Eta to NextNode:Eta+synPeriod.
        else if NextNode:Eta>synPeriod 
          set NextNode:Eta to NextNode:Eta-synPeriod.
          
        set counter to counter+1.
        wait 0.01.
    }
    
    //print "  tweak inclination".
    local frame is AngleAxis((t2-Time:Seconds)*360/Body:RotationPeriod, V(0,1,0)).
    local p2 is (-frame) * (tgtPos:Position-Body:Position).
    local normal is Vcrs(p2, PositionAt(Ship,Time:Seconds+NextNode:Eta)-Body:Position).
    //if Vdot(normal,)<0 set normal to -normal.
    tweakNodeInclination(normal, -1).
}

function aeroBrake {
    
}

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


global gDebug is 0.
function deb {
    parameter str.
    
//     if gDebug=0 set gDebug to Time:Seconds.
//     local rdvTime is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
//     local v0 is (VelocityAt(Ship, rdvTime):Orbit- VelocityAt(Target, rdvTime):Orbit):Mag.
//     print "  deb "+str
//         +": dX="
//         +Round((PositionAt(Ship,rdvTime)-PositionAt(Target,rdvTime)):Mag) 
//         +", dV="+Round(v0,1) 
//         +", t=" +Round(rdvTime-gDebug) 
//         +", dt="+Round(rdvTime-Time:Seconds).
}


// ====  AutoStart =======
// debug hook: this code is called before other things run

//print " AutoStart".
switch to 0.
//wait 1.

print "  compiling libbasic".   compile libbasic.
//print "  compiling libatmo".    compile libatmo.
print "  compiling liborbit".   compile liborbit.
//print "  compiling libnav".     compile libnav.
print "  compiling libmission". compile libmission.
print "  compiling librdv".     compile librdv.
//compile libsystem.
//compile globals.



