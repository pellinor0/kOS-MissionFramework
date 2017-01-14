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
  local brakeDist is dv*dv / (2 * acc).
  local brakeTime is 1.1*dV:Mag / (Ship:AvailableThrust/Mass). // 10% margin
  local loadTime is KUniverse:DefaultLoadDistance:Orbit:Load / dV:Mag.
  print " warpToBrakeDist".
  print "  acc="       +Round(Ship:AvailableThrust/Mass).
  print "  brakeDist=" +Round(brakeDist,2).
  print "  brakeTime=" +Round(brakeTime,2).
  print "  loadTime =" +Round(loadTime,2).

  add Node(t,0,0,0).
  setNextNodeDv( -getOrbitFacing(Ship, t)*dV ).
  lock Steering to stNode().
  wait until VectorAngle(Facing:Vector, NextNode:Deltav) < 3.
  unlock Steering.
  remove NextNode.
  warpRails(t -Max(loadTime, brakeTime/2) -10).
  set WarpMode to "PHYSICS".
}

function rdvDock {
    print " rdvDock".
    local deltaV is getDeltaV().

    // unloaded part (can target vessel but not individual parts)
    warpToBrakeDist().
    lock targetPos to Target:Position.
    lock targetUp to Facing:UpVector.
    rdv(targetPos, targetUp, 1).

    // find docking ports
    global targetPort is 0.
    local dock is prepareDocking().
    if dock {
        // gShipRadius from target port
        lock targetPos to targetPort:NodePosition
                       +targetPort:PortFacing:Forevector*gShipRadius.
        lock targetUp to targetPort:PortFacing:Forevector.
    } else {
        // radial from target
        lock targetUp to (Body:Position -Target:Position):Normalized.
        lock targetPos to (10+gShipRadius)*targetUp +Target:Position.
    }

    print "  packDist  =" +KUniverse:DefaultLoadDistance:Orbit:Pack.   //2300
    print "  unpackDist=" +KUniverse:DefaultLoadDistance:Orbit:Unpack. //2050.

    local rcsDV is getRcsDeltaV().
    rdv(targetPos, targetUp, 0).
    unlock gOffset.
    unlock Steering.

    if hasRcsDeltaV(5) {
        RCS off.
        killRot().
        cancelRelativeVelRcs().
    } else {
        cancelRelativeVel(upVector).
        killRot().
    }
    //print "  posErr="+Round(Vdot(Ship:Position - targetPos(), dV:Normalized), 3).
    print "  dVCost ="+Round(deltaV-getDeltaV(),2).

    if dock {
        dockingApproach(targetPort).
        wait 1.
        Core:DoEvent("open terminal").
    }
    set rcsDV to rcsDV-getRcsDeltaV().
    if rcsDV>0.01 print "  rcsDV used="+Round(rcsDv, 2).
}

function rdv {
    // Assumptions:
    // * targetPos is a part of Target vessel
    parameter targetPos.     // (Vector) lock to target position
    parameter upVector.
    parameter returnOnLoad is false.

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
    local far is true.  // true: use orbital mechanics, false:
    local useRCS is false. //hasRcsDeltaV(25).
    local rdvT is 0.

    function update {
        wait 0.
        set dX to (targetPos() -Ship:Position).
        set dV to Velocity:Orbit - Target:Velocity:Orbit.
        set brakeAcc to dV:SqrMagnitude/(2* Vdot(dV:Normalized, dX)).
        if far {
            if Mod(count,5)=0 { // expensive stuff
                set rdvT to findClosestApproach(Time:Seconds, Time:Seconds+2*dV:Mag/dX:Mag).
                if (dX:Mag<600) {set far to false. print "  switch to local navigation".}
            }
            local offset is targetPos()-Target:Position.
            local dX2 is PositionAt(Target,rdvT) +offset -PositionAt(Ship,rdvT).
            local dV2 is VelocityAt(Target,rdvT):Orbit
                        -VelocityAt(Ship,  rdvT):Orbit.
            set dX2 to Vxcl(dV2,dX2).
            set vErr to Vxcl(dV, -dX2/(rdvT -Time:Seconds)).
        } else {
            set vErr to Vxcl(dX, dV).
        }
        debugDirection(Steering).

        // try to negate vErr per second
        // limit angle to retrograde when closing in
        local corrAcc is Min(vErr:Mag/2, dX:Mag/500).

        // correct with RCS if available
        if useRCS {
            if (vErr:Mag<0.05) set Ship:Control:Translation to V(0,0,0).
              else set Ship:Control:Translation to -Facing*(-vErr:Normalized).
            //set steerVec to -dV:Normalized*brakeAcc.
        } //else {
            set steerVec to -dV:Normalized*brakeAcc -vErr:Normalized*corrAcc.
        //}

        local ttt is Max(0, Vdot(steerVec:Normalized, Facing:Forevector)).
        if (brakeAcc>acc/2)      // braking
          set tt to steerVec:Mag/acc *ttt^10 *accFactor.
        else if (corrAcc > 0.03) // correction
          set tt to steerVec:Mag/acc *ttt^300 *accFactor.
        else
          set tt to 0.

        print "bAcc=" +Round(brakeAcc,    2) at (38, 0).
        print "dX  =" +Round(dX:Mag,      1) at (38, 1).
        print "vErr=" +Round(vErr:Mag,3)+"   " at (38,2).
        print "ttt =" +Round(ttt, 3)    +"   " at (38,3).
        set count to count+1.
    }

    lock Steering to Lookdirup(steerVec, upVector).
    until Vang(Steering:ForeVector, Facing:ForeVector)<3 update().
    if useRCS RCS on.
    clearScreen2().
    lock Throttle to tt.
    set WarpMode to "Rails".
    until (dX:Mag < KUniverse:DefaultLoadDistance:Orbit:Load) {
        update().
        if (vErr:Mag > 0.1) set Warp to 0.
        else if (tt=0) set Warp to 2.
    }
    if (returnOnLoad) {
      set Warp to 0.
      until (Target:Loaded) {
        update().
      }
      unlock Throttle.
      unlock Steering.
      return.
    }
    until (dX:Mag < 200) update().
    checkRdv().

    until (dV:Mag < 0.2 or Vdot(dV, dX)<0) update().
    debugDirectionOff().
    unlock Throttle.
    unlock Steering.
}

