--[[
	Pet Buddy by Sonaza
	Battle Pet management addon
	
	All rights reserved
	Questions can be sent to temu92@gmail.com
--]]

local ADDON_NAME, SHARED_DATA = ...;
local A = unpack(SHARED_DATA);

local ITEM_BUTTON_CATEGORIES = {
	{
		type = "spell",
		alwaysVisible = true,
		
		items = {
			125439,
		},
	},
	
	{
		type = "item",
		alwaysVisible = true,
		
		items = {
			86143,
		},
	},
	
	{
		type = "item",
		iconTexture = "INTERFACE\\ICONS\\Icon_UpgradeStone_Rare.blp",
		tooltipTitle = "Battle Stones",
		tooltipDescription = "Pet quality upgrade items",
		target = "target",
		
		items = {
			98715,
			92679,
			92675,
			92676,
			92683,
			92678,
			92680,
			92677,
			92681,
			92682,
			92665,
			92741,
		},
	},
	
	{
		type = "item",
		iconTexture = "Interface\\ICONS\\Icon_UpgradeStone_legendary.blp",
		tooltipTitle = "Battle-Training Stones",
		tooltipDescription = "Pet leveling stones",
		target = "target",
		
		items = {
			122457, -- Ultimate stone (patch 6.1)
			116429,
			127755, -- Fel stone 6.2
			116424,
			116422,
			116374,
			116421,
			116416,
			116417,
			116419,
			116420,
			116423,
			116418,
		},
	},
	
	{
		type = "item",
		iconTexture = "Interface\\ICONS\\INV_Misc_Food_53.blp",
		tooltipTitle = "Pet Treats",
		tooltipDescription = "Experience boosting treats",
		target = "target",
		
		items = {
			98112,
			98114,
		},
	},
	
	{
		type = "item",
		iconTexture = "Interface\\ICONS\\INV_Misc_Petbiscuit_01.blp",
		tooltipTitle = "Miscellaneous",
		tooltipDescription = "Other battle pet related items",
		target = "target",
		
		items = {
			71153,
			89906,
			43352,
			43626,
			37431,
			
			-- 37460,
			-- 44820,
		},
	},
};

function A:CheckSameItems(oldItems, newItems)
	for cid, items in pairs(newItems) do
		if(not oldItems[cid]) then
			-- print("Categories are different");
			return false
		end
		
		for i, itemID in pairs(items) do
			if(not oldItems[cid][i] or oldItems[cid][i] ~= itemID) then
				-- if(not oldItems[cid][i]) then print("Different amount of items")
				-- elseif(oldItems[cid][i] ~= itemID) then print("Different items found") end
				
				return false
			end
		end
	end
	
	-- print("Items should be the same");
	return true;
end

