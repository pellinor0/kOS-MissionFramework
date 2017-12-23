
//local controlPart is Ship:PartsDubbed(gShipType+"Control")[0].
//set gGearHeight to Round(Vdot(controlPart:Position, Up:Vector)+Altitude
//                              -GeoPosition:TerrainHeight, 2).
//print "gearheight="+gGearHeight.

//set gGearHeight to Altitude-GeoPosition:TerrainHeight.
//print "  gearHeight="+gGearHeight.

global startPos is GeoPosition.
global startAlt is Altitude.
//print "  gearHeight="+gGearHeight.
//print "  startPos="+startPos.
print "  startAlt="+startAlt.
global logFile is "0:/logs/gtLog.ks".
log "" to logFile.
DeletePath(logFile).

global params is Lexicon().

function initLog {
  global lastLog is 0.
  global gd is List().
  global gh is List().
  global gvx is List().
  global gvy is List().

  set gDoLog to 1.
  set gLogDeltaTime to 2.

  print "  Log start".
  when (1) then {
      if (gDoLog) {
        if (Time:Seconds - lastLog > gLogDeltaTime) {
          // Logging
          set lastLog to Time:Seconds.
          //eLog:Add( Altitude*9.81 +0.5*Airspeed*Airspeed ).
          //lLog:Add( Longitude ).
          gd:add( Round( (Ship:Position-startPos:Position):Mag ,2)).
          gh:add( Round( Altitude-startAlt ,2)).
          gvx:add( Round( Vxcl(Up:Vector, Velocity:Surface):Mag ,2)).
          gvy:add( Round( Vdot(Up:Vector, Velocity:Surface)     ,2)).
        }
        preserve.
      } else {
        print "  Logging finished! " +gd:Length +" entries.".
        print "  Status="+Status.
        print "  Altitude="+Altitude.
        //writeLog().
        params:Add( "d", gd).
        params:Add( "h", gh).
        params:Add( "vx", gvx).
        params:Add( "vy", gvy).
        WriteJson(params, "0:/logs/land"+Body:Name+".json").
      }
  }
}


// do gravity turn and collect data
function gravTurn {
    print " gravTurn".

    // normalize TWR to 2.0
    local g is Body:Mu/(Body:Radius * (Body:Radius +0.1)). // +0.1 = workaround to overflow
    lock acc to Ship:AvailableThrust / Mass.
    lock tt to 2*g/acc.
    print "   tt="+tt.
    local pp is 90.
    lock Steering to Heading(90,pp).
    wait 1.
    print "   angle from up: " +Vang(Up:Vector, Facing:ForeVector).

    print "  initial ascent".
    //when (1) then {debugDirection(Steering). preserve.}
    set Warpmode to "PHYSICS".
    set Warp to 1.
    lock Throttle to tt.
    until (Altitude > startAlt+5) { wait 0. }
    initLog().

    print "  small nudge".
    set pp to 80.
    wait 2.

    print "  follow prograde".
    lock Steering to LookdirUp(Velocity:Surface, Facing:TopVector).

    global bounce is 0.
    when ( Ship:VerticalSpeed<-1 ) then { when ( Ship:VerticalSpeed>0 ) then {set bounce to 1.} }

    lock abortCondition to (bounce=1 or Apoapsis>20000).
    until (abortCondition) { wait 0. }
    if (Apoapsis>20000) {
      local PA is Vang(startPos:Position-Body:Position, PositionAt(Ship, Time:Seconds+Eta:Apoapsis)-Body:Position).
      print "  PE="+Round(Periapsis).
      print "  PA="+Round(PA,2).
      params:Add( "PE", Round(Periapsis)).
      params:Add( "PA", Round(PA,2)).
    } else {
      print " abort".
    }
    set gDoLog to 0.
    unlock Throttle.
}

gravTurn().
wait 1000.
