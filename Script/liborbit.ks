@lazyglobal off.
// simple functions you need in space
print "  Loading liborbit".

function launchTimeToRdv {
    parameter launchPhaseAngle. // where the target should be with respect to me
    
    local phaseAngle is Target:Longitude - Longitude. // only works in equatorial orbit
    local waitAngle is (launchPhaseAngle - phaseAngle).
    if (waitAngle < 0) { set waitAngle to waitAngle+360. }
    local synPeriod is 1/ (1/Target:Obt:Period - 1/(6*3600)).
    local launchTime is Time:Seconds +waitAngle/360*synPeriod.
//     print "LaunchTimeToRdv".
//     print "  phaseAngle      =" + phaseAngle.
//     print "  launchPhaseAngle=" + launchPhaseAngle.
//     print "  synPeriod       =" + synPeriod.
//     print "  waitAngle =" + ROUND(waitAngle).
    return launchTime.
}

function nodeCircAtAP {
    local apTime is Time:Seconds + Eta:Apoapsis.
    local circVel is Sqrt(Body:Mu / (Apoapsis + Body:Radius)).
    local dV is circVel - Velocityat(Ship, apTime):Orbit:Mag.
    add Node(apTime,0,0,dV).
}

function nodeUncircularize {
    parameter otherEnd. // new AP or PE
    parameter t.
    // Assumption: this is called at any point where the radial velocity is zero
    //   (i.e. AP, PE, or from circular orbit)
    local v1 is Velocityat(Ship, t):Orbit:Mag.
    local alt is (PositionAt(Ship,t)-Body:Position):Mag. // contains Body:Radius!
    local sma is 0.5*(alt+otherEnd+Body:Radius).
    local v2 is Sqrt(Body:Mu *(2/(alt) - 1/sma)). // vis-viva eq.
    add Node(t,0,0,v2-v1).
    print "nodeUncircularize".
    wait 0.01.
    print "  HasNode="+HasNode.
    print "  eta="+Round(NextNode:Eta, 2).
    print "  dv ="+Round(NextNode:DeltaV:Mag, 2).

    //print "  otherEnd="+Round(otherEnd).
    //print "  v1 =" +Round(v1, 2).
    //print "  v2 =" +Round(v2, 2).
    //print "  sma=" +Round(sma, 2).
    //print "  r  =" +Body:Radius.
    //print "  alt=" +Round(alt, 2).
    //print "  mu =" +Round(Body:Mu,1).
    //print "  eta="+Round(t-Time:Seconds, 2).
    //print "  dv ="+Round(v2-v1, 2).
    wait 0.01.
}

function suicideBurn {
    local acc is Ship:AvailableThrust / Mass.
    if (acc=0) {
        print "  ERROR: suicideBurn: acc=0!".
        return.
    }
    
    local g is Body:Mu/(Body:Radius * Body:Radius).
    if (acc < g) {
        suicideBurnChutes().
        return.
    }
    
    if Altitude>100000 warpRails(timeToAltitude(100000)). // todo: better altitude
    // todo: warp until burn
    set Warp to 0.
    set WarpMode to "PHYSICS".
    set Warp to 3. // 4x
    
    local clearing is 8.
    local lock v to Velocity:Surface.
    local v0 is 0. // touchdown speed
    local hCorr is -0.5*v0*v0/(acc-g). // correction for landing speed
    local height is 0.
    local accNeeded is 0.
    
    local tt is 0.
    lock tt010 to tt.
    lockThrottle(tt010@).
    lockSteering(stSrfRetro@).
    until Status = "LANDED" or Status = "SPLASHED" {
        wait 0.01.
        set height to Altitude - Max(0.01, GeoPosition:TerrainHeight)-clearing +hCorr.
        if (height>0) {
            set accNeeded to (v:SqrMagnitude - v0*v0)/(2*height) + g.
            if (height < 1000) {set Warp to 0.}
        }
        else
          set accNeeded to (v:Mag - v0)*2.
        
        set tt to Max(0, (accNeeded/acc)-0.85)*20. // start at 85%, full at 90%
        
        print "aN  =" +Round(accNeeded, 2) at (38, 0).
        print "acc =" +Round(acc,       2) at (38, 1).
        print "tt  =" +Round(tt,        2) at (38, 2).
        print "h   =" +Round(height,    2) at (38, 3).
    }
    unlockThrottle().
    lockSteering(stUp@).
    //wait 5.
    unlockSteering().
    wait 0.01.
}

