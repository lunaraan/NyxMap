local MapSettings = {
    UseDeepEqDefault = false,
	LenReturnsRootCount = false,
	AllowAllCustomization = false -- Not recommended. Only for debugging. Setting this to true can result in undefined behavior
}
table.freeze(MapSettings)

return MapSettings