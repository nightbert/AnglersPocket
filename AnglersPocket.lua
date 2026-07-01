local addonName = ...

local FISHING_SPELL_ID = 7620
local FISHING_POLES = {
  [6256] = true,
  [6367] = true,
  [6365] = true,
  [6366] = true,
  [19022] = true,
  [19970] = true,
  [25978] = true,
  [12225] = true,
}

local BAIT_ITEMS = {
  6529,
  6530,
  6532,
  6533,
  6811,
  7307,
  34861,
}

local defaults = {
  locked = true,
  size = 36,
  position = {
    point = "CENTER",
    relPoint = "CENTER",
    x = 0,
    y = -200,
  },
}

local db
local button
local baitButtons = {}
local configFrame
local pendingUpdate = false
local pendingBaitUpdate = false

local baitEnchantDuration
local baitLastTimeLeft
local UpdateFishingCooldown

local function ApplyDefaults(destination, source)
  if type(destination) ~= "table" then
    destination = {}
  end

  for key, value in pairs(source) do
    if type(value) == "table" then
      destination[key] = ApplyDefaults(destination[key], value)
    elseif destination[key] == nil then
      destination[key] = value
    end
  end

  return destination
end

local function EnsureDB()
  if type(AnglersPocketDB) ~= "table" then
    if type(FishermansFriendDB) == "table" then
      AnglersPocketDB = FishermansFriendDB
    else
      AnglersPocketDB = {}
    end
  end
  db = ApplyDefaults(AnglersPocketDB, defaults)
end

local function IsFishingPoleEquipped()
  local itemId = GetInventoryItemID("player", 16)
  return itemId and FISHING_POLES[itemId] or false
end

local function GetItemIconById(itemId)
  if not itemId then
    return nil
  end
  if GetItemIcon then
    return GetItemIcon(itemId)
  end
  if GetItemInfoInstant then
    local _, _, _, _, icon = GetItemInfoInstant(itemId)
    return icon
  end
  local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemId)
  return icon
end

local function SavePosition()
  if not button then
    return
  end
  local point, _, relPoint, x, y = button:GetPoint(1)
  if not point then
    return
  end
  db.position.point = point
  db.position.relPoint = relPoint
  db.position.x = math.floor(x + 0.5)
  db.position.y = math.floor(y + 0.5)
end

local function ApplyPosition()
  if not button then
    return
  end
  local pos = db.position
  button:ClearAllPoints()
  button:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
end

local function SetLocked(locked)
  db.locked = locked and true or false
end

local function UpdateButton()
  if not button then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    pendingUpdate = true
    return
  end

  pendingUpdate = false
  if IsFishingPoleEquipped() then
    local spellName = GetSpellInfo(FISHING_SPELL_ID)
    if spellName then
      button:SetAttribute("spell", spellName)
      button:Show()
      UpdateFishingCooldown()
      return
    end
  end

  button:Hide()
end

UpdateFishingCooldown = function()
  if not button or not button:IsShown() then
    if button and button.cooldown then
      button.cooldown:Hide()
    end
    baitEnchantDuration = nil
    baitLastTimeLeft = nil
    return
  end

  local hasMainHandEnchant, timeLeftMs = GetWeaponEnchantInfo()
  if not hasMainHandEnchant or not timeLeftMs or timeLeftMs <= 0 then
    baitEnchantDuration = nil
    baitLastTimeLeft = nil
    button.cooldown:Hide()
    return
  end

  local timeLeft = timeLeftMs / 1000
  if not baitEnchantDuration or not baitLastTimeLeft or timeLeft > baitLastTimeLeft + 2 then
    baitEnchantDuration = timeLeft
  end
  baitLastTimeLeft = timeLeft

  local duration = baitEnchantDuration or timeLeft
  local start = GetTime() - math.max(duration - timeLeft, 0)
  CooldownFrame_Set(button.cooldown, start, duration, true)
  button.cooldown:Show()
end

local function PositionBaitButtons(visibleButtons)
  local anchor = button
  for _, baitButton in ipairs(visibleButtons) do
    baitButton:ClearAllPoints()
    baitButton:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
    anchor = baitButton
  end
end

local function UpdateBaitButtons()
  if #baitButtons == 0 then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    pendingBaitUpdate = true
    return
  end

  pendingBaitUpdate = false
  if not button or not button:IsShown() then
    for _, baitButton in ipairs(baitButtons) do
      baitButton.itemId = nil
      baitButton:Hide()
    end
    UpdateFishingCooldown()
    return
  end

  local visibleButtons = {}
  for index, itemId in ipairs(BAIT_ITEMS) do
    local baitButton = baitButtons[index]
    local count = GetItemCount(itemId)
    if count and count > 0 then
      baitButton.itemId = itemId
      baitButton.icon:SetTexture(GetItemIconById(itemId) or "Interface/Icons/INV_Misc_QuestionMark")
      baitButton.count:SetText(count > 1 and count or "")
      baitButton:SetAttribute("macrotext", string.format("/use item:%d\n/use 16", itemId))
      baitButton:Show()
      visibleButtons[#visibleButtons + 1] = baitButton
    else
      baitButton.itemId = nil
      baitButton.count:SetText("")
      baitButton:SetAttribute("macrotext", nil)
      baitButton:Hide()
    end
  end

  PositionBaitButtons(visibleButtons)
  UpdateFishingCooldown()
end

local function CreateButton()
  if button then
    return
  end

  button = CreateFrame("Button", "AnglersPocketButton", UIParent, "SecureActionButtonTemplate")
  button:SetSize(db.size, db.size)
  button:SetAttribute("type", "spell")
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:SetMovable(true)
  button:RegisterForDrag("LeftButton")
  button:EnableMouse(true)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexture(GetSpellTexture(FISHING_SPELL_ID) or "Interface/Icons/Trade_Fishing")

  button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

  button:SetScript("OnDragStart", function(self)
    if not db.locked then
      self:StartMoving()
    end
  end)

  button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not db.locked then
      SavePosition()
    end
  end)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.SetSpellByID then
      GameTooltip:SetSpellByID(FISHING_SPELL_ID)
    else
      local spellName = GetSpellInfo(FISHING_SPELL_ID) or "Fishing"
      GameTooltip:SetText(spellName)
    end
    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
  button.cooldown:SetAllPoints()
  if button.cooldown.SetHideCountdownNumbers then
    button.cooldown:SetHideCountdownNumbers(false)
  end

  ApplyPosition()
  UpdateButton()
