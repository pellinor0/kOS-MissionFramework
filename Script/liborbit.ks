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

    wait until (VerticalSpeed > 5) or apReached.
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
    if (Status = "LANDED" or Status="SPLASHED") return.
    if (not tgt:HasSuffix("LAT")) set tgt to Body:GeoPositionOf(Target:Position).
    local ld is KUniverse:DefaultLoadDistance:Landed.
    print "  loadDist Landed:" +ld:Load +", "+ld:Unload+", "+ld:Unpack+", "+ld:pack.
    set ld:Pack to 2200.
    set ld:Unpack to 2150.

    local startDv is getDeltaV().
    local tgtHeight is Max(0.01, tgt:TerrainHeight)+10. // +10: keep a bit of clearing
    local acc is Ship:AvailableThrust / Mass.
    local g is Body:Mu/(Body:Radius * (Body:Radius +0.1)). // +0.1 = workaround to overflow

    print " vacLandAtTgt".
    print "  tgtHeight="+Round(tgtHeight, 1).
    //print "  tgt=LatLng("+Round(tgt:Lat,3) +", "+Round(tgt:Lng,3)+")".
    print "  g=" +Round(g,2) +", acc=" +Round(acc,2) +", TWR="+Round(acc/g,2).
    local accFactor is 1.
    if (acc > 2.5*g) {  // limit TWR for stability
        set accFactor to 2.5*g/acc.
        set acc to acc*accFactor.
    }
    if (Exists("0:/logs/land"+Body:Name+".json")) {
      local params is ReadJson("0:/logs/land"+Body:Name+".json").
      local burnAlt is params["h"][(params["h"]:Length-1)].
      if (Periapsis > burnAlt) {   // else we already did that burn
        if (not HasNode) {
          local PA is Mod(tgt:Lng-Longitude+360, 360)-Params["PA"].
          local synPeriod is 1/ (1/Obt:Period - 1/Body:RotationPeriod).
          local dt is synPeriod*(PA/360).
          if (dt<30) {set dt to dt+synPeriod.}
          print "  PA="+Round(PA,2).
          print "  dt="+Round(dt,2).
          nodeUncircularize(params["PE"], Time:Seconds+dt).
          local function frame { parameter dt. return -AngleAxis(360* dt/Body:RotationPeriod, V(0,1,0)). }
          local p2 is frame(NextNode:Eta) * (tgt:Position-Body:Position).
          local normal is Vcrs(p2, PositionAt(Ship,Time:Seconds+NextNode:Eta)-Body:Position).
          print "  incErr="+Round(Vang(normal, getOrbitNormal()),2).
          tweakNodeInclination(normal, -1).
        }
        execNode().
      }
    } else {
      local nodeHeight is tgtHeight+3000. //sBurnHeight/4.
      print "  nodeHeight="+Round(nodeHeight, 1).
      if (Obt:Periapsis > nodeHeight) {
          // make a node that brings me above the target at the
          //   suicide burn height
          if not HasNode nodeDeorbitAngle(tgt, nodeHeight).
          execNode().
      }
    }
    local height is 1e6.
    local brakeAcc is 0.
    local corrAcc is 0.
    local vSollDir is 0.
    local vErr is 0.
    local v is 0.
    local tt is 0.
    local steerVec is -Velocity:Surface.

    if HasTarget {
      lock Steering to Lookdirup(steerVec, -Target:Position). // assume KAS-Port points to -UpVector
    } else {
      lock Steering to Lookdirup(steerVec, Facing:UpVector).
    }

    local g is Body:Mu/(Body:Radius* (Body:Radius+0.1)).
    print "  g="+Round(g,3).
    local vErrPIDx is PidLoop(0.2, 0.01, 0.03, -1, 1). // KP, KI, KD, MINOUTPUT, MAXOUTPUT
    local vErrPIDy is PidLoop(0.2, 0.01, 0.03, -1, 1). // KP, KI, KD, MINOUTPUT, MAXOUTPUT
    local sbc is 1000.

    local v0 is 1. // touchdown speed
    local hCorr is -0.5*v0*v0/(acc-g) -10. // correction for touchdown speed and gearHeight
    local tImpact is Time:Seconds+1e12.

    local function update {
        wait 0.
        set v to Velocity:Surface.
        set height to Altitude - tgtHeight.

        // == Suicide burn countdown => throttle ==
        // suicide burn countdown (borrowed from MJ)
        set tImpact to timeToAltitude2(tgtHeight, Time:Seconds, Time:Seconds+Eta:Periapsis, 0.2).
        local sinP is Sin( Max(0, 90-Vang(-Velocity:Surface, Up:Vector)) ).
        if (sinp<0.95) {
          local effDecel is 0.5*(-2*g*sinP +Sqrt( (2*g*sinP)^2 +4*(acc*acc*0.9 -g*g))). //"*0.9"= keep small acc reserve
          local decelTime is Velocity:Surface:Mag/effDecel.
          set sbc to tImpact-Time:Seconds -decelTime/2.
          set tt to 1/Max(sbc/2,1).
          print "SBC =" +Round(sbc,      2) +"  " at (38, 0).
        } else {
          // final approach / touchdown
          set height to Altitude - Max(0.01, GeoPosition:TerrainHeight) +hCorr.
          local accNeeded is 0.
          if (height>2)
            set accNeeded to (Velocity:Surface:SqrMagnitude - v0*v0)/(2*height) + g.
          else
            set accNeeded to (Velocity:Surface:Mag - v0)*2.
          set tt to Max(0, (accNeeded*accFactor/acc)-0.7)*5. // start at 70%, full at 90%
        }
        print "tt  =" +Round(tt, 2)  at (38, 1).

        // == Navigation => X/Y error ==
        // aim at a point 60% of current height over target
        local aimPoint is tgt:Position +Up:Vector*(Altitude-tgtHeight)*0.4.
        local frame is LookdirUp(v, Up:Vector).
        set vErr to -frame * Vxcl(aimPoint:Normalized, v).
        debugVec(4, "vErr",frame*vErr, frame*(-vErr)+Velocity:Surface-10*Up:Vector).
        debugVec(3, "aimPoint", aimPoint-tgt:Position, tgt:Position).
        print "vErr=" +Round(vErr:Mag,2) at (38,7).

        // PID control => X/Y corr
        local corrX is vErrPIDx:Update(Time:Seconds, vErr:X).
        local corrY is vErrPIDy:Update(Time:Seconds, vErr:Y).
        print "corX=" +Round(corrX, 2)+"    " at (38,8).
        print "corY=" +Round(corrY, 2)+"    " at (38,9).

        // Steering: corr => steerVec
        local maxCorr is Max(0, Min(0.25, 0.01*(tImpact-Time:Seconds) )).
        if (sbc<0) set corrY to Max(corrY,0).
        set corrX to Max(-maxCorr, Min(corrX, maxCorr)).
        set corrY to Max(-maxCorr, Min(corrY, maxCorr)).
        local steerFrame is LookdirUp(v, Up:Vector).
        set steerVec to -v:Normalized +corrX*steerFrame:StarVector +corrY*steerFrame:UpVector.
        //if (sinp<0.5 and sbc>10) // early: augment corrX with throttle (if we have room for cutting throttle)
        //  set tt to tt-0.1*corrY.

        set steerVec to steerVec .
        debugVec(5, "v", Velocity:Surface, -10*Up:Vector).
        print "dt  ="+Round( tImpact -Time:Seconds -2*sbc ) +"  " at (38,20).
        print "tImp="+Round( tImpact -Time:Seconds )        +"  " at (38,21).
        print "tgtP="+(not Target:UnPacked)+"  " at (38,22).
        //debugDirection(Steering).
    }

    print " landing burn".
    set WarpMode to "RAILS".
    set Warp to 3. // 50x
    //until (sbc < 50) update().
    until (Time:Seconds > tImpact-2*sbc) update().

    set WARP to 0. wait 0. set WARPMODE to "PHYSICS". wait 0.
    until (Ship:Unpacked) update().
    print "  ship unpacked".
    set Warp to 3.
    until (Vang(Facing:ForeVector, Steering:ForeVector) <5) update().
    set WarpMode to "Rails". set Warp to 2.
    until (tt/accFactor>0.02) update().
    set WarpMode to "Physics". set Warp to 1.

    When (HasTarget and Target:Loaded) Then {
      print "  Target loaded: d=" +Target:Position:Mag.
      When (HasTarget and Target:unpacked) Then { print "  Target unpacked: d=" +Target:Position:Mag. }
    }

    lock Throttle to tt.
    until (sbc < 10) update().
    set Warp to 1.
    if (HasTarget) {
      until (Target:UnPacked or height<400) update().
      if (Target:Unpacked) {
        print "  target unpacked".
        set tgt to chooseBasePort().
        set tgtHeight to Max(0.01, tgt:TerrainHeight).
      } else print "  WARNING: Target still packed!".
    }

    //until (height < 30) { update(). } //dynWarp(). }
    //suicideBurn().
    until Status = "LANDED" or Status = "SPLASHED" { update(). }
    unlock Throttle.
    set Warp to 0.

    local endDv is getDeltaV().
    print "  dvCost  ="+Round(startDv-getDeltaV(), 1).
    print "  posError=" +Round(Vxcl(Up:Vector,tgt:Position):Mag,1).

    lock Steering to stUp().
    // print "  ang="+Round(Vang(Up:Vector, Facing:ForeVector),2)
    //      +", vel="+Round(Ship:AngularVel:Mag,2).
    wait until (Ship:AngularVel:Mag<0.1).
    wait 2.
    wait until (Ship:AngularVel:Mag<0.1).
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
    return Target:Body:GeoPositionOf(pos):Position +North:Vector*(gShipRadius+10).
}

