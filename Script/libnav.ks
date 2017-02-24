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
        wait 0.
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
    print " nodeReturnFromMoon".
    // find final speed
    local parent is Body:Body.
    local tgtPE is 70000.
    local tgtAP is 0.5*(Body:Orbit:Apoapsis+Body:Orbit:Periapsis).
    local sma is 0.5*(tgtAP +tgtPE) +parent:Radius.
    local rad is tgtAP+parent:Radius.
    local tgtVel is Sqrt(parent:Mu*(2/rad - 1/sma )). // vis viva eq.
    set tgtVel to Body:Orbit:Velocity:Orbit:Mag -tgtVel.

    local escVel is Sqrt(2*Body:Mu / (Altitude+Body:Radius)).
    local nodeVel is Sqrt( tgtVel^2 + escVel^2).

    add Node(Time:Seconds, 0,0,nodeVel-Velocity:Orbit:Mag).
    print "  dvCost="+Round(nodeVel-Velocity:Orbit:Mag, 2).
    wait 0.

    // check direction => shift time
    // Assumption: prograde circular equatorial orbit
    // theta-90° should be the angle between nodeVel and escapeVel
    local theta is ArcCos(-1 / NextNode:Orbit:Eccentricity).
    local retroLng is Body:GeoPositionOf(Body:Position -Body:Obt:Velocity:Orbit):Lng.
    local waitAngle is retroLng -theta - Longitude.
    until (waitAngle>0) set waitAngle to waitAngle+360.
    //print "  waitAngle=" +Round(waitAngle,2).
    //print "  theta=" +Round(theta,2).
    set NextNode:Eta to NextNode:Eta +Obt:Period*waitAngle/360.
    tweakNodeInclination( Vcrs(Body:Obt:Velocity:Orbit, Body:Position-Body:Body:Position) ).

    print" try to get an AN/DN halfway home".
    local parentOrbit is NextNode:Orbit:NextPatch.
    local halftime is Time:Seconds+parentOrbit:Period/4.
    local tHalfPos is timeToAltitude2(parentOrbit:Apoapsis/2,
                                      halfTime, halfTime+parentOrbit:Period/4).
    //print "  tHalfPos=" +Round(tHalfPos -Time:Seconds).
    //print "  halfTime=" +Round(halfTime -Time:Seconds).

    local tgtNormal is V(0,1,0).
    if HasTarget
      set tgtNormal to getOrbitNormal(Target).
    else
      set tgtNormal to -Body:Body:AngularVel:Normalized.

    // == binary search ==
    // tmpHeight is what we want to bring to zero.
    lock tmpHeight to Vdot(tgtNormal, PositionAt(Ship,tHalfPos)-Body:Body:Position ).
    local d is 128.
    local step is 2.
    local par is -128.
    until (Abs(d)<0.001 or Abs(d)>10000) {
        set par to par+d.
        local moonPrograde is Vcrs(V(0,1,0), Body:Position-Body:Body:Position):Normalized.
        local escNormal is -par*moonPrograde + 100*tgtNormal.
        tweakNodeInclination(escNormal).
        wait 0.
        //print "  Iteration: par="+Round(par,3) +", tmpHeight="+Round(tmpHeight).
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
    //     //tweakNodeInclination(escNormal).
    //     print "  actEscAngle="+Round(VectorAngle(Vcrs(Body:Position,Velocity:Orbit),V(0,1,0)),2).

    // todo: same thing from an inclined orbit
    //      (when launching from a non-eq moon base)
}

function nodeIncChange {
    // change inclination at next AN/DN
    parameter tgtNormal.
    add Node(timeToAnDn(tgtNormal), 0,0,0).
    tweakNodeInclination(tgtNormal).
}

