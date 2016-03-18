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
    local lngErr is 1000.
    local t2 is 0.
    until Abs(lngErr)<0.1 {
        //print " Iteration".
        set t2 to timeToAltitude2(tgtHeight, 
                                    Time:Seconds+NextNode:Eta,
                                    Time:Seconds+NextNode:Eta+NextNode:Orbit:Period/2).
        local lng1 is Body:GeoPositionOf(PositionAt(Ship,t2)):Lng.
        local lng2 is tgtPos:lng+ 360*(t2-Time:Seconds)/Body:RotationPeriod.
        set lngErr to lng1-lng2.
        if (lngErr < -180) set lngErr to lngErr+360.
        local dt is -lngErr*synPeriod/360.
        //print "  t2="+Round(t2-Time:Seconds).
        //print "  lngErr="+Round(lngErr, 2).
        //print "  dt=" +Round(dt).
        set NextNode:Eta to NextNode:Eta +dt.
        if NextNode:Eta<0 
          set NextNode:Eta to NextNode:Eta+synPeriod.
        else if NextNode:Eta>synPeriod 
          set NextNode:Eta to NextNode:Eta-synPeriod.
          
        wait 0.01.
    }    
    
    //print "  tweak inclination".
    local frame is AngleAxis((t2-Time:Seconds)*360/Body:RotationPeriod, V(0,1,0)).
    local p2 is -frame*(tgtPos:Position-Body:Position).
    local normal is Vcrs(p2, PositionAt(Ship,Time:Seconds+NextNode:Eta)-Body:Position).
    //if Vdot(normal,)<0 set normal to -normal.
    tweakNodeInclination(normal, -1).
}

function aeroBrake {
    
}

run once libnav.
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

// Workaround for compiling functions 
//   that lock Steering and Throttle
function lockSteering {
    parameter x. // global variable or lock
    lock Steering to x().
}
function lockThrottle {
    parameter x. // global variable or lock
    lock Throttle to x().
}
function lockThrottleFull { lock Throttle to 1.}
function unlockSteering   { unlock Steering. }
function unlockThrottle   { unlock Throttle. }