function dockingApproach {
    parameter targetPort.
    // Assumptions:
    // * already positioned
    // * dockable

    print " dockingApproach".
    print "  aligning".
    gMyPort:ControlFrom.
    lock Steering to LookdirUp(-targetPort:PortFacing:ForeVector, Facing:UpVector).
    wait until Vang(Facing:ForeVector, -targetPort:PortFacing:ForeVector) < 2.
    local vSoll is 0.
    local dx is gMyPort:NodePosition-targetPort:NodePosition.
    local vErr is 0.
    local dZ is 0.

    //print "  xyErr=" +Round(Vxcl(targetPort:PortFacing:ForeVector, dx):Mag, 2).
    //print "  zDist=" +Round(Vdot(targetPort:PortFacing:ForeVector, dx),     2).
    RCS on.
    clearScreen2().
    local offset is 1.
    function update {
        wait 0.
        set dX to gMyPort:NodePosition-targetPort:NodePosition
                  -offset*targetPort:PortFacing:ForeVector.

        set vSoll to -dX:Normalized * Min(0.2, 3*dX:Mag).
        set vErr to Velocity:Orbit-Target:Velocity:Orbit -vSoll.
        if(vErr:Mag > 0.02)
          set Ship:Control:Translation to -Facing*(-vErr:Normalized).
        else
          set Ship:Control:Translation to V(0,0,0).

        print "dX   ="+Round(dX:Mag,2)    at (38,0).
        print "vSoll="+Round(vSoll:Mag,2) at (38,1).
        print "vErr ="+Round(vErr:Mag,2)  at (38,2).
    }

    print "  positioning".
    until (dX:Mag < 0.3) update().
    set offset to 0.
    RCS on.
    print "  final approach".

    //print "  port1: state=" +gMyPort:State.
    //print "  port2: state=" +targetPort:State.
    until (dX:Mag < 0.1) update().

    set Ship:Control:Translation to V(0,0,0).
    RCS off.
    wait until gMyPort:State:Contains("Docked").
    print "  docked".
    unlock Steering.
    killRotByWarp().
}

function cancelRelativeVel {
    parameter upVector.

    print " cancelRelativeVel".
    local t is 0.
    local acc is Ship:AvailableThrust / Mass.
    local v0dir is (Target:Velocity:Orbit - Velocity:Orbit):Normalized.
    local dV is v0Dir.
    lock Steering to LookdirUp(dV, upVector).
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
  local dockable is false.
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
    set dockable to true.
  }
  return dockable.
}

function chooseDockingPort {
  // Assumption: all ports are compatible
  local portList is Target:PartsTagged(Target:Name+"Port").
  print "  ports found on target: "+portList:Length.
  if (portList:Length=0) return false.

  // if not free -> discard
  local bestAngle is 999.
  local index is 0.
  until (index>=portList:Length) {
    local port is portList[index].
    if (port:State="READY"){
      local angle is Vang(port:PortFacing:ForeVector, port:NodePosition).
      print "  angle="+Round(angle,2).
      if (angle>70 and angle<bestAngle){
        set bestAngle to angle.
        set targetPort to port. // global variable declared by calling function
      }
    }
    set index to index+1.
  }

  print "  bestAngle="+Round(bestAngle,2).
  return (bestAngle<>999).
}
