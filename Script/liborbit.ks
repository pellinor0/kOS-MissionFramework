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
    // print "LaunchTimeToRdv".
    // print "  phaseAngle      =" + phaseAngle.
    // print "  launchPhaseAngle=" + launchPhaseAngle.
    // print "  synPeriod       =" + synPeriod.
    // print "  waitAngle =" + ROUND(waitAngle).
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
    wait 0.
    //print " nodeUncircularize".
    //print "  dv ="+Round(NextNode:DeltaV:Mag, 2).
}

function suicideBurn {
    print " suicideBurn".
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

    local clearing is 5.
    local v0 is 1. // touchdown speed
    local hCorr is -0.5*v0*v0/(acc-g). // correction for landing speed
    local height is 0.
    local accNeeded is 0.

    local tt is 0.
    lock Throttle to tt.
    lock Steering to stSrfRetro().
    until Status = "LANDED" or Status = "SPLASHED" {
        wait 0.
        set height to Altitude - Max(0.01, GeoPosition:TerrainHeight)-clearing +hCorr.
        if (height>2) {
            set accNeeded to (Velocity:Surface:SqrMagnitude - v0*v0)/(2*height) + g.
            if (height < 1000) {set Warp to 0.}
        }
        else
          set accNeeded to (Velocity:Surface:Mag - v0)*2.

        set tt to Max(0, (accNeeded/acc)-0.7)*5. // start at 7%, full at 90%

        print "aN  =" +Round(accNeeded, 2) at (38, 0).
        print "acc =" +Round(acc,       2) at (38, 1).
        print "tt  =" +Round(tt,        2) at (38, 2).
        print "h   =" +Round(height,    2) at (38, 3).
    }
    unlock Throttle.
    lock Steering to stUp().
    //wait 5.
    unlock Steering.
    wait 0.
}

function vacAscent {
    parameter tgtAP.

    if (Vang(Up:Vector, Facing:ForeVector) > 10) {
        print "  WARNING: vacAscent: not facing up!".
        lock Steering to stUp().
        wait until Vang(Up:Vector, Facing:ForeVector) < 10.
    }

    checkBalance().
    local lock pp to 90.
    set Warpmode to "PHYSICS".
    set Warp to 1.

    //local lock headCorr to -Vdot(vel:Normalized, North:Vector).
    lock Steering to Heading(90,pp). //90+headCorr
    lock Throttle to 1.
    local lock apReached to (Apoapsis > tgtAP*0.99).

    wait until (VerticalSpeed > 60) or apReached.
    print "  Gravity turn".
    local startAlt is Altitude.
    local lock shape to ((Altitude-startAlt) / (tgtAP-startAlt)) ^gLaunchParam.
    local lock pp to 90*(1-shape).

    wait until (Apoapsis > 10000) or apReached.
    lock Steering to stPrograde().

    wait until apReached.
    unlock Throttle.
    unlock Steering.
    set Warp to 0.
}

