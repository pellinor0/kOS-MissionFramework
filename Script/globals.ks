// Persistent Data
global pMissionCounter is 0.
global gMissionCounter is 0.
global gMissionStartManual is 0.

// == global Parameters ==
// (Defaults can be overridden in the ship's params.ks)
global tgtVesselName is "KSS".
global gLkoAP is 80000.


global spacePort is LatLng(-0.04909, -74.697). // KSC runway 09
global spacePortHeight is 69.

// == Vessel-specific parameters ==
// these are set manually
global deorbitPe is 22000.
global gIsPlane is 0.
global gBuiltinAoA is 3. // only use for planes
global gShipRadius is 5.
global gAeroBrakeDir is V(0,0,1). // prograde(?)
global gLaunchParam is 0.22. // for planes
// these are set automatically
global gShipType is "". // from Core nameTag
global dockable is 0.  // looks for parts named "shuttlePort"
global myPort is 0.
// these are measured by the calibrate mission
global gLaunchDuration is 0.
global gLaunchAngle is 0.
global landingPA is 0.
global launchPA is 0.
global gGearHeight is 0.
//global lList is List().  // guidance data from last log
//global eList is List().