function nodeFastTransfer {
    // transfer between low orbits where synodic period
    // is too long to wait for a hohmann window
    // Assumptions: * both orbits are circular
    //              * relative inclination is small
    //              * close to equatorial

    // timing: AN/DN with target
    //local t2 is timeToAnDn( getOrbitNormal(Target) ). // seems not to work
    local an is Vcrs(getOrbitNormal(Ship), getOrbitNormal(Target)):Normalized.
    if (Vdot(an, Prograde:Vector)<0) set an to -an.
    local dt is Obt:Period * Vang(-Body:Position, an)/360.
    if (dt<0) {
      print "  WARNING: dt=" +Round(dt,2).
      wait 1000.
    }
    local tNode is dt+Time:Seconds.

    // prograde component: catch up in one orbit
    local synPeriod is 1/ (1/Obt:Period - 1/Target:Obt:Period).
    local waitAngle is Mod(-Target:Longitude + Longitude +360, 360).
    local transPeriod is (1 + waitAngle/360)*Target:Obt:Period.
    local transSma is (transPeriod^2 *Body:Mu /(4* 3.1415^2) )^(1/3).
    local transAp is 2*(transSma -Body:Radius) -(Obt:SemiMajorAxis-Body:Radius).
    //print "  waitAngle=" +Round(waitAngle,2).
    nodeUnCircularize(transAp, tNode).

    // normal component: do half of the inc change
    tweakNodeInclination( getOrbitNormal(Ship)+getOrbitNormal(Target) ).
    refineRdvBruteForce(Time:Seconds+NextNode:Eta+NextNode:Obt:Period).
}

function nodeFastTransfer2 {
    parameter t is -1.
    // transfer between low orbits where synodic period
    // is too long to wait for a hohmann window
    // Assumptions: * target orbit is circular
    //              * t is my AP/PE
    //              * relative inclination is small
    //              * close to equatorial
    print "  t="+Round(t-Time:Seconds) +", tPE="+Round(Eta:Periapsis).

    if (t=-1) {
      // default timing: AN/DN with target
      //local t2 is timeToAnDn( getOrbitNormal(Target) ). // seems not to work
      local an is Vcrs(getOrbitNormal(Ship), getOrbitNormal(Target)):Normalized.
      if (Vdot(an, Prograde:Vector)<0) set an to -an.
      local dt is Obt:Period * Vang(-Body:Position, an)/360.
      if (dt<0) {
        print "  WARNING: dt=" +Round(dt,2).
        askConfirmation().
      }
      set t to dt+Time:Seconds.
    }

    function posToLng {
      parameter pos.
      return Body:GeoPositionOf(pos):Lng.
    }
    // prograde component: catch up in one orbit
    local waitAngle is Mod(posToLng(PositionAt(Ship,t))-posToLng(PositionAt(Target,t))+360, 360).
    print "  waitAngle=" +Round(waitAngle,2).
    //local synPeriod is 1/ (1/Obt:Period - 1/Target:Obt:Period).
    //local waitAngle is Mod(-Target:Longitude + Longitude +360, 360).
    local transPeriod is (1 + waitAngle/360)*Target:Obt:Period.
    local transSma is (transPeriod^2 *Body:Mu /(4* 3.1415^2) )^(1/3).
    local transAp is 2*(transSma -Body:Radius) -((PositionAt(Ship,t)-Body:Position):Mag-Body:Radius).
    print "  tgtP="+Round(Target:Orbit:Period).
    print "  transPeriod="+Round(transPeriod).
    print "  transSMA="+Round(transSMA).
    print "  myPE=" +Round(Periapsis) +" / " +Round((PositionAt(Ship,t)-Body:Position):Mag-Body:Radius).
    print "  transAP="+Round(transAP).
    print "  t="+Round(t-Time:Seconds).
    nodeUnCircularize(transAp, t).

    // normal component: do half of the inc change
    tweakNodeInclination( getOrbitNormal(Ship)+getOrbitNormal(Target) ).
    refineRdvBruteForce(Time:Seconds+NextNode:Eta+NextNode:Obt:Period).
}

