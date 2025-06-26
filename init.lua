-- self._Metadata and self._KVs are not intended to be edited by the user directly, although doing so is not prohibited
-- Doing so can result in undefined/broken behavior.
-- Do so at your own risk

-- :: Modules :: --
local Helpers = require(script.Helpers)
local Types = require(script.Types)
local WarnList = require(script.WarnList)
local MapSettings = require(script.MapSettings)

-- :: Map Class :: --
local Map = { }
Map.__index = Map
Map.__len = function(self)
	if MapSettings.LenReturnsRootCount then
		return self:GetRootCount()
	end
	return self:Count()
end
Map.__eq = function(self, otherMap)
	if MapSettings.UseDeepEqDefault then
		return self:IsEqual(otherMap)
	end
	return self:IsShallowEqual(otherMap)
end

local INFINITE_SIZE = -1

local function CreateDataDict()
	local metadata = {
		_TotalCount = 0,
		_RootCount = 0,
		_Capacity = INFINITE_SIZE,
		_IsLocked = false,
		_IsFixedCapacity = false,

		_NyxMap = true,

		_ProhibitedSettings = {
			["_TotalCount"] = true,
			["_RootCount"] = true,
			["_NyxMap"] = true,
			["_ProhibitedSettings"] = true
		}
	}
	return metadata
end

local function CreateSelf()
	local self = setmetatable({}, Map)
	self._Metadata = CreateDataDict()
	self._KVs = {}
	return self
end

local function Split(location)
	location = string.gsub(location, "/+$", "")
	local split = string.split(location, '/')
	for i = #split, 1, -1 do
		if split[i] == '' then
			table.remove(split, i)
		end
	end
	return split
end

function Map.New()
	local self = CreateSelf()
	return self
end

function Map.With(_settings)
	local self = CreateSelf()
	for key, value in _settings do
		if self._Metadata[key] == nil then
			warn("Unknown key '" .. key .. "'")
			continue
		end
		if self._Metadata._ProhibitedSettings[key] ~= nil
			and not MapSettings.AllowAllCustomization then
			warn("Key '" .. key .. "' is non customizable")
			continue
		end
		self._Metadata[key] = value
	end

	return self
end

-- Checks for '_LunaranMap' as other map implementations could include '_Metadata' at the top level
-- Not 100% safe as user can remove these flags. For general purpose only
function Map.IsValidMap(map)
	return map["_Metadata"] ~= nil
		and map["_Metadata"]["_NyxMap"] ~= nil
end

function Map:_GetDictPath(location)
	local split = Split(location)
	local first = split[1]
	local currentPath = self._KVs[first]

	if typeof(currentPath) ~= Types.Table then return nil end

	if #split == 1 then
		return currentPath
	end

	for i = 2, #split do
		local path = split[i]
		if typeof(currentPath[path]) ~= Types.Table then return nil end

		currentPath = currentPath[path]
		if currentPath == nil then
			return nil
		end
	end
	return currentPath
end

function Map:IsLocked()
	return self._Metadata._IsLocked
end

function Map:IsConst()
	return table.isfrozen(self._KVs) or table.isfrozen(self._Metadata)
end

function Map:_CanEdit(key, arg1)
	if key == "_TotalCount" then
		if self:Capacity() > INFINITE_SIZE and self:Count() >= self:Capacity() then
			return false, WarnList.SizeWarn
		end
	elseif key == "_Capacity" then
		if self._Metadata._IsFixedCapacity then
			return false, WarnList.FixedCapacityWarn
		elseif arg1 < self._Metadata._Capacity then
			return false, WarnList.CapacityLessThanWarn
		end
	end

	-- General 'uneditable'
	if self:IsConst() then
		return false, WarnList.ConstMapWarn
	end
	if self:IsLocked() then
		return false, WarnList.LockedMapWarn
	end

	return true
end

function Map:_UpdateTotalCount(num)
	self._Metadata._TotalCount += num
end

function Map:_UpdateRootCount(num)
	self._Metadata._RootCount += num
end

