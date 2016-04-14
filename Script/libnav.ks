// more complex navigation things
@lazyglobal off.
print "  Loading libnav".

// == make a new node ==
function nodeFineRdv {
    local t is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
    add Node( (Time:Seconds + t)/2, 0,0,0 ).
    refineRdvBruteForce(t).
}

function nodeHohmannInc {
    // Assumption: we just started a hohmann Transfer
    // => correct Inclination at half way
    print " nodeHohmannInc".
    local t is timeToAltitude( (Apoapsis+Periapsis)/2 ).
    //print "  t=" +Round(t-Time:Seconds).
    //print "  height=" +Round( (Apoapsis+Periapsis)/4).
    local t2 is findClosestApproach(Time:Seconds, Time:Seconds+Obt:Period).
    //print "  t="+Round(t-Time:Seconds).
    //local tFrame is getOrbitFacing(Target,Time:Seconds+Eta:Apoapsis).
    local pos is PositionAt(Ship,t).
    local tgtNormal is Vcrs(Body:Position-pos, PositionAt(Target,t2)-pos):Normalized.
    local vZ is Vdot(VelocityAt(Ship,t):Orbit, tgtNormal).
    print "  vz="+Round(vZ,2).
    
    add Node(t,0,-vZ,0).
    refineRdvBruteForce(t2).
}

function nodeTuneCapturePE {
    parameter pe.
    // Assumption: we are just entering the SOI
    
    // binary search
    local startDV is Vxcl(Ship:Position-Body:Position, Velocity:Orbit):Mag.
    add Node(Time:Seconds+30, -startDV+1,0,0).
    local d is 1.
    local step is 2.
    until (Abs(d)<0.02) {
        set NextNode:RadialOut to NextNode:RadialOut+d.
        wait 0.01.
        //print "  pe="+Round(NextNode:Orbit:Periapsis) 
        //     +", dV="+Round(NextNode:RadialOut,2) +", d="+Round(d,3).
        
        if (NextNode:Orbit:Periapsis > pe) {
            if (d>0) {
                set step to 0.5.
                set d to -d.
            }
        } else if d<0 set NextNode:RadialOut to NextNode:RadialOut-d.
        set d to d * step.
    }
}

