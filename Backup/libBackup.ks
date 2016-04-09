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


// does not work yet
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
