// functions that are only needed inside an Atmosphere
@lazyglobal off.
print "  Loading libAtmo".

function atmoAscentRocket {
    
    local tgtAP is gLkoAP.
    local lock ppp to 90.
    lock vel to Velocity:Surface.
    local lock velPP to 90-Vang(Up:Vector, vel).
    local lock headCorr to -Vdot(vel:Normalized, North:Vector).
    lock st002 to Heading(90+headCorr, ppp).
    lockSteering(st002@).
    lockThrottleFull().
    
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
        wait 0.01.
        coastToSpace(tgtAP).
    }
    set Warp to 0.
}

function atmoAscentPlane {
    // todo: support different engine configurations
    // * rapier
    // * rapier +nuke (light nukes before air runs out)
    // * panther/whiplash +rocket (switch mode + switch to rockets)
    
    local ppmin is 13.
    lockThrottleFull().
    
    local pp is ppMin.
    local lock rollCorr to -Vdot(Velocity:Orbit:Normalized, North:Vector).
    local lock velPP to 90-Vang(Up:Vector, Velocity:Surface).
    
    //lock Steering to Heading (90, pp-gBuiltinAoA) *R(0,0,rollCorr).
    //function stTmp1 { return Heading (90, pp-gBuiltinAoA) *R(0,0,rollCorr). }
    set SteeringManager:PitchTorqueFactor to 5.
    lock st001 to Heading (90, pp-gBuiltinAoA) *R(0,0,rollCorr).
    lockSteering(st001@).
    
    local engines is Ship:PartsDubbed(gShipType+"Engine").
    //lock Steering to Heading (90,pp -gBuiltinAoA).
    // quelle // lock Steering to SrfPrograde *R(0,0,roll) *R(-(aoa+aoaCorr-gBuiltinAoA),0,0).
    stage. 
    set WarpMode to "PHYSICS".
    set Warp to 2.

    wait until (Status <> "PRELAUNCH" and Status <> "LANDED").
    print "  takeoffVel="+Round(Velocity:Surface:Mag,1).
    Gear off.
    
    // flightPath von MJ (startAlt=0)
    local lock shape to ((Altitude-0) / (19000-0)) ^gLaunchParam.
    local v is V(0,0,0).
    local vTgt is 0.
    local aoaTgt is 0.
    local ppMJ is 0.
    function update {
        wait 0.01.
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
        print "ttAP=" +Round(Eta:Apoapsis,1) +"  " at (38, 5).
    }
    
    
    print "  Initial Climb".
    until (Altitude>25000) update().
    
    set pp to ppMin. 
    set Warp to 2.  // wait until max speed (better: watch ttAP ?)
    local velTmp is Velocity:Orbit:Mag.
    until (Velocity:Orbit:Mag<velTmp) { // or (Ship:AvailableThrust < 30)
        set velTmp to Velocity:Orbit:Mag.
        dynWarp().
    }
    
    print "  Switch to Rockets: vel=" +Round(Velocity:Surface:Mag) +", alt="+Round(Altitude).
    set pp to 23. 
    for eng in engines {
        if (eng:Isp > 1000)  // don't do this twice on resume
          eng:GetModule("MultiModeEngine"):DoEvent("Toggle Mode").
    }
    wait 0.01.
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
    
    set SteeringManager:PitchTorqueFactor to 1.
    unlock Steering.
    unlock st001.
}

