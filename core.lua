--[[
	Pet Buddy by Sonaza
	Battle Pet management addon
	
	All rights reserved
	Questions can be sent to temu92@gmail.com
--]]

local ADDON_NAME, SHARED_DATA = ...;

local _G = getfenv(0);

local LibStub = LibStub;
local A = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0");
_G[ADDON_NAME] = A;
SHARED_DATA[1] = A;

local E = {};
SHARED_DATA[2] = E;

BINDING_HEADER_PETBUDDY = "Pet Buddy";
_G["BINDING_NAME_CLICK PetBuddyFrameToggler:LeftButton"] = "Toggle Pet Buddy";
_G["BINDING_NAME_PETBUDDY_TOGGLE_BUTTONS"] = "Show Pet Related Items Menu";
_G["BINDING_NAME_PETBUDDY_TOGGLE_LOADOUTS"] = "Show Pet Loadouts Menu";
_G["BINDING_NAME_PETBUDDY_SEARCH_LOADOUTS"] = "Search Pet Loadouts";

local PetsBattleData = {};

function A:OnEnable()
	LoadAddOn("Blizzard_PetJournal");
	
	A.SecureFrameToggler = CreateFrame("Button", "PetBuddyFrameToggler", nil, "SecureHandlerClickTemplate");
	A.SecureFrameToggler:SetFrameRef("PetBuddyFrame", PetBuddyFrame);
	
	A.SecureFrameToggler:SetAttribute("_onclick", [[
		local frame = self:GetFrameRef("PetBuddyFrame");
		if(frame:IsShown()) then
			frame:Hide();
		else
			frame:Show();
		end
	]]);
	
	A.LoginTime = GetTime();
	A.PetHealTime = 0;
	
	A:RegisterEvent("PET_BATTLE_OPENING_START");
	A:RegisterEvent("PET_BATTLE_CLOSE");
	
	A:RegisterEvent("PET_BATTLE_PET_CHANGED", A.UpdatePets);
	A:RegisterEvent("PET_BATTLE_HEALTH_CHANGED", A.UpdatePets);
	A:RegisterEvent("PET_BATTLE_LEVEL_CHANGED", A.UpdatePets);
	A:RegisterEvent("PET_BATTLE_XP_CHANGED", A.UpdatePets);
	
	A:RegisterEvent("PET_JOURNAL_NEW_BATTLE_SLOT", A.UpdatePets);
	
	A:RegisterEvent("UPDATE_SUMMONPETS_ACTION", A.UpdatePets);
	A:RegisterEvent("PET_JOURNAL_LIST_UPDATE", A.UpdatePets);
	
	-- A:RegisterEvent("PLAYER_ENTERING_WORLD");
	A:RegisterEvent("ZONE_CHANGED");
	A:RegisterEvent("SPELL_UPDATE_COOLDOWN");
	
	A:RegisterEvent("CURSOR_UPDATE");
	
	A:RegisterEvent("PLAYER_REGEN_DISABLED");
	A:RegisterEvent("PLAYER_REGEN_ENABLED");
	
	
	A:RegisterEvent("GOSSIP_SHOW");
	A:RegisterEvent("GOSSIP_CLOSED");
	A:RegisterEvent("GOSSIP_CONFIRM");
	
	A:RegisterEvent("BARBER_SHOP_OPEN");
	A:RegisterEvent("BARBER_SHOP_CLOSE");
	
	A:UpdatePets();
	
	A:ScheduleRepeatingTimer(function()
		if(not A.BlizzHooked and PetJournal_UpdatePetLoadOut) then
			hooksecurefunc("PetJournal_UpdatePetLoadOut", function()
				if(not C_PetBattles.IsInBattle()) then
					A:UpdatePets();
				end
			end);
			A.BlizzHooked = true;
		end
		
		A:UpdateAutoResummon();
		
		if(GossipFrame:IsShown() and A.PetHealer.IsGarrisonNPC) then
			A:UpdateWoundedText();
		end
	end, 1.0);
end

function PetBuddySetUtility(utility_id)
	if(not A or not A.db) then return end
	if(InCombatLockdown()) then return end
	
	PetBuddyFrame:Show();
	
	A.db.global.PetUtilityMenuState = utility_id or 0;
	A:UpdateUtilityMenuState();
end

function PetBuddyFocusSearch()
	PetBuddySetUtility(2);
	if(PetBuddyFrameLoadoutsSearchBox) then
		PetBuddyFrameLoadoutsSearchBox:SetFocus();
	end
end