function nodeTweakPE {
    parameter tgtPE is 90000.
    parameter t is Time:Seconds+100.
    print " nodeTweakPE".
    // tweak PE with a radial burn
    // (used when coming from high orbit)
    function meas {
      parameter p.

      set NextNode:RadialOut to p.
      wait 0.
      local result is NextNode:Orbit:Periapsis-tgtPE.
      //print "  tgtPE="+tgtPE +", PE="+NextNode:Orbit:Periapsis.
      //print "  meas(" +Round(p,3) +")=" +Round(result,2).
      return result.
    }

    local vel is VelocityAt(Ship,t):Orbit.
    local pos is PositionAt(Ship,t)-Body:Position.
    local minRad is Sin(Vang(pos,vel))*vel:Mag.
    print "  vel="+Round(vel:Mag,1).
    print "  angle="+Vang(pos,vel).
    print "  minRad="+Round(minRad,2).

    add Node(t,0,0,0).
    local nodeRad is binarySearch(meas@, -minRad, 1000, 0.01). //toDo: unbounded version of binarySearch
    print "  dvCost="+nodeRad.
    set NextNode:RadialOut to nodeRad.
    wait 0.
}

function nodeHohmann {
    parameter incBudget is -1.
    // Assumption: Target is set
    //             Ship orbit is circular
    // Return: rdvTime = Time(UT) of Intersect
    wait 0.
    local synPeriod is 1/ (1/Obt:Period - 1/Target:Obt:Period).
    local ap is (Target:Apoapsis + Target:Periapsis)/2.
    local transSma is Body:Radius +(Altitude +ap)/2.
    local transTime is Sqrt(4*3.1415^2 *transSma^3 /Body:Mu)/2.
    local transAngle is -(-180 +transTime/Target:Obt:Period *360).
    local waitAngle is Target:Longitude - Longitude - transAngle.
    local waitTime is synPeriod * waitAngle/360.
    if (waitTime < 0) set waitTime to waitTime +Abs(synPeriod).
    local rdvTime is Time:Seconds +transTime +waitTime.

    //  print " hohmannNode".
    //  print "  transTime  ="+Round(transTime).
    //  print "  transSma   ="+Round(transSma).
    //  print "  synPeriod  ="+Round(synPeriod).
    //  print "  transAngle ="+Round(transAngle, 2).
    //  print "  waitAngle  ="+Round(waitAngle, 2).
    //  print "  waitTime   ="+Round(waitTime).
    //  print "  ETA to rdv ="+Round(rdvTime-Time:Seconds).
    //  print "  tgtAP      ="+Round(ap).

    local t is Time:Seconds +waitTime.
    nodeUncircularize(ap, t).
    wait 0.

    until not (NextNode:Orbit:Transition = "ENCOUNTER" and
        NextNode:Orbit:NextPatch:Body <> Target) {
        print "  WARNING: Encounter with wrong Body! Delaying transfer.".
        print "   transition="+NextNode:Orbit:Transition.
        print "   name="+NextNode:Orbit:NextPatch:Body.
        set NextNode:Eta to NextNode:Eta +synPeriod.
        wait 2.
    }

    // refine
    // print " initial node".
    // local frame is getOrbitFacing(Ship, rdvTime).
    // local dX is -frame*(PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime)).
    // local dv is -frame*(VelocityAt(Target,rdvTime):Orbit-VelocityAt(Ship,rdvTime):Orbit).
    // print "  dx="+vecToString(dx/1000).
    // print "  dv="+vecToString(dv).
    // diff = rad+, norm+, prograde

    // radial => change node:Prograde
    // print " tune prograde".
    // //set ap to ap+dX:X.
    //  print "  apOld=" +Round((Target:Apoapsis + Target:Periapsis)/2).
    //  print "  tgtAP=" +Round(Target:Apoapsis).
    //  print "  tgtPE=" +Round(Target:Periapsis).

    // set ap to (PositionAt(Target,rdvTime)-Body:Position):Mag -Body:Radius.
    // print "  apNew=" +Round(ap).
    // print "  dAP ="+Round(ap -NextNode:Orbit:Apoapsis).
    // remove NextNode.
    // nodeUncircularize(ap, t).
    // wait 0.
    // set rdvTime to NextNode:Eta+NextNode:Orbit:Period/2.
    // set frame to getOrbitFacing(Ship, rdvTime).
    // set dX to -frame*(PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime)).
    // set dv to -frame*(VelocityAt(Target,rdvTime):Orbit-VelocityAt(Ship,rdvTime):Orbit).
    // print "  dx="+vecToString(dx/1000).
    // print "  dv="+vecToString(dv).

    // prograde => shift t (linear approx)
    // print " tune timing".
    // set NextNode:Eta to NextNode:Eta +dx:Z/dv:Z.
    // print "  dt="+Round(dx:Z/dv:Z).
    // wait 0.
    // set frame to getOrbitFacing(Ship, rdvTime).
    // set dX to -frame*(PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime)).
    // set dv to -frame*(VelocityAt(Target,rdvTime):Orbit-VelocityAt(Ship,rdvTime):Orbit).
    // print "  dx="+vecToString(dx/1000).
    // print "  dv="+vecToString(dv).
    //
    // add Node(Time:Seconds+ NextNode:Eta+ 2*6*3600, 0,6,0).

    // refineRdvBruteForce(rdvTime).

    // Tweak inclination such that the new AN/DN is half way to the target orbit.
    local n is getOrbitNormal(Ship).
    local h is Vdot(PositionAt(Target,rdvTime)-Body:Position, n)/2.
    local tgtAngle is arcTan(h/NextNode:Orbit:SemiMinorAxis).
    //print "  n="+vecToString(n).
    //print "  h="+Round(h).
    //print "  tgtAngle="+Round(tgtAngle,2).
    local tgtNormal is n*Sqrt(NextNode:Orbit:SemiMinorAxis^2 + h^2)
                       -VelocityAt(Ship,Time:Seconds+NextNode:Eta+0.1):Orbit:Normalized*h.

    tweakNodeInclination(tgtNormal, incBudget).
    return rdvTime.
}

