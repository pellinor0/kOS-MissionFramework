// functions that are only needed inside an Atmosphere
@lazyglobal off.
print "  Loading libAtmo".

function planeToHeading {
  parameter normal.                          // desired orbital plane
  set normal to Vxcl(normal, Up:ForeVector). // plane through current position
  return Body:GeoPositionOf(Ship:Position +Vcrs(Up:ForeVector, normal)):Heading.
}

function getHeading {
  return Body:GeoPositionOf(Ship:Position +Ship:Velocity:Surface):Heading.
}

function atmoAscentRocket {
    parameter tgtPlane is V(0,1,0).
    set tgtPlane to Vxcl(tgtPlane, Up:ForeVector). // plane through current position
    local tgtAP is gLkoAP.
    local lock ppp to 90.
    lock vel to Velocity:Surface.
    local lock velPP to 90-Vang(Up:Vector, vel).

    if (tgtPlane = V(0,0,0)) {
      set tgtPlane to Ship:North:ForeVector.
    }

    local launchHeading is planeToHeading(tgtPlane).
    print "  launchHeading="+launchHeading.
    lock Steering to Heading(launchHeading, ppp).
    lock Throttle to 1.

    if(Status = "PRELAUNCH" or Status="Landed") { stage. }
    if (Stage:SolidFuel > 0) when (Stage:SolidFuel <= 0.02) then {
        print "  stage".
        stage.
        if (Stage:SolidFuel > 0) when (Stage:SolidFuel <= 0.02) then {
            stage.
        }
    }

    set Warpmode to "PHYSICS".
    set Warp to 3.

    local lock apReached to (Apoapsis > tgtAP*0.95).
    until (VerticalSpeed > 60) or apReached {dynWarp().}

    print "  Gravity turn".
    // flightPath (copied from mechJeb)
    local startAlt is Altitude.
    local lock shape to ((Altitude-startAlt) / (Body:Atm:Height-startAlt)) ^gLaunchParam.
    local lock ppp to 90*(1-shape).

    function update {
        print "v   =" +Round(Velocity:Surface:Mag, 2) +"  " at (38, 0).
        print "sha =" +Round(shape, 2)  +"  " at (38, 1).
        print "ppp =" +Round(ppp, 2)    +"  " at (38, 2).
        print "alt =" +Round(Altitude, 2)+"  " at (38, 3).
        dynWarp().
    }

    until ((Apoapsis > 10000) or apReached) {update().}

    local lock ppp to velPP.
    until (Altitude > 30000) or apReached {dynWarp().}

    lock vel to ((Altitude-30000)*Velocity:Orbit
                +(40000-Altitude)*Velocity:Surface)/10000.
    until (Altitude > 40000) or apReached {dynWarp().}
    lock vel to Velocity:Orbit.

    until apReached {dynWarp().}
    unlock Throttle.
    unlock Steering.
    unlock vel.

    if Body:Atm:Exists {
        print "  Coasting to space".
        wait 0.
        coastToSpace(tgtAP).
    }
    set Warp to 0.
}