function PetBuddyPetFrame_ResetAbilitySwitches(self)
	for slotIndex = 1, 3 do
		local petFrame = _G['PetBuddyFramePet' .. slotIndex];
		if(petFrame ~= self) then
			petFrame.SwitchingAbilities = false;
			petFrame.stats:Show();
			petFrame.abilities:Hide();
			
			petFrame.abilities.spell1.selected:Hide();
			petFrame.abilities.spell2.selected:Hide();
			petFrame.abilities.spell3.selected:Hide();
		end
	end
end

function PetBuddyPetFrame_OnClick(self, button)
	if(InCombatLockdown()) then return end
	
	if(button == "LeftButton") then
		PetBuddyPetFrame_ResetAbilitySwitches(self);
		
		self.SwitchingAbilities = not self.SwitchingAbilities;
		if(self.SwitchingAbilities) then
			self.stats:Hide();
			self.abilities:Show();
		else
			self.stats:Show();
			self.abilities:Hide();
		end
		
		if(PetBuddyFrame.spellSelect.currentAnchor) then
			-- PetBuddyFrame.spellSelect.selected:Hide();
			PetBuddyFrame.spellSelect.currentAnchor:SetChecked(false);
		end
		PetBuddyFrame.spellSelect:Hide();
		
	elseif(button == "RightButton") then
		A:OpenContextMenu();
	end
end

function A:UpdateUtilityMenuState()
	if(InCombatLockdown()) then return end
	
	if(A.db.global.PetUtilityMenuState < 0 or A.db.global.PetUtilityMenuState > 2) then
		A.db.global.PetUtilityMenuState = 0;
	end
	
	if(A.db.global.PetUtilityMenuState == 1) then
		PetBuddyFrameButtons:Show();
		PetBuddyFrameLoadouts:Hide();
		A:UpdateItemButtons();
		
	elseif(A.db.global.PetUtilityMenuState == 2) then
		PetBuddyFrameButtons:Hide();
		PetBuddyFrameLoadouts:Show();
		PetBuddyFrameLoadouts_UpdateList();
	else
		PetBuddyFrameButtons:Hide();
		PetBuddyFrameLoadouts:Hide();
	end
	
	PetBuddyFrameLoadoutsScrollFrame_ToggleVisibility(false);
end

function PetBuddyFrame_OnMouseWheel(self, delta)
	if(InCombatLockdown() or C_PetBattles.IsInBattle()) then return end
	
	local menuState = A.db.global.PetUtilityMenuState;
	
	menuState = menuState - delta;
	if(menuState > 2) then menuState = 0; end
	if(menuState < 0) then menuState = 2; end
	
	A.db.global.PetUtilityMenuState = menuState;
	
	A:UpdateUtilityMenuState();
	
	CloseMenus();
end

function PetBuddyFrame_GetRequiredLevel(petFrame, abilityID)
	for i=1, 6 do
		if(petFrame.petAbilities[i] == abilityID) then
			return petFrame.petAbilityLevels[i];
		end
	end
	return 0;
end

