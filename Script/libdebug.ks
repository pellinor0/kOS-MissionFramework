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
    if m:AllFields:Length>0  print "  "+n+" Fields: " +m:AllFields.
  }
}

//When (1) Then {
//  log "t="+Throttle to "0:/log.txt".
//  preserve.
//}

local function vTgtHover {
  // target speed in hover mode

  local dH is Altitude-tgtHeight.
  local dX is Vxcl(Up:Vector, tgtPos - Ship:Position).

  // horizontal: move to Target, TWR=0.3 brake
  // vertical: TWR=1.9 suicide burn (slower if far from target)
  local vx is -Sqrt(dx:Mag *0.3 *g ) * dX:Normalized.
  local vy is -Up:Vector * (Sqrt(2*dH * 0.9*g) * (dH/dX:Mag)).
  return vx+vy.
}
local function vTgtFinal {
  // target speed in final landing
  local dh is Altitude-tgtHeight.
  local dx is Vxcl(Up:Vector, tgtPos - Ship:Position).

  // horizontal: converge exponentially
  // vertical: descend at 1m/s
  local vx is -dx*0.3.
  local vy is -Up:Vector.
  return vx+vy.
}
local function vTgtDeorbit {
  local tImpact is timeToAltitude2(tgtHeight, Time:Seconds, Time:Seconds+Eta:Periapsis, 0.2).
  local sinP is Sin( Max(0, 90-Vang(-Velocity:Surface, Up:Vector)) ).
  local effDecel is 0.5*(-2*g*sinP +Sqrt( (2*g*sinP)^2 +4*(acc*acc*0.9 -g*g))). //"*0.9"= keep small acc reserve
  local decelTime is Velocity:Surface:Mag/effDecel.
  //set sbc to tImpact-Time:Seconds -decelTime/2.
  //set tt to 1/Max(sbc/2,1).

  local vTgt is Velocity:Surface:Normalized * (tImpact-Time:Seconds -decelTime/2)*effDecel.
  //print "SBC =" +Round(sbc,      2) +"  " at (38, 0).
  //print "vTgt=" +Round(vTgt:Mag,2) at (38,0).

  //set SteerVec to
  return vTgt.
}
local vTgtFunc is vTgtDeorbit@.
