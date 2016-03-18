// unbenutzte Funktionen

//  SMA fuer hyperbol. orbit
//    https://en.wikipedia.org/wiki/Semi-major_axis
//    local sma is 1/(v1:Mag^2/Body:Mu + 2/Altitude.Body:Radius).

//  Refine hohmann
//    https://github.com/xeger/kos-ramp/blob/master/node_hoh.ks

//  Inclination math
//    https://github.com/xeger/kos-ramp/blob/master/node_inc_tgt.ks



// trueAnomaly = angle between PE and position
function time_pe_to_ta {
    parameter
      orbit_in, // orbit
      ta_deg.   // target true anomaly [degrees]

    local ecc is orbit_in:Eccentricity.
    local sma is orbit_in:SemiMajorAxis.
    local e_anom_deg is arcTan2( sqrt(1-ecc^2) *sin(ta_deg), ecc + cos(ta_deg) ).
    local e_anom_rad is e_anom_deg * pi/180.
    local m_anom_rad is e_anom_rad - ecc*sin(e_anom_deg).
    return m_anom_rad / sqrt( orbit_in:Body:Mu / sma^3).
}
function eta_to_ta {
    parameter
      orbit_in,
      ta_deg.
    
    local targetTime is time_pe_to_ta(orbit_in, ta_deg).
    local curTime is time_pe_to_ta(orbit_in, orbit_in:TrueAnomaly).
    local ta is targetTime-curTime.
    if ta<0 set ta to ta +orbit_in:Period.
    return ta.
}


// gute Idee aber tut noch nicht
function f_refineHohmann {
    set Terminal:Height to 100.
    print "f_refineHohmann".
    
    // time of other end
    local t is Time:Seconds +NextNode:Eta +NextNode:Orbit:Period/2.
    local synPeriod is 1/ (1/Ship:Obt:Period - 1/Target:Obt:Period).
    print "  synPeriod=" +Round(synPeriod).
    
    
    // Frame: my facing at AP (fore=prograde, up=radial)
    lock rad to PositionAt(Ship,t)-Body:Position.
    lock vel to VelocityAt(Ship,t):Orbit.
    lock frame to LookdirUp(vel, rad).
    // distance
    lock dist to PositionAt(Target,t)-PositionAt(Ship,t).
    print "  dist="+Round(dist:Mag).
    
    // transform       (vermutlich Star/Top/Fore = -Norm/Rad/Pro)
    lock dist2 to -frame*dist. // ?/?/Prograde
    print "  dist=" +vecToString(dist2).

    print " Step1: Phase".
    local t1 is synPeriod * (dist2:Z / (3.1415*(Target:Apoapsis +Target:Periapsis))).
    print "  t1="+Round(t1).
    
    print "  oldEta=" +Round(NextNode:Eta).
    //wait 100.
    set NextNode:Eta to NextNode:Eta-t1.
    wait 0.001.
    print "  dist=" +vecToString(dist2).
    
    
    
    print " Step2: Altitude".
    print "  r1="+(rad:Mag-Body:Radius).
    print "  r2="+((PositionAt(Target,t)-Body:Position):Mag-Body:Radius).
    print "  rErr=" +dist2:Y.
    
    
    print " Step3: Inclination".
    
    
    wait 1000.
    //local r1 is Obt:
    //unlock t.
}

function f_dockingApproachNose {
    // Assumptions:
    // * DockingPort is the outermost part of the vessel
    // * DockingPort points (exactly) forward and in line with CoM
    // * target is in loading range

    // find target port
    //   (better: search for correct type of dockingNode)
    local targetPort is Target:DockingPorts[0].
    local delta is 0.25.
    local myLength is (Ship:Position - myPort:NodePosition):Mag.
    lock targetPos to targetPort:NodePosition +(myLength + delta)*targetPort:PortFacing:Vector.
    f_rdv(targetPos).
    unlock targetPos.
    
    print "Docking".
    unlock Steering.
    lock Steering to LookdirUp(-targetPort:Facing:Forevector, Ship:Facing:TopVector).
    wait until (Ship:DockingPorts[0]:NodePosition - targetPort:NodePosition):Mag < 0.01.
    unlock Steering.
    wait 1.
    killRot().
}

