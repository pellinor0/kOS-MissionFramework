@lazyglobal off.
RunOncePath("0:/libbasic").
RunOncePath("0:/liborbit").
RunOncePath("0:/librdv").
RunOncePath("0:/libnav").
print "  Loading libmission".

// == Mission Steps ==
//  IMPORTANT: These advance the mission counter. Skipping them in a mission file
//  can break the resume mechanic (so caution with 'if' clauses around such a call!).
function m_waitForLaunchWindow {
    if not missionStep() return.

    if(Status = "PRELAUNCH") {
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
    } else print "Skipping Launch Timing (state=" +Status +" != PRELAUNCH)".
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
            RunOncePath("0:/libatmo").
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
            if not nextNodeExists() {
                nodeCircAtAP().
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
        RunOncePath("0:/libatmo").
        atmoDeorbit().
    }

    if missionStep() {
        print "Landing".
        RunOncePath("0:/libatmo").
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
    if missionStep() {
        if (not hasPort()) return.
        print "Undock".
        if(not gMyPort:State:Contains("Docked")) {
            print "  Port was not docked".
            return.
        }
        gMyPort:ControlFrom.
        wait 0.
        gMyPort:Undock().
        wait 0.
        gMyPort:ControlFrom.
        Core:DoEvent("open terminal").
        wait 0.

        //debugDirection(Facing).
        local mp is Ship:MonoPropellant.
        RCS on.
        set Ship:Control:Fore to -1.
        wait 4.
        set Ship:Control:Fore to 0.
        RCS off.
        print "  burnt "+Round(mp -Ship:MonoPropellant, 2) +" mp".
        print "  waiting for safe distance".
        set WarpMode to "RAILS".
        set Warp to 2.
        wait 2.5*gShipRadius.
        set Warp to 0.
        wait until Ship:Unpacked.
        Ship:PartsDubbed(gShipType+"Control")[0]:ControlFrom.
    }
}

function m_rendezvousDock {
    if missionStep() {
        print "Rendezvous".
        RunOncePath("0:/librdv").
        rdvDock().
        Core:DoEvent("open terminal").
    }
}

function m_hohmannToTarget {
    if missionStep() {
        print "Hohmann Transfer".
        if not nextNodeExists() nodeHohmann().
        execNode().
    }
}

function m_fineRdv {
    if missionStep() {
        print "Fine tuning approach".
        if not nextNodeExists() nodeFineRdv().
        execNode().
        checkRdv().
    }
}

function m_nodeIncCorr {
    if missionStep() {
        print "Correct for inclination".
        if not nextNodeExists() nodeHohmannInc().
        execNode().
    }
}

function m_vacLand {
    parameter tgt. // GeoCoordinates
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
        vacAscent(tgtAP).
    }
    if missionStep() {
        print "Circularize".
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
        if not nextNodeExists() nodeReturnFromMoon().
        execNode().
    }
    m_waitForTransition("ESCAPE").

    if missionStep() {
        print "Correct Inclination".
        if not nextNodeExists() nodeIncChange(V(0,1,0)).
        execNode().
    }
}

function m_capture {
    parameter alt.
    // Assumption: we have just entered the SOI

    if missionStep() {
        print "Adjust PE".
        nodeTuneCapturePE(alt).
        wait 0.
        tweakNodeInclination( V(0,1,0), -1).
        execNode().
    }

    if missionStep() {
        print "Circularize at PE".
        if not nextNodeExists() {
            nodeUnCircularize(alt, Time:Seconds+Eta:Periapsis).
            wait 0.
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

    log "" to "1:/mission.ks".
    DeletePath("1:/mission.ks").
    local missionName is "m_"+name+".ks".
    CopyPath("0:/missions/"+missionName, "1:/mission.ks").
    //rename file missionName to mission.ks.
    set pMissionCounter to 1.
    log "set pMissionCounter to 1." to "1:/persistent.ks".
}

function resumeMission {
    set gMissionCounter to 0.
    if (gMissionStartManual)
      print "Resume Mission (manual)".
    else
      print "Resume Mission (Auto)".

    RunPath("1:/mission.ks").
    if (gMissionCounter = 100000) {
        //print "Mission interrupted!".
    } else {
        print "Mission finished!".
        set gMissionCounter to 0.
        set pMissionCounter to 0.
        log "set pMissionCounter to 0." to "1:/persistent.ks".
    }
}

function interruptMission {
    // skip rest of the mission
    set gMissionCounter to 100000.
}

function missionStep {
    if (gMissionCounter > pMissionCounter) {
        //print "  interrupted mission: mc="+missionCounter +", pmc=" +pMissionCounter.
        return 0.
    } else if (gMissionCounter = pMissionCounter) {
        set gMissionCounter to gMissionCounter+1.
        set pMissionCounter to pMissionCounter+1.
        //print "  running mission: mc="+missionCounter +", pmc=" +pMissionCounter.
        log "set pMissionCounter to " +gMissionCounter +"." to "1:/persistent.ks".
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