function atmoAscentPlane {
    parameter tgtPlane is V(0,1,0).
    // todo: support different engine configurations
    // * rapier
    // * rapier +nuke (light nukes before air runs out)
    // * panther/whiplash +rocket (switch mode + switch to rockets)
    set tgtPlane to Vxcl(Up:ForeVector, tgtPlane):Normalized. // plane through current position
    //print "  tgtInc=" +Round(Vang(V(0,1,0), tgtPlane) ,2).
    lock vel to Velocity:Surface.

    local ppmin is 13.
    lock Throttle to 1.

    local pp is ppMin.
    local lock velPP to 90-Vang(Up:Vector, Velocity:Surface).

    local engines is Ship:PartsDubbed(gShipType+"Engine").

    // Takeoff
    Brakes off.
    stage.
    set WarpMode to "PHYSICS".
    set Warp to 2.
    lock Steering to Heading(gSpacePortHeading, pp-gBuiltinAoA).

    wait until (VerticalSpeed > 5).
    print "  takeoffVel="+Round(Velocity:Surface:Mag,1).
    Gear off.
    local lock rollCorr to Max(-20, Min(20, -100*Vdot(vel:Normalized, tgtPlane))).
    lock Steering to Heading (getHeading(), pp-gBuiltinAoA) *R(0,0,rollCorr).

    // flightPath von MJ (startAlt=0)
    local lock shape to ((Altitude-0) / (19000-0)) ^gLaunchParam.
    local v is V(0,0,0).
    local vTgt is 0.
    local aoaTgt is 0.
    local ppMJ is 0.
    function update {
        wait 0.
        set v to Velocity:Surface.
        set vTgt to 300+Altitude/30.
        set aoaTgt to Max(3, (v:Mag-vTgt)/15). // try to keep speed
          // don't overshoot ascent path
        set ppMJ to 90 -(90-ppMin)*shape.
        set pp to velPP +aoaTgt.
        set pp to Max(ppMin, Min(pp, ppMJ)).
        dynWarp().

        print "v   =" +Round(v:Mag, 2) +"  " at (38, 0).
        print "vT  =" +Round(vTgt, 2)  +"  " at (38, 1).
        print "aoaT=" +Round(aoaTgt, 2)+"  " at (38, 2).
        print "pp  =" +Round(pp, 2)    +"  " at (38, 3).
        print "ppMJ=" +Round(ppMJ, 2)  +"  " at (38, 4).
        //print "ttAP=" +Round(Eta:Apoapsis,1) +"  " at (38, 5).
        print "rc  =" +Round(rollCorr, 2)    at (38, 6).
        print "hdg =" +Round(getHeading(),2) at (38, 7).
        //DebugDirection(Steering).
    }

    print "  Initial Climb".
    until (Altitude>25000) update().
    when (Altitude>30000) then {
        lock vel to ((Altitude-30000)*Velocity:Orbit +(40000-Altitude)*Velocity:Surface)/10000.
        when (Altitude>40000) then lock vel to Velocity:Orbit.
    }

    set pp to ppMin.
    set Warp to 2.  // wait until max speed (better: watch ttAP ?)
    local velTmp is Velocity:Orbit:Mag.
    until (Velocity:Orbit:Mag<velTmp) { // or (Ship:AvailableThrust < 30)
        set velTmp to Velocity:Orbit:Mag.
        dynWarp().
    }

    print "  Switch to Rockets: vel=" +Round(Velocity:Surface:Mag) +", alt="+Round(Altitude).
    set pp to 22.
    for eng in engines {
        if (eng:Isp > 1000)  // don't do this twice on resume
          eng:GetModule("MultiModeEngine"):DoEvent("Toggle Mode").
    }
    wait 0.
    local tmpDV is getDeltaV().
    print "  tmpDv="+Round(tmpDv).

    until Apoapsis > gLkoAP*0.99 { // leave room for some lift
        dynWarp().
    }
    unlock Throttle.

    print "  AP reached. Coasting to space".
    coastToSpace(gLkoAP).
    wait until Altitude > Body:Atm:Height.
    print "  dV in rocket mode:" +Round( (tmpDv-getDeltaV()), 1).

    //set SteeringManager:PitchTorqueFactor to 1.
    unlock Steering.
}

