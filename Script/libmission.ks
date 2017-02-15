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
    local launchTime is Time:Seconds.

    if(Status<>"PRELAUNCH" and Status<>"LANDED") {
      print "Skipping Launch Timing (state=" +Status +" != PRELAUNCH)". return.
    }

    local tgtPlane is getOrbitNormal(Target).
    local tgtInc is Vang(tgtPlane, V(0,1,0)).
    if (tgtInc > 1) and (Abs(Latitude) > 1) {
      print "  Launch into plane of target".
      // find LAT extremum of target plane
      local lng2 is Body:GeoPositionOf(Body:Position-tgtPlane):Lng.
      local angle is Mod(lng2-Longitude+360, 360).
      set launchTime to Time:Seconds +(angle/360)*Body:RotationPeriod.
      //print "  lng1 =" +Round(Longitude,2).
      //print "  lng2 =" +Round(lng2,2).
      //print "  waitAngle=" +Round(angle,2).
      //print "  lat=" +Round(Latitude,2) +", inc="+Round(tgtInc,2).
      //debugVec(1, "tgtPlane", 1e6*tgtPlane, Body:Position).
      //wait 1000.

      if (tgtInc > Abs(Latitude))
      {
        // launch when crossing target plane
        local angleDiff is arcCos(Abs(Latitude)/tgtInc).
        //print "  angleDiff="+Round(angleDiff,2).
        local dt is Body:RotationPeriod *angleDiff/360.
        //print "  dt="+Round(dt,2).
        if (launchTime-dt > Time:Seconds)
          set launchTime to launchTime-dt.
        else
          set launchTime to launchTime+dt.
      }

      print "  Try to match phase of target".
      // simple version to avoid large transfer times
      local synPeriod is 1/ (1/Target:Obt:Period - 1/Body:RotationPeriod).
      local lngCorr is 360* (launchTime-Time:Seconds)/synPeriod.
      local lngErr is Mod(Target:Longitude -Longitude +lngCorr +360 +180,360)-180. // norm to +-180
      if (Defined gLaunchAngle) set lngErr to lngErr+gLaunchAngle.
      local dt is -synPeriod *lngErr/360.
      if (launchTime+dt < Time:Seconds) { set dt to dt+synPeriod. }
      set launchTime to launchTime+dt.
      //print "   lngErr="+lngErr.
      //print "   synPeriod="+synPeriod.
      //print "   lngCorr="+lngCorr.
      //print "   dt="+dt.
    }
    else
    {
      print "  Try to match phase of target".
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
      set launchTime to launchTimeToRdv( launchPA+transferPA -0). // some error margin
    }

    print "Warping to Launch (dt="+Round(launchTime - Time:Seconds) +")".
    warpRails(launchTime, false).
}

function m_waitForTransition {
    parameter type.

    if missionStep() {
        print "Wait for transition".
        if (Obt:Transition <> type) {
            print "  WARNING: next transition != "+type+" !".
            print "           type="+Obt:Transition.
            askConfirmation().
            return.
        }
        local b is Body.
        warpRails(Time:Seconds+Eta:Transition).
        wait until Body <> b.
    }
}

function m_ascentLKO {
    parameter tgtPlane is V(0,1,0).

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
              atmoAscentPlane(tgtPlane).
            else
              atmoAscentRocket(tgtPlane).

            if (Obt:Inclination > 0.01)
              print "  Inclination=" +Round(Obt:Inclination, 3).
        }
    }

    if missionStep() {
        print "Circularize".
        if (Periapsis > Body:Atm:Height) {
            print "  Skipping :already in orbit".
        } else {
            if (HasTarget) set tgtPlane to getOrbitNormal(Target).
            //print "  relativeInc=" +Round(Vang(getOrbitNormal(Ship), tgtPlane ),2).
            if not nextNodeExists() {
                nodeCircAtAP().
                if (tgtPlane <> V(0,0,0)) {
                  tweakNodeInclination(tgtPlane).
                }
            }
            execNode().

            if (Obt:Inclination > 0.01)
              print "  Inclination=" +Round(Obt:Inclination, 3).

            //if launchTime<>0 print "  time  to LKO =" +(Time:Seconds-launchTime).
            //if launchTime<>0 print "  angle to LKO =" +(Longitude-launchAngle).
        }
    }

    if missionStep() {
        if (Apoapsis/Periapsis > 1.05) {
            print "Circle correction".
            if not nextNodeExists() {
                nodeCircularize(Time:Seconds+20).
            }
            execNode().
        }
    }
}

