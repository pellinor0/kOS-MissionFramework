parameter missionName.

RunOncePath("0:/libdev").
RunOncePath("0:/libsystem").
RunOncePath("0:/libmission").
set gMissionStartManual to 1.
prepareMission(missionName).
resumeMission().