function PetBuddyFrame_ShowPetSelect(self)
	local slotFrame = self:GetParent():GetParent();
	local abilities = slotFrame.petAbilities;
	local slotIndex = slotFrame:GetID();

	local abilityIndex = self:GetID();
	local spellIndex1 = abilityIndex;
	local spellIndex2 = spellIndex1 + 3;
	
	-- print(slotFrame:GetName(), slotIndex, slotFrame.petID)
	
	--Get the info for the pet that has this ability
	local speciesID, customName, level, xp, maxXp, displayID, isFavorite, petName, petIcon, petType = C_PetJournal.GetPetInfoByPetID(slotFrame.petID);
	
	if PetBuddyFrame.spellSelect:IsShown() then 
		if PetBuddyFrame.spellSelect.slotIndex == slotIndex and 
			PetBuddyFrame.spellSelect.abilityIndex == abilityIndex then
			PetBuddyFrame.spellSelect:Hide();
			self.selected:Hide();
			return;
		elseif(PetBuddyFrame.spellSelect.currentAnchor and PetBuddyFrame.spellSelect.currentAnchor ~= self) then
			PetBuddyFrame.spellSelect.currentAnchor:SetChecked(false);
			PetBuddyFrame.spellSelect.currentAnchor.selected:Hide();
			PetBuddyFrame.spellSelect.currentAnchor = nil;
			-- PetBuddyFrame.Loadout["Pet"..PetBuddyFrame.spellSelect.slotIndex]["spell"..PetBuddyFrame.spellSelect.abilityIndex].selected:Hide();
		end
	end
	
	self.selected:Show();
	PetBuddyFrame.spellSelect.slotIndex = slotIndex;
	PetBuddyFrame.spellSelect.abilityIndex = abilityIndex;
	PetBuddyFrame.spellSelect:SetFrameLevel(PetJournalLoadoutBorder:GetFrameLevel()+1);
	PetJournal_HideAbilityTooltip();
	
	--Setup spell one
	local name, icon, petType, requiredLevel;
	if (abilities[spellIndex1]) then
		name, icon, petType = C_PetJournal.GetPetAbilityInfo(abilities[spellIndex1]);
		requiredLevel = PetBuddyFrame_GetRequiredLevel(slotFrame, abilities[spellIndex1]);
		PetBuddyFrame.spellSelect.Spell1:SetEnabled(requiredLevel <= level);
	else
		name = "";
		icon = "";
		petType = "";
		requiredLevel = 0;
		PetBuddyFrame.spellSelect.Spell1:SetEnabled(false);
	end

	if ( requiredLevel > level ) then
		PetBuddyFrame.spellSelect.Spell1.additionalText = format(PET_ABILITY_REQUIRES_LEVEL, requiredLevel);
	else
		PetBuddyFrame.spellSelect.Spell1.additionalText = nil;
	end
	PetBuddyFrame.spellSelect.Spell1.icon:SetTexture(icon);
	PetBuddyFrame.spellSelect.Spell1.icon:SetDesaturated(requiredLevel > level);
	PetBuddyFrame.spellSelect.Spell1.BlackCover:SetShown(requiredLevel > level);
	PetBuddyFrame.spellSelect.Spell1.LevelRequirement:SetShown(requiredLevel > level);
	PetBuddyFrame.spellSelect.Spell1.LevelRequirement:SetText(requiredLevel);
	PetBuddyFrame.spellSelect.Spell1.slotIndex = slotIndex;
	PetBuddyFrame.spellSelect.Spell1.abilityIndex = abilityIndex;
	PetBuddyFrame.spellSelect.Spell1.abilityID = abilities[spellIndex1];
	PetBuddyFrame.spellSelect.Spell1.petID = slotFrame.petID;
	PetBuddyFrame.spellSelect.Spell1.speciesID = slotFrame.speciesID;
	
	--Setup spell two
	if (abilities[spellIndex2]) then
		name, icon, petType = C_PetJournal.GetPetAbilityInfo(abilities[spellIndex2]);
		requiredLevel = PetBuddyFrame_GetRequiredLevel(slotFrame, abilities[spellIndex2]);
		PetBuddyFrame.spellSelect.Spell2:SetEnabled(requiredLevel <= level);
	else
		name = "";
		icon = "";
		petType = "";
		requiredLevel = 0;
		PetBuddyFrame.spellSelect.Spell2:SetEnabled(false);
	end

	if ( requiredLevel > level ) then
		PetBuddyFrame.spellSelect.Spell2.additionalText = format(PET_ABILITY_REQUIRES_LEVEL, requiredLevel);
	else
		PetBuddyFrame.spellSelect.Spell2.additionalText = nil;
	end
	PetBuddyFrame.spellSelect.Spell2.icon:SetTexture(icon);
	PetBuddyFrame.spellSelect.Spell2.BlackCover:SetShown(requiredLevel > level);
	PetBuddyFrame.spellSelect.Spell2.icon:SetDesaturated(requiredLevel > level);
	PetBuddyFrame.spellSelect.Spell2.LevelRequirement:SetShown(requiredLevel > level);
	PetBuddyFrame.spellSelect.Spell2.LevelRequirement:SetText(requiredLevel);
	PetBuddyFrame.spellSelect.Spell2.slotIndex = slotIndex;
	PetBuddyFrame.spellSelect.Spell2.abilityIndex = abilityIndex;
	PetBuddyFrame.spellSelect.Spell2.abilityID = abilities[spellIndex2];
	PetBuddyFrame.spellSelect.Spell2.petID = slotFrame.petID;
	PetBuddyFrame.spellSelect.Spell2.speciesID = slotFrame.speciesID;
	
	PetBuddyFrame.spellSelect.Spell1:SetChecked(self.abilityID == abilities[spellIndex1]);
	PetBuddyFrame.spellSelect.Spell2:SetChecked(self.abilityID == abilities[spellIndex2]);
	
	PetBuddyFrame.spellSelect:SetPoint("TOP", self, "BOTTOM", 0, 0);
	PetBuddyFrame.spellSelect:Show();
	
	PetBuddyFrame.spellSelect.currentAnchor = self;
