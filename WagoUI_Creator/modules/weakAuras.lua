---@diagnostic disable: undefined-field
local _, addon = ...
local L = addon.L
local moduleName = "WeakAuras"
local LAP = LibStub:GetLibrary("LibAddonProfiles")
local lapModule = LAP:GetModule(moduleName)
local DF = _G["DetailsFramework"]

local options_dropdown_template = DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
local m
local frameWidth = 750
local frameHeight = 540
local scrollBoxWidth = 250
local scrollBoxHeight = frameHeight - 165
local lineHeight = 30

local getChosenResolution = function()
  return addon:GetCurrentPack().resolutions.chosen
end

local setWeakAuraExportState = function(resolution, id, value)
  addon:GetCurrentPack().profileKeys[resolution][moduleName][id] = value
end

local getWeakAuraExportState = function(resolution, id)
  addon:GetCurrentPack().profileKeys[resolution][moduleName] = addon:GetCurrentPack().profileKeys[resolution]
  [moduleName] or {}
  return addon:GetCurrentPack().profileKeys[resolution][moduleName][id]
end

local scrollBoxData = {
  [1] = {},
  [2] = {},
}

local function addToData(i, info)
  -- only insert if not already in list
  for _, existingInfo in ipairs(scrollBoxData[i]) do
    if existingInfo.id == info.id then
      return
    end
  end
  tinsert(scrollBoxData[i], info)
  setWeakAuraExportState(getChosenResolution(), info.id, true)
  m.scrollBoxes[i].onSearchBoxTextChanged()
end

local function copyExportString(id)
  addon:Async(function()
    addon.copyHelper:SmartShow(addon.frames.mainFrame, 0, 50, L["Preparing export string..."])
    if addon.db.exportOptions[moduleName] then
      if lapModule.setExportOptions then
        lapModule.setExportOptions(addon.db.exportOptions[moduleName])
      end
    end
    local exportString = lapModule.exportGroup(id)
    addon.copyHelper:Hide()
    addon:TextExport(exportString)
  end, "copyWAExportString")
end

