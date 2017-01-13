@lazyglobal off.
//print "  Loading libbasic".

Function askConfirmation {
  parameter deadline is Time:Seconds+1e9.
  set AG1 to false.
  print "  == press AG1 to continue ==".
  until (AG1 or (Time:Seconds>deadline)) {
    print "dt =" +Round(deadline-Time:Seconds)+"  " at (38,1).
    //print "AG1=" +AG1+"  " at (38,1).
    wait 0.
  }
}

function warpRails {
    parameter tPar.
    function countDown {return tPar - Time:Seconds.}
    if (countDown() > 4*3600) {
      if countDown()< 6*3600
        print "  warpRails: dt=" +Round(countDown()/3600,2) +" h".
      else
        print "  warpRails: dt=" +Round(countDown()/(6*3600),2) +" day(s)".
      //print "  warpRails: dt=" +Round(tPar- Time:Seconds, 1).
      askConfirmation(tPar).
    }

    if (countDown()<0) { return. }

    set Warp to 0.
    wait 0.
    set WarpMode to "RAILS".

    if (countdown() >  5) {set Warp to 1. wait 0.1.}
    if (countdown() > 25) {set Warp to 2. wait 0.1.}
    if (countdown() > 50) {set Warp to 3. wait 0.1.}

    function warpLevel {
        parameter level.
        parameter deadline.
        if (countdown() > deadline) {
            set Warp to level.          // 10k
            until Warp=level or countdown() < deadline {
                wait 0.
                set Warp to level.
            }
            wait until countdown() < deadline.
        }
    }

    warpLevel(6, 5000).
    warpLevel(5,  500).
    warpLevel(4,   50).
    warpLevel(3,   25).
    warpLevel(2,    5).
    warpLevel(1,  0.5).

    //local tmp is Time:Seconds.
    set Warp to 0.
    wait until not Ship:Unpacked.
    //set tmp to Time:Seconds-tmp.
    //if (tmp>0) print "  unpacking time= "+Round(tmp,3).

    if (countDown() < 0) print "  WARNING: warpRails: countdown="+countdown().
    //print "   warpRails end".
}

function setTarget {
  parameter tgt is Ship.
  if (tgt <> Ship) {
    local count is 0.
    until HasTarget {
      if (count=1) print "WARNING: setTarget only works when KSP is focused!".
      set Target to tgt.
      wait 0.
      set count to count+1.
    }
  }
}

function normalizeAngle {
    parameter angle.

    until angle > 0 { set angle to angle+360. }
    return Mod( angle+180 , 360) -180.
}

function targetBaseName {
    local tmp is Target:Name:Split(" ").
    return tmp[0].
}

function killRot {
    parameter accuracy is 0.01.
    print " killRot".

    local av is Ship:AngularVel.
    local dx is 64.// damping (workaround for missing torque info)
    local dy is 64.
    local dz is 64.

    until av:Mag<accuracy {
        wait 0.
        set av to -Facing*Ship:AngularVel.
        if(Ship:Control:Roll *av:Z < 0) set dZ to dZ/2.
        if(Ship:Control:Pitch*av:X < 0) set dX to dX/2.
        if(Ship:Control:Yaw  *av:Y > 0) set dY to dY/2.
        set Ship:Control:Roll  to  av:Z*dZ.
        set Ship:Control:Pitch to  av:X*dX.
        set Ship:Control:Yaw   to -av:Y*dY.
    }
    set Ship:Control:Roll  to 0.
    set Ship:Control:Pitch to 0.
    set Ship:Control:Yaw   to 0.
    //print "  vRest="+Round(Ship:AngularVel:Mag, 4).
}

function killRotByWarp {
    print " killRotByWarp".
    set Warp to 0.
    set WarpMode to "RAILS".
    until Warp=1 {
      set WarpMode to "RAILS".
      set Warp to 1.
      wait 0.
    }
    wait 0.1.
    set Warp to 0.
    //print "  wait until Ship:Unpacked".
    wait until Ship:Unpacked.
}

function vecToString {
    parameter v.
    return "("+Round(V:X, 3) +", " +Round(V:Y, 3) +", "+Round(V:Z, 3) +") m="+Round(v:Mag,2).
}

