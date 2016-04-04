@lazyglobal off.
run once libbasic.
run once liborbit.
run once librdv.
print "  Loading libmission".

// == Mission Steps ==
//  IMPORTANT: These advance the mission counter. Skipping them in a mission file
//  can break the resume mechanic (so caution with 'if' clauses around such a call!). 
function m_waitForLaunchWindow {
    if not missionStep() return.
    
    if(Status = "PRELAUNCH") {
        run once liborbit.
        local lkoPeriod is 2*3.1415*sqrt((gLkoAP+Body:Radius)^3 / Body:Mu).
        local tgtPeriod is Target:Obt:Period.
        local launchPA is getPhaseAngle(gLaunchDuration, 
                                        gLaunchAngle, 
                                        Body:RotationPeriod, 
                                        tgtPeriod).
        
        local transferPA is getPhaseAngle(0.5*(lkoPeriod+tgtPeriod), 
                                        0, 
                                        lkoPeriod, 
                                        tgtPeriod).
        //print "  lkoPeriod=" +Round(lkoPeriod).
        print "  launchPA =" +Round(launchPA,   2).
        print "  transPA  =" +Round(transferPA, 2).
    
        //wait 1.
        local launchTime is launchTimeToRdv( launchPA+transferPA -0). // some error margin
        print "Warping to Launch (dt="+Round(launchTime - Time:Seconds) +")".
        warpRails(launchTime).
    } else print "Skipping Launch Timing (not PRELAUNCH)".
}

function m_waitForDeorbitWindow {
    if not missionStep() return.
    // correct for 
    
    
}

function m_waitForTransition {
    parameter type.
    
    if missionStep() {
        if (Obt:Transition <> type) {
            print "  WARNING: next transition != "+type+" !".
            print "           type="+Obt:Transition.
            interruptMission().
            return.
        }
        local b is Body.
        warpRails(Time:Seconds+Eta:Transition).
        wait until Body <> b.
    }
}

function m_ascentLKO {
    local launchTime is 0.
    local launchAngle is 0.
    
    if missionStep() {
        print "Ascent".
        if (Periapsis > Body:Atm:Height) {
            print "  Skipping: already in orbit".
        } else if Verticalspeed < -1 {
            print "  Skipping: this looks like a landing".
        } else {
            run once libatmo.
            set launchTime to Time:Seconds.
            set launchAngle to Longitude.
            if gIsPlane
              atmoAscentPlane().
            else 
              atmoAscentRocket().
            
            if (Obt:Inclination > 0.01)
              print "  Inclination=" +Round(Obt:Inclination, 3).
        }
    }
    
    if missionStep() {
        print "Circularize".
        if (Periapsis > Body:Atm:Height) {
            print "  Skipping :already in orbit".
        } else {
            run once liborbit.
            if not nextNodeExists() {
                nodeCircAtAP().
                run once libnav.
                tweakNodeInclination(V(0,1,0), 0.01).
            }
            execNode().
            
            if (Obt:Inclination > 0.01)
              print "  Inclination=" +Round(Obt:Inclination, 3).
            
            //if launchTime<>0 print "  time  to LKO =" +(Time:Seconds-launchTime).
            //if launchTime<>0 print "  angle to LKO =" +(Longitude-launchAngle).
        }
    }
}

function m_landFromLKO {
    
    if missionStep() {
        print "Deorbit".
        run once libatmo.
        run once libnav.
        atmoDeorbit(). 
    }

    if missionStep() {
        print "Landing".
        run once libatmo.
        if (gIsPlane)
          atmoLandingPlane().
        else
          atmoLandingRocket().

        evalLanding().
    }
}

function m_askConfirmation {
    parameter msg.
    // confirmation happened if we resumed 
    //   manually and from this step.
    if (gMissionCounter <> pMissionCounter-1) 
      set gMissionStartManual to 0.
    
    if missionStep() {
        if(gMissionStartManual)
            set gMissionStartManual to 0.
        else {
            print msg.
            print "  type RUN RESUME to continue".
            interruptMission().
        }
    }
}

function m_undock {
    if missionStep() and  dockable {
        print "Undock".
        local module is myPort:GetModule("ModuleDockingNode").
        if(not myPort:State:Contains("Docked")) {
            print "  Port was not docked".
            return.
        }
        module:DoEvent("control from here").
        wait 0.01.
        //myPort:GetModule("ModuleDockingNode"):DoEvent("Undock").
        myPort:Undock().
        wait 0.01.
        module:DoEvent("control from here").
        Core:DoEvent("open terminal").
        wait 0.01.
        
        local mp is Ship:MonoPropellant.
        RCS on.
        set Ship:Control:Fore to -1.
        wait 2.
        set Ship:Control:Fore to 0.
        RCS off.
        print "  burnt "+Round(mp -Ship:MonoPropellant, 2) +" mp".
        print "  waiting for safe distance".
        wait 10.
        
        Ship:PartsDubbed(gShipType+"Control")[0]
            :GetModule("ModuleCommand"):DoEvent("control from here").
    }
}