function m_landFromLKO {
    parameter waitForInc is true.

    if missionStep() {
        print "Deorbit".
        RunOncePath("0:/libatmo").
        atmoDeorbit(waitForInc).
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

    if missionStep() {
        print msg.
        askConfirmation().
    }
}

function m_fillTanks {
    parameter includeLFO is true.
    if missionStep() {
        print "Fill Tanks".
        if (gShipType=Ship:Name) { print "  No host vessel found". return. }
        local tanklist is Ship:PartsTagged(gShipType+"Tank"). // my tanks
        local hostList is Ship:PartsTagged(Ship:Name+"Tank"). // host tanks
        if (tankList:Length=0) { print "  Ship has no tagged tanks". return. }
        if (hostList:Length=0) { print "  Host has no tagged tanks". return. }
        local transfers is List().

        function tryTransfer {
          parameter res.
          parameter fill is true.

          local tList2 is List().
          local hList2 is List().
          for p in tankList { for r in p:Resources { if r:Name=res tList2:Add(p). } }
          for p in hostList { for r in p:Resources { if r:Name=res hList2:Add(p). } }
          if (tList2:Length>0 and hList2:Length>0) {
            print "  Tanks found: "+res +" (" +hList2:Length +"/"+tList2:Length +")".
            if (fill)
              transfers:Add( TransferAll(res, hList2, tList2) ).
            else
              transfers:Add( TransferAll(res, tList2, hList2) ).
          } else print "  No tanks found: "+res +" (" +hList2:Length +"/"+tList2:Length +")".
        }

        tryTransfer("MonoPropellant").  // fill
        tryTransfer("Supplies").        // fill
        tryTransfer("Mulch", false).    // empty
        if includeLFO {
          tryTransfer("LiquidFuel").
          tryTransfer("Oxidiser").
        }
        for t in transfers { set t:Active to True. }
        for t in transfers { wait until t:Active=false. }
        for t in transfers { print "  Transferred " +Round(t:Transferred,2) +" "+t:Resource +" ("+t:Status+")". }
    }
}

function m_undock {
    if missionStep() {
        if (not hasPort()) return.
        print "Undock".
        gMyPort:ControlFrom.
        wait 0.
        if gMyPort:State:Contains("Docked") {
          gMyPort:Undock().
        } else if gMyPort:State="PreAttached" {
          print "  PortState=PreAttached".
          //print "  Please decouple the ship manually".
          askConfirmation(). // not waiting here causes NAN Orbits
          gMyPort:GetModule("ModuleDockingNode"):DoEvent("Decouple Node").
          wait until gMyPort:State<>"PreAttached".
          KUniverse:ForceSetActiveVessel(Ship).
        } else {
          Ship:PartsDubbed(gShipType+"Control")[0]:ControlFrom.
          print "  Port was not docked (" +gMyPort:State +")".
          return.
        }
        wait 0.
        gMyPort:ControlFrom.
        Core:DoEvent("open terminal").
        wait 0.

        //debugDirection(Facing).
        local mp is Ship:MonoPropellant.
        local rcsDvSoll is getRcsDeltaV()-0.5.
        RCS on.
        set Ship:Control:Fore to -1.
        wait until getRcsDeltaV()<rcsDvSoll.
        set Ship:Control:Fore to 0.
        RCS off.
        print "  burned "+Round(mp -Ship:MonoPropellant, 2) +" mp".
        print "  waiting for safe distance".
        set WarpMode to "RAILS".
        set Warp to 2.
        wait 2.5*gShipRadius.
        set Warp to 0.
        wait until Ship:Unpacked.
        Ship:PartsDubbed(gShipType+"Control")[0]:ControlFrom.
        checkBalance().
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

function m_grabWithClaw {
    parameter dir is V(0,0,-1).
    if missionStep() {
        print "Grab with Claw".
        RunOncePath("0:/librdv").
        grabWithClaw(dir).
    }
}

function m_hohmannToTarget {
    parameter incBudget is -1.
    if missionStep() {
        print "Hohmann Transfer".
        if not nextNodeExists() nodeHohmann(incBudget).
        execNode().
    }
}

function m_fastTransferToTarget {
    if missionStep() {
        print "Fast Transfer".
        if not nextNodeExists() nodeFastTransfer().
        execNode().
    }
}

function m_fineRdv {
    if missionStep() {
        print "Fine tuning approach".
        if not nextNodeExists() nodeFineRdv().
        execNode().
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
    parameter tgt is 0. // GeoCoordinates
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
    m_matchPlane().
}

function m_matchPlane {
  if missionStep() {
      print "Match plane of Target".
      if not nextNodeExists() {
        if HasTarget
          nodeIncChange(getOrbitNormal(Target)).
        else
          nodeIncChange(V(0,1,0)).
      }
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
        tweakNodeInclination( V(0,1,0) ).
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
    // todo: find back into plane
    //if missionStep() {
    //  print "  find back into plane".
    //  local plane is V(0,0,1).
    //  if HasTarget set plane to getOrbitNormal(Target).
    //}

    // todo: correct inclination

    if missionStep() {
        print "  tune PE".
        //toDo: make sure PE is above atmo / touching target orbit
        if not nextNodeExists() nodeTweakPE().
        execNode().

    }
    //toDo: aerobrake if vessel can do it
    if missionStep() {
        print "Return from high orbit".
        // rdv with target
        if HasTarget and (not nextNodeExists()) { nodeFastTransfer2(Time:Seconds+Eta:Periapsis). }
        //askConfirmation().
        execNode().
    }
}

// == Mission Infrastructure ==
function prepareMission {
    parameter name.

    if Exists("1:/mission.ks") DeletePath("1:/mission.ks").
    local missionName is "m_"+name+".ks".
    CopyPath("0:/missions/"+missionName, "1:/mission.ks").
    set pMissionCounter to 1.
    log "set pMissionCounter to 1." to "1:/persistent.ks".
}

function resumeMission {
    set gMissionCounter to 0.

    RunPath("1:/mission.ks").
    print "Mission finished!".
    log "set pMissionCounter to 0." to "1:/persistent.ks".
    shutDownCore().
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
