local newType is "TT4b".
print " rename Vessel: oldType="+gShipType +", newType="+newType.
print " rename parts: ".
for p in getElement():Parts {
  if p:Tag:StartsWith(gShipType) {
    local rest is p:Tag:Remove(0,gShipType:Length).
    print "  "+p:Tag +" -> " +newType+rest.
    set p:Tag to newType+rest.
  }
}
askConfirmation().
