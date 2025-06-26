local WarnList =  {
    ["LockedMapWarn"] = "Attempt to edit locked map is prohibited",
	["SizeWarn"] = "Count exceeds size of map",
	["InvalidType"] = function(expected, got)
		return "Invalid type. Expected '" .. expected .. "', got '" .. got .. "'" 
	end,
	["KeyNotFound"] = "Key was not provided, this is illegal",
	["ValueNotFound"] = "Value was not provided, this is prohibited",
    ["ConstMapWarn"] = "Attempt to edit const map is illegal",
	["FixedCapacityWarn"] = "Attempt to edit a map with fixed capacity is illegal",
	["CapacityLessThanWarn"] = "Attempt to set capacity lower than current capacity is illegal"
}
table.freeze(WarnList)

return WarnList