function atmoDeorbit {
    parameter waitForInc is true.
    if(Periapsis < Body:Atm:Height) {
        print "  WARNING: atmoDeorbit: not in Orbit!".
        return.
    }
    if gIsPlane and ((not (defined gDoLog)) or (gDoLog=0)) {
        local logFile is "landingLog_"+gShipType+".ks".
        runFile("0:/logs/", logFile).
    }
    print "  landingPA=" +Round(gLandingPA, 2).
    local tgt is LatLng(gSpaceport:Lat, gSpacePort:Lng+gLandingPA).
    //print "  tgt=LatLng(" +Round(tgt:Lat) +", "+Round(tgt:Lng)+")".
    if (not nextNodeExists()) nodeDeorbit(tgt, Body:Atm:Height*0.75, gDeorbitPE, waitForInc).
    execNode().

    //local t is timeToAltitude2(Body:Atm:Height*0.75, Time:Seconds, Time:Seconds +Obt:Period/2).
    //local p is PositionAt(Ship,t).
    //local lngFromRot is 360*(t-Time:Seconds)/(6*3600).
    //local actLngErr is Body:GeoPositionOf(p):Lng -gSpacePort:Lng -gLandingPA -lngFromRot.
    //print "  lngErr=" +Round(Mod(actLngErr+180,360)-180, 2).

    //print "  rotAng=" +Round(Body:RotationAngle, 2).
    //print "  lan   =" +Round(Obt:Lan, 2).
    //print "  lng   =" +Round(gSpacePort:Lng, 2).
    //local lanErr is (Obt:Lan+90) -(gSpacePort:Lng+Body:RotationAngle). // tgt should be highest point of orbit
    //print "  lanErr=" +Round( Mod(lanErr+180,360)-180, 2).
    print "  lanErr=" +Round( Mod(getLanDiffToKsc()+180,360)-180, 2).
    //debugVec(5, Body:Position, 1000000*SolarPrimeVector, "SolarPrime").
    //print "  lngFromRot=" +Round(lngFromRot, 2).
    //wait 1000.
}

function atmoLandingRocket {
    if (Status = "LANDED" or Status="SPLASHED") return.

    if(Periapsis >= Body:Atm:Height) {
        print "  WARNING: not suborbital!".
        return.
    }
    if (Altitude > Body:Atm:Height) {
        print "  Warp to atmosphere".
        set WarpMode to "RAILS".
        until (Altitude < Body:Atm:Height) {
            if (Warp < 3) set Warp to 3.
            wait 0.
        }
        set Warp to 0.
    }
    set WarpMode to "PHYSICS".
    set Warp to 3. // 4x

    lock Steering to Retrograde.

    wait until Altitude < 50000.
    set Warp to 2.
    wait until Altitude < 30000.
    set Warp to 1.

    print "  arm Chutes".
    Chutes on.
    wait until (Velocity:Surface:Mag < 260
            and Velocity:Surface:Mag <> 0). // seems to happen if pod explodes
    lock Steering to stSrfRetro().
    wait until (Altitude - Max(0, GeoPosition:TerrainHeight)) < 500.

    print "  Powered Landing".
    suicideBurn().
    unlock Steering.
}

