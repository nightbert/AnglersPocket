local addonName = ...

local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
local GetItemCount = (C_Item and C_Item.GetItemCount) or GetItemCount

local GetSpellName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
local GetSpellTexture = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture

local GetCVar = (C_CVar and C_CVar.GetCVar) or GetCVar
local SetCVar = (C_CVar and C_CVar.SetCVar) or SetCVar

local FISHING_SPELL_ID = 7620
local ITEM_CLASS_WEAPON = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon)
  or LE_ITEM_CLASS_WEAPON
  or 2
local ITEM_SUBCLASS_FISHING_POLE = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole)
  or LE_ITEM_WEAPON_FISHINGPOLE
  or 20

local BAIT_ITEMS = {
  -- Classic
  6529, -- Shiny Bauble
  6530, -- Nightcrawlers
  6532, -- Bright Baubles
  6533, -- Aquadynamic Fish Attractor
  6811, -- Aquadynamic Fish Lens
  7307, -- Flesh Eating Worm

  -- The Burning Crusade
  34861, -- Sharpened Fish Hook

  -- Wrath of the Lich King
  46006, -- Glow Worm

  -- Cataclysm
  62673, -- Feathered Lure
  67404, -- Glass Fishing Bobber
  68049, -- Heat-Treated Spinning Lure

}

local TIMER_INTERVAL = 0.5
local TIMER_WARNING_SECONDS = 60

local SIZE_MIN, SIZE_MAX, SIZE_STEP = 24, 64, 2
local BAIT_SCALE = 0.75
local GLOW_SCALE = 1.75

local SOUND_SETTINGS = {
  { key = "sfx", cvar = "Sound_SFXVolume", label = "Effects volume" },
  { key = "music", cvar = "Sound_MusicVolume", label = "Music volume" },
  { key = "ambience", cvar = "Sound_AmbienceVolume", label = "Ambience volume" },
}

local BAIT_DIRECTIONS = {
  { key = "down", label = "Below", point = "TOP", relPoint = "BOTTOM", x = 0, y = -2 },
  { key = "up", label = "Above", point = "BOTTOM", relPoint = "TOP", x = 0, y = 2 },
  { key = "left", label = "Left", point = "RIGHT", relPoint = "LEFT", x = -2, y = 0 },
  { key = "right", label = "Right", point = "LEFT", relPoint = "RIGHT", x = 2, y = 0 },
}

