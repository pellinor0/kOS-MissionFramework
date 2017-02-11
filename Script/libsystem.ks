@lazyglobal off.
//print "  Loading libsystem".

function loadPersistent {
    if Exists("1:/persistent.ks") RunPath("1:/persistent.ks").
}

function writePersistent {
    if Exists("1:/persistent.ks") DeletePath("1:/persistent.ks").
    log "set pMissionCounter to " +pMissionCounter +"." to "1:/persistent.ks".
}

function shutDownCore {
  Core:DoAction("Close Terminal", true).
  Core:Deactivate.
}

function askConfirmation {
  parameter deadline is Time:Seconds+1e9.
  set AG1 to false.
  print "  == press AG1 to continue ==".
  until (AG1 or (Time:Seconds>deadline)) {
    print "dt =" +Round(deadline-Time:Seconds)+"  " at (38,1).
    //print "AG1=" +AG1+"  " at (38,1).
    wait 0.
  }
}

function setControlPart {
  parameter tag is "Control".
  local pList is Ship:PartsDubbed(gShipType+tag).
  if (pList:Length=1)
    pList[0]:ControlFrom.
  else
  {
    print "no unique control part found: num="+pList:Length.
    print "please activate control part manually".
    askConfirmation().
  }
}
