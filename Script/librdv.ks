// functions for rendezvous/docking with other vessels
@lazyglobal off.
print "  Loading librdv".


function checkRdv {
    parameter offsetP is V(0,0,0).
    wait 0.
    local t is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
    local dX1 is Target:Position+offsetP.
    local dX2 is PositionAt(Target,t)+offsetP -PositionAt(Ship,t).
    local dV1 is Target:Velocity:Orbit -VelocityAt(Ship,Time:Seconds):Orbit.
    local dV2 is VelocityAt(Target,t):Orbit
                -VelocityAt(Ship,  t):Orbit.
    print "  checkRdv: ETA=" +Round(t-Time:Seconds, 1).
    //print "            dX2=" +Round(dX2:Mag,2)
    //               +", lin=" +Round(Vxcl(dV2,dX2):Mag,2).
    print "    dX [r/n/p]="+vecToString( -getOrbitFacing(Ship,t)*dX2, 0).
    print "    dV [r/n/p]="+vecToString( -getOrbitFacing(Ship,t)*dV2, 0).
}

function warpToBrakeDist {
  local t is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
  local dV is VelocityAt(Target,t):Orbit-VelocityAt(Ship,t):Orbit.
  local acc is Ship:AvailableThrust/Mass.
  local brakeTime is 1.1*dV:Mag / acc. // 10% margin
  local brakeDist is dv*dv / (2 * acc).
  local loadTime is KUniverse:DefaultLoadDistance:Orbit:Load / dV:Mag.
  print " warpToBrakeDist".
  print "  acc="       +Round(acc,2).
  print "  brakeDist=" +Round(brakeDist,2).
  print "  brakeTime=" +Round(brakeTime,2).
  print "  loadTime =" +Round(loadTime,2).

  add Node(t,0,0,0).
  setNextNodeDv( -getOrbitFacing(Ship, t)*dV ).
  lock Steering to stNode().
  set WarpMode to "PHYSICS".
  set Warp to 2.
  wait until VectorAngle(Facing:Vector, NextNode:Deltav) < 3.
  set Warp to 0.
  unlock Steering.
  remove NextNode.
  warpRails(t -Max(loadTime, brakeTime/2) -10).
  set WarpMode to "PHYSICS".
}

function rdvDock {
    print " rdvDock".
    local deltaV is getDeltaV().

    if (Target:Position:Mag > KUniverse:DefaultLoadDistance:Orbit:Load) {
      // unloaded part (can target vessel but not individual parts)
      warpToBrakeDist().
      lock targetPos to Target:Position.
      lock targetUp to Facing:UpVector.
      rdv().
    }

    // find docking ports
    local targetOffset is 0.
    global targetPort is 0.
    local dock is prepareDocking().
    if dock {
        // gShipRadius from target port
        set targetOffset to (-Target:Facing)*
          (targetPort:NodePosition
           +targetPort:PortFacing:Forevector*gShipRadius
           -Target:Position).
    } else {
        // radial from target
        set targetOffset to (-Target:Facing)*((10+gShipRadius)*(Body:Position -Target:Position):Normalized).
    }

    rdv(targetOffset, true).

    local tmpVel is (Velocity:Orbit-Target:Velocity:Orbit):Mag.
    if ( tmpVel<2 and hasRcsDeltaV(1.5+tmpVel) ) {
        RCS off.
        killRot().
        cancelRelativeVelRcs().
    } else {
        cancelRelativeVel().
        killRot().
    }
    //print "  posErr="+Round(Vdot(Ship:Position - targetPos(), dV:Normalized), 3).
    print "  dVCost(LFO) ="+Round(deltaV-getDeltaV(),2).

    if dock {
        killRotByWarp().
        dockingApproach((-Target:Facing)*(targetPort:NodePosition-Target:Position),
                        (-Target:Facing)*targetPort:PortFacing:ForeVector ).
        wait 1.
        Core:DoEvent("open terminal").
    }
}