local defaults = {
  locked = true,
  baitGlow = false,
  baitDirection = "down",
  loginMessage = true,
  autoLoot = false,
  fishingSound = {
    enabled = false,
    sfx = 1,
    music = 0,
    ambience = 0.3,
  },
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
local pendingLayout = false

local UpdateBaitTimer
local UpdateBaitButtons

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
  if AnglersPocketDB.baitDirection == nil and AnglersPocketDB.horizontal ~= nil then
    AnglersPocketDB.baitDirection = AnglersPocketDB.horizontal and "right" or "down"
  end
  AnglersPocketDB.horizontal = nil
  db = ApplyDefaults(AnglersPocketDB, defaults)
end

local function GetBaitDirectionIndex()
  for index, direction in ipairs(BAIT_DIRECTIONS) do
    if direction.key == db.baitDirection then
      return index
    end
  end
  return 1
end

local function IsFishingPoleEquipped()
  local itemId = GetInventoryItemID("player", 16)
  if not itemId then
    return false
  end

  local _, _, _, _, _, classId, subClassId = GetItemInfoInstant(itemId)
  return classId == ITEM_CLASS_WEAPON and subClassId == ITEM_SUBCLASS_FISHING_POLE
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

local function ResetPosition()
  for key, value in pairs(defaults.position) do
    db.position[key] = value
  end
  ApplyPosition()
end

local function FormatVolume(value)
  return string.format("%.2f", value)
end

local function UpdateFishingSound(forceRestore)
  if not db then
    return
  end

  local settings = db.fishingSound
  local active = not forceRestore and settings.enabled and IsFishingPoleEquipped()

  if active then
    if not db.savedVolumes then
      local saved = {}
      for _, entry in ipairs(SOUND_SETTINGS) do
        saved[entry.cvar] = GetCVar(entry.cvar)
      end
      db.savedVolumes = saved
    end
    for _, entry in ipairs(SOUND_SETTINGS) do
      if db.savedVolumes[entry.cvar] then
        SetCVar(entry.cvar, FormatVolume(settings[entry.key]))
      end
    end
  elseif db.savedVolumes then
    for _, entry in ipairs(SOUND_SETTINGS) do
      local original = db.savedVolumes[entry.cvar]
      local current = tonumber(GetCVar(entry.cvar))
      if original and current and math.abs(current - settings[entry.key]) < 0.01 then
        SetCVar(entry.cvar, original)
      end
    end
    db.savedVolumes = nil
  end
end

local function UpdateAutoLoot(forceRestore)
  if not db then
    return
  end

  local active = not forceRestore and db.autoLoot and IsFishingPoleEquipped()

  if active then
    if db.savedAutoLoot == nil then
      db.savedAutoLoot = GetCVar("autoLootDefault")
    end
    SetCVar("autoLootDefault", "1")
  elseif db.savedAutoLoot ~= nil then
    if GetCVar("autoLootDefault") == "1" then
      SetCVar("autoLootDefault", db.savedAutoLoot)
    end
    db.savedAutoLoot = nil
  end
end

local function ApplyLayout()
  if not button then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    pendingLayout = true
    return
  end

  pendingLayout = false
  button:SetSize(db.size, db.size)
  local baitSize = db.size * BAIT_SCALE
  for _, baitButton in ipairs(baitButtons) do
    baitButton:SetSize(baitSize, baitSize)
    baitButton.glow:SetSize(baitSize * GLOW_SCALE, baitSize * GLOW_SCALE)
  end
  UpdateBaitButtons()
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
    local spellName = GetSpellName(FISHING_SPELL_ID)
    if spellName then
      button:SetAttribute("spell", spellName)
      button.preview = false
      button.icon:SetDesaturated(false)
      button:Show()
      UpdateBaitTimer()
      return
    end
  end

  button:SetAttribute("spell", nil)
  if not db.locked then
    button.preview = true
    button.icon:SetDesaturated(true)
    button:Show()
    UpdateBaitTimer()
    return
  end
  button:Hide()
end

local function SetLocked(locked)
  db.locked = locked and true or false
  UpdateButton()
  UpdateBaitButtons()
end

local function FormatTimeLeft(seconds)
  if seconds >= TIMER_WARNING_SECONDS then
    return string.format("%dm", math.ceil(seconds / 60))
  end
  return string.format("%ds", math.ceil(seconds))
end

local function SetBaitGlow(show)
  for _, baitButton in ipairs(baitButtons) do
    local glow = baitButton.glow
    if show then
      if not glow:IsShown() then
        glow:Show()
        if glow.pulse then
          glow.pulse:Play()
        end
      end
    elseif glow:IsShown() then
      if glow.pulse then
        glow.pulse:Stop()
      end
      glow:Hide()
    end
  end
end

UpdateBaitTimer = function()
  if not button or not button.timer then
    return
  end

  local active = button:IsShown() and not button.preview
  local timeLeftMs
  if active then
    local hasMainHandEnchant, mainHandTimeLeft = GetWeaponEnchantInfo()
    if hasMainHandEnchant and mainHandTimeLeft and mainHandTimeLeft > 0 then
      timeLeftMs = mainHandTimeLeft
    end
  end

  if timeLeftMs then
    local seconds = timeLeftMs / 1000
    button.timer:SetText(FormatTimeLeft(seconds))
    if seconds < TIMER_WARNING_SECONDS then
      button.timer:SetTextColor(1, 0.2, 0.2)
    else
      button.timer:SetTextColor(1, 1, 1)
    end
    button.timer:Show()
  else
    button.timer:Hide()
  end

  SetBaitGlow(db.baitGlow and active and not timeLeftMs)
end

local function PositionBaitButtons(visibleButtons)
  local direction = BAIT_DIRECTIONS[GetBaitDirectionIndex()]
  local anchor = button
  for _, baitButton in ipairs(visibleButtons) do
    baitButton:ClearAllPoints()
    baitButton:SetPoint(direction.point, anchor, direction.relPoint, direction.x, direction.y)
    anchor = baitButton
  end
end

local function SetBaitCount(baitButton, count)
  baitButton.count:SetText(count > 1 and count or "")
  baitButton.icon:SetDesaturated(count == 0)
end

UpdateBaitButtons = function()
  if #baitButtons == 0 then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    pendingBaitUpdate = true
    for _, baitButton in ipairs(baitButtons) do
      if baitButton.itemId then
        SetBaitCount(baitButton, GetItemCount(baitButton.itemId) or 0)
      end
    end
    return
  end

  pendingBaitUpdate = false
  if not button or not button:IsShown() then
    for _, baitButton in ipairs(baitButtons) do
      baitButton.itemId = nil
      baitButton:Hide()
    end
    UpdateBaitTimer()
    return
  end

  local visibleButtons = {}
  for index, itemId in ipairs(BAIT_ITEMS) do
    local baitButton = baitButtons[index]
    local count = GetItemCount(itemId)
    if count and count > 0 then
      baitButton.itemId = itemId
      baitButton.icon:SetTexture(GetItemIconById(itemId) or "Interface/Icons/INV_Misc_QuestionMark")
      SetBaitCount(baitButton, count)
      baitButton:SetAttribute("macrotext", string.format("/use item:%d\n/use 16", itemId))
      baitButton:Show()
      visibleButtons[#visibleButtons + 1] = baitButton
    else
      baitButton.itemId = nil
      SetBaitCount(baitButton, 0)
      baitButton:SetAttribute("macrotext", nil)
      baitButton:Hide()
    end
  end

  PositionBaitButtons(visibleButtons)
  UpdateBaitTimer()
end

local function CreateButton()
  if button then
    return
  end

  button = CreateFrame("Button", "AnglersPocketButton", UIParent, "SecureActionButtonTemplate")
  button:SetSize(db.size, db.size)
  button:SetAttribute("type", "spell")
  button:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
  button:SetMovable(true)
  button:RegisterForDrag("LeftButton")
  button:EnableMouse(true)

  button.icon = button:CreateTexture(nil, "ARTWORK")
  button.icon:SetAllPoints()
  button.icon:SetTexture(GetSpellTexture(FISHING_SPELL_ID) or "Interface/Icons/Trade_Fishing")

  button.timer = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  button.timer:SetPoint("BOTTOMRIGHT", -2, 2)
  button.timer:Hide()

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
      local spellName = GetSpellName(FISHING_SPELL_ID) or "Fishing"
      GameTooltip:SetText(spellName)
    end
    if not db.locked then
      GameTooltip:AddLine("Drag to move. Lock the button in the config window (/ap).", 0.6, 0.8, 1, true)
    end
    GameTooltip:Show()
  end)

  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local ticker = CreateFrame("Frame", nil, button)
  local sinceLastTick = 0
  ticker:SetScript("OnUpdate", function(_, elapsed)
    sinceLastTick = sinceLastTick + elapsed
    if sinceLastTick >= TIMER_INTERVAL then
      sinceLastTick = 0
      UpdateBaitTimer()
    end
  end)

  ApplyPosition()
  UpdateButton()
end

local function CreateBaitButtons()
  if #baitButtons > 0 then
    return
  end

  local baitSize = db.size * BAIT_SCALE
  for index = 1, #BAIT_ITEMS do
    local baitButton = CreateFrame(
      "Button",
      "AnglersPocketBaitButton" .. index,
      UIParent,
      "SecureActionButtonTemplate"
    )
    baitButton:SetSize(baitSize, baitSize)
    baitButton:SetAttribute("type", "macro")
    baitButton:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonDown", "RightButtonUp")
    baitButton:EnableMouse(true)

    baitButton.icon = baitButton:CreateTexture(nil, "ARTWORK")
    baitButton.icon:SetAllPoints()
    baitButton.icon:SetTexture("Interface/Icons/INV_Misc_QuestionMark")

    baitButton.count = baitButton:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    baitButton.count:SetPoint("BOTTOMRIGHT", -2, 2)
    baitButton.count:SetText("")

    baitButton:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")

    local glow = baitButton:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface/Buttons/UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, 0.82, 0)
    glow:SetSize(baitSize * GLOW_SCALE, baitSize * GLOW_SCALE)
    glow:SetPoint("CENTER")
    glow:Hide()
    if glow.CreateAnimationGroup then
      local pulse = glow:CreateAnimationGroup()
      pulse:SetLooping("BOUNCE")
      local fade = pulse:CreateAnimation("Alpha")
      if fade.SetFromAlpha then
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.3)
      end
      fade:SetDuration(0.6)
      glow.pulse = pulse
    end
    baitButton.glow = glow

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