function vacAscent {
    parameter tgtAP.
    
    if (Vang(Up:Vector, Facing:ForeVector) > 10) {
        print "  WARNING: vacAscent: not facing up!".
        lockSteering(stUp@).
        wait until Vang(Up:Vector, Facing:ForeVector) > 10.
    }
    
    local lock pp to 90.
    set Warpmode to "PHYSICS".
    set Warp to 1.
    
    //local lock headCorr to -Vdot(vel:Normalized, North:Vector).
    lock st012 to Heading(90,pp). //90+headCorr
    lockSteering(st012@).
    lockThrottleFull().
    local lock apReached to (Apoapsis > tgtAP*0.99).
    
    wait until (VerticalSpeed > 60) or apReached.
    print "  Gravity turn".
    local startAlt is Altitude.
    local lock shape to ((Altitude-startAlt) / (tgtAP-startAlt)) ^0.04.
    local lock pp to 90*(1-shape).
    
    wait until (Apoapsis > 10000) or apReached.
    lockSteering(stPrograde@).
    
    wait until apReached.
    unlockThrottle().
    unlockSteering().
    set Warp to 0.
}

function vacLandAtTgt {
    parameter tgt. // GeoCoordinates
    if(Status = "LANDED" or Status="SPLASHED") return.
        
    local startDv is getDeltaV().
    local tgtHeight is Max(0.01, tgt:TerrainHeight).
    local acc is Ship:AvailableThrust / Mass.
    local g is Body:Mu/(Body:Radius * (Body:Radius +0.1)). // +0.1 = workaround to overflow
    local accFactor is 1.
    if (acc > 10*g) {  // limit TWR for stability
        set accFactor to 10*g/acc.
        set acc to acc*accFactor.
    }
    //print " vacLandAtTgt".
    //print "  tgtHeight="+Round(tgtHeight, 1).
    //print "  tgt=LatLng("+Round(tgt:Lat,3) +", "+Round(tgt:Lng,3)+")".
    //print "  g=" +Round(g,2) +", acc=" +Round(acc,2).
    
    local sBurnHeight is Velocity:Orbit:SqrMagnitude/(0.5*acc-g).
    local nodeHeight is tgtHeight+sBurnHeight/4.
    //print "  nodeHeight="+Round(nodeHeight, 1).
    if (Obt:Periapsis > tgtHeight) {
        // make a node that brings me above the target at the
        //   suicide burn height
        if not HasNode nodeDeorbit(tgt, nodeHeight, -Body:Radius*0.7).
        execNode().
    }
    
    local clearing is 10.
    local height is 1000000.
    local brakeAcc is 0.
    local corrAcc is 0.
    local vSollDir is 0.
    local vErr is 0.
    local v is 0.
    local tt is 0.
    local steerVec is -Velocity:Surface.
    lock st015 to Lookdirup(steerVec, Facing:UpVector).
    lockSteering(st015@).
    lock tt015 to tt.
    lockThrottle(tt015@).
    
    function update {
        wait 0.01.
        set v to Velocity:Surface.
        set height to Altitude - Max(0.01, GeoPosition:TerrainHeight)-clearing.
        set brakeAcc to v:SqrMagnitude/(2*height) + g.
        set vSollDir to (tgt:Position +Up:Vector*(Altitude +3*tgtHeight)/4):Normalized.
        set vErr to Vxcl(vSollDir, v).
        
        // try to negate vErr/10 per second
        set corrAcc to Min(brakeAcc, Sqrt(Min(vErr:Mag/10, acc^2-brakeAcc^2))). 
        set steerVec to -v:Normalized*brakeAcc -vErr:Normalized*corrAcc.
        set tt to Max(0,((steerVec:Mag/acc)-0.4)*5 *accFactor
                        *Vdot(steerVec, Facing:Forevector)).
//         print "bAcc=" +Round(brakeAcc,    2) at (38, 0).
//         print "cAcc=" +Round(corrAcc,     2) at (38, 1).
//         print "sAcc=" +Round(steerVec:Mag,2) at (38, 2).
//         print "tAcc=" +Round(tt/accFactor,2) at (38, 3).
//         print "h   =" +Round(height,      1) at (38, 4).
        print "vErr=" +Round(vErr:Mag,1)+"  "    at (38, 0).
    }

    print " landing burn".
    set WarpMode to "RAILS".
    set Warp to 3. // 50x

    // todo: intermediate correction burn
    //       (still with orbital navigation)
    
    // todo: use suicideBurnCountdown instead of height

    until (height < 10000) update().
    until (height < 20)   {update(). dynWarp(). }
    unlockThrottle().
    suicideBurn().

    local endDv is getDeltaV().
    print "  dvCost  ="+Round(startDv-getDeltaV(), 1).
    print "  posError=" +Round(tgt:Position:Mag,1).

    lockSteering(stUp@).
//     print "  ang="+Round(Vang(Up:Vector, Facing:ForeVector),2)
//          +", vel="+Round(Ship:AngularVel:Mag,2).
    wait until (Vang(Up:Vector, Facing:ForeVector)<1 and Ship:AngularVel:Mag<0.1).
}