function atmoLandingPlane {
    if (Status = "LANDED" or Status="SPLASHED") return.
    if(Periapsis >= Body:Atm:Height) {
        print "  WARNING: not suborbital!".
        return.
    }
    if (Altitude > Body:Atm:Height) {
        print "  Warp to atmosphere".
        set WarpMode to "RAILS".
        until (Altitude < Body:Atm:Height) {
            if (Warp < 3) set Warp to 3.
            wait 0.
        }
    }
    set WarpMode to "PHYSICS".
    set Warp to 3. // 4x

    global gLogFile is "landingLog_"+gShipType+".ks".
    if not (defined gLogDeltaTime) global gLogDeltaTime is 20.
    if not (defined gDoLog) global gDoLog is 0.
    if gDoLog {
        initLandingLog().
        printFuelLeft().
    } else {
        print "  Following descent path".
        runFile("0:/logs/", gLogFile).
        if(lList:Length < 2) print "  WARNING: "+gLogFile+" is missing or corrupt!".
    }

    local i is 0.
    local eDot is 1000000.

    local roll is 0.

    local s is 0. // path parameter
    local eSoll is 0.
    local v is 0.
    local e is 0. // energy
    local eErr is 0.
    local relLng is 0.

    // set profile as a list of height/aoa pairs
    local proH is List(70000,40000,0).  // height
    local proA is List(   60,   40,10). // AoA
    local j is 1.
    function getAoa {
      if (Altitude < proH[j]) {
        set j to j+1.
        print "i   ="+j +",alt="+Round(Altitude/1000)+"k" at (38,14).
      }
      local s is (proH[j-1]-Altitude)/(proH[j-1]-proH[j]).
      //print "s   ="+Round(s  , 2)+"   " at (38,15).
      return proA[j-1]*(1-s) +proA[j]*s.
    }

    local aoa is 60.
    local aoaCorr is 0.
    //when Altitude < 40000 then {
    //    lock aoa to (Altitude*0.001 +20).
    //    when Altitude < 3000 then lock aoa to 10+Altitude*0.0033.
    //}

    local steerDir is Prograde.
    lock Steering to steerDir.
    //set SteeringManager:PitchTorqueFactor to 5.

    //if gDoLog
     // assume we are braking (with what acceleration?)
    lock flareCondition to (Altitude -gSpacePortHeight < 0.2*VerticalSpeed^2).
    //else
    //  lock flareCondition to (Altitude < gSpacePortHeight+20 or relLng < -359).

    function getRunwayHeading {
      local dLng is Sin(gSpacePortHeading).
      local dLat is Cos(gSpacePortHeading).
      local p1 is gSpacePort:Position.
      local p2 is LatLng( gSpacePort:Lat +dLat, gSpacePort:Lng +dLng ):Position.
      print "  dLat=" +Round(dLat,2).
      print "  dLng=" +Round(dLng,2).
      return Body:GeoPositionOf(p2-p1+Body:Position).
    }
    local rwHeading is getRunwayHeading. // as GeoCoords so it doesn't change over time

    Gear off.
    clearScreen2().
    until flareCondition() {
        wait 0.
        local aoa is getAoa().

        if ((not gDoLog) and lList:Length > 2) {
            local aimPoint is gSpacePort:Position -Min(Abs(relLng), 10)*10000*rwHeading:Position:Normalized.
            local bearSoll is Body:GeoPositionOf(aimPoint):Bearing.
            set roll to Max(-15, Min(15, -3*bearSoll)).

            set aoaCorr to Max(3.5-aoa, Min(-0.5*eErr, 90-aoa)).
            set aoaCorr to Min(aoaCorr, aoa).
            set relLng to -Vang(gSpacePort:Position-Body:Position, Ship:Position-Body:Position)
                          -Abs(gSpacePort:Bearing)*0.01.  // room for turning
            set v to Velocity:Surface:Mag.
            set e to 0.5*v*v +9.81*(Altitude -gSpacePortHeight).
            until (lList[i] > relLng) {
                set i to i+1.
                set eDot to ( eList[i] -eList[i-1]) /gLogDeltaTime.
            }
            set s to (relLng - lList[i-1]) / (lList[i] - lList[i-1]).
            set eSoll to s*eList[i] + (1-s)*eList[i-1].
            set eErr to (e-eSoll)/eDot.      // Steering value for conserving/wasting energy

            debugVec(1, Body:Position, (aimPoint-Body:Position)*2, "aimPoint").
            print "eDot="+Round(eDot, 0)+"   " at (38,0).
            print "dE  ="+Round(e-eSoll , 0)+" " at (38,1).
            print "aoaC="+Round(aoaCorr, 3) at (38,2).
            print "rLng="+Round(relLng, 3)+"  " at (38,5).
            print "roll="+Round(roll,     2)+"   " at (38,6).
            //print "bSol="+Round(bearSoll,2)+"   "  at (38,7).
            //print "lat ="+Round(Latitude,2)     at (38,13).
        }
        set steerDir to SrfPrograde *R(0,0,roll) *R(-(aoa+aoaCorr-gBuiltinAoA),0,0).

        when (Altitude<200) then {
            Gear on.
            Lights on.
        }
        dynWarp().
        //debugDirection (Steering).
    }
    Gear on.
    Lights on.
    set Warp to 0.

    if (gDoLog) {

    } else {
    //if (relLng < -359) print "  Coming in high".
    // print "   Alt=" +Round(Altitude).
    // print "   vz =" +Round(VerticalSpeed).
    // print "   h  =" +Round(Altitude).
    // print "   h0 =" +Round(gSpacePortHeight).

        //wait until (Altitude -gSpacePortHeight) < Abs(VerticalSpeed)*3.
        // todo: control vertical speed as a function of height
    }

    print "  Flare: alt=" +Round(Altitude,1)
         +", vVel=" +Round(VerticalSpeed,2).
    // print "   Alt=" +Round(Altitude).
    // print "   vz =" +Round(VerticalSpeed).
    // print "   h  =" +Round(Altitude).
    // print "   h0 =" +Round(gSpacePortHeight).
    set roll to 0.
    lock Steering to Heading(gSpacePortHeading, 10-gBuiltinAoa).
    if gDoLog writeLandingLog().

    wait until Status <> "FLYING".
    Brakes on.
    wait until Airspeed < 0.1.
    Lights off.
    unlock Steering.
    set SteeringManager:PitchTorqueFactor to 1.
}