local function CreateCheckbox(parent, labelText, onClick)
  local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  check:SetScript("OnClick", function(self)
    onClick(self:GetChecked() and true or false)
  end)

  local label = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("LEFT", check, "RIGHT", 4, 0)
  label:SetText(labelText)
  return check
end

local function CreateSlider(parent, labelText, minValue, maxValue, step, formatValue, onChange)
  local slider = CreateFrame("Slider", nil, parent)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(270, 16)
  slider:SetMinMaxValues(minValue, maxValue)
  slider:SetValueStep(step)
  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end
  slider:EnableMouse(true)

  local track = slider:CreateTexture(nil, "BACKGROUND")
  if track.SetColorTexture then
    track:SetColorTexture(0.15, 0.15, 0.15, 0.7)
  else
    track:SetTexture(0.15, 0.15, 0.15, 0.7)
  end
  track:SetPoint("LEFT", 10, 0)
  track:SetPoint("RIGHT", -10, 0)
  track:SetHeight(6)

  slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")
  local thumb = slider:GetThumbTexture()
  if thumb then
    thumb:SetSize(32, 32)
  end

  local label = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 2)
  label:SetText(labelText)

  local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 2)

  slider:SetScript("OnValueChanged", function(self, value)
    value = math.floor(value / step + 0.5) * step
    valueText:SetText(formatValue(value))
    if not self.silent then
      onChange(value)
    end
  end)

  function slider:SetValueSilently(value)
    self.silent = true
    self:SetValue(value)
    self.silent = false
    valueText:SetText(formatValue(value))
  end

  return slider
