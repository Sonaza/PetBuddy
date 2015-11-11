--[[
	Pet Buddy by Sonaza
	Battle Pet management addon
	
	All rights reserved
	Questions can be sent to temu92@gmail.com
--]]

local ADDON_NAME, SHARED_DATA = ...;
local A = unpack(SHARED_DATA);

local PETBUDDY_LOADOUT_TEXT = "Enter a name for current pet loadout:|n|n%s";
local CURRENT_LOADOUT_NAME = nil;

StaticPopupDialogs["PETBUDDY_LOADOUT_ERROR_LOCKED"] = {
	text = "Cannot save loadout: all pet battle slots are not unlocked.",
	button1 = ACCEPT,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

StaticPopupDialogs["PETBUDDY_LOADOUT_ERROR_NOT_FOUND"] = {
	text = "Cannot restore loadout: all saved pets cannot be found.",
	button1 = ACCEPT,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

StaticPopupDialogs["PETBUDDY_LOADOUT_SAVE_EXISTS"] = {
	text = "Another loadout with the same name already exists. Do you want to overwrite?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		local data = self.data;
		if(data.newSave) then
			A:DeleteLoadout(data.name);
			A:SaveLoadout(data.name);
		else
			A:DeleteLoadout(data.name);
			A:RenameLoadout(data.oldName, data.name);
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

StaticPopupDialogs["PETBUDDY_LOADOUT_OVERWRITE"] = {
	text = "Are you sure you want to overwrite \"%s\" with current loadout?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		local name = self.data;
		A:DeleteLoadout(name);
		A:SaveLoadout(name);
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
};

StaticPopupDialogs["PETBUDDY_LOADOUT_RESTORE"] = {
	text = "Are you sure you want to restore loadout \"%s\"?",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		A:RestoreLoadout(self.data);
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1,
};

StaticPopupDialogs["PETBUDDY_LOADOUT_DELETE"] = {
	text = "Are you sure you want to |cffff5555delete|r loadout \"%s\"? The action cannot be undone.",
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		A:DeleteLoadout(self.data);
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1,
};
	
StaticPopupDialogs["PETBUDDY_LOADOUT_SAVE"] = {
	text = "Enter a name for current pet loadout:",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 38,
	OnAccept = function(self)
		local name = string.trim(self.editBox:GetText());
		A:SaveLoadout(name);
	end,
	EditBoxOnEnterPressed = function(self)
		local name = string.trim(self:GetParent().editBox:GetText());
		A:SaveLoadout(name);
		self:GetParent():Hide();
	end,
	OnShow = function(self)
		self.editBox:SetFocus();
	end,
	OnHide = function(self)
		ChatEdit_FocusActiveWindow();
		self.editBox:SetText("");
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1,
};
	
StaticPopupDialogs["PETBUDDY_LOADOUT_RENAME"] = {
	text = "Enter a new name for the loadout:",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 38,
	OnAccept = function(self)
		local new_name = string.trim(self.editBox:GetText());
		A:RenameLoadout(self.data, new_name);
	end,
	EditBoxOnEnterPressed = function(self)
		local new_name = string.trim(self:GetParent().editBox:GetText());
		A:RenameLoadout(self:GetParent().data, new_name);
		self:GetParent():Hide();
	end,
	OnShow = function(self)
		self.editBox:SetText(self.data);
		self.editBox:SetFocus();
	end,
	OnHide = function(self)
		ChatEdit_FocusActiveWindow();
		self.editBox:SetText("");
	end,
	timeout = 0,
	exclusive = 1,
	whileDead = 1,
	hideOnEscape = 1,
};

function A:GetPetLoadoutText(saved_loadout)
	local loadoutText = "";
	for slotIndex = 1, 3 do
		local petID, ability1, ability2, ability3, locked;
		
		if(not saved_loadout) then
			petID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
		elseif(saved_loadout[slotIndex].petID and saved_loadout[slotIndex].abilities) then
			petID = saved_loadout[slotIndex].petID;
			ability1, ability2, ability3 = unpack(saved_loadout[slotIndex].abilities);
			locked = false;
		end
		
		local petString;
		
		if(petID and C_PetJournal.GetPetInfoByPetID(petID)) then
			local speciesID, customName, level, _, _, _, _, speciesName, _, petType = C_PetJournal.GetPetInfoByPetID(petID);
			local health, maxHealth, _, _, rarity = C_PetJournal.GetPetStats(petID);
			
			local ability1_name = C_PetJournal.GetPetAbilityInfo(ability1);
			local ability2_name = C_PetJournal.GetPetAbilityInfo(ability2);
			local ability3_name = C_PetJournal.GetPetAbilityInfo(ability3);
			
			local rarityColor = ITEM_QUALITY_COLORS[rarity-1];
			
			local petTypeIcon = "|TInterface\\PetBattles\\PetIcon-"..PET_TYPE_SUFFIX[petType]..":16:16:0:0:128:256:102:63:129:168|t";
			
			local formattedSpeciesName = not customName and speciesName ;
			
			if(customName) then
				petString = string.format("%s[%d]|r |cffffffff%s|r |cff999999(%s)|r %s|n%s / %s / %s",
					rarityColor.hex, level, customName, speciesName, petTypeIcon,
					ability1_name, ability2_name, ability3_name);
			else
				petString = string.format("%s[%d]|r |cffffffff%s|r %s|n%s / %s / %s",
					rarityColor.hex, level, speciesName, petTypeIcon,
					ability1_name, ability2_name, ability3_name);
			end
		else
			petString = string.format("|cffff5555Pet #%d not found|r", slotIndex);
		end
		
		loadoutText = string.format("%s%s|n|n", loadoutText, petString);
	end
	
	return loadoutText;
end
	
function A:SaveLoadout(loadout_name)
	if(not loadout_name) then return false end
	if(loadout_name == "") then return end
	
	if(self.db.global.SavedLoadouts[loadout_name]) then
		StaticPopup_Show("PETBUDDY_LOADOUT_SAVE_EXISTS", loadout_name, nil, {
			newSave = true,
			name = loadout_name,
		});
	end
	
	local currentLoadout = {};
	
	for slotIndex = 1, 3 do
		local petID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
		if(locked) then
			StaticPopup_Show("PETBUDDY_LOADOUT_ERROR_LOCKED");
			return false;
		end
		
		tinsert(currentLoadout, {
			petID = petID,
			abilities = { ability1, ability2, ability3 },
		});
	end
	
	self.db.global.SavedLoadouts[loadout_name] = currentLoadout;
	
	PetBuddyFrameLoadouts_UpdateList();
	CloseMenus();
end

function A:RestoreLoadout(loadout_name)
	if(not loadout_name) then return false end
	if(loadout_name == "") then return end
	
	local loadout = self.db.global.SavedLoadouts[loadout_name];
	if(not loadout) then return false end
	
	for slotIndex, data in ipairs(loadout) do
		if(not C_PetJournal.GetPetInfoByPetID(data.petID)) then
			StaticPopup_Show("PETBUDDY_LOADOUT_ERROR_NOT_FOUND");
			return;
		end
	end
	
	for slotIndex, data in ipairs(loadout) do
		C_PetJournal.SetPetLoadOutInfo(slotIndex, data.petID);
		
		for spellIndex, abilityID in ipairs(data.abilities) do
			C_PetJournal.SetAbility(slotIndex, spellIndex, abilityID);
		end
	end
	
	PetJournal_UpdatePetLoadOut();
	PetBuddyPetFrame_ResetAbilitySwitches();
	
	PetBuddyFrameLoadoutsScrollFrame_ToggleVisibility(false);
	CloseMenus();
	
	PetBuddyFrameLoadoutsSearchBox:ClearFocus();
end

function A:RenameLoadout(old_loadout_name, new_loadout_name)
	if(not old_loadout_name or not new_loadout_name) then return false end
	if(new_loadout_name == "") then return end
	
	if(self.db.global.SavedLoadouts[new_loadout_name]) then
		StaticPopup_Show("PETBUDDY_LOADOUT_SAVE_EXISTS", new_loadout_name, nil, {
			newSave = false,
			name = new_loadout_name,
			oldName = old_loadout_name,
		});
	end
	
	self.db.global.SavedLoadouts[new_loadout_name] = self.db.global.SavedLoadouts[old_loadout_name];
	self.db.global.SavedLoadouts[old_loadout_name] = nil;
	
	PetBuddyFrameLoadouts_UpdateList();
	CloseMenus();
end

function A:DeleteLoadout(loadout_name)
	if(not loadout_name) then return false end
	if(loadout_name == "") then return end
	
	if(self.db.global.SavedLoadouts[loadout_name]) then
		self.db.global.SavedLoadouts[loadout_name] = nil;
	end
	
	PetBuddyFrameLoadouts_UpdateList();
	CloseMenus();
end

function A:GetSortedLoadouts()
	local loadoutData = {};
	for loadout_name, pets in pairs(A.db.global.SavedLoadouts) do
		local searchHit = true;
		if(PetBuddyFrameLoadouts.filterText ~= "") then
			searchHit = string.find(string.lower(loadout_name), PetBuddyFrameLoadouts.filterText) ~= nil;
			
			if(not searchHit) then
				for i=1, 3 do
					local speciesID, customName, _, _, _, _, _, speciesName = C_PetJournal.GetPetInfoByPetID(pets[i].petID);
					if(speciesID) then
						searchHit = string.find(string.lower(speciesName), PetBuddyFrameLoadouts.filterText) ~= nil;
						
						if(not searchHit and customName) then
							searchHit = string.find(string.lower(customName), PetBuddyFrameLoadouts.filterText) ~= nil;
						end
					end
					
					if(searchHit) then break; end
				end
			end
		end
		
		if(searchHit) then
			tinsert(loadoutData, {
				name = loadout_name,
				pets = pets,
			});
		end
	end
	
	table.sort(loadoutData, function(a, b)
		if(a == nil and b == nil) then return false end
		if(a == nil) then return true end
		if(b == nil) then return false end
		
		return string.lower(a.name) < string.lower(b.name);
	end);
	
	if(#loadoutData == 0) then
		tinsert(loadoutData, {
			name = "N/A",
			pets = {},
			notFound = true,
		});
	end
	
	return loadoutData, #loadoutData;
end

function PetBuddyFrameLoadouts_UpdateList()
	local scrollFrame = PetBuddyFrameLoadouts.scrollFrame;
	local offset = HybridScrollFrame_GetOffset(scrollFrame);
	local buttons = scrollFrame.buttons;
	
	local loadoutData, foundLoadouts = A:GetSortedLoadouts();
	
	local button, index;
	for i=1, #buttons do
		button = buttons[i];
		index = offset + i;
		local data = loadoutData[index];
		
		if(index <= foundLoadouts) then
			button.data = data;
			
			if(not data.notFound) then
				button.errorText:Hide();
				
				button.name:Show();
				button.name:SetText(data.name);
				
				button.background:SetVertexColor(1, 1, 1);
				button.backgroundError:Hide();
				button.hasMissingPet = false;
				
				for i=1,3 do
					local petIcon = button['pet'..i];
					petIcon:Show();
					
					local petID = data.pets[i].petID;
					
					local speciesID, customName, level, _, _, _, _, name, icon, petType = C_PetJournal.GetPetInfoByPetID(petID);
					
					if(speciesID) then
						local health, maxHealth, _, _, rarity = C_PetJournal.GetPetStats(petID);
						local rarityColor = ITEM_QUALITY_COLORS[rarity-1];
						
						petIcon.level:SetText(level);
						
						petIcon.icon:Show();
						petIcon.icon:SetTexture(icon);
						petIcon.iconBorder:SetVertexColor(rarityColor.r, rarityColor.g, rarityColor.b);
						
						petIcon.petTypeIcon:Show();
						petIcon.petTypeIcon:SetTexture("Interface\\PetBattles\\PetIcon-"..PET_TYPE_SUFFIX[petType]);
						
						petIcon.isDead:Hide();
					else
						petIcon.level:SetText("");
						
						petIcon.icon:Hide();
						petIcon.iconBorder:SetVertexColor(0.8, 0.1, 0.1);
						
						petIcon.petTypeIcon:Hide();
						petIcon.isDead:Show();
						
						button.background:SetVertexColor(0.8, 0.1, 0.1);
						button.backgroundError:Show();
						button.hasMissingPet = true;
					end
				end
				
				button:SetScript("OnEnter", PetBuddyLoadoutsButton_OnEnter);
				button:SetScript("OnLeave", PetBuddyLoadoutsButton_OnLeave);
			else
				for i=1,3 do
					local petIcon = button['pet'..i];
					petIcon:Hide();
				end
				
				button.name:Hide();
				
				button.errorText:Show();
				button.errorText:SetText("No Results");
				
				button:SetScript("OnEnter", nil);
				button:SetScript("OnLeave", nil);
			end
			
			button:Show();
		else
			button.data = nil;
			button.hasMissingPet = false;
			button:Hide();
		end
	end
	
	local totalHeight = foundLoadouts * 46;
	HybridScrollFrame_Update(scrollFrame, totalHeight, scrollFrame:GetHeight());
end

function PetBuddyLoadoutsButton_OnClick(self, button)
	if(self.data.notFound) then return end
	
	if(button == "LeftButton") then
		if(not self.hasMissingPet) then
			StaticPopup_Show("PETBUDDY_LOADOUT_RESTORE", self.data.name, nil, self.data.name)
		else
			StaticPopup_Show("PETBUDDY_LOADOUT_DELETE", self.data.name, nil, self.data.name)
		end
	elseif(button == "RightButton") then
		PetBuddyFrameLoadouts_OpenContextMenu(self)
	end
end

function PetBuddyLoadoutsButton_OnEnter(self)
	if(not self.data) then return end
	
	GameTooltip:ClearLines();
	GameTooltip:ClearAllPoints();
	GameTooltip:SetPoint("RIGHT", self, "LEFT", -1, 0);
	GameTooltip:SetOwner(self, "ANCHOR_PRESERVE");
	
	GameTooltip:AddLine("Loadout: |cffffffff" .. self.data.name .. "|r");
	GameTooltip:AddLine("|n");
	GameTooltip:AddLine(A:GetPetLoadoutText(self.data.pets));
	
	if(not self.hasMissingPet) then
		GameTooltip:AddLine("Left-Click |cffffffffRestore this loadout");
	else
		GameTooltip:AddLine("|cffff5555One or more pets are missing and this saved loadout is invalid");
		GameTooltip:AddLine("|n");
		GameTooltip:AddLine("Left-Click |cffffffffDelete this loadout");
	end
	
	GameTooltip:AddLine("Right-Click |cffffffffOpen options");
	
	GameTooltip:Show();
end

function PetBuddyLoadoutsButton_OnLeave(self)
	GameTooltip:Hide();
end

function PetBuddyFrameLoadouts_OnSearchTextChanged(self)
	SearchBoxTemplate_OnTextChanged(self);
	PetBuddyFrameLoadouts.filterText = string.lower(self:GetText());
	
	if(PetBuddyFrameLoadouts.filterText ~= "") then
		PetBuddyFrameLoadoutsScrollFrame_ToggleVisibility(true);
	end
	
	PetBuddyFrameLoadouts_UpdateList();
end

function PetBuddyFrameLoadouts_OnLoad(self)
	self.filterText = "";
	self.scrollFrame.update = PetBuddyFrameLoadouts_UpdateList;
	-- self.scrollFrame.scrollBar.doNotHide = true;
	
	HybridScrollFrame_CreateButtons(self.scrollFrame, "PetBuddyLoadoutsButtonTemplate", 0, 0, nil, nil, 0, 0);
end

function PetBuddyLoadoutsSaveButton_OnLoad(self)
	local actionData = {
		iconTexture = "Interface\\AddOns\\PetBuddy\\Media\\SaveButtonIcon",
		-- count = "S",
		tooltipTitle = "Save Loadout",
		tooltipDescription = "Save current pets and abilities so that they can later be restored",
		func = function(self) StaticPopup_Show("PETBUDDY_LOADOUT_SAVE") end,
	};
	
	PetBuddyFrameButton_Initialize(self, "custom", actionData);
end

function PetBuddyLoadoutsToggleButton_OnLoad(self)
	local actionData = {
		iconTexture = "Interface\\AddOns\\PetBuddy\\Media\\ToggleButtonIconDown",
		tooltipTitle = "Toggle Loadout List",
		tooltipDescription = "Show/hide the list of existing loadouts",
		func = function(self)
			local showstate = not PetBuddyFrameLoadoutsScrollFrame:IsShown();
			PetBuddyFrameLoadoutsScrollFrame_ToggleVisibility(showstate);
		end,
	};
	
	PetBuddyFrameButton_Initialize(self, "custom", actionData);
end

function PetBuddyFrameLoadoutsScrollFrame_ToggleVisibility(showstate)
	PetBuddyFrameLoadoutsScrollFrame:SetShown(showstate);
	
	local button = PetBuddyFrameLoadouts.toggleButton;
	
	if(showstate) then
		PetBuddyFrameLoadouts_UpdateList();
		HybridScrollFrame_SetOffset(PetBuddyFrameLoadouts.scrollFrame, 0);
		button.icon:SetTexture("Interface\\AddOns\\PetBuddy\\Media\\ToggleButtonIconUp");
	else
		button.icon:SetTexture("Interface\\AddOns\\PetBuddy\\Media\\ToggleButtonIconDown");
	end
end

function PetBuddyFrameLoadouts_OpenContextMenu(relativeFrame)
	if(not relativeFrame) then return end
	
	if(not PetBuddyFrameLoadouts.ContextMenu) then
		PetBuddyFrameLoadouts.ContextMenu = CreateFrame("Frame", "PetBuddyLoadoutsContextMenuFrame", PetBuddyFrame, "UIDropDownMenuTemplate");
	end
	
	local data = relativeFrame.data;
	
	local contextMenuData = {
		{
			text = data.name, isTitle = true, notCheckable = true,
		},
		{
			text = "Restore",
			func = function()
				StaticPopup_Show("PETBUDDY_LOADOUT_RESTORE", data.name, nil, data.name);
			end,
			notCheckable = true,
		},
		{
			text = "Rename",
			func = function()
				StaticPopup_Show("PETBUDDY_LOADOUT_RENAME", data.name, nil, data.name);
			end,
			notCheckable = true,
		},
		{
			text = "Overwrite",
			func = function()
				StaticPopup_Show("PETBUDDY_LOADOUT_OVERWRITE", data.name, nil, data.name);
			end,
			notCheckable = true,
		},
		{
			text = "Delete",
			func = function()
				StaticPopup_Show("PETBUDDY_LOADOUT_DELETE", data.name, nil, data.name);
			end,
			notCheckable = true,
		},
	};
	
	if(relativeFrame.hasMissingPet) then
		contextMenuData[2].disabled = true;
	end
	
	PetBuddyFrameLoadouts.ContextMenu:SetPoint("TOPLEFT", relativeFrame, "CENTER", 0, 5);
	EasyMenu(contextMenuData, PetBuddyFrameLoadouts.ContextMenu, "cursor", 0, 0, "MENU", 5);
end