function nodeReturnFromMoon {
    // Assumption: prograde circular equatorial orbit
    
    // find final speed
    local tgtPE is 70000.
    local parent is Body:Body.
    local tgtAP is 0.5*(Body:Orbit:Apoapsis+Body:Orbit:Periapsis).
    local sma is 0.5*(tgtAP +tgtPE) +parent:Radius.
    local rad is tgtAP+parent:Radius.
    local tgtVel is Sqrt(parent:Mu*(2/rad - 1/sma )). // vis viva eq.
    print "nodeReturnFromMoon".
    //print "  tgtVel ="+Round(tgtVel,1).
    //print "  bodyVel="+Round(Body:Velocity:Orbit:Mag).
    set tgtVel to Body:Orbit:Velocity:Orbit:Mag -tgtVel.
    
    local escVel is Sqrt(2*Body:Mu / (Altitude+Body:Radius)).
    //print "  escVel =" +Round(escVel).

    local nodeVel is Sqrt( tgtVel^2 + escVel^2).
    
    add Node(Time:Seconds, 0,0,nodeVel-Velocity:Orbit:Mag).
    print "  dvCost="+Round(nodeVel-Velocity:Orbit:Mag, 2).
    wait 0.01.
    
    // check direction => shift time
    // Assumption: prograde circ equatorial orbit
    // theta-90° should be the angle between nodeVel and escapeVel
    local theta is ArcCos(-1 / NextNode:Orbit:Eccentricity).
    local retroLng is Body:GeoPositionOf(Body:Position -Body:Obt:Velocity:Orbit):Lng.
    local waitAngle is retroLng -theta - Longitude.
    until (waitAngle>0) set waitAngle to waitAngle+360.
    //print "  waitAngle=" +Round(waitAngle,2).
    //print "  theta=" +Round(theta,2).
    set NextNode:Eta to NextNode:Eta +Obt:Period*waitAngle/360.
    tweakNodeInclination( Vcrs(Body:Obt:Velocity:Orbit, Body:Position-Body:Body:Position), -1).
    
    print" try to get an AN/DN halfway home".
    
    // * target (kerbin) orbit normal: 
    //   find time halfway home, project pos to eq plane
    //   plane through Body, Body:Body and that point
    local parentOrbit is NextNode:Orbit:NextPatch.
    local halftime is Time:Seconds+parentOrbit:Period/4.
    local tHalfPos is timeToAltitude2(parentOrbit:Apoapsis/2, 
                                      halfTime, halfTime+parentOrbit:Period/4).
    //print "  tHalfPos=" +Round(tHalfPos -Time:Seconds).
    //print "  halfTime=" +Round(halfTime -Time:Seconds).
    
    // => parentNormal is wrong (SOI coords of parent instead of local SOI)
    //    but seems to be close enough
    local parentNormal is -Body:Body:AngularVel:Normalized.
    //print "  parentNormal=" +vecToString(parentNormal).
    
    // == tmpHeight is what we want to bring to zero. ==
    lock tmpHeight to Vdot(parentNormal, PositionAt(Ship,tHalfPos)-Body:Body:Position ).
    
    
    // binary search
    local d is 128.
    local step is 2.
    local par is -128.
    until (Abs(d)<0.001 or Abs(d)>10000) {
        local moonPrograde is Vcrs(V(0,1,0), Body:Position-Body:Body:Position):Normalized.
        //print "  moonPrograde=" +vecToString(moonPrograde).
        
        set par to par+d.
        local escNormal is -par*moonPrograde + 100*V(0,1,0).
        tweakNodeInclination(escNormal, -1).
        wait 0.01.
//          print " Iteration".
//          print "  par="+Round(par,3).
//          print "  tmpHeight="+Round(tmpHeight).
        if (tmpHeight>0) {
            if (d>0) {
                set step to 0.5.
                set d to -d.
            }
        } else if d<0 set par to par-d.
        set d to d * step.
    }
    print "  dvCost="+Round(NextNode:DeltaV:Mag -(nodeVel-Velocity:Orbit:Mag), 2).
    
// == old code ==    
// => more analytical calculation
// (probably useful when starting from an inclined orbit)
//     local tgtNormal is Vcrs(midPos-Body:Body:Position, midPos-Body:Position):Normalized.
//     print "  tgtNormal="+vecToString(tgtNormal).
//     print "  tgtInc   ="+Round(VectorAngle(tgtNormal, parentNormal),2).
//     
//     // * this gives a target normal speed at escape
//     // * get target (Moon) orbit plane from that
//     local parentVel is tgtVel*Vcrs(tgtNormal, Body:Position-Body:Body:Position):Normalized.
//     print "  bodyVel=" +vecToString(Body:Obt:Velocity:Orbit).
//     local bodyNormal is Vcrs(Body:Orbit:Velocity:Orbit, 
//                              Body:Position-Body:Body:Position):Normalized.
//     print "  bodyNormal=" +vecToString(bodyNormal).
//     // ^^ above is in parent-SOI-coords
//     // vv belov is in moon-SOI coords
//     local escNormalVel is Vdot( bodyNormal, parentVel ) / 2.
//     print "  escNormalVel=" +Round(escNormalVel, 2).
//     local escHorizVel is Sqrt(escVel^2 - escNormalVel^2).
//     print "  escHorizVel=" +Round(escHorizVel,2).
//     local escNormal is escNormalVel*moonPrograde + escHorizVel*V(0,1,0). // moon-frame
// //    local escNormal is escNormalVel*Body:Orbit:Velocity:Orbit:Normalized 
// //                      +escHorizVel*bodyNormal. // parent-fr
//     print "  escNormal=" +vecToString(escNormal).
//     print "  escAngle=" +Vang(escNormal, V(0,1,0)).
//     
//     //tweakNodeInclination(escNormal, -1).
//     print "  actEscAngle="+Round(VectorAngle(Vcrs(Body:Position,Velocity:Orbit),V(0,1,0)),2).
    
    //todo: same thing from an inclined orbit
    //      (when launching from a non-eq moon base)
}