end

local function FormatPercent(value)
  return string.format("%d%%", value)
end

local BINDING_COMMAND = "CLICK AnglersPocketButton:LeftButton"
local MODIFIER_KEYS = {
  LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
  LALT = true, RALT = true, LMETA = true, RMETA = true, UNKNOWN = true,
}

local function GetFishingKeyText()
  return GetBindingKey(BINDING_COMMAND) or "Not bound"
end

local function BuildKeyString(key)
  local prefix = ""
  if IsAltKeyDown() then
    prefix = prefix .. "ALT-"
  end
  if IsControlKeyDown() then
    prefix = prefix .. "CTRL-"
  end
  if IsShiftKeyDown() then
    prefix = prefix .. "SHIFT-"
  end
  return prefix .. key
end

local function SetFishingKey(key)
  if InCombatLockdown and InCombatLockdown() then
    print("Angler's Pocket: key bindings cannot be changed in combat.")
    return
  end

  for _, oldKey in ipairs({ GetBindingKey(BINDING_COMMAND) }) do
    SetBinding(oldKey)
  end

  if key then
    local previousAction = GetBindingAction(key)
    if SetBinding(key, BINDING_COMMAND) then
      if previousAction and previousAction ~= "" and previousAction ~= BINDING_COMMAND then
        print(string.format("Angler's Pocket: %s now casts Fishing (was: %s).", key, previousAction))
      end
    else
      print(string.format("Angler's Pocket: %s could not be bound.", key))
    end
  end

  SaveBindings(GetCurrentBindingSet())
end