function nodeDeorbit {
    parameter tgtPos. // GeoCoord
    parameter tgtHeight.
    parameter tgtPE.
    parameter waitForInc is false.
    // Make a node with tgtPE such that my altitude at tgtPos is tgtHeight
    // Assumption: start in circular orbit

    //print " nodeDeorbit".
    nodeUnCircularize(tgtPE,Time:Seconds).
    wait 0.
    //print "  HasNode="+HasNode.
    //print "  eta="+Round(NextNode:Eta, 2).
    //print "  dv ="+Round(NextNode:DeltaV:Mag, 2).
    //print "  tgtPos=" +tgtPos.

    local synPeriod is 1/ (1/Obt:Period - 1/Body:RotationPeriod).
    local lngErr is 1000.
    local t2 is 0.
    local counter is 0.
    local descendTime is 0.
    until Abs(lngErr)<0.1 or counter>6 {
        //print " Iteration".
        set t2 to timeToAltitude2(tgtHeight,
                                    Time:Seconds+NextNode:Eta,
                                    Time:Seconds+NextNode:Eta+NextNode:Orbit:Period/2).
        set descendTime to t2-NextNode:Eta-Time:Seconds.
        local lng1 is Body:GeoPositionOf(PositionAt(Ship,t2)):Lng.
        local lng2 is tgtPos:lng +360*(t2-Time:Seconds)/Body:RotationPeriod.
        set lngErr to lng1-lng2.
        if (lngErr < -180) set lngErr to lngErr+360.
        local dt is -(lngErr/360)*synPeriod.
        //print "  descendTime=" +Round(descendTime,2).
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
        wait 0.
    }

    function frame {
      parameter dt.
      return -AngleAxis(360* dt/Body:RotationPeriod, V(0,1,0)).
    }

    if (waitForInc) {
      // try to hit the target while it is in our orbital plane
      // (assumption: inc <= tgt:Lat)
      local anglestep is 360 -360*Obt:Period/synPeriod.
      //print "  angleStep=" +Round(Mod(angleStep+180,360)-180,2).

      local lanError is getLanDiffToKsc() -360*(NextNode:Eta+descendTime)/Body:RotationPeriod. //not sure about sign
      local bestLanErr is Mod(lanError+180, 360)-180.
      //print "  startLanError=" +Round(bestLanErr, 2).
      local numSteps is Round(6*3600/Obt:Period).  // max wait: 1 day
      local step is 0.
      local bestStep is 0.
      until step > numSteps {
        local lanErr2 is Mod(lanError -step*angleStep +180,360)-180.
        if (abs(lanErr2) < abs(bestLanErr)) {
          set bestLanErr to lanErr2.
          set bestStep to step.
        }
        //print "  step" +step +", lanErr=" +Round(lanErr2, 2).
        set step to step + 1.
      }
      //print "  bestStep=" +bestStep.
      set t2 to t2 +bestStep*synPeriod.
      set NextNode:Eta to NextNode:Eta +bestStep*synPeriod.
    }

    local p2 is frame(NextNode:Eta) * (tgtPos:Position-Body:Position).
    local normal is Vcrs(p2, PositionAt(Ship,Time:Seconds+NextNode:Eta)-Body:Position).
    tweakNodeInclination(normal, 0.1).
}

