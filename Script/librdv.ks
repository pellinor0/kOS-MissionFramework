// functions for rendezvous/docking with other vessels
@lazyglobal off.
print "  Loading librdv".

function rdvDock {
    print " rdvDock".
    if (Ship:Position-Target:Position):Mag >1500 {
        local rdvTime is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
        local v0 is (VelocityAt(Ship, rdvTime):Orbit- VelocityAt(Target, rdvTime):Orbit):Mag.
        deb("r1").
        warpRails(rdvTime - 1500/v0 ).  // warp until target is in physics bubble
    }
    // debug vv
    deb("r2").
    // debug ^^
    wait until Target:Loaded.         // just to be sure
        
    // find docking ports
    local dock is 0.
    local tmp is Target:DockingPorts.
    local targetPort is 0.
    if (dockable and tmp:Length>0) {
      set targetPort to tmp[0].
      set dock to 1.
      print "  Docking possible".
    } else print "  Docking not possible: Rdv only".
    
    wait 0.01.
    local offset is V(0,0,0).
    if dock {
        set offset to -myPort:PortFacing*(myPort:NodePosition-Ship:Position).
        print "  offset=" +vecToString(offset).
        lock frame to LookdirUp(-targetPort:PortFacing:Forevector,
                                 targetPort:PortFacing:UpVector).
        lock targetPos to targetPort:NodePosition              
                          +frame*(-offset+gShipRadius*V(0,0,-1)).
    } else {
        lock targetPos to Target:Position+ 20*Target:Retrograde:Vector. // 20m behind Target
    }
    
    rdv(targetPos, targetPort:PortFacing:Forevector).
    unlock targetPos.
    unlock Steering.
    
    if dock {
        dockingApproach(targetPort).
        wait 1.
        Core:DoEvent("open terminal").
    }
}

function dockingApproach {
    parameter targetPort.
    // Assumptions: 
    // * already positioned 
    // * dockable
    
    print "  dockingApproach".
    myPort:GetModule("ModuleDockingNode"):DoEvent("control from here").
    lock Steering to LookdirUp(-targetPort:PortFacing:ForeVector, 
                               targetPort:PortFacing:UpVector).
    wait until Vang(Facing:ForeVector, -targetPort:PortFacing:ForeVector) < 2.
    wait until Vang(Facing:UpVector,   targetPort:PortFacing:UpVector)   < 2.
    local vSoll is 0.
    local dx is myPort:NodePosition-targetPort:NodePosition.
    local vErr is 0.
    
    //print "  Aligned".
    print "  xyErr=" +Round(Vxcl(targetPort:PortFacing:ForeVector, dx):Mag, 2).
    print "  zDist=" +Round(Vdot(targetPort:PortFacing:ForeVector, dx),     2).
    
    RCS on.
//     set Ship:Control:Fore to 1.
//     set Ship:Control:Fore to 0.
    
    until  ( dX:Mag < 0.1) {
        wait 0.01.
        set dX to myPort:NodePosition-targetPort:NodePosition.
        set vSoll to -dX:Normalized * 0.2.
        set vErr to Velocity:Orbit-Target:Velocity:Orbit -vSoll.
        if(vErr:Mag > 0.03)
          set Ship:Control:Translation to -Facing*(-vErr:Normalized*0.2).
        else
          set Ship:Control:Translation to V(0,0,0).
          
        print "dX   ="+Round(dX:Mag,2)    at (38,0).
        print "vSoll="+Round(vSoll:Mag,2) at (38,1).
        print "vErr ="+Round(vErr:Mag,2)  at (38,2).
    }
    // braking
    
    set Ship:Control:Translation to V(0,0,0).
    //myPort:State:Contains("Docked")
    RCS off.
    unlock Steering.
    print "  docked".
}

function rdv {
    // Assumptions: 
    // * we are in space
    // * targetPos is close enough to ignore orbital mechanics
    parameter targetPos.     // (Vector) lock to target position
    parameter upVector.
    
    //PRINT "rdv".
    local v0 is (Velocity:Orbit - Target:Velocity:Orbit).
    local acc is Ship:AvailableThrust / Mass.
    local accFactor is 1.
    if (acc > 1) {  // limit TWR for stability
        set accFactor to 1/acc.
        set acc to acc*accFactor.
    }

    local brakeAcc is 0.
    local corrAcc is 0.
    local vErr is 0.
    local tt is 0.
    local steerVec is -Velocity:Surface.
    lock Steering to Lookdirup(steerVec, upVector).
    lock Throttle to tt.
    local dX is v(100000,0,0).
    local dV is v0.
    
    function update {
        wait 0.01. 
        
        debugDirection(Steering).
        set dV to Velocity:Orbit - Target:Velocity:Orbit.
        
        print "tPos=" +vecToString(targetPos) at (38, 7).
        set dX to (targetPos() -Ship:Position).

        set brakeAcc to dV:SqrMagnitude/(2* Vdot(dV:Normalized, dX)).
        set vErr to Vxcl(dX, dV).
        
        // try to negate vErr/10 per second
        set corrAcc to vErr:Mag/5. 
        set steerVec to -dV:Normalized*brakeAcc -vErr:Normalized*corrAcc.
        
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
        print "vErr=" +Round(vErr:Mag,1)+"  "    at (38, 6).
    }

    print " brake burn".
    set WarpMode to "RAILS".
    set Warp to 3. // 50x
    
    until (dX:Mag < 2000) update().
    set WarpMode to "PHYSICS".
    set Warp to 3. // 4x

    until (dX:Mag < 500) update().
    set Warp to 1.

    until (dV:Mag < 100) update().
    set Warp to 0.
    
    until (dV:Mag < 0.2 or Vdot(dV, dX)<0) update().

    print "  dx="+vecToString(dx).
    print "  dV="+vecToString(dv).
    debugDirectionOff().
    unlock Throttle.
    unlock Steering.
    
    print "  ds1="+Round(Vdot(Ship:Position - targetPos(), dV:Normalized), 3).
    if (Ship:PartsDubbed(gShipType+"RCS"):Length>1)
      cancelRelativeVelRcs().    
    else
      cancelRelativeVel(upVector).
    
    print "  ds1="+Round(Vdot(Ship:Position - targetPos(), dV:Normalized), 3).
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