function atmoDeorbit {
    //PRINT "Deorbit Burn".
    switch to 0.
    run once liborbit.
    
    if(Periapsis < Body:Atm:Height) {
        print "  WARNING: atmoDeorbit: not in Orbit!".
        return.
    }
    print "  landingPA=" +Round(landingPA, 2).
    //local burnLng is spacePort:Lng + landingPA.
    //local burnTime is timeToLng(burnLng).

//     global waitAngle is burnLng - GeoPosition:Lng.  // workaround "undefined variable"
//     until (waitAngle > 0) {set waitAngle to waitAngle+360. }
//     local synPeriod is 1/ (1/Obt:Period - 1/Body:RotationPeriod).    
//     local burnTime is Time:Seconds + (synPeriod * (waitAngle / 360.0)).
    //print "  waitAngle=" + waitAngle.
    //print "  synPeriod=" +synPeriod.
    //print "  waittime=" +(synPeriod * (waitAngle / 360.0)).
    //print "  burnTime=" +burnTime.
    local tgt is LatLng(spaceport:Lat, spacePort:Lng+landingPA).
    print "  tgt=LatLng(" +Round(tgt:Lat) +", "+Round(tgt:Lng)+")".
    if (not nextNodeExists()) nodeDeorbit(tgt, Body:Atm:Height, deorbitPE).
    //if (not nextNodeExists()) nodeUnCircularize(deorbitPE, burnTime).
    execNode().
}

function atmoLandingRocket {
    if (Status = "LANDED" or Status="SPLASHED") return.
    switch to 0.
    run once liborbit.

    if(Periapsis >= Body:Atm:Height) {
        print "  WARNING: not suborbital!".
        return.
    }
    if (Altitude > Body:Atm:Height) {
        print "  Warp to atmosphere".
        set WarpMode to "RAILS".
        until (Altitude < Body:Atm:Height) {
            if (Warp < 3) set Warp to 3.
            wait 0.01.
        }
        set Warp to 0.
    }
    set WarpMode to "PHYSICS".
    set Warp to 3. // 4x
    
//    if gDoLog {initLandingLog().}
//    local index is 0.
//    local errH is 0.
//    local h is 0.
//    local lngTgt is 74.75.
    lockSteering(stRetro@).
    
    wait until Altitude < 50000.
    set Warp to 2.
    wait until Altitude < 30000.
    set Warp to 1.
    
    wait until (Velocity:Surface:Mag < 260 
            and Velocity:Surface:Mag <> 0). // seems to happen if pod explodes
    print "  Chutes".
    //print "  v  =" +Velocity:Surface:Mag.
    Chutes on.
    lockSteering(stSrfRetro@).
    wait until (Altitude - Max(0, GeoPosition:TerrainHeight)) < 500.
    
    print "  Powered Landing".
    suicideBurn().
    
    unlock Steering.
    if( (defined gDoLog) and gDoLog) {
        local newLandingPA is landingPA -(Longitude - spacePort:Lng).
        switch to 0.
        log "set landingPA to "+Round(newLandingPA, 2)+"." to "logs/log_"+gShipType+".ks".
        switch to 1.
    }
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
            wait 0.01.
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
        runFile("logs/", gLogFile).
        if(lList:Length < 2) print "  WARNING: "+gLogFile+" is missing or corrupt!".
    }
    
    local i is 0.
    local eDot is 1000000.
    
    local headIst is 90.
    local latErr is 0.
    local angErr is 0.
    local headSoll is 90.
    local roll is 0.
    
    local s is 0. // path parameter
    local eSoll is 0.
    local v is 0.
    local e is 0. // energy
    local eErr is 0.
    lock aoaCorr to 0.
    local relLng is 0.

    lock aoa to 60.
    if not gDoLog lock aoaCorr to Max(3.5-aoa, Min(-0.5*eErr, 90-aoa)).
    when Altitude < 40000 then {
        lock aoa to (Altitude*0.001 +20).
        when Altitude < 3000 then lock aoa to 10+Altitude*0.0033.
    }
    
    set SteeringManager:PitchTorqueFactor to 5.
    lock st005 to SrfPrograde *R(0,0,roll) *R(-(aoa+aoaCorr-gBuiltinAoA),0,0).
    lockSteering(st005@).

//    if gDoLog
     // assume we are braking (with what acceleration?)
    lock flareCondition to (Altitude -spacePortHeight < 0.2*VerticalSpeed^2).
