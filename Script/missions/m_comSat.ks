// first  comSat: go to polar orbit
// second comSat: make orbit opposite to first one
//                (second is the one who has a target)

// raise AP
// (second: place AP in the same plane as first)
if (HasTarget) {
  m_hohmannToTarget(0.1).
} else if missionStep() {
  if (not HasNode) {
    local tgtAlt is 70000000. // above Ceti orbit
    local dt is NextNode:Eta+Orbit:Period/10.
    nodeUnCircularize(tgtAlt, Time:Seconds+180).
    print " Transition:"+NextNode:Obt:Transition.
    until (NextNode:Obt:Transition="FINAL") {
      print "  a moon is in the way => delay node".
      set NextNode:Eta to NextNode:Eta+Orbit:Period/10.
    }
    print " Transition:"+NextNode:Obt:Transition.
  }
  execNode().
}

if missionStep() { print " test". }
if missionStep() { print " test". }
if missionStep() { print " test". }

//print "  HasTarget="+HasTarget.
if (not HasTarget) wait 1. // HasTarget is glitchy
if (HasTarget) {
  m_nodeIncCorr().
} else {
  if missionStep() { print " (no target: no incCorr to do)". }
}

if missionStep() { print " test". }

// circularize at AP
// (second: - match plane
//          - use intermediate orbit to adjust timing
//          - finetune period to first comSat )
if missionStep() {
  if (not HasNode) {
    if (HasTarget) {
      print " phasing orbit".
      local transPeriod is 0.5*Target:Obt:Period. // assuming we are below Target's orbit

      local function transNode {
        parameter periodRatio.
        local transPeriod is periodRatio*Target:Obt:Period.
        local transSma is (transPeriod^2 *Body:Mu /(4* 3.1415^2) )^(1/3).
        local transPE is 2*(transSma -Body:Radius) -Apoapsis.
        print "  transPeriod=" +Round(transPeriod,2).
        print "  tgtPeriod=" +Round(Target:Orbit:Period,2).
        print "  transSMA=" +Round(transSma,2).
        print "  transPE=" +Round(transPE,2).
        nodeUnCircularize(transPE, Time:Seconds+Eta:Apoapsis).
        tweakNodeInclination(getOrbitNormal(Target)).
        print "  period diff: "+Round(Target:Obt:Period-NextNode:Obt:Period).
        print "  period ratio: "+Round(Target:Obt:Period / NextNode:Obt:Period, 4).
      }

      local periods is 1.
      transNode(0.5).
      if (NextNode:Orbit:Transition<>"FINAL") {
        print "  Warning: Transition="+NextNode:Orbit:Transition +" != FINAL".
        remove NextNode.
        set periods to 2.
        transNode(2/1.5).
      }
    } else {
      local t1 is Time:Seconds+Eta:Apoapsis.
      print "  dt="+Round(t1-Time:Seconds,2) +" = "+Round((t1-Time:Seconds)/(6*3600),2)+"d".
      local circVel is Sqrt(Body:Mu / (Apoapsis + Body:Radius)).
      print "  circVel="+Round(circVel,2).
      local oldVel is VelocityAt(Ship,t1):Orbit:Mag.
      print "  oldVel="+Round(oldVel, 2).
      //local nodeVel is circVel*getOrbitNormal() - VelocityAt(Ship,t1):Orbit.
      //print "  nodeVel="+Round(nodeVel:Mag,2).
      debugVec(1, "normal", 1e7*getOrbitNormal(), PositionAt(Ship,t1)).
      debugVec(2, "vel", 1e7*VelocityAt(Ship,t1):Orbit:Normalized, PositionAt(Ship,t1)).
      //debugVec(3, "pos", PositionAt(Ship,t1)).
      //debugVec(4, "Node", nodeVel:Normalized*1e7, PositionAt(Ship,t1)).
      add Node(t1,0,circVel,-oldVel). wait 0.
      //setNextNodeDv(-getOrbitFacing()*(nodeVel)).
    }
  }
  execNode().
}

if missionStep() {
  if (HasTarget) {
    //print "circularize at AP, make sure orbit period is equal to comSat one."
    print " make final orbit".

    local function paF {
      parameter t.
      return Vang( PositionAt(Ship,t)-Body:Position, PositionAt(Target,t)-Body:Position).
    }
    local t is Time:Seconds+Eta:Apoapsis.
    local pa is paF(t).
    print "  pa="+Round(pa,2).
    if (Abs(paF(t+Orbit:Period)-180) < Abs(pa-180)){
      set t to t+Orbit:Period.
      set pa to paF(t).
      print "  pa="+Round(pa,2).
    }
    if (Abs(paF(t+2*Orbit:Period)-180) < Abs(pa-180)){
      set t to t+2*Orbit:Period.
      set pa to paF(t).
      print "  pa="+Round(pa,2).
    }

    local tgtPeriod is Target:Orbit:Period.
    local tgtSma is (tgtPeriod^2 *Body:Mu /(4* 3.1415^2) )^(1/3).
    local tgtOtherEnd is 2*(tgtSma -Body:Radius) -Apoapsis.
    nodeUnCircularize(tgtOtherEnd, t).

    print "  period error: "+Round(Target:Obt:Period-NextNode:Obt:Period).
    print "  period ratio: "+Round(Target:Obt:Period / NextNode:Obt:Period, 4).
    askConfirmation().
    execNode().
  }
}