// -> libatmo ?
function suicideBurnChutes {
    local tt is 0.
    lock tt019 to tt.
    lockThrottle(tt019@).
    lockSteering(stSrfRetro@).
    local lock height to Altitude - Max(0.01, GeoPosition:TerrainHeight).
    local lock v to Velocity:Surface.
    
    wait until height/v:Mag < 5. // 5 seconds before crash
    set Warp to 0.
    set tt to 1.
    
    until Status = "LANDED" or Status = "SPLASHED" {
        wait 0.01.
        print "  vZ  =" +Round(VerticalSpeed) at (38,0).
    } 
    set tt to 0.
    unlockSteering().
    unlockThrottle().
}

function execNode {
    print "  execNode".
    wait 0.01.
    set Warp to 0.
    local acc is Ship:AvailableThrust / Mass.
    if (acc=0) {
        print "  ERROR: execNode: acc=0!".
        return.
    }
    //print "  Nextnode Eta: " +Round(NextNode:Eta, 2).
    if NextNode:DeltaV:Mag > 9999 {
        print "  WARNING: execNode: suspicious node!".
        print "  dV=" +NextNode:DeltaV:Mag.
    }
    
    local burntime is NextNode:Deltav:Mag / acc.
    
    // print "  orient ship".
    lockSteering(stNode@).
    set WarpMode to "PHYSICS".
    set Warp to 3.
    wait until VectorAngle(Facing:Vector, NextNode:Deltav) < 3.
    set Warp to 0.
    
    // print "warp to node".
    local warpTime is Time:Seconds + NextNode:ETA -burntime/2.
    if(warpTime - Time:Seconds > 21) {
        // node drifts off during warp
        unlockSteering().
        warpRails(warpTime -20).
        lockSteering(stNode@).
        wait until VectorAngle(Facing:Vector, NextNode:Deltav) < 3.
    }
    unlockSteering().
    warpRails(warpTime -2).
    lockSteering(stNode@).
    set WarpMode to "PHYSICS".
    set Warp to 1.

    wait until VectorAngle(Facing:Vector, NextNode:Deltav) < 1.
    wait until NextNode:Eta < (burntime/2) +0.1.
    local origDir is NextNode:Deltav.
    local lock chaseAngle to VectorAngle(origDir, NextNode:Deltav).
    
    lock tt021 to (NextNode:Deltav:Mag / acc / 2).
    lockThrottle(tt021@).

    until (chaseAngle > 60) or (NextNode:Deltav:Mag < 0.05) {
        wait 0.01.
        dynWarp().
        print "tt   ="+Round(tt021, 2)       AT (38,0).
    }.

    if(NextNode:Deltav:Mag > 0.05) { 
        print "  WARNING: execNode: error = "+ Round(NextNode:Deltav:Mag, 3).
        //print "  chaseAngle=" +Round(chaseAngle).
        //print "  origDir=" +origDir.
        //print "  dv=" +NextNode:Deltav.
    }
    //print "  dVErr=" +NextNode:Deltav:Mag.
    unlockThrottle().
    unlockSteering().
    remove NextNode.
    wait 0.01.    
    set Warp to 0.
}

function getPhaseAngle {
    // In the RefFrame of orbit1, I pass angleDiff while timeDiff. 
    // How much phaseAngle have I won/lost with respect to my target in orbit2?
    parameter timeDiff.
    parameter angleDiff.
    parameter period1.
    parameter period2.
    
    local synPeriod is 1/ (1/period1 - 1/period2). // negative if p1 > p2
//     print "getPhaseAngle".
//     print "  timeDiff ="+Round(timeDiff,2).
//     print "  angleDiff="+Round(angleDiff,2).
//     print "  synPeriod="+Round(synPeriod,2).
//     print "  period1  ="+Round(period1,2).
//     print "  period2  ="+Round(period2,2).    
//     print "  Result   ="+Round(angleDiff + (timeDiff/synPeriod)*360 ,2).
    return angleDiff + (timeDiff/synPeriod)*360.
}

function nextNodeExists {   // copied from RAMP
  local sentinel is Node(Time:Seconds + 9999999999, 0, 0, 0).
  add sentinel.
  local nn is Nextnode.
  remove sentinel.
  return (nn <> sentinel).
}

function timeToLng {
    parameter tgtLng.
    
    local waitAngle is tgtLng - GeoPosition:Lng.  // workaround "undefined variable"
    until (waitAngle > 0) {set waitAngle to waitAngle+360. }
    local synPeriod is 1/ (1/Obt:Period - 1/Body:RotationPeriod).    
    local t is Time:Seconds + (synPeriod * (waitAngle / 360.0)).

    return t.
}

// some functions to plug into steering
function stNode     { return LookdirUp(NextNode:Deltav, Up:Vector). }
function stUp       { return LookdirUp(Up:Vector, Facing:UpVector). }
function stPrograde { return LookdirUp(Prograde:Vector, Up:Vector). }
function stSrfRetro { return LookdirUp(-Velocity:Surface, Up:Vector).}
function stRetro    { return Retrograde. }

