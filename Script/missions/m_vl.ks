// test Mission: vacLand(at Target)

// suppose we start in 20km circular orbit that passes above the target
setTarget("JannahBase").
set gGearHeight to 1.4.

function vacLandAtTgtLog {
    parameter tgt is 0. // GeoCoordinates (else use Target)
    if (Status = "LANDED" or Status="SPLASHED") return.
    if (not tgt:HasSuffix("LAT")) set tgt to Body:GeoPositionOf(Target:Position).

    local startDv is getDeltaV().
    local tgtHeight is Max(0.01, tgt:TerrainHeight)+gGearHeight.
    local acc is Ship:AvailableThrust / Mass.
    local g is Body:Mu/(Body:Radius * (Body:Radius +0.1)). // +0.1 = workaround to overflow
    local params is ReadJson("0:/logs/land"+Body:Name+".json").

    print " vacLandAtTgt (Log-version)".
    print "  tgtHeight="+Round(tgtHeight, 1).
    print "  Params: ".
    print "   PA="+params["PA"].
    print "   PE="+params["PE"].
    print "  g=" +Round(g,2) +", acc=" +Round(acc,2) +", TWR="+Round(acc/g,2).
    local accFactor is 1.
    if (acc > 2.5*g) {  // limit TWR for stability
        set accFactor to 2.5*g/acc.
        set acc to acc*accFactor.
    }

    local burnAlt is params["h"][(params["h"]:Length-1)].
    if (Periapsis > burnAlt) {   // else we already did that burn
      if (not HasNode) {
        local PA is Mod(tgt:Lng-Longitude+360, 360)-Params["PA"].
        local synPeriod is 1/ (1/Obt:Period - 1/Body:RotationPeriod).
        local dt is synPeriod*(PA/360).
        if (dt<30) {set dt to dt+synPeriod.}
        print "  PA="+Round(PA,2).
        print "  dt="+Round(dt,2).
        nodeUncircularize(params["PE"], Time:Seconds+dt).
      }
      execNode().
    }

    local height is 1e6.
    local brakeAcc is 0.
    local corrAcc is 0.
    local vSollDir is 0.
    local vErr is 0.
    local v is 0.
    local tt is 0.
    local steerVec is -Velocity:Surface.

    if HasTarget {
      lock Steering to Lookdirup(steerVec, -Target:Position). // assume KAS-Port points to -UpVector
    } else {
      lock Steering to Lookdirup(steerVec, Facing:UpVector).
    }

    local g is Body:Mu/(Body:Radius* (Body:Radius+0.1)).
    print "  g="+Round(g,3).
    local vErrPIDx is PidLoop(0.2, 0.01, 0.03, -1, 1). // KP, KI, KD, MINOUTPUT, MAXOUTPUT
    local vErrPIDy is PidLoop(0.2, 0.01, 0.03, -1, 1). // KP, KI, KD, MINOUTPUT, MAXOUTPUT
    local sbc is 1000.

    local v0 is 1. // touchdown speed
    local hCorr is -0.5*v0*v0/(acc-g) -10. // correction for touchdown speed and gearHeight
    local tImpact is Time:Seconds+1e12.

    function update {
        wait 0.
        set v to Velocity:Surface.
        set height to Altitude - tgtHeight.

        // == Suicide burn countdown => throttle ==
        // suicide burn countdown (borrowed from MJ)
        set tImpact to timeToAltitude2(tgtHeight, Time:Seconds, Time:Seconds+Eta:Periapsis, 0.2).
        local sinP is Sin( Max(0, 90-Vang(-Velocity:Surface, Up:Vector)) ).
        if (sinp<0.9) {
          local effDecel is 0.5*(-2*g*sinP +Sqrt( (2*g*sinP)^2 +4*(acc*acc*0.9 -g*g))). //"*0.9"= keep small acc reserve
          local decelTime is Velocity:Surface:Mag/effDecel.
          set sbc to tImpact-Time:Seconds -decelTime/2.
          set tt to 1/Max(sbc/2,1).
          print "SBC =" +Round(sbc,      2) +"  " at (38, 0).
        } else {
          // final approach / touchdown
          set height to Altitude - Max(0.01, GeoPosition:TerrainHeight) +hCorr.
          local accNeeded is 0.
          if (height>2)
            set accNeeded to (Velocity:Surface:SqrMagnitude - v0*v0)/(2*height) + g.
          else
            set accNeeded to (Velocity:Surface:Mag - v0)*2.
          set tt to Max(0, (accNeeded*accFactor/acc)-0.7)*5. // start at 70%, full at 90%
        }
        print "tt  =" +Round(tt, 2)  at (38, 1).

        // == Navigation => X/Y error ==
        // aim at a point 60% of current height over target
        local aimPoint is tgt:Position +Up:Vector*(Altitude-tgtHeight)*0.4.
        local frame is LookdirUp(v, Up:Vector).
        set vErr to -frame * Vxcl(aimPoint:Normalized, v).
        debugVec(4, "vErr",frame*vErr, frame*(-vErr)+Velocity:Surface-10*Up:Vector).
        debugVec(3, "aimPoint", aimPoint-tgt:Position, tgt:Position).
        print "vErr=" +Round(vErr:Mag,2) at (38,7).

        // PID control => X/Y corr
        local corrX is vErrPIDx:Update(Time:Seconds, vErr:X).
        local corrY is vErrPIDy:Update(Time:Seconds, vErr:Y).
        print "corX=" +Round(corrX, 2)+"    " at (38,8).
        print "corY=" +Round(corrY, 2)+"    " at (38,9).

        // Steering: corr => steerVec
        local maxCorr is Max(0, Min(0.25, 0.01*(tImpact-Time:Seconds) )).
        if (sbc<0) set corrY to Max(corrY,0).
        set corrX to Max(-maxCorr, Min(corrX, maxCorr)).
        set corrY to Max(-maxCorr, Min(corrY, maxCorr)).
        local steerFrame is LookdirUp(v, Up:Vector).
        set steerVec to -v:Normalized +corrX*steerFrame:StarVector +corrY*steerFrame:UpVector.
        //if (sinp<0.5 and sbc>10) // early: augment corrX with throttle (if we have room for cutting throttle)
        //  set tt to tt-0.1*corrY.

        set steerVec to steerVec .
        debugVec(5, "v", Velocity:Surface, -10*Up:Vector).
        print "dt  ="+Round( tImpact -Time:Seconds -2*sbc ) +"  " at (38,20).
        print "tImp="+Round( tImpact -Time:Seconds )        +"  " at (38,21).
        //debugDirection(Steering).
    }

    print " landing burn".
    set WarpMode to "RAILS".
    set Warp to 3. // 50x
    //until (sbc < 50) update().
    until (Time:Seconds > tImpact-2*sbc) update().

    set WARP to 0. wait 0. set WARPMODE to "PHYSICS". wait 0.
    until (Ship:Unpacked) update().
    print "  ship unpacked".
    set Warp to 3.
    until (Vang(Facing:ForeVector, Steering:ForeVector) <5) update().
    set WarpMode to "Rails". set Warp to 2.
    until (tt/accFactor>0.02) update().
    set WarpMode to "Physics". set Warp to 1.

    When (HasTarget and Target:Loaded) Then {
      print "  Target loaded: d=" +Target:Position:Mag.
      When (HasTarget and Target:unpacked) Then { print "  Target unpacked: d=" +Target:Position:Mag. }
    }

    lock Throttle to tt.
    until (sbc < 10) update().
    set Warp to 1.
    if (HasTarget) {
      until (Target:UnPacked or height<400) update().
      if (Target:Unpacked) {
        print "  target unpacked".
        set tgt to chooseBasePort().
        set tgtHeight to Max(0.01, tgt:TerrainHeight).
      } else print "  WARNING: Target still packed!".
    }

    until (height < 30) { update(). } //dynWarp(). }
    //suicideBurn().
    until Status = "LANDED" or Status = "SPLASHED" { update(). }
    unlock Throttle.
    set Warp to 0.

    local endDv is getDeltaV().
    print "  dvCost  ="+Round(startDv-getDeltaV(), 1).
    print "  posError=" +Round(Vxcl(Up:Vector,tgt:Position):Mag,1).

    lock Steering to stUp().
    // print "  ang="+Round(Vang(Up:Vector, Facing:ForeVector),2)
    //      +", vel="+Round(Ship:AngularVel:Mag,2).
    wait until (Ship:AngularVel:Mag<0.1).
    wait 2.
    wait until (Ship:AngularVel:Mag<0.1).
}

vacLandAtTgtLog().