-- Updates both the total count and root count depending on context
function Map:_UpdateCount(num, map)
	local canEdit, reason = self:_CanEdit(self._Metadata._TotalCount)
	if not canEdit then
		warn(reason)
		return nil
	end

	if map ~= nil and map == self._KVs then
		if num > 0 then
			self:_UpdateRootCount(1)
		elseif num < 0 then
			self:_UpdateRootCount(-1)
		end
	end
	self:_UpdateTotalCount(num)
end

-- Only checks for equality at the _KVs level
-- Prefered over self:IsEqual
function Map:IsShallowEqual(otherMap)
	if not Map.IsValidMap(otherMap) then
		return false
	end

	for key, value in self._KVs do
		if otherMap._KVs[key] ~= value then
			return false
		end
	end

	return true
end

-- Checks for deep equality within _KVs, going through every key inside of self
-- Only checks key equality and value type equality, not value -> value equality
function Map:IsEqual(otherMap)
	if not Map.IsValidMap(otherMap) then
		return false
	end

	local function loop(_table, _otherMap)
		for key, value in _table do
			if _otherMap[key] == nil or _otherMap[key] ~= value then
				return false
			end

			local _type = typeof(value)
			local otherType = typeof(_otherMap[key])
			if _type == Types.Table and otherType == Types.Table then
				if not loop(_otherMap[key], value) then
					print("???")
					return false
				end
			elseif _type == Types.Table and otherType ~= Types.Table then
				return false
			end
		end
		return true
	end

	local isEqual = loop(otherMap._KVs, self._KVs)
	return isEqual
end

-- Takes a location and ensures that it exists
-- If any subpath is not found, it creates it
function Map:EnsurePath(location)
	local split = Split(location)
	local currentPath = self._KVs

	for _, path in split do
		local value = currentPath[path]
		if value == nil then
			currentPath[path] = {}
			self:_UpdateCount(1, currentPath)
		elseif typeof(value) ~= Types.Table then
			return nil
		end

		currentPath = currentPath[path]
	end

	return currentPath
end

-- Setss at top of _KVs only
function Map:Set(key, value)
	local canEdit, reason = self:_CanEdit("_TotalCount")
	if not canEdit then
		warn(reason)
		return nil
	end

	if key == nil then
		warn(WarnList.KeyNotFound)
		return nil
	end
	if value == nil then
		warn(WarnList.ValueNotFound)
		return nil
	end

	if self._KVs[key] == nil then
		self:_UpdateCount(1, self._KVs)
	end

	self._KVs[key] = value
	return self._KVs[key]
end

function Map:SetAt(location, key, value)
	local canEdit, reason = self:_CanEdit("_TotalCount")
	if not canEdit then
		warn(reason)
		return nil
	end

	if key == nil then
		warn(WarnList.KeyNotFound)
		return nil
	end
	if value == nil then
		warn(WarnList.ValueNotFound)
		return nil
	end

	if location == nil or location == '' then
		return self:Set(key, value)
	end

	local path = self:EnsurePath(location)

	if path ~= nil then
		if path[key] == nil then
			local count = 1
			self:_UpdateCount(count, path)

			if typeof(value) == Types.Table then
				count = Helpers.CountAll(value)
				self:_UpdateCount(count, path)
			end
		end


		path[key] = value
		return path[key]
	end
end

function Map:Resize(newSize)
	local canEdit, reason = self:_CanEdit("_Capacity", newSize)
	if not canEdit then
		warn(reason)
		return nil
	end

	self._Metadata._Capacity = newSize
end

-- Similar to Set, only removes from the top of _KVs
function Map:Remove(key)
	local canEdit, reason = self:_CanEdit("_TotalCount")
	if not canEdit then
		warn(reason)
		return nil
	end

	local _table = self._KVs[key]
	if _table ~= nil then
		self._KVs[key] = nil

		local count = 1
		if (typeof(_table)) == Types.Table then
			count = Helpers.CountAll(_table) + 1 -- + 1 because you need to include _table itself
		end
		self:_UpdateCount(-count, self._KVs)
	end
end

