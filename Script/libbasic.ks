@lazyglobal off.
//print "  Loading libbasic".

function warpRails {
    parameter tPar.
    print "  warpRails: dt=" +Round(tPar- Time:Seconds, 1).
    
    function countDown {return tPar - Time:Seconds.}
    if (countDown()<0) {
        print "   warpRails return".
        return.
    }
//     local ec is Ship:ElectricCharge.
//     if (countDown > 2*ec) {
//         print "  WARNING: low EC".
//         print "    countdown=" +Round(countdown,2).
//         print "    ec=" +Round(ec,2).
//     }
    
    set Warp to 0.
    wait 0.01.
    set WarpMode to "RAILS".
    if (countdown() >  5) {set Warp to 1. wait 0.1.}
    if (countdown() > 25) {set Warp to 2. wait 0.1.}
    if (countdown() > 50) {set Warp to 3. wait 0.1.}
    
    if (countdown() > 5000) {
        set Warp to 6.          // 10k
        until Warp=6 or countdown() < 5000 {
            wait 0.01.
            set Warp to 6.
        }
        wait until countdown() < 5000.
    }
    if (countdown() > 500) {
        set Warp to 5.          // 1000x
        until Warp=5 or countdown() < 500 {
            wait 0.01.
            set Warp to 5.
        }
        wait until countdown() < 500.
    }
    if (countdown() > 50) {
        set Warp to 4.          // 100x
        until Warp=4 or countdown() < 50 {
            wait 0.01.
            set Warp to 4.
        }
        wait until countdown() < 50.
    }
    if (countdown() > 25) {
        set Warp to 3.          // 50x
        until Warp=3 or countdown() < 25 {
            wait 0.01.
            set Warp to 3.
        }
        wait until countdown() < 25.
    }
    if (countdown() > 5) {
        set Warp to 2.          // 10x
        until Warp=2 or countdown() < 5 {
            wait 0.01.
            set Warp to 2.
        }
        wait until countdown() < 5.
    }
    if (countdown() > 0.5) {
        set Warp to 1.          //  5x
        until Warp=1 or countdown() < 0.5 {
            wait 0.01.
            set Warp to 1.
        }
        wait until countdown() < 0.5.
    }
    
    //local tmp is Time:Seconds.
    set Warp to 0.
    wait until not Ship:Unpacked.
    //set tmp to Time:Seconds-tmp.
    //if (tmp>0) print "  unpacking time= "+Round(tmp,3).
    
    if (countDown() < 0)
      print "  WARNING: warpRails: countdown="+countdown().
    
    print "   warpRails end".
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
        wait 0.01.
        set av to -Facing*Ship:AngularVel.
        if(Ship:Control:Roll *av:Z < 0) set dZ to dZ/2.
        if(Ship:Control:Pitch*av:X < 0) set dX to dX/2.
        if(Ship:Control:Yaw  *av:Y > 0) set dY to dY/2.
        
        set Ship:Control:Roll  to  av:Z*dZ.
        set Ship:Control:Pitch to  av:X*dX.
        set Ship:Control:Yaw   to -av:Y*dY.
//         print "av  ="+Round(av:Mag,3) at (38,0).
//         print "rol ="+Round(Ship:Control:Roll,  3) at (38,1).
//         print "pit ="+Round(Ship:Control:Pitch, 3) at (38,2).
//         print "yaw ="+Round(Ship:Control:Yaw,   3) at (38,3).
//         print "dx  ="+Round(dx,2)+" " at (38,4).
//         print "dy  ="+Round(dy,2)+" " at (38,5).
//         print "dz  ="+Round(dz,2)+" " at (38,6).
//         print "avx  ="+Round(av:X,2)+" " at (38,7).
//         print "avy  ="+Round(av:Y,2)+" " at (38,8).
//         print "avz  ="+Round(av:Z,2)+" " at (38,9).
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
      wait 0.01.
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
//     print " getDeltaV".
//     print "  isp="+Round(isp,1).
//     print "  fuel="+Round(fuel,2).
//     print "  lf="+Round(Ship:LiquidFuel).
//     print "  ox="+Round(Ship:Oxidizer).
    return isp * ln(Ship:Mass / (Ship:Mass-fuel))*9.81.
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

function clearScreen2 {
    from {local x is 0.} until x = 10 step {set x to x+1.} DO {
        print "                      " at (38,x).
    }
}