function rdv {
    parameter targetOffset is V(0,0,0).
    parameter loadedVersion is false. // false: target is out of loading range
    print " rdv".
    if (Target:Position:Mag<100 and (Target:Velocity:Orbit-Velocity:Orbit):Mag<1) return.
    print "  targetOffset="+vecToString(targetOffset).
    if loadedVersion print "  loadedVersion=true".

    local v0 is (Velocity:Orbit - Target:Velocity:Orbit).
    local acc is Ship:AvailableThrust / Mass.
    local accFactor is 1.
    if (acc > 1) {  // limit TWR for stability
        set accFactor to 1/acc.
        set acc to acc*accFactor.
        //print "  accFactor="+Round(accFactor,3).
    }

    local vErr is 0.
    local tt is 0.
    local dX is v(100000,0,0).
    local dV is Velocity:Orbit - Target:Velocity:Orbit.
    local brakeAcc is 0.
    local steerVec is -dV:Normalized*brakeAcc.
    local count is 0.
    local far is true.  // true: use orbital mechanics, false: linear approximation
    //local useRCS is hasRcsDeltaV(25).
    local rdvT is 0.
    local tOffset is V(0,0,0).
    local vErrPIDx is PidLoop(0.2, 0, 0.05, -1, 1). // KP, KI, KD, MINOUTPUT, MAXOUTPUT
    local vErrPIDy is PidLoop(0.2, 0, 0.05, -1, 1). // KP, KI, KD, MINOUTPUT, MAXOUTPUT

    local function update {
        wait 0.
        local targetPos is Target:Position.
        if (loadedVersion) set tOffset to Target:Facing*targetOffset.

        set dX to (Target:Position -Ship:Position +tOffset).
        set dV to Velocity:Orbit - Target:Velocity:Orbit.
        set brakeAcc to dV:SqrMagnitude/(2* Vdot(dV:Normalized, dX)).
        if far {
            if Mod(count,5)=0 { // expensive stuff
                wait 0.
                set rdvT to findClosestApproach(Time:Seconds, Time:Seconds+2*dV:Mag/dX:Mag).
                if (rdvT-Time:Seconds < 10) {
                  set far to false.
                  print "  switch to local navigation: dt="
                    +Round(rdvT-Time:Seconds,1)
                    +", dX=" +Round(dX:Mag).
                }
            }
            local dX2 is PositionAt(Target,rdvT) -PositionAt(Ship,rdvT) +tOffset.
            local dV2 is VelocityAt(Target,rdvT):Orbit -VelocityAt(Ship,  rdvT):Orbit.
            set dX2 to Vxcl(dV2, dX2).
            set vErr to Vxcl(dV, -dX2/(rdvT -Time:Seconds)).
        } else {
            set vErr to Vxcl(dX, dV).
        }
        //debugDirection(Steering).

        // try to negate vErr per second
        // limit angle to retrograde when closing in

        local frame is LookdirUp(dX, Body:Position).
        local tmpX is vErrPIDx:update(Time:Seconds, Vdot(vErr,Frame:UpVector)). // set roll to Max(-15, Min(15, -3*bearSoll)).
        local tmpY is vErrPIDy:update(Time:Seconds, Vdot(vErr,Frame:StarVector)). // set roll to Max(-15, Min(15, -3*bearSoll)).

        local tmp is (tmpX*Frame:UpVector +tmpY*Frame:StarVector).
        local corrAcc is tmp:Normalized *Min(tmp:Mag, dX:Mag/500).

        // correct with RCS if available
        //if useRCS {
        //    if (vErr:Mag<0.05) set Ship:Control:Translation to V(0,0,0).
        //      else set Ship:Control:Translation to -Facing*(-vErr:Normalized).
        //    set steerVec to -dV:Normalized*brakeAcc.
        //} else {
            set steerVec to -dV:Normalized*brakeAcc +corrAcc. //-vErr:Normalized*corrAcc.
        //}

        local ttt is Max(0, Vdot(steerVec:Normalized, Facing:Forevector)).
        if (brakeAcc>acc/2)      // braking
          set tt to steerVec:Mag/acc *ttt^10 *accFactor.
        else if (corrAcc:Mag > 0.03) // correction
          set tt to steerVec:Mag/acc *ttt^300 *accFactor.
        else
          set tt to 0.

        print "bAcc=" +Round(brakeAcc,    2) at (38, 0).
        print "dX  =" +Round(dX:Mag,      1) at (38, 1).
        print "vErr=" +Round(vErr:Mag,3)+"   " at (38,2).
        print "ttt =" +Round(ttt, 3)    +"   " at (38,3).
        print "tOff=" +Round(tOffset:Mag,2)+ "  " at (38,4).
        debugVec(1, "dX", dX).
        debugVec(2, "tOffset", tOffset ,Target:Position).
        debugVec(3, "vel", dV).
        debugVec(4, "vErr", vErr, dV-vErr).
        set count to count+1.
    }

    lock Steering to Lookdirup(steerVec, Facing:UpVector).
    until Vang(Steering:ForeVector, Facing:ForeVector)<3 update().
    //if useRCS RCS on.
    clearScreen2().
    lock Throttle to tt.
    set WarpMode to "Rails".
    until (dX:Mag < KUniverse:DefaultLoadDistance:Orbit:Load) {
        update().
        if (vErr:Mag > 0.1) set Warp to 0.
        else if (tt=0) set Warp to 2.
    }
    if (not loadedVersion) {
      set Warp to 0.
      until (Target:Loaded) { update(). }
      print "  target loaded".
    } else {
      until (dV:Mag < 0.2 or Vdot(dV, dX)<0) update().
    }

    debugDirectionOff().
    debugVecOff().
    unlock Throttle.
    unlock Steering.
}