function nodeIncChange {
    // change inclination at next AN/DN
    parameter tgtNormal.
    add Node(timeToAnDn(tgtNormal), 0,0,0).
    tweakNodeInclination(tgtNormal, -1).
}

function nodeHohmann {
    // Assumption: Target is set
    //             Target orbit is equatorial
    //             Ship orbit is circular
    // Return: rdvTime = Time(UT) of Intersect
    wait 0.01.
    local synPeriod is 1/ (1/Obt:Period - 1/Target:Obt:Period).
    local ap is (Target:Apoapsis + Target:Periapsis)/2.
    //local transTime is (Target:Obt:Period + Obt:Period)/4.
    local transSma is Body:Radius +(Altitude +ap)/2.
    local transTime is Sqrt(4*3.1415^2 *transSma^3 /Body:Mu)/2.
    local transAngle is -(-180 +transTime/Target:Obt:Period *360).
    local waitAngle is Target:Longitude - Longitude - transAngle. 
    if (waitAngle < 0) set waitAngle to waitAngle+360.
    local waitTime is waitAngle * synPeriod/360.
    local rdvTime is Time:Seconds +transTime +waitTime.

//      print " hohmannNode".
//      print "  transTime  ="+Round(transTime).
//      print "  transSma   ="+Round(transSma).
//      print "  phase angle="+Round(phaseAngle, 2).
//      print "  synPeriod  ="+Round(synPeriod).
//      print "  transAngle ="+Round(transAngle, 2).
//      print "  waitAngle  ="+Round(waitAngle, 2).
//      print "  waitTime   ="+Round(waitTime).
//      print "  ETA to rdv ="+Round(rdvTime-Time:Seconds).
//      print "  tgtAP      ="+Round(ap).

    local t is Time:Seconds +waitTime.
    nodeUncircularize(ap, t).
    wait 0.01.
    
    until not (NextNode:Orbit:Transition = "ENCOUNTER" and 
        NextNode:Orbit:NextPatch:Body <> Target) {
        print "  WARNING: Encounter with wrong Body! Delaying transfer.".
        print "   transition="+NextNode:Orbit:Transition.
        print "   name="+NextNode:Orbit:NextPatch:Body.
        set NextNode:Eta to NextNode:Eta +synPeriod.
        wait 2.
    }
    
    // refine
//     print " initial node".
//     local frame is getOrbitFacing(Ship, rdvTime).
//     local dX is -frame*(PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime)).
//     local dv is -frame*(VelocityAt(Target,rdvTime):Orbit-VelocityAt(Ship,rdvTime):Orbit).
//     print "  dx="+vecToString(dx/1000).
//     print "  dv="+vecToString(dv).
    // diff = rad+, norm+, prograde
    
    // radial => change node:Prograde
//     print " tune prograde".
//     //set ap to ap+dX:X.
//      print "  apOld=" +Round((Target:Apoapsis + Target:Periapsis)/2).
//      print "  tgtAP=" +Round(Target:Apoapsis).
//      print "  tgtPE=" +Round(Target:Periapsis).
     
//     set ap to (PositionAt(Target,rdvTime)-Body:Position):Mag -Body:Radius.
//     print "  apNew=" +Round(ap).
//     print "  dAP ="+Round(ap -NextNode:Orbit:Apoapsis).
//     remove NextNode.
//     nodeUncircularize(ap, t).
//     wait 0.01.
//     set rdvTime to NextNode:Eta+NextNode:Orbit:Period/2.
//     set frame to getOrbitFacing(Ship, rdvTime).
//     set dX to -frame*(PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime)).
//     set dv to -frame*(VelocityAt(Target,rdvTime):Orbit-VelocityAt(Ship,rdvTime):Orbit).
//     print "  dx="+vecToString(dx/1000).
//     print "  dv="+vecToString(dv).
    
    // prograde => shift t (linear approx)
//     print " tune timing".
//     set NextNode:Eta to NextNode:Eta +dx:Z/dv:Z.
//     print "  dt="+Round(dx:Z/dv:Z).
//     wait 0.01.
//     set frame to getOrbitFacing(Ship, rdvTime).
//     set dX to -frame*(PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime)).
//     set dv to -frame*(VelocityAt(Target,rdvTime):Orbit-VelocityAt(Ship,rdvTime):Orbit).
//     print "  dx="+vecToString(dx/1000).
//     print "  dv="+vecToString(dv).
//     
//     add Node(Time:Seconds+ NextNode:Eta+ 2*6*3600, 0,6,0).
    
     //run once libnav.
     //refineRdvBruteForce(rdvTime).
    
    local n is getOrbitNormal(Ship).
    local h is Vdot(PositionAt(Target,rdvTime)-Body:Position, n)/2.
    local tgtAngle is arcTan(h/NextNode:Orbit:SemiMinorAxis).
    //print "  n="+vecToString(n).
    //print "  h="+Round(h).
    //print "  tgtAngle="+Round(tgtAngle,2).
    local tgtNormal is n*Sqrt(NextNode:Orbit:SemiMinorAxis^2 + h^2)
                       -VelocityAt(Ship,Time:Seconds+NextNode:Eta+0.1):Orbit:Normalized*h.
    tweakNodeInclination(tgtNormal, 0.01).
    return rdvTime.
}

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
    //set synPeriod to 2*Orbit:Period -synPeriod.  // correction if Retrograde
    //print "  period   ="+Round(Obt:Period).
    //print "  synPeriod="+Round(synPeriod).
    //print "  rotPeriod="+Round(Body:RotationPeriod).
    local lngErr is 1000.
    local t2 is 0.
    local counter is 0.
    until Abs(lngErr)<0.1 or counter>6 {
        //print " Iteration".
        set t2 to timeToAltitude2(tgtHeight,
                                    Time:Seconds+NextNode:Eta,
                                    Time:Seconds+NextNode:Eta+NextNode:Orbit:Period/2).
        local lng1 is Body:GeoPositionOf(PositionAt(Ship,t2)):Lng.
        local lng2 is tgtPos:lng +360*(t2-Time:Seconds)/Body:RotationPeriod.
        set lngErr to lng1-lng2.
        if (lngErr < -180) set lngErr to lngErr+360.
        local dt is -(lngErr/360)*synPeriod.
        //print "  t2="+Round(t2-Time:Seconds).
        //print "  lngErr="+Round(lngErr, 2).
        //print "  lngDelta="+Round(360*(t2-Time:Seconds)/Body:RotationPeriod).
        //print "  dt=" +Round(dt).
        set NextNode:Eta to NextNode:Eta +dt.
        if NextNode:Eta<0
          set NextNode:Eta to NextNode:Eta+synPeriod.
        else if NextNode:Eta>synPeriod
          set NextNode:Eta to NextNode:Eta-synPeriod.
        
        set counter to counter+1.
        wait 0.01.
    }
    
    //print "  tweak inclination".
    local frame is AngleAxis((t2-Time:Seconds)*360/Body:RotationPeriod, V(0,1,0)).
    local p2 is (-frame) * (tgtPos:Position-Body:Position).
    local normal is Vcrs(p2, PositionAt(Ship,Time:Seconds+NextNode:Eta)-Body:Position).
    //if Vdot(normal,)<0 set normal to -normal.
    tweakNodeInclination(normal, -1).
}


