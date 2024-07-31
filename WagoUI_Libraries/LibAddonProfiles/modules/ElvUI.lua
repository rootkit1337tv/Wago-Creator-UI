local _, loadingAddonNamespace = ...;
---@type LibAddonProfilesPrivate
local private = loadingAddonNamespace.GetLibAddonProfilesInternal and loadingAddonNamespace:GetLibAddonProfilesInternal();
if (not private) then return; end
local EXPORT_PREFIX = '!E1!'

---@return boolean
local isLoaded = function()
  return ElvUI and true or false
end

---@return boolean
local needsInitialization = function()
  return false
end

---@return nil
local openConfig = function()
  SlashCmdList["ACECONSOLE_ELVUI"]()
end

---@return nil
local closeConfig = function()
  local E = ElvUI[1]
  E.Config_CloseWindow()
end

---@return table<string, any>
local getProfileKeys = function()
  return ElvDB.profiles
end

---@return string
local getCurrentProfileKey = function()
  local E = ElvUI[1]
  return ElvDB.profileKeys and ElvDB.profileKeys[E.mynameRealm]
end

---@param profileKey string
local setProfile = function(profileKey)
  local E = ElvUI[1]
  E.data:SetProfile(profileKey)
end

---@param profileKey string
---@return boolean
local isDuplicate = function(profileKey)
  return getProfileKeys()[profileKey]
end

---@param profileString string
---@param profileKey string | nil
---@param profileData table | nil
---@param rawData table | nil
---@return string | nil
local testImport = function(profileString, profileKey, profileData, rawData)
  local prefix = strsub(profileString, 1, 4)
  if prefix ~= EXPORT_PREFIX then return nil end
  local distributor = ElvUI[1]:GetModule("Distributor");
  local profileType, key, data = distributor:Decode(profileString)
  if key and data and profileType == "profile" then
    return key
  end
end

---@param profileString string
---@param profileKey string
local importProfile = function(profileString, profileKey, fromIntro)
  local E = ElvUI[1]
  local D = E:GetModule('Distributor')
  local success = D:ImportProfile(profileString)
  if not success then return end
  if fromIntro then
    E.global.general.UIScale = E:PixelBestSize()
    E:PixelScaleChanged()
  end
end

---@param profileKey string | nil
---@return string | nil
local exportProfile = function(profileKey)
  if not profileKey then return nil end
  --Core\General\Distributor.lua
  local E = ElvUI[1]
  local D = E:GetModule('Distributor')
  local _, profileExport = D:GetProfileExport("profile", "text", profileKey)
  return profileExport
end

---@param profileStringA string
---@param profileStringB string
---@return boolean
local areProfileStringsEqual = function(profileStringA, profileStringB)
  if not profileStringA or not profileStringB then return false end
  local E = ElvUI[1]
  local D = E:GetModule('Distributor')
  local _, _, profileDataA = D:Decode(profileStringA)
  local _, _, profileDataB = D:Decode(profileStringB)
  if not profileDataA or not profileDataB then return false end
  return private:DeepCompareAsync(profileDataA, profileDataB)
end

---@type LibAddonProfilesModule
local m = {
  moduleName = "ElvUI",
  icon = [[Interface\AddOns\ElvUI\Core\Media\Textures\LogoAddon]],
  slash = "/ec",
  needReloadOnImport = true,
  needsInitialization = needsInitialization,
  needProfileKey = false,
  isLoaded = isLoaded,
  openConfig = openConfig,
  closeConfig = closeConfig,
  isDuplicate = isDuplicate,
  testImport = testImport,
  importProfile = importProfile,
  exportProfile = exportProfile,
  getProfileKeys = getProfileKeys,
  getCurrentProfileKey = getCurrentProfileKey,
  setProfile = setProfile,
  areProfileStringsEqual = areProfileStringsEqual,
}
private.modules[m.moduleName] = m
