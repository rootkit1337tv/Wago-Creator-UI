---@type string
local addonName = ...
---@class WagoUICreator
local addon = select(2, ...)
local L = addon.L
local LAP = LibStub("LibAddonProfiles")
local DF = _G["DetailsFramework"]
local LWF = LibStub("LibWagoFramework")

local profileDropdowns = {}
local db

function addon:CreateFrameContent(f)
  db = addon.db
  local contentWidth = f:GetWidth()
  local contentHeight = f:GetHeight()
  addon:CreateProfileList(f, contentWidth - 6, contentHeight)
end

do
  local f = CreateFrame("frame")
  local tx = f:CreateTexture()
  function addon:TestTexture(path)
    tx:SetTexture("?")
    tx:SetTexture(path)
    return tx:GetTexture()
  end
end

function addon:CreateProfileList(f, width, height)
  local function contentScrollboxUpdate(self, data, offset, totalLines)
    local currentUIPack = addon:GetCurrentPackStashed()
    -- hide all lines
    for i = 1, totalLines do
      local line = self:GetLine(i)
      if not currentUIPack or not data[i + offset] then
        line.icon:Hide()
        line.nameLabel:SetText("")
        line.manageButton:Hide()
        line.profileDropdown:Hide()
        -- line.exportButton:Hide()
        line.lastUpdateLabel:SetText("")
        line:SetBackdropColor(unpack({.8, .8, .8, 0.1}))
        line.notInstalledLabel:SetText("")
      else
        line.icon:Show()
        line.manageButton:Show()
        line.profileDropdown:Show()
      end
    end
    if not currentUIPack then
      return
    end
    addon.ModuleFunctions:SortModuleConfigs()
    for i = 1, totalLines do
      local index = i + offset
      local info = data[index]
      if (info) then
        local line = self:GetLine(i)
        ---@type LibAddonProfilesModule
        local lapModule = info.lapModule
        local res = currentUIPack.resolutions
        local loaded = lapModule:isLoaded() and res.enabled[res.chosen]
        local canEnable = LAP:CanEnableAnyAddOn(lapModule.addonNames)
        if loaded then
          line:SetBackdropColor(unpack({.8, .8, .8, 0.3}))
        else
          line:SetBackdropColor(unpack({.5, .5, .5, 0.1}))
        end

        -- icon
        -- need to test if the texture exists
        local tex = addon:TestTexture(info.icon) and info.icon or QUESTION_MARK_ICON
        line.icon:SetTexture(tex)
        line.icon:SetPushedTexture(tex)
        line.icon:SetDisabledTexture(tex)
        line.icon:SetHighlightAtlas(lapModule.openConfig and "bags-glow-white" or "")
        if not lapModule.openConfig then
          line.icon:ClearHighlightTexture()
        end
        line.icon:SetTooltip(lapModule.openConfig and string.format(L["Click to open %s options"], info.name) or nil)
        line.icon:SetScript(
          "OnClick",
          function()
            lapModule:openConfig()
            f.contentScrollbox:Refresh()
          end
        )

        if info.queuedEnable then
          line.notInstalledLabel:SetTextColor(1, 1, 1, 1)
        else
          line.notInstalledLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        end

        if canEnable then
          line:SetScript(
            "OnClick",
            function()
              LAP:EnableAddOns(lapModule.addonNames)
              addon:ShowReloadIndicator()
              -- set hasLoggedInEver so the AddOn auto starts after reload
              -- we might want to use another db entry incase we use hasLoggedInEver for other purposes
              -- for now it's ok
              addon.db.hasLoggedInEver = false
              info.queuedEnable = true
              f.contentScrollbox:Refresh()
            end
          )
        else
          line:SetScript("OnClick", nil)
        end

        if loaded then
          line.icon:SetEnabled(true)
          line.notInstalledLabel:SetText("")
        else
          line.icon:SetEnabled(false)
          line.notInstalledLabel:SetText(
            info.queuedEnable and L["Enabled after reload"] or canEnable and L["AddOn disabled - click to enable"] or
              L["Not Installed"]
          )
        end

        -- name
        line.nameLabel:SetText(lapModule.moduleName)
        if not loaded then
          line.nameLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        else
          line.nameLabel:SetTextColor(1, 1, 1, 1)
        end

        -- profile dropdown
        if info.hasGroups then
          line.manageButton:Show()
          line.profileDropdown:Hide()
          line.manageButton:SetClickFunction(
            function()
              local copyCallback = function()
                addon:Async(
                  function()
                    if info.copyFuncOverride then
                      -- TODO: what is this?
                    else
                      -- TODO: this needs to be fixed to work with the new profile system
                      addon.copyHelper:SmartShow(addon.frames.mainFrame, 0, 50, L["Preparing export string..."])
                      info.exportFunc()
                      addon.copyHelper:Hide()
                      addon:TextExport(WagoUICreatorDB.profiles[info.name][1])
                    end
                  end,
                  "copy1Func"
                )
              end
              info.manageFunc(addon.frames.mainFrame, 1, L["Copy"], nil, copyCallback)
            end
          )
          --show how many WAs are marked
          local marked = 0
          local exportedIds = currentUIPack.profileKeys[currentUIPack.resolutions.chosen][info.name]
          if exportedIds then
            for _, id in pairs(exportedIds) do
              if id then
                marked = marked + 1
              end
            end
          end
          if marked > 0 then
            line.manageButton:SetText(L["Manage"] .. " (" .. marked .. ")")
          else
            line.manageButton:SetText(L["Manage"])
          end
        else
          line.manageButton:Hide()
          line.profileDropdown:Show()
        end
        local profileKey = currentUIPack.profileKeys[currentUIPack.resolutions.chosen][info.name]
        local fallbackOptions = function()
          return profileKey and
            {
              {
                value = profileKey,
                label = profileKey,
                onclick = function()
                  addon.UpdatePackSelectedUI()
                end
              }
            } or
            {}
        end
        line.profileDropdown.func = loaded and info.dropdown1Options or fallbackOptions
        line.profileDropdown:Refresh()
        if not info.hasGroups then
          line.profileDropdown:Select(profileKey)
          if not profileKey then
            line.profileDropdown:NoOptionSelected()
          end
          -- if profile key is no longer valid
          -- this is only a visual change, we do not want to touch the exported data / profile key here
          if profileKey and lapModule:isLoaded() and not lapModule:getProfileKeys()[profileKey] then
            line.profileDropdown:NoOptionSelected()
          end
        end
        if not loaded then
          line.profileDropdown:Disable()
          line.profileDropdown.myIsEnabled = false
          line.manageButton:Disable()
        else
          line.profileDropdown:Enable()
          line.profileDropdown.myIsEnabled = true
          line.manageButton:Enable()
        end

        --last update
        local metaData = currentUIPack.profileMetadata[currentUIPack.resolutions.chosen][info.name]
        if metaData then
          local lastUpdatedAt = 0
          local lastUpdatedAtString
          if type(metaData.lastUpdatedAt) == "number" then
            lastUpdatedAt = metaData.lastUpdatedAt
          elseif type(metaData.lastUpdatedAt) == "table" then
            for _, v in pairs(metaData.lastUpdatedAt) do
              if v > lastUpdatedAt then
                lastUpdatedAt = v
              end
            end
          end
          lastUpdatedAtString = lastUpdatedAt and date("%b %d %H:%M", lastUpdatedAt) or ""
          line.lastUpdateLabel:SetText(lastUpdatedAtString)
        else
          line.lastUpdateLabel:SetText("")
        end
        if loaded then
          line.lastUpdateLabel:SetTextColor(1, 1, 1, 1)
        else
          line.lastUpdateLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        end

      --export button
      -- local profileKeyToExport = currentUIPack.profileKeys[currentUIPack.resolutions.chosen][info.name]
      -- local setExportButtonText = function()
      --   local text = L["Export"]
      --   if lapModule.nonNativeProfileString then
      --     text = text.." "..L["nonNativeExportLabel"]
      --   end
      --   line.exportButton:SetText(text)
      -- end
      -- setExportButtonText()
      -- if lapModule.nonNativeProfileString then
      --   line.exportButton:SetTooltip(L["exportButtonWarning"].."\n\n"..L["nonNativeExportTooltip"])
      -- else
      --   line.exportButton:SetTooltip(L["exportButtonWarning"])
      -- end
      -- if info.hasGroups then
      --   line.exportButton:Hide()
      -- else
      --   line.exportButton:Show()
      --   if not loaded or not profileKeyToExport then
      --     line.exportButton:Disable()
      --   else
      --     line.exportButton:Enable()
      --   end
      --   line.exportButton:SetClickFunction(function()
      --     addon:Async(function()
      --       line.exportButton:Disable()
      --       line.exportButton:SetText(L["Exporting..."])
      --       local exportString = lapModule:exportProfile(profileKeyToExport)
      --       if exportString and type(exportString) == "string" then
      --         addon:TextExport(exportString)
      --       end
      --       line.exportButton:Enable()
      --       setExportButtonText()
      --     end, "copyProfileString")
      --   end)
      -- end
      end
    end
  end

  local function createScrollLine(self, index)
    local line = CreateFrame("Button", nil, self)
    PixelUtil.SetPoint(line, "TOPLEFT", self, "TOPLEFT", 1, -((index - 1) * (self.LineHeight + 1)) - 1)
    line:SetSize(width - 18, self.LineHeight)
    if not line.SetBackdrop then
      Mixin(line, BackdropTemplateMixin)
    end
    line:SetBackdrop({bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tileSize = 64, tile = true})
    line:SetBackdropColor(unpack({.8, .8, .8, 0.3}))
    DF:Mixin(line, DF.HeaderFunctions)

    -- icon
    local icon = DF:CreateButton(line, nil, 42, 42, "", nil, nil, QUESTION_MARK_ICON, nil, nil, nil, nil)
    line:AddFrameToHeaderAlignment(icon)
    line.icon = icon

    -- name
    local nameLabel = DF:CreateLabel(line, "", 16, "white")
    line:AddFrameToHeaderAlignment(nameLabel)
    line.nameLabel = nameLabel

    -- profile dropdown
    local profileDropdown =
      LWF:CreateDropdown(
      line,
      180,
      30,
      nil,
      1,
      function()
        return {}
      end
    )
    tinsert(profileDropdowns, profileDropdown)
    line:AddFrameToHeaderAlignment(profileDropdown)
    line.profileDropdown = profileDropdown

    -- manage button
    line.manageButton = LWF:CreateButton(line, 180, 30, L["Manage"], 16)
    line.manageButton:SetAllPoints(profileDropdown.dropdown)

    -- not installed / can enable / enabled after reload
    local notInstalledLabel = DF:CreateLabel(line, "", 10, "white")
    notInstalledLabel:SetPoint("RIGHT", profileDropdown.dropdown, "LEFT", -10, 0)
    notInstalledLabel:SetTextColor(0.5, 0.5, 0.5, 1)
    line.notInstalledLabel = notInstalledLabel

    -- last update
    local lastUpdateLabel = DF:CreateLabel(line, "", 10, "white")
    line:AddFrameToHeaderAlignment(lastUpdateLabel)
    line.lastUpdateLabel = lastUpdateLabel

    -- export button
    -- line.exportButton = LWF:CreateButton(line, 180, 30, "", 16)
    -- line:AddFrameToHeaderAlignment(line.exportButton)

    line:AlignWithHeader(f.contentHeader, "LEFT")
    return line
  end

  local totalHeight = 0

  ---comment
  ---@param widgets table<number, Frame>
  ---@param xOffset number | nil
  ---@param yOffset number | nil
  ---@param xGap number | nil
  local function addLine(widgets, xOffset, yOffset, xGap)
    xOffset = xOffset or 0
    yOffset = yOffset or 0
    xGap = xGap or 10
    local maxHeight = 0
    for i, widget in ipairs(widgets) do
      if i == 1 then
        widget:SetPoint("TOPLEFT", f, "TOPLEFT", xOffset, 0 - totalHeight + yOffset)
      else
        widget:SetPoint("LEFT", widgets[i - 1], "RIGHT", xGap + xOffset, 0)
      end
      maxHeight = math.max(maxHeight, widget:GetHeight())
    end
    totalHeight = totalHeight + maxHeight + 10 - yOffset
  end

  local function getPacksForDropdown()
    local packs = {}
    for _, pack in pairs(addon:GetAllPacksStashed()) do
      local newPack = {
        value = pack.localName,
        label = pack.localName,
        onclick = function()
          db.chosenPack = pack.localName
          addon.UpdatePackSelectedUI()
        end
      }
      table.insert(packs, newPack)
    end
    return packs
  end

  local packDropdown = LWF:CreateDropdown(f, 200, 40, 16, 1.5, getPacksForDropdown)
  if not db.chosenPack then
    packDropdown:NoOptionSelected()
  else
    packDropdown:Select(db.chosenPack)
  end
  f.packDropdown = packDropdown

  local newPackEditBox = LWF:CreateTextEntry(f, 200, 40, nil, 16)
  local newPackLabel = DF:CreateLabel(f, L["Pack name:"], 10)
  newPackLabel:SetPoint("BOTTOMLEFT", newPackEditBox, "TOPLEFT", 0, 2)
  newPackEditBox:HookScript(
    "OnChar",
    function()
      addon:ResetNewPackErrorLabel()
    end
  )

  local newPackErrorLabel = DF:CreateLabel(f, "", 10)
  newPackErrorLabel:SetPoint("TOPLEFT", newPackEditBox, "BOTTOMLEFT", 6, -2)
  newPackEditBox:HookScript(
    "OnEnterPressed",
    function()
      addon:CreatePackStashed()
    end
  )
  f.newPackErrorLabel = newPackErrorLabel
  ---@param text string
  ---@param error boolean
  function addon:SetNewPackErrorLabel(text, error)
    newPackErrorLabel:SetText(text)
    if error then
      newPackErrorLabel:SetTextColor(1, 0, 0, 1)
    else
      newPackErrorLabel:SetTextColor(1, 1, 1, 1)
    end
    if text and text ~= "" then
      newPackEditBox:SetFocus()
    end
  end
  function addon:ResetNewPackErrorLabel()
    addon:SetNewPackErrorLabel(L["Use the same name as you did on the website"], false)
  end
  addon:ResetNewPackErrorLabel()

  addon.GetNewEditBoxText = function()
    return newPackEditBox:GetText()
  end

  local createNewPackButton = LWF:CreateButton(f, 150, 40, L["Create Pack"], 16)
  createNewPackButton:SetClickFunction(addon.CreatePackStashed)
  f.createNewPackButton = createNewPackButton

  local deletePackButton = LWF:CreateButton(f, 150, 40, L["Delete"], 16)
  deletePackButton:SetClickFunction(addon.DeleteCurrentPackStashed)
  f.deletePackButton = deletePackButton
  addLine({packDropdown, newPackEditBox, createNewPackButton, deletePackButton}, 5, -10)

  -- resolution explainer
  local resExplainerLabel = DF:CreateLabel(f, "Startup", 16, "white")
  resExplainerLabel:SetWidth((width - 40) / 2)
  resExplainerLabel:SetWordWrap(true)
  resExplainerLabel:SetText(
    L[
      "Choose which resolutions you want the UI pack to support. You can provide a separate profile for each resolution and AddOn."
    ]
  )
  addLine({resExplainerLabel}, 5, -10)

  -- resolution
  local resolutions = {}
  for _, res in ipairs(addon.resolutions.entries) do
    local newRes = {
      value = res.value,
      label = res.displayNameLong,
      onclick = function()
        local currentPack = addon:GetCurrentPackStashed()
        if not currentPack then
          return
        end
        currentPack.resolutions.chosen = res.value
        addon.UpdatePackSelectedUI()
      end
    }
    table.insert(resolutions, newRes)
  end

  local resolutionDropdown =
    LWF:CreateDropdown(
    f,
    200,
    40,
    16,
    1.5,
    function()
      return resolutions
    end
  )
  local resolutionCheckBox =
    LWF:CreateCheckbox(
    f,
    40,
    function(_, _, value)
      local currentPack = addon:GetCurrentPackStashed()
      if not currentPack then
        return
      end
      currentPack.resolutions.enabled[currentPack.resolutions.chosen] = value
      f.contentScrollbox:Refresh()
    end,
    false
  )
  f.resolutionCheckBox = resolutionCheckBox

  function addon.UpdatePackSelectedUI()
    local currentPack = addon:GetCurrentPackStashed()
    if not currentPack then
      local packs = addon:GetAllPacksStashed()
      for _, pack in pairs(packs) do
        db.chosenPack = pack.localName
        addon.UpdatePackSelectedUI()
        return
      end
    end

    if not currentPack then
      resolutionDropdown:NoOptionSelected()
      resolutionDropdown:Disable()
      resolutionCheckBox:Disable()
      f.exportAllButton:Disable()
      deletePackButton:Disable()
    else
      resolutionDropdown:Enable()
      addon:RefreshDropdown(resolutionDropdown)
      resolutionCheckBox:Enable()
      resolutionDropdown:Select(currentPack.resolutions.chosen)
      resolutionCheckBox:SetValue(currentPack.resolutions.enabled[currentPack.resolutions.chosen])
      f.exportAllButton:Enable()
      deletePackButton:Enable()
    end
    addon:RefreshDropdown(packDropdown)
    packDropdown:Select(db.chosenPack)
    f.contentScrollbox:Refresh()
    addon:UpdateNoPackLabel()
  end

  function addon.RefreshContentScrollBox()
    f.contentScrollbox:Refresh()
  end

  local resolutionEnabledLabel = DF:CreateLabel(f, "Startup", 16, "white")
  resolutionEnabledLabel:SetText(L["Enable this resolution"])

  -- logo
  local logo = DF:CreateImage(f, [[Interface\AddOns\]] .. addonName .. [[\media\wagoLogo512]], 256, 256)
  logo:SetPoint("TOPRIGHT", f, "TOPRIGHT", -45, 24)

  local slashLabel = DF:CreateLabel(f, "Slash command: |cFFC1272D" .. addon.slashPrefixes[1] .. "|r", 20, "white")
  slashLabel:SetPoint("TOP", logo, "BOTTOM", 0, 25)

  addLine({resolutionDropdown, resolutionCheckBox, resolutionEnabledLabel}, 5, 0)

  -- export explainer
  local exportExplainerLabel = DF:CreateLabel(f, "Startup", 16, "white")
  exportExplainerLabel:SetWidth((width - 40) / 2)
  exportExplainerLabel:SetWordWrap(true)
  exportExplainerLabel:SetText(L["exportExplainerLabel"])
  addLine({exportExplainerLabel}, 5, 0)

  local exportAllButton = LWF:CreateButton(f, 250, 40, L["Save All Profiles"], 16)
  exportAllButton:SetClickFunction(addon.ExportAllProfiles)
  f.exportAllButton = exportAllButton

  local previewButton = LWF:CreateButton(f, 150, 40, L["Preview"], 16)
  previewButton:SetClickFunction(
    function()
      if not WagoUI.framesCreated then
        WagoUI.db.introEnabled = true
        WagoUI.db.introState.currentPage = "WelcomePage"
      end
      WagoUI:ToggleFrame()
      LWF:StartSplitView(addon.frames.mainFrame, WagoUI.frames.mainFrame, true, 30)
    end
  )
  f.previewButton = previewButton

  addLine({exportAllButton, previewButton}, 5, 0, 160)

  local reloadIndicator = DF:CreateButton(f, nil, 40, 40, "", nil, nil, "UI-RefreshButton", nil, nil, nil, nil)
  reloadIndicator:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
  reloadIndicator:SetTooltip(L["RELOAD_HINT"])
  reloadIndicator:SetFrameStrata("DIALOG")
  reloadIndicator:Hide()
  reloadIndicator:SetClickFunction(
    function()
      ReloadUI()
    end
  )

  function addon:ShowReloadIndicator()
    reloadIndicator:Show()
  end

  local widths = {
    options = 60,
    name = 450,
    profile = 200,
    lastUpdate = 150
    -- export = 200,
  }
  local totalHeaderWidth = 0
  for _, w in pairs(widths) do
    totalHeaderWidth = totalHeaderWidth + w
  end

  local headerTable = {
    {text = L["Options"], width = widths.options, offset = 1},
    {text = L["Name"], width = widths.name},
    {text = L["Profile to Save"], width = widths.profile},
    {text = L["Last Save"], width = width - totalHeaderWidth + widths.lastUpdate}
    -- { text = L["Export"],          width = width - totalHeaderWidth + widths.export },
  }
  local lineHeight = 42
  local contentScrollbox =
    DF:CreateScrollBox(
    f,
    nil,
    contentScrollboxUpdate,
    {},
    width - 17,
    height - totalHeight + 4,
    0,
    lineHeight,
    createScrollLine,
    true
  )
  f.contentHeader = DF:CreateHeader(f, headerTable, nil, addonName .. "ContentHeader")
  f.contentScrollbox = contentScrollbox
  addLine({f.contentHeader}, 0, 0)
  contentScrollbox:SetPoint("TOPLEFT", f.contentHeader, "BOTTOMLEFT")
  contentScrollbox.ScrollBar.scrollStep = 60
  DF:ReskinSlider(contentScrollbox)
  contentScrollbox.ScrollBar.ScrollUpButton.Highlight:ClearAllPoints(false)
  contentScrollbox.ScrollBar.ScrollDownButton.Highlight:ClearAllPoints(false)

  local noPacksContainer = CreateFrame("Frame", nil, f)
  noPacksContainer:SetSize(width, height)
  noPacksContainer:SetAllPoints(contentScrollbox)
  f.noPacksContainer = noPacksContainer
  local noPacksLabel = DF:CreateLabel(noPacksContainer, L["Create a new pack to start"], 40, "grey")
  noPacksLabel:SetTextColor(0.5, 0.5, 0.5, 1)
  noPacksLabel:SetJustifyH("CENTER")
  noPacksLabel:SetPoint("CENTER", noPacksContainer, "CENTER", 0, 33)

  function addon:UpdateNoPackLabel()
    if addon:GetCurrentPackStashed() then
      noPacksContainer:Hide()
    else
      noPacksContainer:Show()
    end
  end

  addon.ModuleFunctions:SortModuleConfigs()
  contentScrollbox:SetData(addon.moduleConfigs)
  contentScrollbox:Refresh()
  addon.UpdatePackSelectedUI()
  -- TODO:
  -- hooksecurefunc(contentScrollbox, "Refresh", function()
  --   addon:RefreshAllProfileDropdowns()
  -- end)
  addon.contentScrollbox = contentScrollbox
end