// == tweak an existing node ==
function tweakNodeInclination {
    parameter normal.
    parameter budget. // as a factor of initial node deltaV
    // manipulate node to kill normal component
    //   while keeping speed/PE constant
    // Assumption: Node is set
//    print " tweakNodeInclination".
    wait 0.01.
    local t is Time:Seconds+NextNode:Eta.
    local v is VelocityAt(Ship,t+0.01):Orbit.
    local pos is PositionAt(Ship,t+0.01)-Body:Position.
    local vN is Vxcl(pos, v).
    local radDir is Vcrs(pos, normal):Normalized.
    local vErr is vN:Mag*radDir -vN.
    local newDv is -getOrbitFacing(Ship, t-0.01)*(NextNode:DeltaV +vErr).
    local dvCost is newDv:Mag -NextNode:DeltaV:Mag.
    
    if(budget<0 or dvCost < NextNode:DeltaV:Mag*budget) {
        //print "  normal=" +vecToString(normal:Normalized).
        //local frame is getOrbitFacing(Ship, Time:Seconds+Eta:Apoapsis).
        //print "  pos ="+vecToString(-frame*pos).
        //print "  vN  ="+vecToString(-frame*vN).
        //print "  vErr="+vecToString(-frame*vErr).
        
//        print "  inc before=" +Round(NextNode:Orbit:Inclination, 3).
        setNextNodeDV(newDv).
//        print "  inc after =" +Round(NextNode:Orbit:Inclination, 3).
//        print "  dvCost    =" +Round(dvCost,2).
    } else {
        // adjust the normal to use less dV
        print " tweakNodeInclination: limiting change to budget".
        local factor is NextNode:DeltaV:Mag*budget/dvCost.
        local newNormal is factor*normal:Normalized +(1-factor)*(Vcrs(v,pos):Normalized).
        tweakNodeInclination(newNormal, 2*budget).
    }
}