local function CreateConfigFrame()
  if configFrame then
    return
  end

  configFrame = CreateFrame("Frame", "AnglersPocketConfig", UIParent, "BasicFrameTemplateWithInset")
  configFrame:SetSize(320, 545)
  configFrame:SetPoint("CENTER")
  configFrame:SetMovable(true)
  configFrame:SetClampedToScreen(true)
  configFrame:EnableMouse(true)
  configFrame:RegisterForDrag("LeftButton")
  configFrame:SetScript("OnDragStart", configFrame.StartMoving)
  configFrame:SetScript("OnDragStop", configFrame.StopMovingOrSizing)
  configFrame:Hide()

  local title = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  if configFrame.TitleBg then
    title:SetPoint("LEFT", configFrame.TitleBg, "LEFT", 8, 0)
  else
    title:SetPoint("TOPLEFT", 12, -8)
  end
  title:SetText("Angler's Pocket")

  local info = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  info:SetPoint("TOPLEFT", 12, -30)
  info:SetWidth(290)
  info:SetJustifyH("LEFT")

  local function CreateHeader(text)
    local header = configFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    header:SetText(text)
    return header
  end

  local generalHeader = CreateHeader("General")
  generalHeader:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 2, -4)

  local unlock = CreateCheckbox(configFrame, "Unlock button", function(checked)
    SetLocked(not checked)
  end)
  unlock:SetPoint("TOPLEFT", generalHeader, "BOTTOMLEFT", 4, -2)

  local loginMessageCheck = CreateCheckbox(configFrame, "Show chat message at login", function(checked)
    db.loginMessage = checked
  end)
  loginMessageCheck:SetPoint("TOPLEFT", unlock, "BOTTOMLEFT", 0, 2)

  local buttonHeader = CreateHeader("Button")
  buttonHeader:SetPoint("TOPLEFT", loginMessageCheck, "BOTTOMLEFT", -4, -8)

  local sizeSlider = CreateSlider(configFrame, "Button size", SIZE_MIN, SIZE_MAX, SIZE_STEP, tostring, function(value)
    db.size = value
    ApplyLayout()
  end)
  sizeSlider:SetPoint("TOPLEFT", buttonHeader, "BOTTOMLEFT", 10, -22)

  local baitLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  baitLabel:SetPoint("TOPLEFT", sizeSlider, "BOTTOMLEFT", 0, -14)
  baitLabel:SetText("Bait position:")

  local glowCheck = CreateCheckbox(configFrame, "Highlight baits when none is applied", function(checked)
    db.baitGlow = checked
    UpdateBaitTimer()
  end)
  glowCheck:SetPoint("TOPLEFT", baitLabel, "BOTTOMLEFT", -6, -10)

  local fishingHeader = CreateHeader("Fishing")
  fishingHeader:SetPoint("TOPLEFT", glowCheck, "BOTTOMLEFT", -4, -8)

  local keyLabel = configFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  keyLabel:SetPoint("TOPLEFT", fishingHeader, "BOTTOMLEFT", 10, -14)
  keyLabel:SetText("Cast key:")

  local autoLootCheck = CreateCheckbox(configFrame, "Auto loot with pole equipped", function(checked)
    db.autoLoot = checked
    UpdateAutoLoot()
  end)
  autoLootCheck:SetPoint("TOPLEFT", keyLabel, "BOTTOMLEFT", -6, -10)

  local buttonOffset = math.max(keyLabel:GetStringWidth(), baitLabel:GetStringWidth()) + 8

  local keyButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
  keyButton:SetSize(150, 22)
  keyButton:SetPoint("LEFT", keyLabel, "LEFT", buttonOffset, 0)
  keyButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  local baitDropdown = CreateFrame("DropdownButton", nil, configFrame, "WowStyle1DropdownTemplate")
  baitDropdown:SetWidth(150)
  baitDropdown:SetPoint("LEFT", baitLabel, "LEFT", buttonOffset, 0)

  local baitEntries = {}
  for _, direction in ipairs(BAIT_DIRECTIONS) do
    baitEntries[#baitEntries + 1] = { direction.label, direction.key }
  end

  MenuUtil.CreateRadioMenu(baitDropdown, function(key)
    return db.baitDirection == key
  end, function(key)
    db.baitDirection = key
    ApplyLayout()
  end, unpack(baitEntries))

  local function StopKeyCapture()
    keyButton.capturing = false
    keyButton:EnableKeyboard(false)
    keyButton:SetText(GetFishingKeyText())
  end

  keyButton:SetScript("OnClick", function(self, mouseButton)
    if mouseButton == "RightButton" then
      SetFishingKey(nil)
      StopKeyCapture()
    elseif self.capturing then
      StopKeyCapture()
    else
      self.capturing = true
      self:EnableKeyboard(true)
      self:SetText("Press a key...")
    end
  end)

  keyButton:SetScript("OnKeyDown", function(self, key)
    if not self.capturing or MODIFIER_KEYS[key] then
      return
    end
    if key ~= "ESCAPE" then
      SetFishingKey(BuildKeyString(key))
    end
    StopKeyCapture()
  end)

  keyButton:SetScript("OnHide", StopKeyCapture)

  keyButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Cast key")
    GameTooltip:AddLine("Left-click, then press a key (with Shift/Ctrl/Alt if you like). Escape cancels. Right-click removes the binding.", 1, 1, 1, true)
    GameTooltip:Show()
  end)

  keyButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  local soundHeader = CreateHeader("Sound while fishing")
  soundHeader:SetPoint("TOPLEFT", autoLootCheck, "BOTTOMLEFT", -4, -8)

  local soundSliders = {}
  local function UpdateSoundSlidersAlpha()
    for _, slider in ipairs(soundSliders) do
      slider:SetAlpha(db.fishingSound.enabled and 1 or 0.4)
    end
  end

  local soundCheck = CreateCheckbox(configFrame, "Adjust volumes with pole equipped", function(checked)
    db.fishingSound.enabled = checked
    UpdateSoundSlidersAlpha()
    UpdateFishingSound()
  end)
  soundCheck:SetPoint("TOPLEFT", soundHeader, "BOTTOMLEFT", 4, -2)

  local anchor = soundCheck
  for index, entry in ipairs(SOUND_SETTINGS) do
    local slider = CreateSlider(configFrame, entry.label, 0, 100, 5, FormatPercent, function(value)
      db.fishingSound[entry.key] = value / 100
      UpdateFishingSound()
    end)
    slider:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", index == 1 and 6 or 0, -23)
    slider.settingKey = entry.key
    soundSliders[#soundSliders + 1] = slider
    anchor = slider
  end

  local resetButton = CreateFrame("Button", nil, configFrame, "UIPanelButtonTemplate")
  resetButton:SetSize(120, 22)
  resetButton:SetPoint("BOTTOMLEFT", 12, 12)
  resetButton:SetText("Reset position")
  resetButton:SetScript("OnClick", function()
    ResetPosition()
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
    glowCheck:SetChecked(db.baitGlow)
    baitDropdown:GenerateMenu()
    autoLootCheck:SetChecked(db.autoLoot)
    loginMessageCheck:SetChecked(db.loginMessage)
    StopKeyCapture()
    sizeSlider:SetValueSilently(db.size)
    soundCheck:SetChecked(db.fishingSound.enabled)
    for _, slider in ipairs(soundSliders) do
      slider:SetValueSilently(math.floor(db.fishingSound[slider.settingKey] * 100 + 0.5))
    end
    UpdateSoundSlidersAlpha()
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
  elseif msg == "glow" then
    db.baitGlow = not db.baitGlow
    UpdateBaitTimer()
    print("Angler's Pocket: bait highlight " .. (db.baitGlow and "enabled" or "disabled"))
    if configFrame and configFrame:IsShown() then
      configFrame:GetScript("OnShow")(configFrame)
    end
  elseif msg == "reset" then
    ResetPosition()
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
events:RegisterEvent("PLAYER_LOGOUT")

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
    UpdateFishingSound()
    UpdateAutoLoot()
    if event == "PLAYER_LOGIN" and db.loginMessage then
      print("Angler's Pocket loaded. Type /ap for options.")
    end
    return
  end

  if event == "PLAYER_EQUIPMENT_CHANGED" then
    local slotId = arg1
    if slotId == 16 then
      UpdateButton()
      UpdateBaitButtons()
      UpdateFishingSound()
      UpdateAutoLoot()
    end
    return
  end

  if event == "PLAYER_LOGOUT" then
    UpdateFishingSound(true)
    UpdateAutoLoot(true)
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
    if pendingLayout then
      ApplyLayout()
    elseif pendingBaitUpdate then
      UpdateBaitButtons()
    end
  end
end)
