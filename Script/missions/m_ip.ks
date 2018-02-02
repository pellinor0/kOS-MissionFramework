
//set Core:Part:Tag to "TT4A ip".
//if HasNode { wait 0.2. remove NextNode. wait 0.2. }

if missionStep() {
  print " Escape node".
  if not HasNode {
    if (Body:Body <> Target:Body) {
      print "WARNING: Body:Body <> Target:Body!".
      askConfirmation().
    }

    // assume target has same grand-parent as our body
    print "  calculate Hohmann transfer".
    local altOrig is (Body:Apoapsis+Body:Periapsis)/2.
    local altTgt  is (Target:Apoapsis+Target:Periapsis)/2.

    local parent is Body:Body.
    local transSma is parent:Radius +(altOrig +altTgt)/2.
    local transTime is Sqrt(4*3.1415^2 *transSma^3 /parent:Mu)/2.
    //print "  altOrig="+Round(altOrig/1000000)+" Mm".
    //print "  altTgt="+Round(altTgt/1000000)+" Mm".
    //print "  transSma   ="+Round(transSma).
    //print "  transTime  ="+Round(transTime/(6*3600)) +" d".

    //print "  pBody="+Round(Body:Orbit:Period/(6*3600))+" d".
    //print "  pTgt ="+Round(Target:Orbit:Period/(6*3600))+" d".
    local synPeriod is 1/ (1/Body:Orbit:Period - 1/Target:Obt:Period).
    local transAngle is -(-180 +transTime/Target:Obt:Period *360).
    local waitAngle is Target:Longitude - Body:Longitude - transAngle.
    local waitTime is synPeriod * waitAngle/360.
    if (waitTime < 0) set waitTime to waitTime +Abs(synPeriod).
    //print "  synPeriod  ="+Round(synPeriod/(6*3600),2) +" d".
    //print "  transAngle ="+Round(transAngle, 2).
    //print "  waitAngle ="+Round(waitAngle, 2).
    //print "  waitTime ="+Round(waitTime/(6*3600),2)+" d".

    local vOut is Sqrt(parent:Mu *(2/(altOrig) - 1/transSma)). // vis-viva eq. for transfer
    //print "  vOut="+Round(vOut,2).

    print " calculate escape burn".
    local vExc is vOut-VelocityAt(Body,Time:Seconds):Orbit:Mag. //Body:Velocity:Orbit is zero
    local tgtAng is 0.
    if (vExc<0) { set tgtAng to 180. set vExc to -vExc. }
    local escSma is 1/(2/Body:SoiRadius - vExc^2/Body:Mu). // hyperbolic excess speed (vis-viva reverse)
    local vEsc is Sqrt(Body:Mu *(2/((Apoapsis+Periapsis)/2+Body:Radius) - 1/escSma)). // vis-viva for escape trajectory
    local dv is vEsc-Velocity:Orbit:Mag.
    //print "  vExc="+Round(vExc,2).
    //print "  escSma="+Round(escSma).
    //print "  vEsc="+Round(vEsc,2).
    //print "  dV="+Round(dv,2).

    print " node timing".
    add Node(Time:Seconds+waitTime, 0, 0, dV).
    if (NextNode:Orbit:Transition <> "Escape") {
      print "WARNING: wrong transition: "+NextNode:Orbit:Transition.
      askConfirmation().
    }
    local tEsc is 0.
    local vBody is 0.
    local vExc is 0.
    local angErr is 0.
    local function vecToLng { parameter vec. return Body:GeoPositionOf(vec:Normalized*1e6+Body:Position):Lng. }
    local function tuneEscAngle {
      set tEsc to Time:Seconds+NextNode:Orbit:NextPatchEta.
      set vBody to VelocityAt(Body,tEsc-1):Orbit.
      set vExc to VelocityAt(Ship,tEsc-1):Orbit.
      set angErr to Mod(vecToLng(vBody) - vecToLng(vExc) -tgtAng +720+180, 360)-180.
      //print "  lng1="+Round(vecToLng(vBody), 2).
      //print "  lng2="+Round(vecToLng(vExc), 2).
      //print "  vExc="+Round(vExc:Mag,2).
      //print "  vBody="+Round(vBody:Mag).
      print "  angErr="+Round(angErr,2).
      //print "  dt="+Round(Orbit:Period*(angErr/360)).
      //debugVec(1, "vExc", vExc:Normalized*1e6).
      //debugVec(2, "vBody", vBody:Normalized*1e6).
      set NextNode:Eta to NextNode:Eta + Orbit:Period*(angErr/360).
    }
    tuneEscAngle().

    local rdvTime is Time:Seconds +transTime +NextNode:Eta.
    print "  rdvTime=" +Round((rdvTime-Time:Seconds)/(6*3600),3)+" d".
    local closeTime is findClosestApproach(rdvTime-transTime/2, rdvTime+transTime/2).
    set rdvTime to closeTime.
    //print "  rdvTime=" +Round((rdvTime-Time:Seconds)/(6*3600),3)+" d, closest approach= "+Round( (findClosestApproach(rdvTime-transTime/2, rdvTime+transTime/2)-Time:Seconds)/(6*3600), 3).
    //debugVec(1, "r1", PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime), PositionAt(Ship,rdvTime)).
    set rdvTime to rdvTime +refineRdvBruteForce(rdvTime, 1000, 3600, 10).
    //print "  rdvTime=" +Round((rdvTime-Time:Seconds)/(6*3600),3)+" d, closest approach= "+Round( (findClosestApproach(rdvTime-transTime/2, rdvTime+transTime/2)-Time:Seconds)/(6*3600), 3).
    //debugVec(4, "r4", PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime), PositionAt(Ship,rdvTime)).
    refineRdvBruteForce(rdvTime, 0, 3600).
    print "  rdvTime=" +Round((rdvTime-Time:Seconds)/(6*3600),3)+" d, closest approach= "+Round( (findClosestApproach(rdvTime-transTime/2, rdvTime+transTime/2)-Time:Seconds)/(6*3600), 3).
    //debugVec(5, "r5", PositionAt(Target,rdvTime)-PositionAt(Ship,rdvTime), PositionAt(Ship,rdvTime)).
  }
  execNode().
}