function getDeltaV {
    // assumptions: only one ISP present
    list engines in tmp.
    local isp is tmp[0]:VacuumIsp.
    local fuel is (Ship:LiquidFuel + Ship:Oxidizer)*0.005.
    local m is Ship:Mass.
    return isp * ln(m/(m-fuel))*9.81.
}
function getRcsDeltaV {
    local fuel is Ship:MonoPropellant*0.004.
    local isp is 240.
    local m is Ship:Mass.
    //print "  getRcsDv: "+Round(isp * ln(m/(m-fuel))*9.81, 2).
    return isp * ln(m/(m-fuel))*9.81.
}
function hasRCS {
    return Ship:PartsDubbed(gShipType+"RCS"):Length>0.
}
function hasRcsDeltaV {
    parameter req is 5.
    return (hasRcs() and getRcsDeltaV()>req).
}
function hasPort {
    local tmp is Ship:PartsDubbed(gShipType+"Port").
    if tmp:Length > 0 {
        set gMyPort to tmp[0].
        return true.
    }
    return false.
}
function isDockable {
    return hasPort() and (hasRcsDeltaV(2)).
}

global xAxis is VecDraw( V(0,0,0), V(1,0,0), RGB(1.0,0.5,0.5), "X axis", 1, false ).
global yAxis is VecDraw( V(0,0,0), V(0,1,0), RGB(0.5,1.0,0.5), "Y axis", 1, false ).
global zAxis is VecDraw( V(0,0,0), V(0,0,1), RGB(0.5,0.5,1.0), "Z axis", 1, false ).
function debugDirection {
    parameter dir.

    set xAxis to VecDraw( V(0,0,0), 12*dir:ForeVector, RGB(1.0,0.5,0.5), "Fore", 1, true ).
    set yAxis to VecDraw( V(0,0,0), 12*dir:TopVector,  RGB(0.5,1.0,0.5), "Top",  1, true ).
    set zAxis to VecDraw( V(0,0,0), 12*dir:StarVector, RGB(0.5,0.5,1.0), "Star", 1, true ).
}
function debugDirectionOff {
    set xAxis to VecDraw( V(0,0,0), V(1,0,0), RGB(1.0,0.5,0.5), "X axis", 1, false ).
    set yAxis to VecDraw( V(0,0,0), V(0,1,0), RGB(0.5,1.0,0.5), "Y axis", 1, false ).
    set zAxis to VecDraw( V(0,0,0), V(0,0,1), RGB(0.5,0.5,1.0), "Z axis", 1, false ).
}

global debugVec1 is VecDraw( V(0,0,0), V(0,1,0), RGB(1.0,0.5,0.5), "v1", 1, false ).
global debugVec2 is VecDraw( V(0,0,0), V(0,1,0), RGB(0.5,1.0,0.5), "v2", 1, false ).
global debugVec3 is VecDraw( V(0,0,0), V(0,1,0), RGB(0.5,0.5,1.0), "v3", 1, false ).
global debugVec4 is VecDraw( V(0,0,0), V(0,1,0), RGB(0.5,0.5,1.0), "v4", 1, false ).
global debugVec5 is VecDraw( V(0,0,0), V(0,1,0), RGB(0.5,0.5,1.0), "v5", 1, false ).
function debugVec {
  parameter n.
  parameter str.
  parameter vec.
  parameter vBase is V(0,0,0).

  if (n=1)
    set debugVec1 to VecDraw( vBase, vec, RGB(1,0,0), str, 1, true ).
  else if (n=2)
    set debugVec2 to VecDraw( vBase, vec, RGB(0,1,0), str, 1, true ).
  else if (n=3)
    set debugVec3 to VecDraw( vBase, vec, RGB(0,1,1), str, 1, true ).
  else if (n=4)
    set debugVec4 to VecDraw( vBase, vec, RGB(1.0,0.5,0.5), str, 1, true ).
  else if (n=5)
    set debugVec5 to VecDraw( vBase, vec, RGB(0.5,1.0,0.5), str, 1, true ).
}


function clearScreen2 {
    from {local x is 0.} until x = 10 step {set x to x+1.} DO {
        print "                 " at (38,x).
    }
}