//    else
//      lock flareCondition to (Altitude < spacePortHeight+20 or relLng < -359).
    
    Gear off.
    clearScreen2().
    until flareCondition() {
        wait 0.01.
        
        if (not gDoLog and lList:Length > 2) {
            set relLng to Mod(GeoPosition:Lng -spacePort:Lng -720, 360). // norm to [-360,0]
            set v to Velocity:Surface:Mag.
            set e to 0.5*v*v +9.81*(Altitude -spacePortHeight).
            until (lList[i] > relLng) { 
                set i to i+1. 
                set eDot to ( eList[i] -eList[i-1]) /gLogDeltaTime.
            }
            set s to (relLng - lList[i-1]) / (lList[i] - lList[i-1]).
            set eSoll to s*eList[i] + (1-s)*eList[i-1].
            set eErr to (e-eSoll)/eDot.      // Steering value for conserving/wasting energy
            
            set headIst to Vang(Vxcl(Velocity:Surface, Up:Vector), North:Vector).
            set latErr to Latitude-spacePort:Lat.
            set angErr to latErr/(-relLng) *(180/3.1415). // small angle approx.
            set headSoll to 90 +2*angErr.
            set roll to -headSoll + headIst.
            
            print "eDot="+Round(eDot, 0)+"   " at (38,0).
            print "dE  ="+Round(e-eSoll , 0)+" " at (38,1).
            print "aoaC="+Round(aoaCorr, 3) at (38,2).
            
            print "latE="+Round(latErr*10472, 1)+"  " at (38,4). // meters
            //print "angE="+Round(angErr, 3)+"   " at (38,4).
            print "rLng="+Round(relLng, 3)+"  " at (38,5).
            //print "roll="+Round(roll,     2)+"   " at (38,6).
            //print "hIst="+Round(headIst,  2)+"   " at (38,11).
            //print "hSol="+Round(headSoll, 2)+"   " at (38,12).
        }
        //print "aoaT="+Round(aoa, 2)+"   " at (38,13).
        //print "aoaE="+Round(Vang(Facing:Forevector,
        //                         Velocity:Surface)-(aoa+aoaCorr)+gBuiltinAoA, 2) at (38,14).
        
        when Altitude<200 then {
            Gear on.
            Lights on.
        }
        dynWarp().
        //debugDirection (st005()).
    }
    Gear on.
    Lights on.
    set Warp to 0.
    
    if (gDoLog) {
        
    } else {
        //if (relLng < -359) print "  Coming in high".
    //     print "   Alt=" +Round(Altitude).
    //     print "   vz =" +Round(VerticalSpeed).
    //     print "   h  =" +Round(Altitude).
    //     print "   h0 =" +Round(spacePortHeight).    
        
        //wait until (Altitude -spacePortHeight) < Abs(VerticalSpeed)*3.
        // todo: control vertical speed as a function of height
    }

    print "  Flare: alt=" +Altitude +", vVel=" +VerticalSpeed.
//     print "   Alt=" +Round(Altitude).
//     print "   vz =" +Round(VerticalSpeed).
//     print "   h  =" +Round(Altitude).
//     print "   h0 =" +Round(spacePortHeight).
    set roll to 0.
    lock st007 to Heading(90, aoa).
    lockSteering(st007@).
    if gDoLog writeLandingLog().
    
    wait until Status <> "FLYING".
    Brakes on.
    lock aoa to 0.
    wait until Airspeed < 0.1.
    Lights off.
    unlock Steering.
    set SteeringManager:PitchTorqueFactor to 1.
    unlock aoaCorr.
    unlock aoa.
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
      wait 0.01.
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

    local logFile is "logs/"+gLogFile.
    local newLandingPA is landingPA -(finalLng - spacePort:Lng).
    switch to 0.
    log "" to logFile.
    delete logFile.

    log ("set landingPA to " +Round(newLandingPA, 3) +".") to logFile.
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
    print "  lngErr=" +Round(GeoPosition:Lng - spacePort:Lng, 3).
    print "  latErr=" +Round(GeoPosition:Lat - spacePort:Lat, 3).
    print "  dist  =" +Round(spacePort:Position:Mag, 3).
}