end

local function CreateBaitButtons()
  if #baitButtons > 0 then
    return
  end

  local baitSize = db.size * 0.75
  for index = 1, #BAIT_ITEMS do
    local baitButton = CreateFrame(
      "Button",
      "AnglersPocketBaitButton" .. index,
      UIParent,
      "SecureActionButtonTemplate"
    )
    baitButton:SetSize(baitSize, baitSize)
    baitButton:SetAttribute("type", "macro")
    baitButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    baitButton:EnableMouse(true)

    baitButton.icon = baitButton:CreateTexture(nil, "ARTWORK")
    baitButton.icon:SetAllPoints()
    baitButton.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")

    baitButton.count = baitButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    baitButton.count:SetPoint("BOTTOMRIGHT", -2, 2)
    baitButton.count:SetText("")

    baitButton:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

    baitButton:SetScript("OnEnter", function(self)
      if self.itemId then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. self.itemId)
        GameTooltip:Show()
      end
    end)

    baitButton:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    baitButton:Hide()
    baitButtons[index] = baitButton
  end
end

local function CreateConfigFrame()
  if configFrame then
    return
  end

  configFrame = CreateFrame("Frame", "AnglersPocketConfig", UIParent, "BasicFrameTemplateWithInset")
  configFrame:SetSize(260, 150)
  configFrame:SetPoint("CENTER")
  configFrame:Hide()

  local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOPLEFT", 12, -8)
  title:SetText("Angler's Pocket")

  local info = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  info:SetPoint("TOPLEFT", 12, -30)
  info:SetWidth(230)
  info:SetJustifyH("LEFT")
  info:SetText("Unlock the button to drag it on the screen.")

  local unlock = CreateFrame("CheckButton", nil, configFrame, "UICheckButtonTemplate")
  unlock:SetPoint("TOPLEFT", info, "BOTTOMLEFT", -4, -6)
  unlock:SetScript("OnClick", function(self)
    SetLocked(not self:GetChecked())
  end)

  local unlockLabel = unlock:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  unlockLabel:SetPoint("LEFT", unlock, "RIGHT", 4, 0)
  unlockLabel:SetText("Unlock button")

  local resetButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
  resetButton:SetSize(140, 22)
  resetButton:SetPoint("TOPLEFT", unlock, "BOTTOMLEFT", 4, -8)
  resetButton:SetText("Reset position")
  resetButton:SetScript("OnClick", function()
    db.position.point = defaults.position.point
    db.position.relPoint = defaults.position.relPoint
    db.position.x = defaults.position.x
    db.position.y = defaults.position.y
    ApplyPosition()
  end)

  local closeButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
  closeButton:SetSize(80, 22)
  closeButton:SetPoint("BOTTOMRIGHT", -12, 12)
  closeButton:SetText("Close")
  closeButton:SetScript("OnClick", function()
    configFrame:Hide()
  end)

  configFrame:SetScript("OnShow", function()
    unlock:SetChecked(not db.locked)
  end)
end

SLASH_ANGLERSPOCKET1 = "/ap"
SLASH_ANGLERSPOCKET2 = "/anglerspocket"
SlashCmdList.ANGLERSPOCKET = function(msg)
  msg = string.lower(msg or "")
  if msg == "unlock" then
    SetLocked(false)
    if configFrame then
      configFrame:Show()
    end
  elseif msg == "lock" then
    SetLocked(true)
  elseif msg == "reset" then
    db.position.point = defaults.position.point
    db.position.relPoint = defaults.position.relPoint
    db.position.x = defaults.position.x
    db.position.y = defaults.position.y
    ApplyPosition()
  else
    if not configFrame then
      CreateConfigFrame()
    end
    if configFrame:IsShown() then
      configFrame:Hide()
    else
      configFrame:Show()
    end
  end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("SPELLS_CHANGED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(_, event, arg1, ...)
  if event == "ADDON_LOADED" and arg1 == addonName then
    EnsureDB()
    CreateButton()
    CreateBaitButtons()
    CreateConfigFrame()
    return
  end

  if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
    ApplyPosition()
    UpdateButton()
    UpdateBaitButtons()
    return
  end

  if event == "PLAYER_EQUIPMENT_CHANGED" then
    local slotId = arg1
    if slotId == 16 then
      UpdateButton()
      UpdateBaitButtons()
    end
    return
  end

  if event == "BAG_UPDATE_DELAYED" then
    UpdateBaitButtons()
    return
  end

  if event == "SPELLS_CHANGED" then
    UpdateButton()
    UpdateBaitButtons()
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    if pendingUpdate then
      UpdateButton()
    end
    if pendingBaitUpdate then
      UpdateBaitButtons()
    end
  end
end)