function refineRdvBruteForce {
    parameter t.
    
    wait 0.01.
    local myNode is NextNode.
    local lock pRel to (PositionAt(Ship, t) - PositionAt(Target, t)):Mag.
    local lock vRel to (VelocityAt(Ship, t):Orbit - VelocityAt(Target, t):Orbit):Mag.
    local vr0 is vRel.
    local lock measure to pRel/100 +Max(0,vRel-vr0) + NextNode:DeltaV:Mag.
    local measureStart is measure.
    local oldDV is V(NextNode:RadialOut, NextNode:Normal, NextNode:Prograde).
    
    local d is 2.
    local dMin is 0.125.
    local better is 0.
    local best is measure.
    local dvStart is NextNode:DeltaV.
    local tStart is NextNode:Eta +Time:Seconds.
    print " refineRdvBF".
    //print "  start measure=" +Round(best, 2).
    print "  Start: dist=" + Round(pRel,1) +", vRel=" +Round(vRel,2).
    
    until ((d < dMin) or (best < 5) ) {
        set better to 0.
        
        // try radial
        set mynode:RadialOut to (mynode:RadialOut + d).
        wait 0.01.
        if (measure < best) {   
            set best to measure. 
            set better to 1.
        } else { 
            set mynode:RadialOut to (mynode:RadialOut - 2*d).
            wait 0.01.  
            if (measure < best) {
                set best to measure. 
                set better to 1.
            } else {
                set mynode:RadialOut to (mynode:RadialOut + d).
                wait 0.01.
            }
        }
        
        // try normal
        set mynode:Normal to (mynode:Normal + d).
        wait 0.01.
        if (measure < best) {   
            set best to measure. 
            set better to 1.
        } else { 
            set mynode:Normal to (mynode:Normal - 2*d).
            wait 0.01.  
            if (measure < best) {
                set best to measure. 
                set better to 1.
            } else {
                set mynode:Normal to (mynode:Normal + d).
                wait 0.01.
            }
        }
        
        // try prograde
        set mynode:Prograde to (mynode:Prograde + d).
        wait 0.01.
        if (measure < best) {   
            set best to measure. 
            set better to 1.
        } else { 
            set mynode:Prograde to (mynode:Prograde - 2*d).
            wait 0.01.  
            if (measure < best) {
                set best to measure. 
                set better to 1.
            } else {
                set mynode:Prograde to (mynode:Prograde + d).
                wait 0.01.
            }
        }

        // shift node time
        set mynode:Eta to (mynode:Eta + d).
        wait 0.01.
        if (measure < best) {   
            set best to measure. 
            set better to 1.
        } else { 
            set mynode:Eta to (mynode:Eta - 2*d).
            wait 0.01.  
            if (measure < best) {
                set best to measure. 
                set better to 1.
            } else {
                set mynode:Eta to (mynode:Eta + d).
                wait 0.01.
            }
        }
        
        //print "  best="+Round(best,2) +", dV=" +Round(mynode:DeltaV:Mag,2) +", d="+Round(d, 1).
        //print "  best="+Round(best,2) +", pRel=" +Round(pRel) +", vRel="+Round(vRel,1).
        set d to d * 0.9.
        if(better = 0) set best to measure.
    }

    if (measure>measureStart) setNodeDv(oldDv).
    print "  End:   dist=" + Round(pRel) +", vRel=" +Round(vRel,2).
    print "  dvCost=" +Round(NextNode:DeltaV:Mag -dvStart:Mag, 2)
         +", dvChange=" +Round((NextNode:DeltaV -dvStart):Mag, 2)
         +", dt=" +Round(NextNode:Eta+Time:Seconds -tStart,2).
}


