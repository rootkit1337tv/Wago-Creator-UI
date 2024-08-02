local _, addon = ...
local moduleName = "BugSack"
local LAP = LibStub:GetLibrary("LibAddonProfiles")
local lapModule = LAP:GetModule(moduleName)

local function dropdownOptions(index)
  local res = {}
  if not lapModule.isLoaded() then return res end
  local profileKeys = lapModule.getProfileKeys()
  local currentProfileKey = lapModule.getCurrentProfileKey()
  return addon.ModuleFunctions:CreateDropdownOptions(moduleName, index, res, profileKeys, currentProfileKey)
end

---@type ModuleConfig
local moduleConfig = {
  moduleName = moduleName,
  lapModule = lapModule,
  dropdownOptions = dropdownOptions,
  copyFunc = nil,
  hookRefresh = nil, --this addon doesn't have profiles at all
  copyButtonTooltipText = string.format(addon.L.noBuiltInProfileTextImport, moduleName),
  sortIndex = 21,
}

addon.ModuleFunctions:InsertModuleConfig(moduleConfig)