function nodeDeorbitAngle {
  parameter tgtPos. // GeoCoord
  parameter tgtHeight.
  parameter tgtAngle is 30.

  local tNode is Time:Seconds+100.
  add Node(tNode,0,0,0).
  print "  tweak node:prograde => tgtAngle at tgtHeight".
  function meas1 {
    parameter p.
    set NextNode:Prograde to p.
    wait 0.
    local t is timeToAltitude2(tgtHeight, tNode, tNode+NextNode:Orbit:Period/2).
    local angle is Vang(VelocityAt(Ship,t):Orbit,-PositionAt(Ship,t)+Body:Position).
    local result is (90-angle)-tgtAngle.
    print "   meas(" +Round(p,3) +")=" +Round(90-angle,2).
    return result.
  }
  set NextNode:Prograde to binarySearch(meas1@, -Velocity:Orbit:Mag, 0, 0.2).
  if Abs(NextNode:Prograde)>Velocity:Orbit:Mag {
    print "  WARNING: nodeDeorbitAngle is retrograde!".
    askConfirmation().
  }

  local synPeriod is 1/ (1/Obt:Period - 1/Body:RotationPeriod).
  local lngErr is 1000.
  local t2 is 0.
  local counter is 0.
  local descendTime is 0.
  until Abs(lngErr)<0.1 or counter>6 {
      //print " Iteration".
      set t2 to timeToAltitude2(tgtHeight,
                                  Time:Seconds+NextNode:Eta,
                                  Time:Seconds+NextNode:Eta+NextNode:Orbit:Period/2).
      set descendTime to t2-NextNode:Eta-Time:Seconds.
      local lng1 is Body:GeoPositionOf(PositionAt(Ship,t2)):Lng.
      local lng2 is tgtPos:lng +360*(t2-Time:Seconds)/Body:RotationPeriod.
      set lngErr to lng1-lng2.
      if (lngErr < -180) set lngErr to lngErr+360.
      local dt is -(lngErr/360)*synPeriod.
      //print "  descendTime=" +Round(descendTime,2).
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
      wait 0.
  }

  function frame { parameter dt. return -AngleAxis(360* dt/Body:RotationPeriod, V(0,1,0)). }
  local p2 is frame(NextNode:Eta) * (tgtPos:Position-Body:Position).
  local normal is Vcrs(p2, PositionAt(Ship,Time:Seconds+NextNode:Eta)-Body:Position).
  tweakNodeInclination(normal, -1).
}