// == times ==
function timeToAltitude {
    parameter tgtAlt.
    // Only works in elliptic orbit
    
    local t0 is Time:Seconds.
    local t1 is 0.
    if (VerticalSpeed > 0)
      set t1 to t0 +Eta:Apoapsis.
    else
      set t1 to t0 +Eta:Periapsis.

    if VerticalSpeed*(Altitude -tgtAlt) > 0 {
        print "  WARNING: target Altitude already passed!".
        print "    alt="+Altitude +", tgtAlt="+tgtAlt.
        return t0.
    }
    return timeToAltitude2(tgtAlt, t0, t1).
}

function timeToAltitude2 {
    parameter tgtAlt.
    parameter t0.
    parameter t1.
    // Binary search (assuming monotony)
    local dir is -1.
    set tgtAlt to tgtAlt+Body:Radius.
    if (tgtAlt - (PositionAt(Ship,t0)-Body:Position):Mag)>0 set dir to 1.
    local dt is (t1-t0)/2.
    local t is t0.
    until (dt < 1) {
//         print "  dir="+dir.
//         print "  tgtAlt="+tgtAlt.
        if ( (dir * (tgtAlt - (PositionAt(Ship,t+dt) -Body:Position):Mag)) > 0)
          set t to t+dt.
        
        set dt to dt/2.
    }
    return t.
}

function timeToDist {
    parameter dist.
    parameter t0.
    parameter t1.
    // Binary search (assuming monotony)
    local dir is -1.
    function d {parameter t. return dist-(PositionAt(Ship,t)-PositionAt(Target,t)):Mag.}
    if (d(t0)>0) set dir to 1.
    local dt is (t1-t0)/2.
    local t is t0.
    until (dt < 1) {
        if (dir*d(t+dt) > 0) set t to t+dt.
        set dt to dt/2.
    }
    return t.
}