function A:UpdateItemButtons()
	if(InCombatLockdown()) then return end
	if(not PetBuddyFrame:IsShown()) then return end
	
	if(not A.previousItems) then
		A.previousItems = {};
	end
	
	local totalItems, extraButtonData = {}, {};
	
	local currentButtonIndex = 1;
	
	for categoryIndex, data in pairs(ITEM_BUTTON_CATEGORIES) do
		local foundItems = {};
		local buttonData = {};
		
		for _, id in pairs(data.items) do
			
			if(data.type == "item") then
				if(GetItemCount(id) > 0 or data.alwaysVisible) then
					tinsert(foundItems, id);
				end
				
			elseif(data.type == "spell") then
				if(IsSpellKnown(id) or data.alwaysVisible) then
					tinsert(foundItems, id);
				end
			end
			
		end
		
		local numFoundItems = #foundItems;
		if(numFoundItems > 0) then
			if(numFoundItems == 1) then
				buttonData = {
					type = data.type,
					actionData = foundItems[1];
					target = data.target,
				};
			elseif(numFoundItems > 1) then
				buttonData = {
					type = "flyout",
					actionData = {
						iconTexture = data.iconTexture,
						tooltipTitle = data.tooltipTitle,
						tooltipDescription = data.tooltipDescription,
						buttons = {},
					};
				};
				
				for _, id in pairs(foundItems) do
					tinsert(buttonData.actionData.buttons, {
						type = data.type,
						actionID = id,
						target = data.target,
					})
				end
			end
			
			totalItems[categoryIndex] = foundItems;
			extraButtonData[currentButtonIndex] = buttonData;
			
			currentButtonIndex = currentButtonIndex + 1;
		end
	end
	
	-- local isSameItems = A:CheckSameItems(A.previousItems, totalItems);
	
	-- if(not isSameItems) then
		for i=1,6 do
			local currentButton = PetBuddyFrameButtons['itemButton' .. i];
			if(currentButton) then currentButton:Hide() end
		end
		
		for currentButtonIndex, buttonData in ipairs(extraButtonData) do
			local currentButton = PetBuddyFrameButtons['itemButton' .. currentButtonIndex];
			PetBuddyFrameButton_Initialize(currentButton, buttonData.type, buttonData.actionData, buttonData.target or nil);
		end
		-- print("Updating buttons")
	-- else
	-- 	-- print("Skipping update because same items");
	-- end
	
	A.previousItems = totalItems;
end

function PetBuddyFrameButtons_OnShow(self)
	self:RegisterEvent("BAG_UPDATE_DELAYED");
	A:UpdateItemButtons();
end

function PetBuddyFrameButtons_OnHide(self)
	self:UnregisterEvent("BAG_UPDATE_DELAYED");
end

function PetBuddyFrameButtons_OnEvent(self, event, ...)
	PetBuddyFlyout_Close();
	A:UpdateItemButtons();
end

function PetBuddyFrameButton_Initialize(self, type, actionData, target)
	self:Show();
	
	-- self.icon:SetTexCoord("0.055", "0.945", "0.055", "0.945")
	
	self.actionType = type;
	self.actionData = actionData;
	
	self:UnregisterAllEvents();
	
	self.Count:SetText("");
	self.icon:SetVertexColor(1, 1, 1);
	
	self:SetScript("PreClick", nil);
	self:SetScript("PostClick", function()
		if(self.actionType ~= "flyout") then
			self:SetChecked(false);
		end
	end);
	
	-- self:SetScript("OnEnter", function()
	-- 	print(self.actionData, target);
	-- end);
	
	self.FlyoutArrow:Hide();
	
	if(self.actionType == "spell") then
		local spellName, _, spellIcon = GetSpellInfo(self.actionData);
		self.icon:SetTexture(spellIcon);
		
		self:SetAttribute("type", "spell");
		self:SetAttribute("unit", target or "player");
		self:SetAttribute("spell", spellName);
		
		-- if(IsSpellKnown(self.actionData) or self.actionData == 125439) then
		if(IsSpellKnown(self.actionData) and IsUsableSpell(self.actionData)) then
			self.icon:SetVertexColor(1, 1, 1);
		else
			self.icon:SetVertexColor(0.55, 0.25, 0.25);
		end
		
		local start, duration, enabled = GetSpellCooldown(self.actionData);
		self.cooldown:SetCooldown(start, duration);
		
		self:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	elseif(self.actionType == "item") then
		local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(self.actionData);
		self.icon:SetTexture(itemTexture);
		
		self:SetAttribute("type", "item");
		self:SetAttribute("unit", target or "player");
		self:SetAttribute("item", itemName);
		
		-- self:SetScript("PreClick", function()
		-- 	print(self.actionData, target, itemName);
		-- end);
		
		local itemCount = GetItemCount(self.actionData);
		if(IsConsumableItem(self.actionData)) then
			self.Count:SetText(itemCount);
		else
			self.Count:SetText("");
		end
		
		if(itemCount > 0 and IsUsableItem(self.actionData)) then
			self.icon:SetVertexColor(1, 1, 1);
		elseif(itemCount > 0 and not IsUsableItem(self.actionData)) then
			self.icon:SetVertexColor(0.55, 0.25, 0.25);
		else
			self.icon:SetVertexColor(0.55, 0.55, 0.55);
		end
		
		local start, duration = GetItemCooldown(self.actionData);
		self.cooldown:SetCooldown(start, duration);
		
		self:RegisterEvent("BAG_UPDATE_DELAYED");
		self:RegisterEvent("BAG_UPDATE_COOLDOWN");
	elseif(self.actionType == "flyout") then
		self.icon:SetTexture(self.actionData.iconTexture);
		
		if(self.actionData.count) then
			self.Count:SetText(self.actionData.count);
		end
		
		self:SetAttribute("type", nil);
		
		self.FlyoutArrow:Show();
		self.FlyoutArrow:ClearAllPoints();
		self.FlyoutArrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -7);
		SetClampedTextureRotation(self.FlyoutArrow, 180);
		
		self.FlyoutBorder:SetSize(47, 47);
		
		self:SetScript("PreClick", function()
			if(PetBuddyFlyout:IsShown() and PetBuddyFlyout.anchorFrame ~= self) then
				PetBuddyFlyout_Close();
			end
			
			if(not PetBuddyFlyout:IsShown()) then
				PetBuddyFlyout_Open(self);
			else
				PetBuddyFlyout_Close();
			end
		end);
	elseif(self.actionType == "custom") then
		self.icon:SetTexture(self.actionData.iconTexture);
		
		if(self.actionData.count) then
			self.Count:SetText(self.actionData.count);
		end
		
		self:SetAttribute("type", nil);
		self:SetScript("PreClick", self.actionData.func);
	else
		self.icon:SetTexture("Interface\\Icons\\inv_misc_toy_02");
		self.icon:SetVertexColor(0.3, 0.3, 0.3);
	end
