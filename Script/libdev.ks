@lazyglobal off.
print "  Loading libdev".
if (Ship:ElectricCharge<1) { Core:Deactivate. }
switch to 0.

// ====  AutoStart =======
// debug hook: this code is called before the other libraries are loaded

//print "  compiling libbasic".   compile libbasic.
//print "  compiling libatmo".    compile libatmo.
//print "  compiling liborbit".   compile liborbit.
//print "  compiling libnav".     compile libnav.
//print "  compiling libmission". compile libmission.
//print "  compiling librdv".     compile librdv.
//print "  compiling libsystem".  compile libsystem.
//print "  compiling libsetup".   compile libsetup.
//print "  compiling globals".    compile globals.
//print "  compiling boot".       compile "boot/boot.ks".
//print "  copying bootFile".     CopyPath("0:/boot/boot.ksm","1:/boot/").
// =======================

//print "  copying mission file".   CopyPath("0:/missions/m_ip.ks","1:/mission.ks").
//print "  copying param file".     CopyPath("0:/params/params_t2.ks","1:/params.ks").
//until (not hasnode) {remove nextnode. wait 0.}

//wait 5.
//run libdebug.
//moduleInfo(Ship:PartsDubbed("bp4Tank")[0]).

function hopLaunch {
  parameter tgt. // GeoCoordinates

  local slope is tan(50).
  local tgtDir is Vxcl(Up:Vector,tgt:Position):Normalized.
  lock Steering to LookdirUp(tgtDir+slope*Up:Vector, Up:Vector).
  lock Throttle to 1.
  local lock pos to PositionAt(Ship,Time:Seconds+Eta:Apoapsis*2).
  wait 1.
  //print "ang =" +Round(Vang(pos-tgt:Position, tgt:Position), 2)+"    " at (38,3).
  print "  dist="+Round(tgt:Position:Mag).
  debugVec(1, "tgt", tgt:Position:Normalized, Up:Vector*2).
  debugVec(2, "diff", (pos-tgt:Position):Normalized, Up:Vector*2).
  until (Vang(tgt:Position-pos, tgt:Position)>90) {
    debugVec(1, "tgt", tgt:Position:Normalized, Up:Vector*2).
    debugVec(2, "diff", (pos-tgt:Position):Normalized, Up:Vector*2).

    print "ang =" +Round(Vang(pos-tgt:Position, tgt:Position), 2)+"    " at (38,3).
    wait 0.
  }.
  lock Steering to LookdirUp(Up:Vector, Facing:UpVector).
  unlock Throttle.
  unlock Steering.
  //warpRails(Time:Seconds+Eta:Apoapsis).

}
function landSomewhere {

}