end

function A:UpdatePetAbility(abilityFrame, abilityID, petID)
	local speciesID, customName, level, xp, maxXp, displayID, isFavorite, petName, petIcon, petType = C_PetJournal.GetPetInfoByPetID(petID);
	local requiredLevel = PetBuddyFrame_GetRequiredLevel(abilityFrame:GetParent():GetParent(), abilityID);
	
	local name, icon, typeEnum = C_PetJournal.GetPetAbilityInfo(abilityID);
	abilityFrame.icon:SetTexture(icon);
	abilityFrame.abilityID = abilityID;
	abilityFrame.petID = petID;
	abilityFrame.speciesID = speciesID;
	abilityFrame.selected:Hide();
	
	local levelTooLow = requiredLevel > level;
	abilityFrame.icon:SetDesaturated(levelTooLow);
	abilityFrame.BlackCover:SetShown(levelTooLow);
	abilityFrame.LevelRequirement:SetText(requiredLevel);
	abilityFrame.LevelRequirement:SetShown(levelTooLow);
	
	if(levelTooLow) then
		abilityFrame.additionalText = format(PET_ABILITY_REQUIRES_LEVEL, requiredLevel);
	else
		abilityFrame.additionalText = nil;
	end
end

function A:UpdateBattleData()
	local index = 1;
	
	wipe(PetsBattleData);
	for slotIndex = 1, 3 do
		local petID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
		if(locked or not petID) then break end
		
		local health = C_PetJournal.GetPetStats(petID);
		if(health > 0) then
			PetsBattleData[index] = {
				petID = petID,
				slotIndex = slotIndex,
				battleIndex = index,
			};
			
			index = index + 1;
		end
	end
end

function A:PET_BATTLE_OPENING_START()
	if(self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.SHOW and not PetBuddyFrame:IsShown()) then
		PetBuddyFrame:Show();
		A.BattleVisibilityChange = true;
	elseif(self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.HIDE and PetBuddyFrame:IsShown()) then
		PetBuddyFrame:Hide();
		A.BattleVisibilityChange = true;
	end
	
	A.UtilityMenu = self.db.global.PetUtilityMenuState;
	self.db.global.PetUtilityMenuState = 0;
	A:UpdateUtilityMenuState();
	
	A:UpdateNumWoundedPets();
	
	A:UpdateBattleData();
	A:UpdatePets();
end

function A:PET_BATTLE_CLOSE()
	if(A.BattleVisibilityChange) then
		if(self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.SHOW) then
			PetBuddyFrame:Hide();
		elseif(self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.HIDE) then
			PetBuddyFrame:Show();
		end
		
		A.BattleVisibilityChange = false;
	end
	
	if(self.db.global.PetUtilityMenuState == 0 and A.UtilityMenu) then
		self.db.global.PetUtilityMenuState = A.UtilityMenu;
		A.UtilityMenu = nil;
		A:UpdateUtilityMenuState();
	end
	
	A:UpdatePets();
	A:UpdateNumWoundedPets();
end