function dockingApproach {
    //parameter targetPort.
    parameter portOffset. // offset to Target pos (in Target frame)
    parameter portFacing. // portFacing(Vector)   (in Target frame)
    set portFacing to portFacing:Normalized.
    //print " dockingApproach".
    //print "  portOffset="+vecToString(portOffset,2).
    //print "  portFacing="+vecToString(portFacing,2).

    // Assumptions:
    // * already positioned
    // * dockable
    set WarpMode to "PHYSICS".
    set Warp to 1.

    print "  aligning".
    local offset is 1.
    local isClaw is false.
    local corrOffset is 0.
    if (gMyPort:TypeName="Part"){
      // special treatment for claw
      set isClaw to true.
      set offset to 2.
      gMyPort:GetModule("ModuleGrappleNode"):DoEvent("Control from here").
      set corrOffset to (-Facing*gMyPort:Position) +V(0,0,1). // hardcoded for stock claw
      local m is gMyPort:GetModule("ModuleAnimateGeneric").
      if m:AllEventNames:Contains("Arm") m:DoEvent("Arm").
    } else {
      gMyPort:ControlFrom.
      set corrOffset to (-Facing*gMyPort:NodePosition).
    }
    //print "  corrOffset="+vecToString(corrOffset,2).
    local steerDir is LookdirUp( Target:Facing * (-portFacing), Facing:UpVector).
    lock Steering to steerDir.
    wait until Vang(Facing:ForeVector, Steering:ForeVector) < 5.

    local vSoll is 0.
    local dx is V(0,0,1).
    local vErr is 0.
    local dZ is 0.
    RCS on.
    clearScreen2().

    local function update {
        wait 0.
        if (not HasTarget) return.
        local tgtFrame is Target:Facing.
        local tgtDir is tgtFrame * (-portFacing).
        local tgtPos is Target:Position.
        local off1 is tgtFrame*portOffset.
        local cOff is Facing*corrOffset.
        local off2 is -offset*tgtDir.
        set dX to tgtPos +off1 +off2 -cOff.

        set vSoll to dX:Normalized * (0.2 +dX:Mag/200).
        set vErr to Velocity:Orbit-Target:Velocity:Orbit -vSoll.
        if(vErr:Mag > 0.03) {
          set Ship:Control:Translation to -Facing*(-vErr:Normalized).
        } else {
          set Ship:Control:Translation to V(0,0,0).
        }
        set steerDir to LookdirUp( tgtFrame * (-portFacing), Facing:UpVector).
        print "dX   ="+Round(dX:Mag,2)    at (38,0).
        print "vSoll="+Round(vSoll:Mag,2) at (38,1).
        print "vErr ="+Round(vErr:Mag,2)  at (38,2).
        debugVec(1, "dX", dX, cOff).
        debugVec(2, "final", -off2, dX+cOff).
        debugVec(3, "offs", off1, tgtPos ).
        debugVec(4, "corr", cOff).
        //wait 0.
        //if (not HasTarget) return.
        //debugVec(5, "vel", (Velocity:Orbit-Target:Velocity:Orbit)*25).  // 0.2m/s == 5m
    }

    print "  positioning".
    until (dX:Mag < 0.3) update().
    set offset to 0.
    print "  final approach".
    set Warp to 0.

    until (dX:Mag<0.05) or (HasTarget=false) update().
    if HasTarget {
      print "  extending approach".
      set offset to offset-2. update().
      until (dX:Mag<0.05) or (HasTarget=false) update().
    }
    wait until (not HasTarget).

    set Ship:Control:Translation to V(0,0,0).
    unlock Steering.
    RCS off.
    print "  docked".
    setControlPart().
    debugVecOff().
    killRotByWarp().
}

