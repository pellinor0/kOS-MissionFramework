// functions for rendezvous/docking with other vessels
@lazyglobal off.
print "  Loading librdv".

function checkRdv {
    parameter offsetP is V(0,0,0).
    wait 0.01.
    local rdvTime is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
    local dX1 is Target:Position+offsetP.
    local dX2 is PositionAt(Target,rdvTime)+offsetP -PositionAt(Ship,rdvTime).
    local dV1 is Target:Velocity:Orbit -VelocityAt(Ship,Time:Seconds):Orbit.
    local dV2 is VelocityAt(Target,rdvTime):Orbit
                -VelocityAt(Ship,  rdvTime):Orbit.
    //local dXErr  is dX2-dX1.
    local linErr is Vxcl(dV1, dX1).
    
    //local drift is getDriftPrediction().
    local orbitAng is (rdvTime-Time:Seconds)*360/Obt:Period.
    print "  checkRdv: ETA=" +Round(rdvTime-Time:Seconds, 1).
    print "            dX2=" +Round(dX2:Mag,2)
                   +", lin=" +Round(Vxcl(dV2,dX2):Mag,2).
    print "            dXL=" +Round(linErr:Mag, 2).
    print "            dXA=" +Round(Vang(dX2,linErr), 2).
    print "            OrA=" +Round(orbitAng, 1).
}

function rdvDock {
    print " rdvDock".
    if (Ship:Position-Target:Position):Mag >2200 {
        local rdvTime is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
        local v0 is (VelocityAt(Ship, rdvTime):Orbit- VelocityAt(Target, rdvTime):Orbit):Mag.
        if (rdvTime <= Time:Seconds) 
          print "WARNING: already past the closest approach!".
          
        warpRails(rdvTime - 2200/v0 ).  // warp until target is in physics bubble
    }
    
    wait until Target:Loaded.         // just to be sure
    local rcsDV is getRcsDeltaV().
    
    // find docking ports
    local dock is 0.
    local tmp is Target:DockingPorts.
    local targetPort is 0.
    if (gDockable and tmp:Length>0) {
      set targetPort to tmp[0].
      set dock to 1.
      print "  Docking possible".
      //print "  port="+targetPort.
    } else print "  Docking not possible: Rdv only".
    
    wait 0.01.
    if dock {
        // gShipRadius from target port
        lock gOffset to targetPort:NodePosition -Target:Position
                       +targetPort:PortFacing:Forevector*gShipRadius.
        lock targetUp to targetPort:PortFacing:Forevector.
    } else {
        // behind target
        lock targetUp to (Body:Position -Target:Position):Normalized.
        lock gOffset to (10+gShipRadius)*targetUp.
    }
    lock targetPos to Target:Position+gOffset.
    print "  offset="+Round(gOffset:Mag,2).
    
    local rdvT is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
    local tmpDX is PositionAt(Ship,rdvT)-PositionAt(Target,rdvT).
    local useRCS is (hasRcs() and getRcsDeltaV()>5).
    
    function doCorrection {
        print " correction".
        set rdvT to findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
        local dX2 is PositionAt(Target,rdvT) +gOffset -PositionAt(Ship,rdvT).
        local dV2 is VelocityAt(Target,rdvT):Orbit
                    -VelocityAt(Ship,  rdvT):Orbit.
        set dX2 to Vxcl(dV2,dX2).
        print "  dx2="+Round(dX2:Mag,2).
        print "  dt ="+Round(rdvT -Time:Seconds).
        local dV is dX2/(rdvT -Time:Seconds).
        print "  dV ="+Round(dV:Mag,2).
        
        if (dV:Mag>2 or not useRCS) {
            local nodeDV is -getOrbitFacing()*dV.
            add Node(Time:Seconds+1,nodeDV:X,nodeDV:Y,nodeDV:Z).
            wait 0.01.
            execNode(false).
        } else {
            rcsPrecisionBurn(dV).
        }
    }
    wait 0.01.
    if(Target:Position:Mag>600) { doCorrection(). }
    checkRdv(gOffset).
    
    rdv(targetPos, targetUp).
    unlock targetPos.
    unlock gOffset.
    unlock Steering.
    
    if dock {
        dockingApproach(targetPort).
        wait 1.
        Core:DoEvent("open terminal").
    }
    local rcsDV2 is getRcsDeltaV().
    print "  rcsDv used="+Round(rcsDv-rcsDv2,2).
}