function hop {
  // suborbital hop to Target (assume no atmosphere)
  print " hop".

  lock Steering to Heading(Target:Heading, 45).
  lock Throttle to 1.
  local p is Ship:Position.
  local d0 is Target:Position:Mag.
  print "  tgtHeight="+Target:Altitude.
  local function update {
    local tImpact is timeToAltitude2(Target:Altitude, Time:Seconds+Eta:Apoapsis, Time:Seconds+Eta:Apoapsis+Obt:Period/2, 0.2).
    set p to PositionAt(Ship, tImpact).
    print "tti =" +Round(tImpact-Time:Seconds,2) at (38,13).
    print "p   =" +Round(p:Mag,2) at (38,14).
    print "ap  =" +Round(Apoapsis) at (38,15).
  }
  set WarpMode to "PHYSICS". set Warp to 1.
  until (Apoapsis > Target:Altitude+10) update().
  until (p:Mag > (Target:Position:Mag +Velocity:Surface:Mag/2) ) update().
  unlock Throttle.
  lock Steering to stSrfRetro.
  set WARP to 3.
  wait Eta:Apoapsis.
  set Warp to 0.
  unlock Steering.
  vacLandAtTgt().
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

    local tt is 0.
    lock Throttle to tt.

    print " execNode".
    if not HasNode return.
    wait 0. set Warp to 0.
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
    print "  dV="+Round(NextNode:Deltav:Mag,2).
    print "  acc="+Round(acc,2).
    print "  burnTime="+Round(burnTime,2).

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

    until (chaseAngle > 60) or (NextNode:Deltav:Mag < 0.05) {
        wait 0.
        set tt to (NextNode:Deltav:Mag / acc / 2).
        if doDynWarp dynWarp().
        print "tt   ="+Round(tt, 2)       AT (38,0).
        //print "st   ="+Steering AT (38,1).
    }.
    set tt to 0. wait 0.

    if(NextNode:Deltav:Mag > 0.05) {
        print "  WARNING: execNode: error = "+ Round(NextNode:Deltav:Mag, 3).
    }
    //unlock Throttle.
    unlock Steering.
    if (doDynWarp=false and hasRcsDeltaV(5)) execNodeRcs.
    if HasNode {remove NextNode. wait 0.}
    set Warp to 0.
    print "  accEnd=" +Round(Ship:AvailableThrust / Mass, 2).
}

function execNodeRcs {
    print "  execNodeRcs".
    local dV is NextNode:DeltaV.
    local dV0 is dV.
    set Warp to 0.
    warpRails(Time:Seconds +NextNode:Eta -2).
    RCS on.

    local function update {
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
