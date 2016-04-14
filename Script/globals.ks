// Persistent Data
global pMissionCounter is 0.
global gMissionCounter is 0.
global gMissionStartManual is 0.

// == global Parameters ==
// (Defaults can be overridden in the ship's params.ks)
global gTgtVesselName is "KSS".
global gLkoAP is 75000.

global gSpacePort is LatLng(-0.04909, -74.697). // KSC runway 09
global gSpacePortHeight is 69.

// == Vessel-specific parameters ==
// these are set manually
global gDeorbitPe is 22000.
global gIsPlane is 0.
global gBuiltinAoA is 3. // only use for planes
global gShipRadius is 5.
global gAeroBrakeDir is V(0,0,1). // prograde(?)
global gLaunchParam is 0.22. // for planes
// these are set automatically
global gShipType is "". // from Core nameTag
global gMyPort is 0.
// these are measured by the calibrate mission
global gLaunchDuration is 0.
global gLaunchAngle is 0.
global gLandingPA is 0.
global gGearHeight is 0. // not used yet