end

function PetBuddyFlyout_Open(parentButton)
	if(not parentButton) then return false end
	
	PetBuddyFlyout.anchorFrame = parentButton;
	
	PetBuddyFlyout_SetFlyoutButtons(parentButton.actionData.buttons);
	
	parentButton.FlyoutBorder:Show();
	-- parentButton.FlyoutBorderShadow:Show();
	parentButton.FlyoutArrow:SetPoint("BOTTOM", parentButton, "BOTTOM", 0, -10);
	
	-- parentButton:SetChecked(false);
	
	PetBuddyFlyout:SetPoint("TOP", parentButton, "BOTTOM", 0, 0);
	PetBuddyFlyout:Show();
end

function PetBuddyFlyout_Close()
	if(PetBuddyFlyout.anchorFrame) then
		PetBuddyFlyout.anchorFrame:SetChecked(false);
	
		PetBuddyFlyout.anchorFrame.FlyoutBorder:Hide();
		PetBuddyFlyout.anchorFrame.FlyoutArrow:SetPoint("BOTTOM", PetBuddyFlyout.anchorFrame, "BOTTOM", 0, -7);
		
		PetBuddyFlyout.anchorFrame = nil;
	end
	
	PetBuddyFlyout:Hide();
end

function PetBuddyFlyout_CreateFlyoutButton(index)
	local previousButton = _G["PetBuddyFlyoutButton" .. (index-1)];
	if(not previousButton) then return false end
	
	if(_G["PetBuddyFlyoutButton" .. index]) then return _G["PetBuddyFlyoutButton" .. index] end
	
	local button = CreateFrame("Button", "PetBuddyFlyoutButton" .. index, previousButton, "PetBuddyButtonTemplate", index);
	button:ClearAllPoints();
	button:SetPoint("TOP", previousButton, "BOTTOM", 0, -5);
	
	return button;
end