function Map:RemoveAt(location, key)
	local canEdit, reason = self:_CanEdit("_TotalCount")
	if not canEdit then
		warn(reason)
		return nil
	end

	local path = self:_GetDictPath(location)
	if path ~= nil and path[key] ~= nil then
		local count = 1
		if (typeof(path[key])) == Types.Table then
			count = Helpers.CountAll(path[key]) + 1 -- + 1 because you need to include _table itself
		end

		path[key] = nil
		self:_UpdateCount(-count, path)
	end
end

function Map:Contains(keyToFind, location)
	if location == nil then
		return self._KVs[keyToFind] ~= nil
	end

	local path = self:_GetDictPath(location)

	if path == nil then return nil end

	return path[keyToFind] ~= nil
end

function Map:Lock()
	if self:IsConst() then
		warn(WarnList.ConstMapWarn)
		return nil
	end
	self._Metadata._IsLocked = true
end

function Map:Unlock()
	if self:IsConst() then
		warn(WarnList.ConstMapWarn)
		return nil
	end
	self._Metadata._IsLocked = false
end

function Map:MakeConst()
	table.freeze(self._KVs)
	table.freeze(self._Metadata)
end

function Map:Clear(overrideLockedMap)
	if self:IsConst() then
		warn(WarnList.ConstMapWarn)
		return nil
	end

	if self:IsLocked() and not overrideLockedMap then
		warn(WarnList.LockedMapWarn)
		warn("Unlock map or pass bool arg")
		return nil
	end

	self._KVs = {}
	self._Metadata._TotalCount = 0
	self._Metadata._RootCount = 0
end

function Map:Count()
	return self._Metadata._TotalCount
end

function Map:GetRootCount()
	return self._Metadata._RootCount
end

function Map:Capacity()
	return self._Metadata._Capacity
end

function Map:For(func)
	for key, value in self._KVs do
		func(key, value)
	end
end

-- Loops through every key/value pair within the map
function Map:ForEvery(func)
	local forLoop
	forLoop = function(_table)
		for key, value in _table do
			if typeof(value) == Types.Table then
				forLoop(value)
			end

			func(key, value)
		end
	end
	forLoop(self._KVs)
end

-- Returns a shallow copy, so nested tables are references
-- Be aware that due to this behavior, editing a nested table from a clone *will* edit all other clones, including the original map
function Map:Copy()
	local copy = setmetatable({}, Map)
	for key, value in self do
		copy[key] = value
	end
	return copy
end

-- Performs a deep copy of self
-- More expensive, but it's yours
function Map:DeepCopy()
	local loop
	loop = function(_table)
		local innerCopy = {}
		for key, value in _table do
			if typeof(value) == Types.Table then
				innerCopy[key] = loop(value)
			else
				innerCopy[key] = value
			end
		end
		return innerCopy
	end

	local contents = loop(self)
	local copy = setmetatable(contents, Map)
	return copy
end

function Map:Get(key)
	if self._KVs[key] ~= nil then
		return self._KVs[key]
	else
		warn("Key '" .. key .. "' not found")
		return nil
	end
end

function Map:GetAt(location, key)
	local path = self:_GetDictPath(location)
	if path == nil then
		warn("Path '" .. location .. "' not found")
		return nil
	end

	if path[key] ~= nil then
		return path[key]
	else
		warn("Key '" .. key .. "' not found")
	end
end

-- Only merges non existing keys, doesn't overwrite existing ones.
function Map:Merge(otherMap)
	if not Map.IsValidMap(otherMap) then return nil end

	local loop
	loop = function(other, this)
		for key, value in other do
			if this[key] ~= nil then continue end

			if typeof(value) == Types.Table then
				this[key] = loop(value, { })
			else
				this[key] = value
			end

			local count = 1
			self:_UpdateCount(count, this)
		end
		return this
	end
	loop(otherMap._KVs, self._KVs)
end

-- Debugging purposes only. Prefer regular count getters instead

-- Use if _KVs is manually edited or if keys/values are suspected to be unaccounted for
function Map:RecountAll()
	local count = Helpers.CountAll(self._KVs)
	self:RecountTop()

	self._Metadata._TotalCount = count
	return count
end

-- Use if _KVs is manually edited or if keys/values are suspected to be unaccounted for
function Map:RecountTop()
	local count = Helpers.Count(self._KVs)
	self._Metadata._RootCount = count
	return count
end

return Map