function m_rendezvousDock {
    if missionStep() {
        print "Rendezvous".
        run once librdv.
        run once libnav.
        rdvDock().
        Core:DoEvent("open terminal").
    }
}

function m_hohmannToTarget {
    if missionStep() {
        print "Hohmann Transfer".
        run once libnav.
        run once liborbit.
        if not nextNodeExists() nodeHohmann().
        execNode().
    }
}

function m_fineRdv {
    if missionStep() {
        print "Fine tuning approach".
        run once libnav.
        if not nextNodeExists() nodeFineRdv().
        execNode().
    }
}

function m_nodeIncCorr {
    if missionStep() {
        print "Correct for inclination".
        run once libnav.
        if not nextNodeExists() nodeHohmannInc().
        execNode().
    }
}

function m_vacLand {
    parameter tgt. // GeoCoordinates
    run once libnav.
    if missionStep() {
        print "Landing at Target (Vac)".
        // Assumption: starting in low orbit
        vacLandAtTgt(tgt).
    }
}

function m_vacLaunch {
    parameter tgtAP.
    
    if missionStep() {
        print "Launch (Vac)".
        run once liborbit.
        vacAscent(tgtAP).
    }
    if missionStep() {
        print "Circularize".
        run once liborbit.
        if not nextNodeExists() {
            nodeCircAtAP().
            tweakNodeInclination(V(0,1,0), 0.02).
            
        }
        execNode().
    }
}

function m_returnFromMoon {
    // return from (eq. orbit around) a moon 
    // to low orbit of its parent
    
    if missionStep() {
        print "Return from Moon".
        run once libnav.
        if not nextNodeExists() nodeReturnFromMoon().
        run once liborbit.
        execNode().
    }
    m_waitForTransition("ESCAPE").
    
    if missionStep() {
        print "Correct Inclination".
        run once libnav.
        if not nextNodeExists() nodeIncChange(V(0,1,0)).
        execNode().
    }
}

function m_capture {
    parameter alt.
    // Assumption: we have just entered the SOI
    
    if missionStep() {
        print "Adjust PE".
        run once libnav.
        nodeTuneCapturePE(alt).
        wait 0.01.
        tweakNodeInclination( V(0,1,0), -1).
        execNode().
    }
    
    if missionStep() {
        print "Circularize at PE".
        run once liborbit.
        if not nextNodeExists() {
            run once libnav.
            nodeUnCircularize(alt, Time:Seconds+Eta:Periapsis).
            wait 0.01.
            tweakNodeInclination( V(0,1,0), 0.02).
        }
        execNode().
    }
}

function m_returnFromHighOrbit {
    if missionStep() {
        //todo: should I reenter or come to a space station?
        
        //toDo: aerobrake
        aeroBrake().
    }
}


// == Mission Infrastructure ==
function prepareMission {
    parameter name.
    
    switch to 1.
    log "" to mission.ks.
    delete mission.ks.
    local missionName is "m_"+name+".ks".
    switch to 0.
    copy "missions/"+missionName to 1.
    switch to 1.
    rename file missionName to mission.ks.
    set pMissionCounter to 1.
    log "set pMissionCounter to 1." to persistent.ks.
}

function resumeMission {
    set gMissionCounter to 0.
    switch to 1.    
    if (gMissionStartManual)
      print "Resume Mission (manual)".
    else
      print "Resume Mission (Auto)".
    
    run mission.ks.
    if (gMissionCounter = 100000) {
        //print "Mission interrupted!".
    } else {
        print "Mission finished!".
        set gMissionCounter to 0.
        set pMissionCounter to 0.
        switch to 1.
        log "set pMissionCounter to 0." to persistent.ks.
    }
}

function interruptMission {
    // skip rest of the mission
    set gMissionCounter to 100000.
}

function missionStep {
    switch to 0.
    if (gMissionCounter > pMissionCounter) { 
        //print "  interrupted mission: mc="+missionCounter +", pmc=" +pMissionCounter.
        return 0.
    } else if (gMissionCounter = pMissionCounter) {
        set gMissionCounter to gMissionCounter+1.
        set pMissionCounter to pMissionCounter+1.
        //print "  running mission: mc="+missionCounter +", pmc=" +pMissionCounter.
        switch to 1.
        log "set pMissionCounter to " +gMissionCounter +"." to persistent.ks.
        switch to 0.
        return 1.
    } else if (gMissionCounter = pMissionCounter-1) {
        set gMissionCounter to gMissionCounter+1.
        print "  resume  mission: mc="+gMissionCounter +", pmc=" +pMissionCounter.
        return 1.
    } else {
        set gMissionCounter to gMissionCounter+1.
        //print "  sync    mission: mc="+missionCounter +", pmc=" +pMissionCounter.
        return 0.
    }
}