function A:UpdatePets()
	if(InCombatLockdown()) then return end
	
	if(not PetsBattleData and C_PetBattles.IsInBattle()) then
		A:UpdateBattleData();
	end
	
	PetBuddyFrameLoadouts_UpdateList();
	A:UpdateDatabrokerText();
	
	for slotIndex = 1, 3 do
		local petFrame = _G['PetBuddyFramePet' .. slotIndex];
		if(not petFrame) then return end
		
		local hasActivePetInSlot = true;
		local realSlotIndex = slotIndex;
		local battleIndex = slotIndex;
		
		if(C_PetBattles.IsInBattle()) then
			if(slotIndex > C_PetBattles.GetNumPets(1)) then
				hasActivePetInSlot = false;
			elseif(PetsBattleData[slotIndex]) then
				realSlotIndex = PetsBattleData[slotIndex].slotIndex;
				battleIndex = PetsBattleData[slotIndex].battleIndex;
			end
		end
		
		if(hasActivePetInSlot) then
			local petID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(realSlotIndex);
			
			if(petID and not locked) then
				petFrame.petID = petID;
				
				local speciesID, customName, level, xp, maxXp, displayID, isFavorite, speciesName, icon, petType, creatureID = C_PetJournal.GetPetInfoByPetID(petID);
				local health, maxHealth, _, _, rarity = C_PetJournal.GetPetStats(petID);
				local isDead = (health == 0);
				
				--Read ability/ability levels into the correct tables
				C_PetJournal.GetPetAbilityList(speciesID, petFrame.petAbilities, petFrame.petAbilityLevels);
				
				A:UpdatePetAbility(petFrame.abilities.spell1, ability1, petID);
				A:UpdatePetAbility(petFrame.abilities.spell2, ability2, petID);
				A:UpdatePetAbility(petFrame.abilities.spell3, ability3, petID);
		
				petFrame.abilities.typeInfo.petID = petID;
				petFrame.abilities.typeInfo.speciesID = speciesID;
				petFrame.abilities.typeInfo.abilityID = PET_BATTLE_PET_TYPE_PASSIVES[petType];
				petFrame.abilities.typeInfo.icon:SetTexture("Interface\\PetBattles\\PetIcon-"..PET_TYPE_SUFFIX[petType]);
				
				if(GetCursorInfo() ~= "battlepet") then
					petFrame.glowHighlight:Hide();
				end
				
				if(C_PetBattles.IsInBattle()) then
					health = C_PetBattles.GetHealth(1, battleIndex);
					maxHealth = C_PetBattles.GetMaxHealth(1, battleIndex);
					
					isDead = (health == 0);
					
					local activePetIndex = C_PetBattles.GetActivePet(1);
					if(activePetIndex == battleIndex) then
						petFrame.glowHighlight:Show();
					end
				end
				
				local rarityColor = ITEM_QUALITY_COLORS[rarity-1];
				
				petFrame.icon:Show();
				petFrame.icon:SetTexture(icon);
				petFrame.iconBorder:SetVertexColor(rarityColor.r, rarityColor.g, rarityColor.b);
				
				petFrame.petTypeTexture:Show();
				petFrame.petTypeTexture:SetTexture(GetPetTypeTexture(petType));

				petFrame.petName:SetFormattedText("%s[%d]|r %s", rarityColor.hex, level, customName or speciesName);
				
				if(not petFrame.SwitchingAbilities) then
					petFrame.stats:Show();
					petFrame.stats.petHealth:Show();
				end
				
				petFrame.stats.petHealth:SetMinMaxValues(0, maxHealth);
				petFrame.stats.petHealth:SetValue(health);
				
				local healthText = "";
				if(not self.db or not self.db.global.PetStatsText.ShowHealthPercentage) then
					healthText = string.format("%d/%d", health, maxHealth);
				else
					healthText = string.format("%d/%d (%d%%)", health, maxHealth, health / maxHealth * 100);
				end
				
				petFrame.stats.petHealth.text:SetText(healthText);
				
				petFrame.dragButton.petTypeIcon:Show();
				petFrame.dragButton.petTypeIcon:SetTexture("Interface\\PetBattles\\PetIcon-"..PET_TYPE_SUFFIX[petType]);
				
				if(level < 25 and maxXp > 0) then
					if(not petFrame.SwitchingAbilities) then
						petFrame.stats.petExperience:Show();
					end
					
					petFrame.stats.petExperience:SetMinMaxValues(0, maxXp);
					petFrame.stats.petExperience:SetValue(xp);
					
					local xpText = "";
					if(not self.db or self.db.global.PetStatsText.RemainingExperience) then
						xpText = string.format("%d", maxXp - xp);
					else
						xpText = string.format("%d/%d", xp, maxXp);
					end
					
					if(not self.db or self.db.global.PetStatsText.ShowExperiencePercentage) then
						local percentage = 0;
						if(not self.db or not self.db.global.PetStatsText.RemainingExperience) then
							percentage = xp / maxXp * 100;
						else
							percentage = (maxXp - xp) / maxXp * 100;
						end
						
						xpText = string.format("%s (%d%%)", xpText, percentage);
					end
					
					petFrame.stats.petExperience.text:SetText(xpText);
				else
					petFrame.stats.petExperience:Hide();
					petFrame.stats.petExperience:SetMinMaxValues(0, 1);
					petFrame.stats.petExperience:SetValue(0);
					petFrame.stats.petExperience.text:SetText("");
				end
				
				if(isDead) then
					petFrame.isDead:Show();
				else
					petFrame.isDead:Hide();
				end
				
				petFrame.slotInfoText:Hide();
			else
				petFrame.petID = nil;
				
				petFrame.icon:Hide();
				petFrame.isDead:Show();
				
				petFrame.iconBorder:SetVertexColor(0.8, 0.1, 0.1);
				
				petFrame.dragButton.petTypeIcon:Hide();
				petFrame.petTypeTexture:Hide();
				
				if(locked) then
					petFrame.stats:Hide();
					
					petFrame.petName:SetText("|cffffee00Slot Locked|r");
					
					petFrame.slotInfoText:Show();
					
					if(self.db.global.ShowPetItems and not PetBuddyFrameLoadouts:IsShown()) then
						PetBuddyFrameButtons:Show();
					end
					
					if(slotIndex == 1) then
						PetBuddyFrameButtons:Hide();
						petFrame.slotInfoText:SetText("Learn Battle Pet Training to Unlock This Slot");
					elseif(slotIndex == 2) then
						petFrame.slotInfoText:SetText("Earn Achievement |cffffff00[Newbie]|r to Unlock This Slot");
					elseif(slotIndex == 3) then
						petFrame.slotInfoText:SetText("Earn Achievement |cffffff00[Just a Pup]|r to Unlock This Slot");
					end
				elseif(not petID and locked == false) then
					petFrame.stats:Hide();
					
					petFrame.petName:SetText("|cffffee00Empty Slot|r");
					
					petFrame.slotInfoText:Show();
					petFrame.slotInfoText:SetText("Add a Battle Pet to This Slot");
				end
			end
			
			petFrame:Show();
		else
			petFrame:Hide();
		end
	end