function vacLandAtTgt {
    parameter tgt is 0. // GeoCoordinates (else use Target)
    if(Status = "LANDED" or Status="SPLASHED") return.
    if (not tgt:HasSuffix("LAT")) set tgt to Body:GeoPositionOf(Target:Position).

    local startDv is getDeltaV().
    local tgtHeight is Max(0.01, tgt:TerrainHeight).
    local acc is Ship:AvailableThrust / Mass.
    local g is Body:Mu/(Body:Radius * (Body:Radius +0.1)). // +0.1 = workaround to overflow
    local accFactor is 1.
    if (acc > 10*g) {  // limit TWR for stability
        set accFactor to 10*g/acc.
        set acc to acc*accFactor.
    }

    print " vacLandAtTgt".
    print "  acc="+Round(acc,3).
    print "  tgtHeight="+Round(tgtHeight, 1).
    //print "  tgtLatLng=("+Round(Target:Latitude,2)+", "+Round(Target:Longitude,2)+")".
    print "  tgt=LatLng("+Round(tgt:Lat,3) +", "+Round(tgt:Lng,3)+")".
    //print "  g=" +Round(g,2) +", acc=" +Round(acc,2).

    //local sBurnHeight is Velocity:Orbit:SqrMagnitude/(0.5*acc-g).
    //print "  sBurnHeight="+sBurnHeight.
    local nodeHeight is tgtHeight+3000. //sBurnHeight/4.
    print "  nodeHeight="+Round(nodeHeight, 1).
    if (Obt:Periapsis > nodeHeight) {
        // make a node that brings me above the target at the
        //   suicide burn height
        //if not HasNode nodeDeorbit(tgt, nodeHeight, -Body:Radius*0.7).
        if not HasNode nodeDeorbitAngle(tgt, nodeHeight).
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
    lock Steering to Lookdirup(steerVec, Facing:UpVector).
    local g is Body:Mu/(Body:Radius* (Body:Radius+0.1)).
    print "  g="+Round(g,3).
    local vErrPIDx is PidLoop(0.05, 0, 0.03, -1, 1). // KP, KI, KD, MINOUTPUT, MAXOUTPUT
    local vErrPIDy is PidLoop(0.05, 0, 0.03, -1, 1). // KP, KI, KD, MINOUTPUT, MAXOUTPUT

    function update {
        wait 0.
        set v to Velocity:Surface.
        //set height to Altitude - Max(0.01, GeoPosition:TerrainHeight)-clearing.
        set height to Altitude - tgtHeight -clearing.


        // predicted landing spot
        local sBurnDist is Velocity:Surface:SqrMagnitude/(0.5*acc-g).
        //local timeToImpact is timeToAltitude2(tgtHeight, Time:Seconds, Time:Seconds+Obt:Period/4).
        //local dt is (timeToImpact-Time:Seconds)*2. // assume linear deceleration
        //local predictPos is dt*Velocity:Surface + Body:Mu/(Body:Radius*Body:Radius)*dt*dt*(-Up:Vector).
        //print "dt  =" +Round(dt  ) at (38,10).
        //print "tti =" +Round(timeToImpact-Time:Seconds,     2) at (38,11).
        //print "=" +Round(,     2) at (38,10).
        //print "=" +Round(,     2) at (38,10).

        //local v1 is dt*Velocity:Surface/2.
        //local v2 is (Up:Vector)*g*dt*dt/2.
        //print "v1  =" +Round(v1:Mag) at (38,12).
        //print "v2  =" +Round(v2:Mag) at (38,13).
        //debugVec(1, "vLin", v1).
        //debugVec(2, "g", v2, Target:Position).

        set brakeAcc to v:SqrMagnitude/(2*height) + g.
        set brakeAcc to 2*brakeAcc -acc/2.
        local aimPoint is tgt:Position +Up:Vector*(Altitude-tgtHeight)*0.4.
        set vSollDir to aimPoint:Normalized.
        set vErr to Vxcl(vSollDir, v).
        local frame is LookdirUp(vSollDir, North:Vector).
        local tmpX is vErrPIDx:update(Time:Seconds, Vdot(vErr,Frame:UpVector)).
        local tmpY is vErrPIDy:update(Time:Seconds, Vdot(vErr,Frame:StarVector)).
        local tmp is -(tmpX*Frame:UpVector +tmpY*Frame:StarVector).

        print "vErr=" +Round(vErr:Mag,1)+"  " at (38, 0).
        print "bAcc=" +Round(brakeAcc,    2)  at (38, 1).

        set corrAcc to Min(height/1000, Min(brakeAcc, Sqrt(Min(tmp:Mag, Max(acc^2-brakeAcc^2,0))))).
        set steerVec to -v:Normalized*brakeAcc -tmp:Normalized*corrAcc.
        set tt to Max(0,((steerVec:Mag/acc)-0.4)*5 *accFactor
                        *Vdot(steerVec, Facing:Forevector)).
        print "cAcc=" +Round(corrAcc,     2) at (38, 2).
        print "sAcc=" +Round(steerVec:Mag,2) at (38, 3).
        print "tAcc=" +Round(tt/accFactor,2) at (38, 4).
        //print "h   =" +Round(height,      1) at (38, 5).
        print "tmpX=" +Round(tmpX,2)+"    " at (38,6).
        print "tmpY=" +Round(tmpY,2)+"    " at (38,7).
        print "tUnP=" +Target:UnPacked at (38,8).
        debugVec(5, "v", Velocity:Surface, -10*Up:Vector).
        debugVec(4, "vErr",vErr, -vErr+Velocity:Surface-10*Up:Vector).
        debugVec(3, "aimPoint", aimPoint-tgt:Position, tgt:Position).
        debugVec(4, "corr", -tmp:Normalized*corrAcc*10, 20*v:Normalized -10*Up:Vector).
        debugDirection(Steering).
    }

    print " landing burn".
    set WarpMode to "RAILS".
    set Warp to 3. // 50x

    // todo: intermediate correction burn
    //       (still with orbital navigation)

    // todo: use suicideBurnCountdown instead of height
    until (height < 13000) update().
    set WARP to 0.
    set WARPMODE to "PHYSICS".
    //print "  wait for unpacking".
    until (Ship:Unpacked) update().
    print "  ship unpacked".
    set Warp to 3.
    until (Vang(Facing:ForeVector, Steering:ForeVector) <3) update().
    set Warp to 1.
    until (height < 10000) update().
    lock Throttle to tt.
    if (HasTarget) {
      until (Target:UnPacked or height<400) update().
      if (Target:Unpacked) {
        print "  target unpacked".
        set tgt to chooseBasePort().
        set tgtHeight to Max(0.01, tgt:TerrainHeight).
      } else print "  WARNING: Target still packed!".
    }

    until (height < 30) { update(). } //dynWarp(). }
    unlock Throttle.
    suicideBurn().

    local endDv is getDeltaV().
    print "  dvCost  ="+Round(startDv-getDeltaV(), 1).
    print "  posError=" +Round(tgt:Position:Mag,1).

    lock Steering to stUp().
    // print "  ang="+Round(Vang(Up:Vector, Facing:ForeVector),2)
    //      +", vel="+Round(Ship:AngularVel:Mag,2).
    wait until (Vang(Up:Vector, Facing:ForeVector)<1 and Ship:AngularVel:Mag<0.1).
}

function chooseBasePort {
    local portList is Target:PartsTagged(Target:Name+"Port").
    local pos is Target:Position.

    if (portList:Length>0) {
      local dir is 0.
      local p is portList[0].
      if p:HasSuffix("PortFacing")
        set dir to p:PortFacing:ForeVector.
      else
        set dir to p:Facing:ForeVector.

      set dir to Vxcl(Target:Position-Target:Body:Position, dir):Normalized.
      set pos to p:Position +dir*(gShipRadius+20).
      print "  port found".
    } else print "  no ports found!".
    return Target:Body:GeoPositionOf(pos) +North:Vector*(gShipRadius+10).
}

// -> libatmo ?
function suicideBurnChutes {
    local tt is 0.
    lock Throttle to tt.
    lock Steering to stSrfRetro().
    local lock height to Altitude - Max(0.01, GeoPosition:TerrainHeight).
    local lock v to Velocity:Surface.

    wait until height/v:Mag < 5. // 5 seconds before crash
    set Warp to 0.
    set tt to 1.

    until Status = "LANDED" or Status = "SPLASHED" {
        wait 0.
        print "  vZ  =" +Round(VerticalSpeed) at (38,0).
    }
    set tt to 0.
    unlock Steering.
    unlock Throttle.
}

function execNode {
    parameter doDynWarp is true.
    print "  execNode".
    wait 0.
    set Warp to 0.
    lock Throttle to 0. // workaround for bug at kssTest circularize
    if (NextNode:DeltaV:Mag<0.15) {
        print "  dV="+NextNode:DeltaV:Mag.
        remove NextNode. wait 0.
        return.
    }
    local acc is Ship:AvailableThrust / Mass.
    if (acc=0) {
        print "  ERROR: execNode: acc=0!".
        return.
    }
    local debugDV is V(NextNode:Prograde,NextNode:RadialOut,NextNode:Normal):Mag.
    if Abs(debugDV -NextNode:DeltaV:Mag) >0.15
      AND Abs(1 - debugDV/NextNode:DeltaV:Mag) > 0.01 {
        print "  WARNING: inconsistent ManeuverNode!".
        print "   deltaV    ="+Round(NextNode:DeltaV:Mag, 2).
        print "   components="+Round(debugDV, 2).
        //print "   ratio=" +Round(Abs(debugDV/NextNode:DeltaV:Mag));
        if (debugDV<0.1) {remove NextNode. wait 0. return.}
    }

    local burntime is NextNode:Deltav:Mag / acc.

    // print "  orient ship".
    lock Steering to stNode().
    set WarpMode to "PHYSICS".
    set Warp to 3.
    wait until VectorAngle(Facing:Vector, NextNode:Deltav) < 3.
    set Warp to 0.

    // print "warp to node".
    local warpTime is Time:Seconds + NextNode:ETA -burntime/2.
    if(warpTime - Time:Seconds > 21) {
        // node drifts off during warp
        unlock Steering.
        warpRails(warpTime -20).
        lock Steering to stNode().
        wait until VectorAngle(Facing:Vector, NextNode:Deltav) < 3.
    }
    unlock Steering.
    warpRails(warpTime -2).
    lock Steering to stNode().
    set WarpMode to "PHYSICS".
    set Warp to 1.

    wait until VectorAngle(Facing:Vector, NextNode:Deltav) < 1.
    wait until NextNode:Eta < (burntime/2) +0.1.
    local origDir is NextNode:Deltav.
    local lock chaseAngle to VectorAngle(origDir, NextNode:Deltav).

    lock Throttle to (NextNode:Deltav:Mag / acc / 2).
    until (chaseAngle > 60) or (NextNode:Deltav:Mag < 0.05) {
        wait 0.
        if doDynWarp dynWarp().
        print "tt   ="+Round(Throttle, 2)       AT (38,0).
        //print "st   ="+Steering AT (38,1).
    }.

    if(NextNode:Deltav:Mag > 0.05) {
        print "  WARNING: execNode: error = "+ Round(NextNode:Deltav:Mag, 3).
    }
    unlock Throttle.
    unlock Steering.
    if (doDynWarp=false and hasRcsDeltaV(5)) execNodeRcs.
    if HasNode {remove NextNode. wait 0.}
    set Warp to 0.
}

function execNodeRcs {
    print "  execNodeRcs".
    local dV is NextNode:DeltaV.
    local dV0 is dV.
    set Warp to 0.
    warpRails(Time:Seconds +NextNode:Eta -2).
    RCS on.

    function update {
        wait 0.
        set dV to NextNode:Deltav.
        //print "dV  ="+Round(dV:Mag,3)  at (38,0).
        if(dV:Mag > 0.05)
          set Ship:Control:Translation to -Facing*dV:Normalized.
        else
          set Ship:Control:Translation to -Facing*dV*20.
    }

    until (Vang(dV0,dV) > 60) or (dV:Mag < 0.005) update().
    //print "   errAng=" +Round(Vang(dV0,dV),1).
    //print "   dV=" +Round(dV:Mag, 3).

    set Ship:Control:Translation to 0.
    RCS off.
    remove NextNode.
    wait 0.
}

function rcsPrecisionBurn {
    parameter dV.

    local isp is 240.
    local cosLoss is (dV:X +dV:Y +dV:Z)/dV:Mag.
    local dMP is dV:Mag *Ship:Mass *cosLoss/ (isp*9.81 *0.004). //0.004= MP density
    local tMP is Ship:MonoPropellant -dMP.
    set Warp to 0.
    RCS on.
    until (Ship:Monopropellant<=tMP) {
        wait 0.
        set Ship:Control:Translation to -Facing*dV:Normalized.
    }
    set Ship:Control:Translation to 0.
    RCS off.

    //print "  rcsPrecisionBurn".
    //print "   errMP="+Round(Ship:MonoPropellant-tMP,3)+ " MP".
    //print "   dMP="+Round(dMP,3).
    //print "   dV=" +Round(dV:Mag, 3).
}

function getPhaseAngle {
    // In the RefFrame of orbit1, I pass angleDiff while timeDiff.
    // How much phaseAngle have I won/lost with respect to my target in orbit2?
    parameter timeDiff.
    parameter angleDiff.
    parameter period1.
    parameter period2.

    local synPeriod is 1/ (1/period1 - 1/period2). // negative if p1 > p2
    // print "getPhaseAngle".
    // print "  timeDiff ="+Round(timeDiff,2).
    // print "  angleDiff="+Round(angleDiff,2).
    // print "  synPeriod="+Round(synPeriod,2).
    // print "  period1  ="+Round(period1,2).
    // print "  period2  ="+Round(period2,2).
    // print "  Result   ="+Round(angleDiff + (timeDiff/synPeriod)*360 ,2).
    return angleDiff + (timeDiff/synPeriod)*360.
}

function nextNodeExists {   // copied from RAMP
  local sentinel is Node(Time:Seconds + 10^10, 0, 0, 0).
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
