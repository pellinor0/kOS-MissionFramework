@lazyglobal off.
print "  Loading libdebug".



//until (not hasnode) remove nextnode.
//if HasNode remove NextNode.
//print "== refresh mission file ==". CopyPath("0:missions/m_ast.ks", "1:mission.ks").
//log "set pMissionCounter to pMissionCounter+1." to "1:/persistent.ks".
//log "set pMissionCounter to 5." to "1:/persistent.ks".
//wait 1000.

// prints the available KSPActions and KSPEvents of a part
// example: moduleInfo(Ship:PartsDubbed("r2Fairing")[0]).
function moduleInfo {
  parameter p. // part

  for n in p:Modules {
    local m is p:geTModule(n).
    if m:AllEvents:Length>0  print "  "+n+" Events: " +m:AllEvents.
    if m:AllActions:Length>0 print "  "+n+" Actions: " +m:AllActions.
  }
}

//When (1) Then {
//  log "t="+Throttle to "0:/log.txt".
//  preserve.
//}