end

function PetBuddyFrame_StartMoving()
	if(A.db.global.IsFrameLocked) then return end
	
	CloseMenus();
	
	PetBuddyFrame:StartMoving();
	PetBuddyFrame:SetUserPlaced(false);
	PetBuddyFrame.IsMoving = true;
	
	-- PetBuddyPetFrame_ResetAbilitySwitches();
end

function PetBuddyFrame_StopMoving()
	if(PetBuddyFrame.IsMoving) then
		PetBuddyFrame:StopMovingOrSizing();
		PetBuddyFrame.IsMoving = false;
		PetBuddyFrame_SavePosition();
	end
end

function PetBuddyFrame_UpdatePetCharms(self)
	local charmsAmount = GetItemCount(116415);
	self.text:SetText(charmsAmount);
	
	A:UpdateDatabrokerText();
end

function PetBuddyFrameDragButton_OnClick(self, button)
	local type, petID = GetCursorInfo();
	if(type == "battlepet") then
		local _, dialog = StaticPopup_Visible("BATTLE_PET_RELEASE");
		if(dialog and dialog.data == petID) then
			StaticPopup_Hide("BATTLE_PET_RELEASE");
		end
		if(PetJournal_IsPendingCage(petID)) then
			UIErrorsFrame:AddMessage(ERR_PET_JOURNAL_PET_PENDING_CAGE, 1.0, 0.1, 0.1, 1.0);
			ClearCursor();
			return;
		end
		
		C_PetJournal.SetPetLoadOutInfo(self:GetParent():GetID(), petID);
		PetJournal_UpdatePetLoadOut();
		ClearCursor();
		PlaySound("igAbilityIconDrop");
	else
		local petID = self:GetParent().petID;
		if(petID) then
			if(button == "LeftButton" and not C_PetBattles.IsInBattle()) then
				-- C_PetJournal.PickupPet(petID);
				-- PlaySound("igAbilityIconPickup");
				
			elseif(button == "MiddleButton" and not InCombatLockdown()) then
				C_PetJournal.SummonPetByGUID(petID);
				
			elseif(button == "RightButton") then
				if(not CollectionsJournal:IsShown()) then
					ToggleCollectionsJournal(2);
				end
				PetJournal_ShowPetCardByID(petID);
			end
		end
	end
	
	CloseMenus();
end
	
function PetBuddyFrameDragButton_OnDragStart(self)
	local petID = self:GetParent().petID;
	if(not petID) then return end
	
	if(not C_PetBattles.IsInBattle()) then
		C_PetJournal.PickupPet(petID);
		PlaySound("igAbilityIconPickup");
		
		CloseMenus();
	end
end