function grabWithClaw {
  parameter vec is (-Target:Facing)*-Target:Facing:ForeVector. // preferred direction
  set vec to vec:Normalized.
  print "  vec="+vecToString(vec).

  if Target:Parts:Length>1 {
    print "  WARNING: Target has more than one part!".
    //return.
  }
  if (not hasClaw()) {  // this sets the claw as gMyPort
    print "  WARNING: no Claw found!".
    return.
  }

  // chose direction
  //local p is Target:Parts[0].
  local sign is 1.
  //print "  Part=" +p:Title.

  //local vec is V(1,0,0).
  //if (Vang(p:Position,p:Facing:ForeVector)<120) {
  //  set vec to V(0,0,-1).                           // preferred: claw at bottom node
  //} else {
  //  if p:Name:Contains("Derp") set vec to V(0,0,1). // horrible CoM!
  //  if (Vang(p:Position,p:Facing*vec)<90) set sign to -1.
  //}

  // docking approach
  gMyPort:GetModule("ModuleGrappleNode"):DoEvent("Control from here").
  dockingApproach(vec*sign, vec*sign).
}

function cancelRelativeVel {
    print " cancelRelativeVel".
    local t is 0.
    local acc is Ship:AvailableThrust / Mass.
    local v0dir is (Target:Velocity:Orbit - Velocity:Orbit):Normalized.
    local dV is v0Dir.
    lock Steering to LookdirUp(dV, Facing:UpVector).
    lock Throttle to (dV:Mag/acc)*2.5 *t^10.

    // until stop or overshoot
    until (dV:Mag < 0.001) or (Vdot(v0dir, dV:Normalized) < 0) {
        wait 0.
        set dV to Target:Velocity:Orbit - Velocity:Orbit.
        set t to Max(0,Vdot(dV:Normalized, Facing:Vector)).

        print "dV   ="+Round(dV:MAG,2)    AT (38,0).
        print "t    ="+Round(t , 3)       AT (38,1).
    }
    //print "  finished: v="+dV:MAG.
    unlock Steering.
    unlock Throttle.
}

function cancelRelativeVelRCS {
    print " cancelRelativeVelRCS".
    local t is 0.
    local v0 is Target:Velocity:Orbit - Velocity:Orbit.
    local v0dir is (Target:Velocity:Orbit - Velocity:Orbit):Normalized.
    local dV is v0Dir.
    local mp is Ship:MonoPropellant.
    local tmpVec is V(0,0,0).
    RCS on.
    // until stop or overshoot
    until (dV:Mag < 0.001) or (Vdot(v0dir, dV:Normalized) < 0) {
        wait 0.
        set dV to Target:Velocity:Orbit - Velocity:Orbit.

        set tmpVec to -Facing * dV:Normalized.
        if(tmpVec:Mag < 0.02) set tmpVec to tmpVec *0.02/tmpVec:Mag.
        set Ship:Control:Translation to tmpVec.

        print "dV   ="+Round(dV:MAG,2)    at (38,0).
        print "t    ="+Round(t , 3)       at (38,1).
    }
    RCS off.
    set Ship:Control:Translation to V(0,0,0).
}

// utilities
function prepareDocking {
  if (not hasPort()) {
    print "  Docking not possible: no port found".
  } else if (not hasRcs()) {
    print "  Docking not possible: no RCS found".
  } else if (getRcsDeltaV()<2) {
    print "  Docking not possible: rcsDeltaV=" +Round(getRcsDeltaV(),2) +" (not enough)".
  } else if (not chooseDockingPort()) {
    print "  Docking not possible: no target port found".
  } else {
    print "  Docking possible".
    return true.
  }
  return false.
}

function chooseDockingPort {
  // Assumption: all ports are compatible
  local portList is Target:PartsTagged(Target:Name+"Port").
  //print "  ports found on target: "+portList:Length.
  if (portList:Length=0) return false.

  // if not free -> discard
  local bestAngle is 999.
  local index is 0.
  for port in portList {
    if (port:State="READY"){
      local angle is Vang(port:PortFacing:ForeVector, port:NodePosition).
      //print "  angle="+Round(angle,2).
      if (angle>70 and angle<bestAngle){
        set bestAngle to angle.
        set targetPort to port. // global variable declared by calling function
      }
    }
  }

  //print "  bestAngle="+Round(bestAngle,2).
  return (bestAngle<>999).
}