function findClosestApproach {
    parameter t0.
    parameter t1.
//     print "findClosestApproach".
    // Assume Target is set.
    // Assume circular orbits
    
    local linearThreshold is Min(Target:Obt:Period, Obt:Period)/36. // 10°
    
//     print "  First Step: brute force search".
    local steps is Ceiling( (t1-t0)/linearThreshold ).
//     print "  steps=" +steps.
//     print "  stepsize=" +Round(linearThreshold).
    local period is Obt:Period.
    local i is 0.
    local tMin is 0.
    local dMin is 1000000000000.
    local d is 0.
    local t is 0.
    until i>steps {
        set t to t0 + i*linearThreshold.
        set d to Abs( (PositionAt(Ship,t)-PositionAt(Target,t)):Mag ).
        if (d < dMin) { 
            set tMin to t. 
            set dMin to d.
        }
        set i to i+1.
    }
//     print "    tMin="+Round(tMin-Time:Seconds).
//     print "    dmin="+Round(dMin).

    local finished is 0.
    local dt is 0.
    local vRel is V(0,0,0).
    local dPar is 0.
    local dist is V(0,0,0).
    until finished {
        // when will the relative velocity be perpendicular to the distance?
        set dist to PositionAt(Ship,tMin)-PositionAt(Target,tMin).
        set vRel to VelocityAt(Target, tMin):Orbit -VelocityAt(Ship, tMin):Orbit.
        //print "  vRel="+vRel.
        set dPar to Vdot(dist, vRel:Normalized). // contains a sign
        set dt to dPar / vRel:Mag.
        set t to tMin+dt.
        set d to Abs( (PositionAt(Ship,t)-PositionAt(Target,t)):Mag ).
        if (d<dMin) {
            set tMin to t.
            set dMin to d.
            if (dt<1) set finished to 1.
        } else {
            set finished to 1.
        }
//         print "  Linear Approximation".
//         print "    vRel=" +Round(vRel:Mag, 2). //+vecToString(vRel).
//         print "    dist=" +Round(dist:Mag, 2). //+vecToString(dist).
//         print "    dPar="+Round(dPar, 2).
//         print "    dt  ="+Round(dt, 2).
//         print "    d   ="+Round(d, 2).
    }
    
    
    return tMin.
}

function timeToAnDn {
    parameter tgtNormal.
    //print " timeToAnDn".
    
    // AN/DN vector of my current half-orbit
    local p0 is -Body:Position.
    local myNormal is Vcrs(p0, Velocity:Orbit):Normalized.
    local andnV is Vcrs(myNormal, tgtNormal):Normalized.
    if Vdot(-Body:Position, andnV)<0 set andnV to -andnV.
    //print "  andnV=" +vecToString(andnV).

    // current half-orbit
    local t0 is Time:Seconds.
    local t1 is t0+Min(Eta:Apoapsis, Eta:Periapsis).
    local p1 is PositionAt(ship,t1)-Body:Position.
    local tgtAngle is Vang(andnV, p1).
    if Vang(p0,p1)<tgtAngle {
        //print " already passed the node => next half-orbit".
        set t0 to t1.
        set t1 to t1+Obt:Period/2.
    }
//     print "  t0="+Round(t0-Time:Seconds) +", t1="+Round(t1-Time:Seconds).
//     print "  startAngle="+Round(Vang(p0,p1)).
//     print "  tgtAngle=" +Round(tgtAngle,2).
    
    // Binary search
    local dt is (t1-t0)/2.
    local t is t0.
    until (dt < 1) {
        set p0 to PositionAt(ship,t+dt)-Body:Position.
//         print "  t="  +Round(t-Time:Seconds) 
//              +", ang="+Round(Vang(p0,p1),2) 
//              +", dt=" +Round(dt,1).
        if ( Vang(p0,p1) > tgtAngle)
          set t to t+dt.
        
        set dt to dt/2.
    }
    return t.    
}


// == misc ==
function getOrbitFacing {
    // orbital frame: rad+, normal+, prograde
    parameter vess is Ship. // vessel
    parameter t is -1.      // -1 = use current
    
    local x is 0. local v is 0.
    if (t=-1) {
        set v to vess:Velocity:Orbit.
        set x to vess:Position-Body:Position.
    } else {
        set v to VelocityAt(vess,t):Orbit.
        set x to PositionAt(vess,t)-Body:Position.
    }
    return LookdirUp(v, Vcrs(v,x)).
}

function setNextNodeDV {
    parameter dv.
    set NextNode:RadialOut to dV:X.
    set NextNode:Normal to dV:Y.
    set NextNode:Prograde to dV:Z.   
}

function getOrbitNormal {
    parameter tgt.
    return Vcrs(tgt:Velocity:Orbit, tgt:Position-Body:Position):Normalized.
}