function nodeCircularize {
  parameter t.
  local sma is (PositionAt(Ship,t)-Body:Position).
  local v is VelocityAt(Ship,t):Orbit.
  local circVel is Sqrt(Body:Mu / sma:Mag) * Vxcl(sma,v):Normalized.
  local nodeDv is -getOrbitFacing(Ship, t)*(circVel-v).
  add Node(t,0,0,0).
  setNextNodeDV(nodeDv).
  print "  nodeCircularize: dV="+Round(nodeDv:Mag,2).
}

// == tweak an existing node ==
function tweakNodeInclination {
    parameter normal.
    parameter budget is -1. // as a factor of initial node deltaV
    // manipulate node to kill normal component
    //   while keeping speed/PE constant
    // Assumption: Node is set
    // print " tweakNodeInclination".
    wait 0.
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
        //print "  oldinc=" +Round(NextNode:Orbit:Inclination, 3).
        setNextNodeDV(newDv).
        //print "  newInc=" +Round(NextNode:Orbit:Inclination, 3).
        print "  dvCost=" +Round(dvCost, 2).
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
    parameter dVWeight is 100.

    wait 0.
    local myNode is NextNode.
    local lock pRel to (PositionAt(Ship, t) - PositionAt(Target, t)):Mag.
    local lock vRel to (VelocityAt(Ship, t):Orbit - VelocityAt(Target, t):Orbit):Mag.
    local vr0 is vRel.
    local lock dVCost to Max(0,vRel-vr0) + NextNode:DeltaV:Mag.
    local lock measure to pRel +dVCost *dVWeight.
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
        wait 0.
        if (measure < best) {
            set best to measure.
            set better to 1.
        } else {
            set mynode:RadialOut to (mynode:RadialOut - 2*d).
            wait 0.
            if (measure < best) {
                set best to measure.
                set better to 1.
            } else {
                set mynode:RadialOut to (mynode:RadialOut + d).
                wait 0.
            }
        }

        // try normal
        set mynode:Normal to (mynode:Normal + d).
        wait 0.
        if (measure < best) {
            set best to measure.
            set better to 1.
        } else {
            set mynode:Normal to (mynode:Normal - 2*d).
            wait 0.
            if (measure < best) {
                set best to measure.
                set better to 1.
            } else {
                set mynode:Normal to (mynode:Normal + d).
                wait 0.
            }
        }

        // try prograde
        set mynode:Prograde to (mynode:Prograde + d).
        wait 0.
        if (measure < best) {
            set best to measure.
            set better to 1.
        } else {
            set mynode:Prograde to (mynode:Prograde - 2*d).
            wait 0.
            if (measure < best) {
                set best to measure.
                set better to 1.
            } else {
                set mynode:Prograde to (mynode:Prograde + d).
                wait 0.
            }
        }

        // shift node time
        set mynode:Eta to (mynode:Eta + d).
        wait 0.
        if (measure < best) {
            set best to measure.
            set better to 1.
        } else {
            set mynode:Eta to (mynode:Eta - 2*d).
            wait 0.
            if (measure < best) {
                set best to measure.
                set better to 1.
            } else {
                set mynode:Eta to (mynode:Eta + d).
                wait 0.
            }
        }

        //print "  best="+Round(best,2) +", dV=" +Round(mynode:DeltaV:Mag,2) +", d="+Round(d, 1).
        //print "  best="+Round(best,2) +", pRel=" +Round(pRel) +", vRel="+Round(vRel,1).
        set d to d * 0.9.
        if(better = 0) set best to measure.
    }

    if (measure>measureStart) setNextNodeDv(oldDv).
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
    parameter dtMin is 1.
    // Binary search (assuming monotony)
    local dir is -1.
    set tgtAlt to tgtAlt+Body:Radius.
    if (tgtAlt - (PositionAt(Ship,t0)-Body:Position):Mag)>0 set dir to 1.
    local dt is (t1-t0)/2.
    local t is t0.
    until (dt < dtMin) {
        // print "  dir="+dir.
        // print "  tgtAlt="+tgtAlt.
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
    // Assume Target is set.
    // Assume circular orbits
    // print "findClosestApproach".

    local p1 is 0.
    if Obt:Transition="Escape" {
      set p1 to Body:Obt:Period.
    } else {
      set p1 to Obt:Period.
    }

    local linearThreshold is Min(Target:Obt:Period, p1)/36. // 10°

    // print "  First Step: brute force search".
    local steps is Ceiling( (t1-t0)/linearThreshold ).
    // print "  steps=" +steps.
    // print "  stepsize=" +Round(linearThreshold).
    local period is p1.
    local i is 0.
    local tMin is 0.
    local dMin is 10^12.
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
    //print "    tMin="+Round(tMin-Time:Seconds).
    //print "    dmin="+Round(dMin).

    local finished is 0.
    local dt is 0.
    local vRel is V(0,0,0).
    local dPar is 0.
    local dist is V(0,0,0).
    until finished {
        // when will the relative velocity be perpendicular to the distance?
        set dist to PositionAt(Ship,tMin)-PositionAt(Target,tMin).
        set vRel to VelocityAt(Target, tMin):Orbit -VelocityAt(Ship, tMin):Orbit.
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
        //print "  Linear Approximation".
        //print "    vRel=" +Round(vRel:Mag, 2). //+vecToString(vRel).
        //print "    dist=" +Round(dist:Mag, 2). //+vecToString(dist).
        //print "    dPar="+Round(dPar, 2).
        //print "    dt  ="+Round(dt, 2).
        //print "    d   ="+Round(d, 2).
    }
    //local vec is -getOrbitFacing(Ship,tMin) *dist.
    //print "  closest approach [r/n/p]="+vecToString(vec,0).
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
    // print "  t0="+Round(t0-Time:Seconds) +", t1="+Round(t1-Time:Seconds).
    // print "  startAngle="+Round(Vang(p0,p1)).
    // print "  tgtAngle=" +Round(tgtAngle,2).

    // Binary search
    local dt is (t1-t0)/2.
    local t is t0.
    until (dt < 1) {
        set p0 to PositionAt(ship,t+dt)-Body:Position.
        // print "  t="  +Round(t-Time:Seconds)
        //  +", ang="+Round(Vang(p0,p1),2)
        //  +", dt=" +Round(dt,1).
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
    parameter t is 0.
    if (t=0) {
      //debugVec(2, "vel", tgt:Velocity:Orbit:Normalized*1e6, tgt:Position).
      //debugVec(3, "pos", (tgt:Position-Body:Position):Normalized*1e6, tgt:Position).
      //debugVec(4, "vcrs", Vcrs(tgt:Velocity:Orbit, tgt:Position-Body:Position):Normalized*1e6, tgt:Position).
      return Vcrs(tgt:Velocity:Orbit, tgt:Position-tgt:Body:Position):Normalized.
    } else {
      return Vcrs(VelocityAt(tgt,t):Orbit, PositionAt(tgt,t)-tgt:Body:Position):Normalized.
    }
}

function getLanDiffToKsc {
  return (Obt:Lan+90) -(gSpacePort:Lng+Body:RotationAngle).
}

function binarySearch {
  parameter measure.  // function f(p) which is monotonous and returns 0 if p is perfect.
  parameter p0 is 0.
  parameter p1 is 1.
  parameter dpMin is 0.01.
  // tweaks a parameter between mMin and pMax to bring the return value of measure() to zero
  //print " binary search".

  local p is p0.
  local dp is (p1-p0)/2.
  local sgn is 1.
  //print "  p0="+Round(p0,3) +", p1="+Round(p1,3).
  //print "  dp="+dp +", dpMin=" +dpMin.
  if (measure(p0)>0) set sgn to -1.
  //print "  sgn="+sgn.
  until (Abs(dp) < dpMin) {
      if ( sgn*measure(p+dp) < 0) { set p to p+dp. }
      set dp to dp/2.
  }
  return p.
}