function PetBuddyFlyout_SetFlyoutButtons(buttonData)
	for index = 1, 20 do
		local button = _G['PetBuddyFlyoutButton' .. index];
		if(button) then
			button:Hide();
		end
	end
	
	for index, data in pairs(buttonData) do
		local button = _G['PetBuddyFlyoutButton' .. index];
		if(not button) then
			button = PetBuddyFlyout_CreateFlyoutButton(index);
		end
		
		PetBuddyFrameButton_Initialize(button, data.type, data.actionID, data.target);
		button:Show();
		
		button:SetScript("PostClick", function()
			PetBuddyFlyout_Close();
		end);
	end
end

function PetBuddyFlyout_OnShow(self)
	CloseMenus();
end

function PetBuddyFlyout_OnHide(self)
	PetBuddyFlyout_Close();
end

function PetBuddyFrameButton_OnEvent(self, event, ...)
	if(event == "SPELL_UPDATE_COOLDOWN") then
		local start, duration, enabled = GetSpellCooldown(self.actionData);
		self.cooldown:SetCooldown(start, duration)
	elseif(event == "BAG_UPDATE_DELAYED" and self.type == "item") then
		local itemCount = GetItemCount(self.actionData);
		if(IsConsumableItem(self.actionData)) then
			self.Count:SetText(itemCount);
		else
			self.Count:SetText("");
		end
		
		if(itemCount > 0) then
			self.icon:SetVertexColor(1, 1, 1);
		else
			self.icon:SetVertexColor(0.55, 0.55, 0.55);
		end
	elseif(event == "BAG_UPDATE_COOLDOWN" and self.type == "item") then
		local start, duration = GetItemCooldown(self.actionData);
		self.cooldown:SetCooldown(start, duration);
	end
end

-- function A:IsUnusableSpell(spellID)
	
-- end

function A:IsPlayerInCelestialTournament()
	local name, type, difficulty, _, _, _, _, mapID = GetInstanceInfo();
	return difficulty == 12 and mapID == 1161;
end

function PetBuddyFrameButton_OnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
	
	if(self.actionType == "spell") then
		GameTooltip:SetSpellByID(self.actionData);
		
		if(not IsUsableSpell(self.actionData)) then
			if(A:IsPlayerInCelestialTournament()) then
				GameTooltip:AddLine("Cannot use while in Celestial Tournament.", 1, 0.2, 0.2);
			else
				GameTooltip:AddLine("Cannot use right now.", 1, 0.2, 0.2);
			end
		end
	elseif(self.actionType == "item") then
		GameTooltip:SetItemByID(self.actionData);
		
		if(not IsUsableItem(self.actionData) and GetItemCount(self.actionData) > 0) then
			if(A:IsPlayerInCelestialTournament()) then
				GameTooltip:AddLine("Cannot use while in Celestial Tournament.", 1, 0.2, 0.2);
			else
				GameTooltip:AddLine("Cannot use right now.", 1, 0.2, 0.2);
			end
		end
	elseif(self.actionType == "flyout") then
		GameTooltip:ClearLines();
		GameTooltip:AddLine(self.actionData.tooltipTitle, 1, 1, 1);
		GameTooltip:AddLine(self.actionData.tooltipDescription);
		
		self.FlyoutBorder:Show();
		-- self.FlyoutBorderShadow:Show();
		self.FlyoutArrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -10);
	elseif(self.actionType == "custom") then
		GameTooltip:ClearLines();
		GameTooltip:AddLine(self.actionData.tooltipTitle, 1, 1, 1);
		GameTooltip:AddLine(self.actionData.tooltipDescription);
	end
	
	GameTooltip:Show();
end

function PetBuddyFrameButton_OnLeave(self)
	if(self.actionType == "flyout") then
		if(not PetBuddyFlyout:IsShown() or PetBuddyFlyout.anchorFrame ~= self) then
			self.FlyoutBorder:Hide();
			-- self.FlyoutBorderShadow:Hide();
			self.FlyoutArrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -7);
		end
	end
	
	GameTooltip:Hide();
end

function IsConsumableItem(item)
	local _, _, _, _, _, itemType = GetItemInfo(item);
	return itemType == "Consumable";
end