function hop {
    parameter tgt. // is 0. // GeoCoordinates (else use Target)
    //if (Status = "LANDED" or Status="SPLASHED") return.
    if (not tgt:HasSuffix("LAT")) set tgt to Body:GeoPositionOf(Target:Position -Target:North:StarVector*(gShipRadius+10)).

    local tgtHeight is Max(0.01, tgt:TerrainHeight)+10. // +10: keep a bit of clearing
    local acc is Ship:AvailableThrust / Mass.
    local g is Body:Mu/(Body:Radius * (Body:Radius +0.1)). // +0.1 = workaround to overflow

    print " hop".
    print "  tgtHeight="+Round(tgtHeight, 1).
    //print "  tgt=LatLng("+Round(tgt:Lat,3) +", "+Round(tgt:Lng,3)+")".
    print "  g=" +Round(g,2) +", acc=" +Round(acc,2) +", TWR="+Round(acc/g,2).
    //local accFactor is 1.
    //if (acc > 2.5*g) {  // limit TWR for stability
    //    set accFactor to 2.5*g/acc.
    //    set acc to acc*accFactor.
    //}

    // constants
    local plannedDecel is 0.8*(g).
    local v0 is 1. // touchdown speed

    // loop variables
    local height is 1e6.
    //local brakeAcc is 0.
    //local corrAcc is 0.
    local vSoll is 0.
    local vErr is 0.
    local v is 0.
    //local corr is V(0,0,0).
    local tt is 0. // scales in m/s^2
    local steerVec is Up:Vector.
    lock Steering to Lookdirup(steerVec, Facing:UpVector).
    lock Throttle to (tt/acc).
    local corr is V(0,0,0).

    local function updateVsoll {
      local dx is Vxcl(Up:Vector,tgt:Position).
      local vSB is -Up:Vector*(Sqrt(2*Max(height,0)*plannedDecel^2)+v0).  // suicide burn
      local vCorr is Vxcl(Up:Vector,tgt:Position):Mag*(0.5*g)^2*(Up:Vector+dx:Normalized) . // displacement: 45° up
      if (vCorr:Mag>20) set vCorr to vCorr*(20/vCorr:Mag). // explodes for large distances => orbital perspective would be better
      set vSoll to vSB+vCorr.
      print "h   =" +Round(height, 2)+"    " at (38,0).
      print "dx  =" +Round(dx:Mag, 2)+"    " at (38,1).
      print "vSB =" +Round(vSB:Mag, 2)+"    " at (38,2).
      print "vCor=" +Round(vCorr:Mag, 2)+"    " at (38,3).
    }
    local function updateCorr {
      local f is Facing.
      set vErr to v-vSoll.

if false { // new version
      local frame is LookdirUp(Up:Vector, North:Vector).
      local tmp is -frame*(-vErr).
      set corr to V(0,tmp:X,tmp:Y) *0.3.
      //set corr:Y to tmp:Y *0.3. // lateral: 30%/s
      //set corr:Z to tmp:Z *0.3.
      local corrVert is Max(tmp:X*2,0). // no thrusting down
      local corrMax is Min(height/100, 1)*corrVert.
      if (corr:Mag > corrMax) set corr to corr:Normalized*corrMax.
      set corr:X to tmp:X *2. // vertical: 0.5s
      set steerVec to Up:Vector*g + frame*corr.
      set steerVec to steerVec:Normalized*Vdot(steerVec,Facing:ForeVector).
} else { // old version
      set corr to -vErr:Normalized*(Min(vErr:Mag, 0.5*g)).
      set steerVec to Up:Vector*g + corr.
}
      print "vErr="+Round(vErr:Mag, 2)+"    " at (38,5).
      print "corr="+Round(corr:Mag, 2)+"    " at (38,6).
      print "st="  +Round(steerVec:Mag, 2)+"    " at (38,7).
      debugVec(1, "vErr", vErr, Ship:Position+10*Up:Vector+vSoll).
      //debugVec(2, "corr", corr/g, Ship:Position+10*Up:Vector).
      //debugVec(3, "steer", steerVec/g, Ship:Position+11*Up:Vector).
      debugVec(3, "v", v, Ship:Position+10*Up:Vector).
      debugVec(4, "vSoll", vSoll, Ship:Position+10*Up:Vector).
      debugVec(5, "tgt", Up:Vector*50, tgt:Position).
    }
    local function updateThrottle {
      set tt to steerVec:Mag.
      print "a/g =" +Round(tt, 3)+"    " at (38,8).
    }

    local function update {
        wait 0.
        set v to Velocity:Surface.
        set height to Altitude - tgtHeight.

        updateVSoll().
        updateCorr().
        updateThrottle().
        //debugVec(2, "vSoll", vSoll, Ship:Position+10*Up:Vector).
        //debugVec(3, "vErr", vErr, Ship:Position+10*Up:Vector+vSoll-2*vErr).
        //debugDirection(Steering).
    }

    set steerVec to Up:Vector.
    set tt to 2.
    set WARP to 0.
    wait until (Abs(VerticalSpeed)>2). //print "  vz="+Round(VerticalSpeed,2).
    until (Apoapsis > Max(GeoPosition:TerrainHeight+50, tgtHeight)) {
      print "AP  ="+Round(Apoapsis, 2)+"    " at (38,0).
      print "terr="+Round(GeoPosition:TerrainHeight, 2)+"    " at (38,1).
    }

    until Status = "LANDED" or Status = "SPLASHED" { update(). }
    unlock Throttle.
    lock Steering to stUp().
    print "  posError=" +Round(Vxcl(Up:Vector,tgt:Position):Mag,2).
    wait until (Ship:AngularVel:Mag<0.1).
    wait 2.
    wait until (Ship:AngularVel:Mag<0.1).
    debugVecOff().debugDirectionOff().
    wait 1000.
}