function PetBuddyFrameDragButton_OnReceiveDrag(self)
	local _, _, _, _, locked = C_PetJournal.GetPetLoadOutInfo(self:GetParent():GetID());
	if(locked) then
		ClearCursor();
		return;
	end
	
	local type, petID = GetCursorInfo();
	if(type == "battlepet") then
		local _, dialog = StaticPopup_Visible("BATTLE_PET_RELEASE");
		if ( dialog and dialog.data == petID ) then
			StaticPopup_Hide("BATTLE_PET_RELEASE");
		end
		if ( PetJournal_IsPendingCage(petID) ) then
			UIErrorsFrame:AddMessage(ERR_PET_JOURNAL_PET_PENDING_CAGE, 1.0, 0.1, 0.1, 1.0);
			ClearCursor();
			return;
		end
		C_PetJournal.SetPetLoadOutInfo(self:GetParent():GetID(), petID);
		PetJournal_UpdatePetLoadOut();
		ClearCursor();
		PlaySound("igAbilityIconDrop");
	end
	
	CloseMenus();
end

function PetBuddyFrameDragButton_OnEnter(self)
	if(not A.db.global.ShowPetTooltips) then return end
	
	-- local slotIndex = self:GetParent():GetID();
	-- if(not slotIndex) then return end
	
	local petID = self:GetParent().petID;
	-- local petID = C_PetJournal.GetPetLoadOutInfo(slotIndex);
	if(not petID) then return end
	
	local speciesID, name, level = C_PetJournal.GetPetInfoByPetID(petID);
	local health, maxHealth, power, speed, breedQuality = C_PetJournal.GetPetStats(petID);
	
	if(speciesID and speciesID > 0) then
		GameTooltip:SetOwner(self, "ANCHOR_LEFT", -2, -74);
		BattlePetToolTip_Show(speciesID, level, breedQuality-1, maxHealth, power, speed, name);
	end
end

function PetBuddyFrameDragButton_OnLeave(self)
	GameTooltip:Hide();
	BattlePetTooltip:Hide();
end

function PetBuddyFrame_OnClick(self, button, ...)
	if(button == "RightButton") then
		A:OpenContextMenu();
	end
end

function PetBuddyFrame_OnShow(self)
	if(not A.db) then return end
	
	A.db.global.Visible = true;
	
	A:RegisterEvent("PET_BATTLE_PET_CHANGED", A.UpdatePets);
	A:RegisterEvent("PET_BATTLE_HEALTH_CHANGED", A.UpdatePets);
	A:RegisterEvent("PET_BATTLE_LEVEL_CHANGED", A.UpdatePets);
	A:RegisterEvent("PET_BATTLE_XP_CHANGED", A.UpdatePets);
	
	A:RegisterEvent("PET_JOURNAL_NEW_BATTLE_SLOT", A.UpdatePets);
	
	A:RegisterEvent("UPDATE_SUMMONPETS_ACTION", A.UpdatePets);
	A:RegisterEvent("PET_JOURNAL_LIST_UPDATE", A.UpdatePets);
	
	A:RefreshMedia();
	
	PetBuddyPetFrame_ResetAbilitySwitches();
	PetBuddyFrame_UpdatePetCharms(PetBuddyFrameTitlePetCharms);
end

function PetBuddyFrame_OnHide(self)
	if(not A.db) then return end
	
	-- if(InCombatLockdown()) then
		A.db.global.Visible = false;
	-- end
	
	A:UnregisterEvent("PET_BATTLE_PET_CHANGED");
	A:UnregisterEvent("PET_BATTLE_HEALTH_CHANGED");
	A:UnregisterEvent("PET_BATTLE_LEVEL_CHANGED");
	A:UnregisterEvent("PET_BATTLE_XP_CHANGED");
	
	A:UnregisterEvent("PET_JOURNAL_NEW_BATTLE_SLOT");
	
	A:UnregisterEvent("UPDATE_SUMMONPETS_ACTION");
	A:UnregisterEvent("PET_JOURNAL_LIST_UPDATE");
end

function A:PLAYER_REGEN_DISABLED()
	if(self.db.global.HideInCombat and PetBuddyFrame:IsShown()) then
		PetBuddyFrame:Hide();
		A.CombatHidden = true;
	end
end

function A:PLAYER_REGEN_ENABLED()
	if(self.db.global.HideInCombat and self.CombatHidden) then
		PetBuddyFrame:Show();
		A.CombatHidden = false;
	end
	
	self.db.global.Visible = PetBuddyFrame:IsShown();
	A:UpdateUtilityMenuState();
end