if missionStep() {
  print " correction node".
  add Node(Time:Seconds+300,0,0,0).
  local rdvTime is findClosestApproach(Orbit:NextPatchEta, Orbit:NextPatchEta+Orbit:NextPatch:Period).
  refineRdvBruteForce(rdvTime, 0, 3600).
  execNode().
}
if missionStep() {
  print " correction node".
  add Node(Time:Seconds+300,0,0,0).
  local rdvTime is findClosestApproach(Orbit:NextPatchEta, Orbit:NextPatchEta+Orbit:NextPatch:Period).
  refineRdvBruteForce(rdvTime, 0, 3600).
  execNode().
}

m_waitForTransition("ESCAPE").

if missionStep() {
  print " correction node".
  if not HasNode {
    local rdvTime is findClosestApproach(Time:Seconds, Time:Seconds+Orbit:Period).
    add Node((Time:Seconds+rdvTime)/2,0,0,0).
    set rdvTime to rdvTime+refineRdvBruteForce(rdvTime, 0, 3600).
    set rdvTime to rdvTime+refineRdvBruteForce(rdvTime, 0, 3600).
    refineRdvBruteForce(rdvTime, 0, 3600).
  }
  execNode().
}
if missionStep() {
  print " correction node".
  if not HasNode {
    local rdvTime is findClosestApproach(Time:Seconds, Time:Seconds+Orbit:Period).
    add Node((Time:Seconds+rdvTime)/2,0,0,0).
    set rdvTime to rdvTime+refineRdvBruteForce(rdvTime, 0, 3600).
    set rdvTime to rdvTime+refineRdvBruteForce(rdvTime, 0, 3600).
    refineRdvBruteForce(rdvTime, 0, 3600).
  }
  execNode().
}


print "...To be continued.".
askConfirmation().