local function createGroupScrollBox(frame, buttonConfig, scrollBoxIndex)
  local filteredData = {}

  local function updateFilteredData(searchString, data)
    wipe(filteredData)
    local initialData = scrollBoxData[scrollBoxIndex]
    if searchString and searchString ~= "" then
      for _, display in pairs(initialData) do
        if display.id:lower():find(searchString) then
          table.insert(filteredData, display)
        end
      end
    else
      for _, display in pairs(initialData) do
        table.insert(filteredData, display)
      end
    end
    --sort top level groups to the top
    table.sort(filteredData, function(a, b)
      local aIdx = a.parent and 0 or 1
      local bIdx = b.parent and 0 or 1
      if aIdx == bIdx then
        return a.id < b.id
      end
      return (aIdx > bIdx)
    end)
    return filteredData
  end

  local function scrollBoxUpdate(self, data, offset, totalLines)
    if self.instructionLabel then
      if #filteredData == 0 then
        self.instructionLabel:Show()
      else
        self.instructionLabel:Hide()
      end
    end
    for i = 1, totalLines do
      local index = i + offset
      local info = filteredData[index]
      if (info) then
        local line = self:GetLine(i)
        line.nameLabel:SetText(info.id)
        local iconSource = info.groupIcon or info.displayIcon or 134400
        iconSource = tonumber(iconSource) or 134400
        line.icon:SetTexture(iconSource)
        line.icon:SetPushedTexture(iconSource)
        line.info = info
      end
    end
  end

  local function createScrollLine(self, index)
    local line = CreateFrame("Button", nil, self)
    local function setLinePoints()
      line:ClearAllPoints()
      PixelUtil.SetPoint(line, "TOPLEFT", self, "TOPLEFT", 1, -((index - 1) * (self.LineHeight + 1)) - 1)
    end
    setLinePoints()
    line:SetSize(scrollBoxWidth - 2, self.LineHeight)
    if not line.SetBackdrop then
      Mixin(line, BackdropTemplateMixin)
    end
    line:SetBackdrop({ bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true })
    line:SetBackdropColor(unpack({ .8, .8, .8, 0.3 }))

    local icon = DF:CreateButton(line, nil, lineHeight, lineHeight, "", nil, nil, 134400, nil, nil, nil, nil)
    icon:SetPoint("left", line, "left", 0, 0)
    icon:ClearHighlightTexture()
    ---@diagnostic disable-next-line: inject-field
    line.icon = icon

    local nameLabel = DF:CreateLabel(line, "", 12, "white")
    nameLabel:SetWordWrap(true)
    nameLabel:SetWidth(scrollBoxWidth - 80)
    nameLabel:SetPoint("left", icon, "right", 2, 0)
    line:SetScript("OnEnter", function(self)
      line:SetBackdropColor(unpack({ .8, .8, .8, 0.5 }))
    end)
    line:SetScript("OnLeave", function(self)
      line:SetBackdropColor(unpack({ .8, .8, .8, 0.3 }))
    end)
    ---@diagnostic disable-next-line: inject-field
    line.nameLabel = nameLabel

    ---@diagnostic disable-next-line: inject-field
    line.buttons = {}
    for idx, buttonData in ipairs(buttonConfig) do
      local button = DF:CreateButton(line, nil, lineHeight, lineHeight, "", nil, nil, buttonData.icon)
      button:SetPushedTexture(buttonData.icon)
      button:SetPoint("right", line, "right", -(idx - 1) * lineHeight, 0)
      button:SetScript("OnClick", function(self)
        buttonData.onClick(line.info)
      end)
      line.buttons[idx] = button
    end

    line:SetMovable(true)
    line:RegisterForDrag("LeftButton")
    line:SetScript("OnDragStart", function(self)
      self:SetScript("OnUpdate", function(self)
        local dropRegionIndex = 1
        for i = 2, #m.scrollBoxes do
          if m.scrollBoxes[i]:IsMouseOver() then
            dropRegionIndex = i
          end
        end
        for i = 2, #m.scrollBoxes do
          if i == dropRegionIndex then
            m.scrollBoxes[i].ShowHighlight()
          else
            m.scrollBoxes[i].HideHighlight()
          end
        end
      end)
      self:StartMoving()
    end)
    line:SetScript("OnDragStop", function(self)
      self:SetScript("OnUpdate", nil)
      self:StopMovingOrSizing()
      setLinePoints()
      local dropRegionIndex = 1
      for i = 2, #m.scrollBoxes do
        m.scrollBoxes[i].HideHighlight()
        if m.scrollBoxes[i]:IsMouseOver() then
          dropRegionIndex = i
          break
        end
      end
      if dropRegionIndex ~= scrollBoxIndex then
        if dropRegionIndex > 1 then
          local info = line.info
          addToData(dropRegionIndex, info)
          if scrollBoxIndex > 1 then
            m.removeFromData(scrollBoxIndex, info)
          end
        else
          m.removeFromData(scrollBoxIndex, line.info)
        end
      end
    end)

    return line
  end

  local groupsScrollBox = DF:CreateScrollBox(frame, nil, scrollBoxUpdate, {},
    scrollBoxWidth, scrollBoxHeight, 0, lineHeight, createScrollLine, true)
  DF:ReskinSlider(groupsScrollBox)

  groupsScrollBox.ShowHighlight = function()
    groupsScrollBox:SetBackdropColor(.8, .8, .8, 0.5)
    groupsScrollBox:SetBackdropBorderColor(1, 1, 1, 1)
  end
  local red, green, blue, alpha = DF:GetDefaultBackdropColor()
  groupsScrollBox.HideHighlight = function()
    groupsScrollBox:SetBackdropColor(red, green, blue, alpha)
    groupsScrollBox:SetBackdropBorderColor(0, 0, 0, 1)
  end
  if scrollBoxIndex > 1 then
    local instructionLabel = DF:CreateLabel(groupsScrollBox, L["Drag and drop\nto add WeakAuras"], 20, "grey")
    instructionLabel:SetTextColor(0.5, 0.5, 0.5, 1)
    instructionLabel:SetJustifyH("center")
    instructionLabel:SetPoint("center", groupsScrollBox, "center", 0, 0)
    groupsScrollBox.instructionLabel = instructionLabel
  end

  local function onSearchBoxTextChanged(...)
    local editBox, _, widget, searchString = ...
    local text = groupsScrollBox.searchBox:GetText()
    searchString = searchString or text:lower()
    local filtered = updateFilteredData(searchString, groupsScrollBox.data)
    if widget then
      if widget.previousNumData and widget.previousNumData == #filtered then
        return
      end
      widget.previousNumData = #filtered
    end
    -- it still breaks in some cases, but this is the best I can do for now
    groupsScrollBox:SetData(filtered)           --fix scroll height reflecting the data
    groupsScrollBox:OnVerticalScroll(0)         --scroll to the top
    groupsScrollBox:Refresh()                   --update the data displayed
    if widget then widget.widget:SetFocus() end --regain focus
  end
  groupsScrollBox.onSearchBoxTextChanged = onSearchBoxTextChanged

  local searchBox = DF:CreateTextEntry(groupsScrollBox, function() end, scrollBoxWidth, 20, "ScriptSearchTextEntry", _, _,
    options_dropdown_template)
  searchBox:SetPoint("bottomleft", groupsScrollBox, "topleft", 0, 2)
  groupsScrollBox.searchBox = searchBox

  searchBox:SetHook("OnChar", onSearchBoxTextChanged)
  searchBox:SetHook("OnTextChanged", onSearchBoxTextChanged)
  local searchLabel = DF:CreateLabel(groupsScrollBox, L["Search:"], DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"))
  searchLabel:SetPoint("bottomleft", searchBox, "topleft", 0, 2)

  return groupsScrollBox
end

local function createManageFrame(w, h)
  ---@diagnostic disable-next-line: undefined-field
  local panelOptions = {
    DontRightClickClose = true,
  }
  m = DF:CreateSimplePanel(UIParent, w, h, "", nil, panelOptions)
  ---@diagnostic disable-next-line: undefined-field
  DF:ApplyStandardBackdrop(m)
  DF:CreateBorder(m)
  m:ClearAllPoints()
  m:SetFrameStrata("FULLSCREEN")
  m:SetFrameLevel(100)
  m.__background:SetAlpha(1)
  m:SetMouseClickEnabled(true)
  m:SetTitle(L["WeakAuras Export Settings"])
  m:Hide()
  m.buttons = {}
  m.StartMoving = function() end

  m.scrollBoxes = {}

  local function removeFromData(i, info)
    for idx, lineInfo in ipairs(scrollBoxData[i]) do
      if lineInfo.id == info.id then
        tremove(scrollBoxData[i], idx)
        setWeakAuraExportState(getChosenResolution(), info.id, nil)
        break
      end
    end
    m.scrollBoxes[i].onSearchBoxTextChanged()
  end
  m.removeFromData = removeFromData

  local buttonConfigs = {
    [1] = {
    },
    [2] = {
      [1] = {
        icon = 4200126,
        onClick = function(info)
          removeFromData(2, info)
        end
      },
      [2] = {
        icon = 450907,
        onClick = function(info)
          copyExportString(info.id)
        end
      },
    },
  }

  for idx, buttonConfig in ipairs(buttonConfigs) do
    local scrollBox = createGroupScrollBox(m, buttonConfig, idx)
    scrollBox:SetPoint("TOPLEFT", m, "TOPLEFT", 60 + ((idx - 1) * (scrollBoxWidth + 110)), -90)
    m.scrollBoxes[idx] = scrollBox
    local labelText = idx == 1 and "WeakAuras" or idx == 2 and L["Export"]
    local label = DF:CreateLabel(scrollBox, labelText, 20, "white")
    label:SetPoint("BOTTOM", scrollBox, "TOP", 0, 30)
  end

  local purgeWagoCheckbox = DF:CreateSwitch(m,
    function(_, _, value)
      WagoUICreatorDB.exportOptions[moduleName].purgeWago = value
      lapModule.setExportOptions(WagoUICreatorDB.exportOptions[moduleName])
    end,
    false, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, DF:GetTemplate("switch", "OPTIONS_CHECKBOX_BRIGHT_TEMPLATE"))
  purgeWagoCheckbox:SetValue(WagoUICreatorDB.exportOptions[moduleName])
  purgeWagoCheckbox:SetSize(25, 25)
  purgeWagoCheckbox:SetAsCheckBox()
  purgeWagoCheckbox:SetPoint("BOTTOMLEFT", m, "BOTTOMLEFT", 60, 20)

  local purgeWagoLabel = DF:CreateLabel(m, "Startup", 16, "white")
  purgeWagoLabel:SetPoint("LEFT", purgeWagoCheckbox, "RIGHT", 10, 0)
  purgeWagoLabel:SetText(L["Purge Wago IDs for exports"])

  local okayButton = DF:CreateButton(m, nil, 200, 40, L["Okay"], nil, nil, nil, nil, nil,
    nil,
    options_dropdown_template)
  okayButton.text_overlay:SetFont(okayButton.text_overlay:GetFont(), 16)
  okayButton:SetClickFunction(function()
    m:Hide()
  end)
  okayButton:SetScript("OnEnter", function(self)
    okayButton.button:SetBackdropBorderColor(1, 1, 1, 1)
  end)
  okayButton:SetScript("OnLeave", function(self)
    okayButton.button:SetBackdropBorderColor(1, 1, 1, 0)
  end)
  okayButton:SetPoint("BOTTOMRIGHT", m, "BOTTOMRIGHT", -60, 20)

  return m
end

local function showManageFrame(anchor)
  if not m then m = createManageFrame(frameWidth, frameHeight) end
  wipe(scrollBoxData[1])
  wipe(scrollBoxData[2])
  for id, display in pairs(WeakAurasSaved.displays) do
    table.insert(scrollBoxData[1], display)
    --populate second list
    if getWeakAuraExportState(getChosenResolution(), id) then
      table.insert(scrollBoxData[2], display)
    end
  end
  for i = 1, 2 do
    m.scrollBoxes[i]:SetData(scrollBoxData[i])
    m.scrollBoxes[i]:Refresh()
    m.scrollBoxes[i].onSearchBoxTextChanged(nil, nil, nil, "")
    m.scrollBoxes[i].searchBox.editbox:SetText("")
  end
  m:ClearAllPoints()
  m:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  m:Show()
end

local function dropdownOptions()
  return {}
end

local function hookRefresh()

end

local onSuccessfulTestOverride = function(_, weakAuraTable)
  WeakAuras.Import(weakAuraTable)
end

---@type ModuleConfig
local moduleConfig = {
  moduleName = moduleName,
  lapModule = lapModule,
  dropdownOptions = dropdownOptions,
  copyFunc = nil,
  hookRefresh = hookRefresh,
  copyButtonTooltipText = nil,
  sortIndex = 11,
  hasGroups = true,
  manageFunc = showManageFrame,
  onSuccessfulTestOverride = onSuccessfulTestOverride,
}

addon.ModuleFunctions:InsertModuleConfig(moduleConfig)