// auxiliary functions used only here
function coastToSpace {
    parameter tgtAP.

    set WarpMode to "PHYSICS".
    set Warp to 4.
    lock Steering to stPrograde().
    when Altitude > Body:Atm:Height*0.995 then set Warp to 0.

    lock Throttle to Max(0, (tgtAP-Apoapsis)/2000).
    until Altitude > Body:Atm:Height {
      //print "tt   ="+Round(Throttle, 3)       at (38,0).
      wait 0.
    }
    unlock Steering.
    unlock Throttle.
}

function initLandingLog {
    // expects filename in global Var gLogFile

    global lastLog is 0.
    global eLog is List().
    global lLog is List().

    print "  Log start".
    when (1) then {
        if (gDoLog) {
            if (Time:Seconds - lastLog > gLogDeltaTime) {
                // Logging
                set lastLog to Time:Seconds.
                eLog:Add( Altitude*9.81 +0.5*Airspeed*Airspeed ).
                lLog:Add( Longitude ).
            }
            preserve.
        } else {
            print "  Logging finished! " +lLog:Length +" entries.".
            print "  Status="+Status.
            print "  Altitude="+Altitude.
        }
    }
}

function writeLandingLog {

    set gDoLog to 0.
    local normLng is 0.
    local finalLng is Longitude.
    lLog:Add(finalLng).
    eLog:Add(Round( Altitude*9.81 +0.5*Airspeed*Airspeed)).

    local logFile is "0:/logs/"+gLogFile.
    local newLandingPA is gLandingPA -(finalLng - gSpacePort:Lng).
    log "" to logFile.
    DeletePath(logFile).

    log ("set gLandingPA to " +Round(newLandingPA, 3) +".") to logFile.
    log ("global lList is List(). global eList is List().") to logFile.
    // avoid missing values
    log "lList:Add(-720). "
       +"eList:Add(" +Round(2*eLog[0]) +")." to logFile.

    from {local i is 0.} until (i = lLog:Length) step {set i to i+1.} do {
        set normLng to Mod(lLog[i] - finalLng -720, 360). // norm to [-360, 0]
        log "lList:Add(" +Round( normLng, 3) +"). "
           +"eList:Add(" +Round( eLog[i])   +")." to logFile.
    }

    // avoid missing values
    log "lList:Add(10). "
       +"eList:Add(0)." to logFile.

    unset eLog.
    unset lLog.
    unset gLogDeltaTime.
    print "  Logfile written!".
}

function printFuelLeft {
    local lf is Ship:LiquidFuel.
    local ox is Ship:Oxidizer.
    print " Fuel left:".
    print "  LF="+Round(lf,2) +", Ox="+Round(ox,2) +", m="+Round((lf+ox)*0.005, 3).
    print "  Fuel imbalance: " +Round(ox -lf*1.1/0.9, 2) +" ox".
}

function evalLanding {
    // check error after landing
    print "  lngErr=" +Round(GeoPosition:Lng - gSpacePort:Lng, 3).
    print "  latErr=" +Round(GeoPosition:Lat - gSpacePort:Lat, 3).
    print "  dist  =" +Round(gSpacePort:Position:Mag, 3).
}