function f_syncVel {
    // sync velocities with target (at time t)
    parameter rdvTime.  // time 
    PRINT "f_syncvel: rdvTime=" +rdvTime.
    local tt is 0.
    lock Throttle to tt.
    
    // warp to burn
    set vRel to (VelocityAt(Ship, rdvTime):Orbit - VelocityAt(Target, rdvTime):Orbit).
    lock Steering to (-vRel):Direction. 
    //PRINT "  orienting ship".
    wait until VectorAngle(Ship:Facing:Vector, -vRel) < 1.
    
    set burnTime to vRel:MAG * Ship:MASS/thrust.
    print burntime.
    local tmpTime  to rdvTime - (burnTime/2). 
    f_warpRails(tmpTime).
    
    // burn
    local lock vRel to Ship:Velocity:Orbit - Target:Velocity:Orbit.
    wait until Time:Seconds > rdvTime -(burntime/2) +0.1.
    set tt to 1. 
    wait until vRel:MAG < 10.
    set Warp to 0.
    set tt to 0.1.
    wait until vRel:MAG < 1.
    set tt to 0.02.
    wait until vRel:MAG < 0.05.
    set tt to 0.
    unlock Steering.
    unlock Throttle.
}

// obsolete (better new version)
function killNodeInclination {
    // manipulate normal component of an an existing node
    // Assumption: Node is set
    // Assumption: angle is small
//     print "  killNodeInclination".
//     print "  dV  before: " +Round(NextNode:DeltaV:Mag, 2).
//     print "  inc before: " +Round(NextNode:Orbit:Inclination, 3).
    local t is Time:Seconds+NextNode:Eta+1. // after node
    local v is VelocityAt(Ship,t):Orbit.
    local vErr is Vdot(v, North:Vector).
    set NextNode:Normal to NextNode:Normal-Verr.
    local factor is 1+(vErr/v:Mag)^2. // small angle approximation
    set NextNode:Prograde to NextNode:Prograde*factor.
    set NextNode:Normal to NextNode:Normal*factor.
    set NextNode:RadialOut to NextNode:RadialOut*factor.
//     wait 0.001.
//     print "  dV after:  " +Round(NextNode:DeltaV:Mag, 2).
//     print "  inc after: " +Round(NextNode:Orbit:Inclination, 3).
//     print "  factor=" +Round(factor, 5).
//     print "  vErr="   +Round(vErr,   2).
}

// backup 13.2.2016, falls ich sie kaputt-entwickle
function atmoAscentPlane {
    
    local tt is 1.
    lock Throttle to tt.
    local pp is 10.
    local lock rollCorr to -Vdot(Velocity:Orbit:Normalized, North:Vector).
    local lock velPP to 90-Vang(Up:Vector, Velocity:Surface).
    lock Steering to Heading (90, Max(pp-gBuiltinAoA, velPP-2)) *R(0,0,rollCorr).
    local engines is Ship:PartsDubbed(gShipType+"Engine").
    //lock Steering to Heading (90,pp -gBuiltinAoA).
    // quelle // lock Steering to SrfPrograde *R(0,0,roll) *R(-(aoa+aoaCorr-gBuiltinAoA),0,0).
    stage. 
    set WarpMode to "PHYSICS".
    set Warp to 3.

    wait until (Status <> "PRELAUNCH" and Status <> "LANDED").
    print "  takeoffVel="+Round(Velocity:Surface:Mag,1).
    
    wait until (Altitude - Max(0, GeoPosition:TerrainHeight) > 20).
    Gear off.

    print "  Initial Climb".
    local acc is Ship:AvailableThrust / Mass.
    print "  acc="+Round(acc,2).
    if acc>20 {set pp to 70. wait until Apoapsis > 4000.  print "  pitch 70".} 
    if acc>10 {set pp to 50. wait until Apoapsis > 6000.  print "  pitch 50".}
    if acc>10 {set pp to 40. wait until Apoapsis > 8000.  print "  pitch 40".}
    if acc>7  {set pp to 30. wait until Apoapsis > 10000. print "  pitch 30".}
    if acc>5  {set pp to 20. wait until Apoapsis > 17000. print "  pitch 20".}
    
    print "  Speed Run".
    set pp to 13. 
    set Warp to 1.  // better: wait until max speed / ttA decreases
    local velTmp is Velocity:Orbit:Mag.
    until (engines[0]:Thrust < 30) or (Velocity:Orbit:Mag<velTmp) {
        set velTmp to Velocity:Orbit:Mag.
    }
    
    print "  Switch mode: vel=" +Round(Velocity:Surface:Mag).
    set pp to 23. 
    for eng in engines {
        if (eng:Isp > 1000)  // don't do this twice on resume
          eng:GetModule("MultiModeEngine"):DoEvent("Toggle Mode").
    }
    
    wait until Apoapsis > gLkoAP*0.99. // leave room for some lift
    set tt to 0.
    unlock Throttle. 
    
    print "  AP reached. Coasting to space".
    coastToSpace(gLkoAP).
    wait until Altitude > Body:Atm:Height.
    unlock Steering.
}