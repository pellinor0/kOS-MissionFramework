@lazyglobal off.
//print "  Loading libsystem".

function loadPersistent {
    log "" to "1:/persistent.ks".
    RunPath("1:/persistent.ks").
}

function writePersistent {
    log "" to "1:/persistent.ks".
    DeletePath("1:/persistent.ks").
    log "set pMissionCounter to " +pMissionCounter +"." to "1:/persistent.ks".
}

function setControlPart {
  local pList is Ship:PartsDubbed(gShipType+"Control").
  if (pList:Length=1)
    pList[0]:ControlFrom.
  else
  {
    print "ERROR: no unique control part found: num="+pList:Length.
    interruptMission().
  }
}
