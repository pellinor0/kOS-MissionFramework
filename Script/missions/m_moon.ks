if Body<>Body("Minmus") set Target to Body("Minmus").

m_ascentLKO().

m_hohmannToTarget().
m_nodeIncCorr().
m_waitForTransition("ENCOUNTER").
m_capture(20000).

// land
//m_vacLand( Body:GeoPositionOf(Vessel("MinmusTarget"):Position +10*North:Vector) ).
m_vacLand(LatLng(4.9,180)).
wait 10.

// launch to useful orbit
m_vacLaunch(20000).

// return burn + inc change
m_returnFromMoon().

// aerobraking
m_returnFromHighOrbit().

// landFromLko().
