--[[
AdiDebug - Adirelle's debug frame.
Copyright 2010 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local db

local currentKey

local frame, messageArea, selector, scrollBar, currentNow

local safetyLock

local function UpdateScrollBar()
	if GameTooltip:GetOwner() == messageArea then
		GameTooltip:Hide()
	end
	if safetyLock then return end
	local numMessages, displayed = messageArea:GetNumMessages(), messageArea:GetNumLinesDisplayed()
	local newMax = max(0, numMessages - displayed)
	if newMax > 0 then
		safetyLock = true
		if newMax ~= select(2, scrollBar:GetMinMaxValues()) then
			scrollBar:SetMinMaxValues(0, newMax)
		end
		local offset = max(0, newMax - messageArea:GetCurrentScroll())
		if offset ~= scrollBar:GetValue() then
			scrollBar:SetValue(offset)
		end
		safetyLock = false
		if not scrollBar:IsShown() then
			scrollBar:Show()
		end
	elseif scrollBar:IsShown() then
		scrollBar:Hide()
	end
end

local function AddMessage(name, now, text)
	if not db.profile.names[currentKey][name] then
		return
	end
	if GameTooltip:GetOwner() == messageArea then
		GameTooltip:Hide()
	end	
	if now ~= currentNow then
		messageArea:AddMessage(strjoin("", "----- ", date("%X", now), strsub(format("%.3f", now % 1), 2)), 0.6, 0.6, 0.6)
		currentNow = now
	end
	messageArea:AddMessage(text)
end

local function RefreshMessages()
	messageArea:Clear()
	currentNow = nil
	if currentKey then
		local m = AdiDebug.messages[currentKey]
		for i = 1, #m do
			AddMessage(unpack(m[i]))
		end
	end
	UpdateScrollBar()
end

local function SelectKey(key)
	if currentKey ~= key then
		currentKey = key
		db.profile.key = currentKey
		selector.text:SetText(currentKey or "")
		RefreshMessages()
	end
end

local GetTableHyperlinkTable = AdiDebug.GetTableHyperlinkTable
local PrettyFormat = AdiDebug.PrettyFormat

local function ShowFrameTooltip(frame)
	GameTooltip:AddDoubleLine("Type:", PrettyFormat(frame:GetObjectType()))
	GameTooltip:AddDoubleLine("Parent:", PrettyFormat(frame:GetParent()))
	if frame:IsObjectType("Region") then
		GameTooltip:AddDoubleLine("Protected:", PrettyFormat(not not frame:IsProtected()))
		local top, bottom, width, height = frame:GetRect()
		GameTooltip:AddDoubleLine("Bottom left:", format("%g,%g", top, bottom))
		GameTooltip:AddDoubleLine("Size:", format("%g,%g", width, height))
	end
	if frame.GetAlpha and frame.IsShown and frame.IsVisible then -- Duck typing
		GameTooltip:AddDoubleLine("Alpha:", PrettyFormat(frame:GetAlpha()))
		GameTooltip:AddDoubleLine("Shown:", PrettyFormat(not not frame:IsShown()))
		GameTooltip:AddDoubleLine("Visible:", PrettyFormat(not not frame:IsVisible()))
	end
	if frame:IsObjectType("Frame") then
		GameTooltip:AddDoubleLine("Strata:", PrettyFormat(frame:GetFrameStrata()))
		GameTooltip:AddDoubleLine("Level:", PrettyFormat(frame:GetFrameLevel()))
	end
end

local function ShowTableTooltip(value)
	local mt = setmetatable(value, nil)
	GameTooltip:AddDoubleLine("Metatable:", PrettyFormat(mt))
	local n = 0
	for k, v in pairs(value) do
		if n < 10 then
			GameTooltip:AddDoubleLine(PrettyFormat(k), PrettyFormat(v))
		end
		n = n + 1		
	end
	if n >= 10 then
		GameTooltip:AddLine(format("%d more entries", n-10))
	end
	setmetatable(value, mt)
end

local function OnHyperlinkClick(self, data, link)
	GameTooltip:ClearLines()
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	local linkType, linkData = strsplit(':', data, 2)
	local ownLink = strmatch(linkType, '^AdiDebug(%w+)$')
	if ownLink then
		GameTooltip:AddDoubleLine(ownLink, link)
		local value = GetTableHyperlinkTable(link)
		if value then
			if ownLink == "Table" then
				ShowTableTooltip(value)
			else
				ShowFrameTooltip(value)
			end
		else
			GameTooltip:AddLine("Has been collected")
		end
	else
		GameTooltip:SetHyperlink(link)
	end
	GameTooltip:Show()
end

local function OnHyperlinkEnter(self, data, link)
	GameTooltip:ClearLines()
	GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
	GameTooltip:AddLine(link)
	local linkType, linkData = strsplit(':', data, 2)
	local ownLink = strmatch(linkType, '^AdiDebug(%w+)$')
	if ownLink then
		GameTooltip:AddDoubleLine("Type:", ownLink)
	else
		GameTooltip:AddDoubleLine("Type:", linkType)
	end
	GameTooltip:AddDoubleLine("Data:", linkData)
	GameTooltip:Show()
end

local function KeyEntry_IsChecked(button)
	return currentKey and button.value == currentKey
end

local function KeyEntry_OnClick(button)
	SelectKey(button.value)
end

local function NameEntry_IsChecked(button)
	return db.profile.names[button.arg1][button.value]
end

local function NameEntry_OnClick(button, key, _, checked)
	db.profile.names[button.arg1][button.value] = checked
	if key == currentKey then
		RefreshMessages()
	end
end

local list = {}
local function Selector_Initialize(frame, level, menuList)
	wipe(list)
	if level == 1 then
		for key in pairs(AdiDebug.messages) do
			tinsert(list, key)
		end
		table.sort(list)
		for i, key in ipairs(list) do
			local opt = UIDropDownMenu_CreateInfo()
			opt.text = key
			opt.value = key
			opt.func = KeyEntry_OnClick
			opt.checked = KeyEntry_IsChecked
			if next(AdiDebug.names[key]) then
				opt.hasArrow = true
			end

			UIDropDownMenu_AddButton(opt, level)
		end
	elseif level == 2 then
		local key = UIDROPDOWNMENU_MENU_VALUE

		for name in pairs(AdiDebug.names[key]) do
			tinsert(list, name)
		end
		table.sort(list)
		tinsert(list, 1, key)

		for i, name in ipairs(list) do
			local opt = UIDropDownMenu_CreateInfo()
			opt.text = name
			opt.value = name
			opt.isNotRadio = true
			opt.func = NameEntry_OnClick
			opt.arg1 = key
			opt.checked = NameEntry_IsChecked
			opt.keepShownOnClick = true
			UIDropDownMenu_AddButton(opt, level)
		end
	end

	local opt = UIDropDownMenu_CreateInfo()
	opt.text = "Close menu"
	opt.notCheckable = true
	UIDropDownMenu_AddButton(opt, level)
end

local function CreateOurFrame()
	db = AdiDebug.db:RegisterNamespace("GUI", {
		profile = {
			point = "TOPLEFT",
			xOffset = 16,
			yOffset = -200,
			width = 640,
			height = 400,
			names = { ['*'] = { ['*'] = true } }
		}
	}, true)

	frame = CreateFrame("Frame", "AdiDebug", UIParent)
	frame:SetBackdrop({
		bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = true, tileSize = 16,
		edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	frame:SetBackdropColor(0,0,0,1)
	frame:SetBackdropBorderColor(1,1,1,1)
	frame:SetSize(db.profile.width, db.profile.height)
	frame:SetPoint(db.profile.point, db.profile.xOffset, db.profile.yOffset)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetToplevel(true)

	frame:EnableMouse(true)
	frame:SetScript('OnMouseDown', function(self)
		if not self.movingOrSizing and IsShiftKeyDown() then
			local x, y = GetCursorPosition()
			local scale = self:GetEffectiveScale()
			local left, bottom, width, height = self:GetRect()
			x, y = (x / scale) - left, (y / scale) - bottom
			local horiz = (x < 16) and "LEFT" or (x > width - 16) and "RIGHT"
			local vert = (y < 16) and "BOTTOM" or (y > height - 16) and "TOP"
			if horiz or vert then
				self:StartSizing(strjoin("", vert or "", horiz or ""))
			else
				self:StartMoving()
			end
			self.movingOrSizing = true
		end
	end)
	frame:SetScript('OnMouseUp', function(self)
		if self.movingOrSizing then
			self.movingOrSizing = nil
			frame:StopMovingOrSizing()
			db.profile.width, db.profile.height = frame:GetSize()
			local _
			_, _, db.profile.point, db.profile.xOffset, db.profile.yOffset = frame:GetPoint()
		end
	end)

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT")
	closeButton:SetScript('OnClick', function() frame:Hide() end)

	selector = CreateFrame("Button", "AdiDebugDropdown", frame, "UIDropDownMenuTemplate")
	selector:SetPoint("TOPLEFT", -12, -4)
	selector:SetWidth(145)
	selector.initialize = Selector_Initialize
	selector.text = _G["AdiDebugDropdownText"]

	messageArea = CreateFrame("ScrollingMessageFrame", nil, frame)
	messageArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -28)
	messageArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 8)
	messageArea:SetFading(false)
	messageArea:SetJustifyH("LEFT")
	messageArea:SetMaxLines(550)
	messageArea:SetFontObject(ChatFontSmall)
	messageArea:SetScript('OnMessageScrollChanged', UpdateScrollBar)
	messageArea:SetScript('OnSizeChanged', UpdateScrollBar)
	messageArea:SetIndentedWordWrap(true)

	messageArea:SetHyperlinksEnabled(true)
	messageArea:SetScript('OnHyperlinkClick', OnHyperlinkClick)
	messageArea:SetScript('OnHyperlinkEnter', OnHyperlinkEnter)
	messageArea:SetScript('OnHyperlinkLeave', GameTooltip_Hide)


	messageArea:EnableMouseWheel(true)
	messageArea:SetScript('OnMouseWheel', function(self, delta)
		local num, displayed = self:GetNumMessages(), self:GetNumLinesDisplayed()
		local step = IsShiftKeyDown() and num or IsControlKeyDown() and displayed or 1
		local current = self:GetCurrentScroll()
		local newOffset = min(max(0, current + step * delta), num - displayed)
		if newOffset ~= current then
			self:SetScrollOffset(newOffset)
			UpdateScrollBar()
		end
	end)

	scrollBar = CreateFrame("Slider", nil, frame, "UIPanelScrollBarTemplate")
	scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -44)
	scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 24)
	scrollBar:SetValueStep(1)
	scrollBar.scrollStep = 3
	frame.SetVerticalScroll = function(_, value)
		if safetyLock then return end
		local _, maxVal = scrollBar:GetMinMaxValues()
		local offset = maxVal - value
		if messageArea:GetCurrentScroll() ~= offset then
			safetyLock = true
			messageArea:SetScrollOffset(offset)
			safetyLock = false
		end
	end
	scrollBar:Hide()

	frame:SetScript('OnShow', UpdateScrollBar)
end

function AdiDebug:Callback(key, ...)
	if key == currentKey then
		AddMessage(...)
		UpdateScrollBar()
	end
end

function AdiDebug:Open(arg)
	if not frame then
		CreateOurFrame()
	elseif not arg and frame:IsShown() then
		frame:Hide()
		return
	end
	if arg and arg ~= "" then
		arg = strlower(arg)
		for key in pairs(AdiDebug.messages) do
			if strlower(key) == arg then
				SelectKey(key)
			end
		end
	elseif db.profile.key and AdiDebug.messages[db.profile.key] then
		SelectKey(db.profile.key)
	end
	frame:Show()
end

AdiDebug.LoadAndOpen = AdiDebug.Open