function dockingApproach {
    parameter targetPort.
    // Assumptions: 
    // * already positioned 
    // * dockable
    
    print " dockingApproach".
    print "  aligning".
    gMyPort:GetModule("ModuleDockingNode"):DoEvent("control from here").
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
        wait 0.01.
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

function rdv {
    // Assumptions: 
    // * targetPos is a part of Target vessel
    parameter targetPos.     // (Vector) lock to target position
    parameter upVector.
    
    local v0 is (Velocity:Orbit - Target:Velocity:Orbit).
    local acc is Ship:AvailableThrust / Mass.
    local accFactor is 1.
    if (acc > 1) {  // limit TWR for stability
        set accFactor to 1/acc.
        set acc to acc*accFactor.
    }

    local brakeAcc is 0.0001.
    local corrAcc is 0.
    local vErr is 0.
    local tt is 0.
    local dX is v(100000,0,0).
    local dV is Velocity:Orbit - Target:Velocity:Orbit.
    local steerVec is -dV:Normalized*brakeAcc.
    local offset is V(0,0,0).
    local count is 0.
    local far is true.    // use orbital mechanics
    local useRCS is (hasRcs() and getRcsDeltaV()>5). // do lateral corrections with RCS
    local rdvT is 0.
    
    lock Throttle to tt.
    lock Steering to Lookdirup(steerVec, upVector).
    if useRCS {
        wait until Vang(Steering:ForeVector, Facing:ForeVector)<3.
        wait until Vang(Steering:TopVector, Facing:TopVector)<3
                and Ship:AngularVel:Mag<0.05.
        RCS on.
    }
    clearScreen2().
    
    function update {
        wait 0.01. 
        set dX to (targetPos() -Ship:Position).
        set dV to Velocity:Orbit - Target:Velocity:Orbit.
        set brakeAcc to dV:SqrMagnitude/(2* Vdot(dV:Normalized, dX)).
        if far {
            if Mod(count,20)=0 { // expensive stuff
                set rdvT to findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
                set offset to targetPos()-Target:Position.
                if (dX:Mag<50) set far to false.
            }
            local dX2 is PositionAt(Target,rdvT) +offset -PositionAt(Ship,rdvT).
            local dV2 is VelocityAt(Target,rdvT):Orbit
                        -VelocityAt(Ship,  rdvT):Orbit.
            set dX2 to Vxcl(dV2,dX2).
            set vErr to Vxcl(dV, -dX2/(rdvT -Time:Seconds)).
        } else {
            set vErr to Vxcl(dX, dV).
            // try to negate vErr/5 per second
            set corrAcc to vErr:Mag/5. 
        }
        debugDirection(Steering).
        
        // correct with RCS if available
        if useRCS {
            if (vErr:Mag<0.05) set Ship:Control:Translation to V(0,0,0).
              else set Ship:Control:Translation to -Facing*(-vErr:Normalized).
            set steerVec to -dV:Normalized*brakeAcc.
        } else {
            set corrAcc to vErr:Mag/5.
            set steerVec to -dV:Normalized*brakeAcc -vErr:Normalized*corrAcc.
        }
        
        local ttt is Max(0, Vdot(steerVec, Facing:Forevector)*accFactor).
        if (brakeAcc>acc/2)               // braking
          set tt to steerVec:Mag/acc *ttt.
        else if (Vang(steerVec, -dV) > 45) // correction
          set tt to steerVec:Mag/acc *ttt.
        else
          set tt to 0.

        print "bAcc=" +Round(brakeAcc,    2) at (38, 0).
        print "cAcc=" +Round(corrAcc,     2) at (38, 1).
        print "sAcc=" +Round(steerVec:Mag,2) at (38, 2).
        print "tAcc=" +Round(tt*acc/accFactor,2)+"  " at (38, 3).
        print "dX  =" +Round(dX:Mag,      1) at (38, 4).
        print "ang =" +Round(Vang(steerVec, -dV) ,1) +"  " at (38,5).
        print "vErr=" +Round(vErr:Mag,3)+"   " at (38, 6).
        print "dV  =" +Round(dV:Mag,2)        at (38,8).
        set count to count+1.
    }

    
    print " brake burn".
    until (dX:Mag < 400) update().
    set Warp to 0.

    until (dX:Mag < 200) update(). checkRdv().
    //set Warp to 0.
    
    until (dV:Mag < 0.2 or Vdot(dV, dX)<0) update().

    //print "  dx="+vecToString(dx).
    //print "  dV="+vecToString(dv).
    debugDirectionOff().
    unlock Throttle.
    unlock Steering.
    RCS off.
    
    print "  ds1="+Round(Vdot(Ship:Position - targetPos(), dV:Normalized), 3).
    killRot().
    if (Ship:PartsDubbed(gShipType+"RCS"):Length>1)
      cancelRelativeVelRcs().    
    else
      cancelRelativeVel(upVector).
    
    print "  ds2="+Round(Vdot(Ship:Position - targetPos(), dV:Normalized), 3).
    print "  dV ="+Round((Velocity:Orbit - Target:Velocity:Orbit):Mag, 3).
}

function cancelRelativeVel {
    // * sync velocities with TARGET
    parameter upVector.
    
    print " cancelRelativeVel".
    local t is 0.
    local acc is Ship:AvailableThrust / Mass.
    local v0dir is (Target:Velocity:Orbit - Velocity:Orbit):Normalized.
    local dV is v0Dir.
    lock Steering to LookdirUp(dV, upVector).
    lock Throttle to (dV:Mag/acc)*2.5 *t^10.
    
    // loop until stop or overshoot
    until (dV:Mag < 0.001) or (Vdot(v0dir, dV:Normalized) < 0) {
        wait 0.01.
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
    // loop until stop or overshoot
    until (dV:Mag < 0.001) or (Vdot(v0dir, dV:Normalized) < 0) {
        wait 0.01.
        set dV to Target:Velocity:Orbit - Velocity:Orbit.
        
        set tmpVec to -Facing * dV:Normalized.
        if(tmpVec:Mag < 0.02) set tmpVec to tmpVec *0.02/tmpVec:Mag.
        set Ship:Control:Translation to tmpVec.
        
        //print "  tr="+Round(tmpVec:x,3) +Round(tmpVec:y,3) +Round(tmpVec:z,3) at (0,48).
        print "dV   ="+Round(dV:MAG,2)    at (38,0).
        print "t    ="+Round(t , 3)       at (38,1).
    }
    RCS off.
    set Ship:Control:Translation to V(0,0,0).
    
    local vErr is Target:Velocity:Orbit - Velocity:Orbit.
    print "  mp  ="+Round(Ship:MonoPropellant -mp, 3).
    print "  vErr="+Round(vErr:Mag, 4).
//     print "  dV  ="+Round((v0-vErr):x,4) +", "+Round((v0-vErr):y,3)+", "+Round((v0-vErr):z,3).
//     print "  v0  ="+Round(v0:x,4)        +", "+Round(v0:y,3)       +", "+Round(v0:z,3).
//     print "  vDot="+Round(Vdot(v0dir, dV:Normalized), 2).
    //print "  finished: v="+dV:Mag.
}