function A:CURSOR_UPDATE()
	if(C_PetBattles.IsInBattle()) then return end
	
	A.CursorUpdateTimer = A:ScheduleTimer(function()
		local lastCursor = A.CurrentCursor;
		A.CurrentCursor = GetCursorInfo();
		
		if(not A.CursorTimerTick) then A.CursorTimerTick = 0 end
		A.CursorTimerTick = A.CursorTimerTick + 1;
		
		local cancelTimer = false;
		if(A.CursorTimerTick >= 30) then cancelTimer = true; end
		
		if(A.CurrentCursor ~= lastCursor) then
			if(A.CurrentCursor == "battlepet") then
				for i=1,3 do
					local button = _G['PetBuddyFramePet'..i..'DragButton'];
					button:GetParent().glowHighlight:Show();
				end
			else
				for i=1,3 do
					local button = _G['PetBuddyFramePet'..i..'DragButton'];
					button:GetParent().glowHighlight:Hide();
				end
			end
			
			A.CursorTimerTick = 0;
			cancelTimer = true;
		end
		
		if(cancelTimer) then A:CancelTimer(A.CursorUpdateTimer); end
	end, 0.01);
end

A.SummonDisabledTimer = 0;
hooksecurefunc("Dismount", function()
	A.SummonDisabledTimer = GetTime();
end)

function A:ZONE_CHANGED()
	A.SummonDisabledTimer = GetTime();
end

function A:IsPlayerEating()
	-- Find localized name for the food/drink buff, there are too many buff ids to manually check
	local localizedFood = GetSpellInfo(33264);
	local localizedDrink = GetSpellInfo(160599);
	return UnitBuff("player", localizedFood) ~= nil or UnitBuff("player", localizedDrink) ~= nil;
end

function A:CanSafelySummonPet()
	return not (not HasFullControl() or UnitOnTaxi("player") 
				or UnitUsingVehicle("player") or UnitIsDeadOrGhost("player")
				or A.BarberShopOpen
				or IsMounted() or IsFalling() or (GetTime()-A.SummonDisabledTimer) < 15.0
				or (GetTime()-A.LoginTime) < 15.0
				or UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil
				or IsStealthed()
				or A:IsPlayerEating());
end

function A:UpdateAutoResummon(forceSummon)
	if(not A:CanSafelySummonPet() and not forceSummon) then return end
	
	local summonedPet = C_PetJournal.GetSummonedPetGUID();
	if(summonedPet and self.db.char.AutoSummonLastPetID ~= summonedPet) then
		self.db.char.AutoSummonLastPetID = summonedPet;
		A:UpdateDatabrokerText();
	end
	
	if(InCombatLockdown() or not self.db.global.AutoSummonPet or (summonedPet and not forceSummon)) then return end
	
	local petID = nil;
	
	if(self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.LAST_PET) then
		if(self.db.char.AutoSummonLastPetID) then
			local speciesID = C_PetJournal.GetPetInfoByPetID(self.db.char.AutoSummonLastPetID);
			
			if(speciesID) then
				petID = self.db.char.AutoSummonLastPetID;
			else
				self.db.char.AutoSummonLastPetID = nil;
			end
		end
	elseif(self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.FAVORITE) then
		C_PetJournal.SummonRandomPet(false);
	elseif(self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.ANY) then
		C_PetJournal.SummonRandomPet(true);
	end
	
	if(petID and petID ~= summonedPet) then
		C_PetJournal.SummonPetByGUID(petID);
		A.SummonDisabledTimer = GetTime();
	end
end

function A:PLAYER_ENTERING_WORLD()
	
end

function A:SPELL_UPDATE_COOLDOWN()
	A.PetHealTime = GetSpellCooldown(125439);
	
	if((GetTime() - A.LoginTime) > 3 or A.PetHealTime > 0) then
		A:UnregisterEvent("SPELL_UPDATE_COOLDOWN");
	end
end

function TogglePetBuddy()
	if(InCombatLockdown()) then
		DEFAULT_CHAT_FRAME:AddMessage("|cffcc22Pet Buddy:|r Cannot toggle in combat");
		return;
	end
	
	if(PetBuddyFrame:IsShown()) then
		PetBuddyFrame:Hide();
	else
		PetBuddyFrame:Show();
	end
	
	A.db.global.Visible = PetBuddyFrame:IsShown();
end
	
function A:OnInitialize()
	SLASH_PETBUDDY1	= "/pb";
	SLASH_PETBUDDY2	= "/petbuddy";
	SlashCmdList["PETBUDDY"] = function(command)
		TogglePetBuddy();
	end
	
	A:InitializeDatabase();
	A:InitializeDatabroker();
end

function A:BARBER_SHOP_OPEN()
	A.BarberShopOpen = true;
end

function A:BARBER_SHOP_CLOSE()
	A.BarberShopOpen = false;
end

function A:OnDisable()
		
end
