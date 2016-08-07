--[[
	Pet Buddy by Sonaza
	Battle Pet management addon
	
	All rights reserved
	Questions can be sent to temu92@gmail.com
--]]

local ADDON_NAME, addon = ...;
local E = addon.E;

local LibStub = LibStub;
local LDB = LibStub:GetLibrary("LibDataBroker-1.1");

local ICON_PATTERN_12 = "|T%s:12:12:0:0|t";
local ICON_PATTERN_16 = "|T%s:16:16:0:0|t";

local PET_BUDDY_ICON = "Interface\\ICONS\\INV_pandarenserpentpet";
local TEX_PET_BUDDY_ICON = ICON_PATTERN_16:format(PET_BUDDY_ICON);

local TEX_HEALTH_ICON = "|TInterface\\PetBattles\\PetBattle-StatIcons:16:16:0:0:32:32:16:32:16:32|t";
local TEX_POWER_ICON = "|TInterface\\PetBattles\\PetBattle-StatIcons:16:16:0:0:32:32:0:16:0:16|t";
local TEX_SPEED_ICON = "|TInterface\\PetBattles\\PetBattle-StatIcons:16:16:0:0:32:32:0:16:16:32|t";

local TEX_STRONG_ICON = ICON_PATTERN_16:format("INTERFACE\\PetBattles\\BattleBar-AbilityBadge-Strong-Small");
local TEX_WEAK_ICON = ICON_PATTERN_16:format("INTERFACE\\PetBattles\\BattleBar-AbilityBadge-Weak-Small");

local PET_CHARM_ID = 116415;
local TEX_PET_CHARM = ICON_PATTERN_12:format("Interface\\ICONS\\ACHIEVEMENT_GUILDPERK_HONORABLEMENTION");

local PET_TYPE_ICON_PATTERN = "|TInterface\\PetBattles\\PetIcon-%s:16:16:0:0:128:256:102:63:129:168|t";

PET_TYPE_SUFFIX = {
	[1] = "Humanoid",
	[2] = "Dragon",
	[3] = "Flying",
	[4] = "Undead",
	[5] = "Critter",
	[6] = "Magical",
	[7] = "Elemental",
	[8] = "Beast",
	[9] = "Water",
	[10] = "Mechanical",
};

local BATTLE_PET_COUNTERS = { -- Weak / Strong
	[1]  = {4, 2}, -- Humanoid
	[2]  = {1, 3}, -- Dragonkin
	[3]  = {6, 8}, -- Flying
	[4]  = {5, 2}, -- Undead
	[5]  = {8, 7}, -- Critter
	[6]  = {2, 9}, -- Magic
	[7]  = {9, 10}, -- Elemental
	[8]  = {10, 1}, -- Beast
	[9]  = {3, 4}, -- Aquatic
	[10] = {7, 6}, -- Mechanical
}

function addon:GetDatabrokerMenuData()
	return {
		{
			text = "Pet Buddy", isTitle = true, notCheckable = true,
		},
		{
			text = "Show wounded pets",
			func = function() self.db.global.Broker.ShowWoundedPets = not self.db.global.Broker.ShowWoundedPets; addon:UpdateDatabrokerText() end,
			checked = function() return self.db.global.Broker.ShowWoundedPets; end,
			isNotRadio = true,
		},
		{
			text = "Show pet charms",
			func = function() self.db.global.Broker.ShowPetCharms = not self.db.global.Broker.ShowPetCharms; addon:UpdateDatabrokerText() end,
			checked = function() return self.db.global.Broker.ShowPetCharms; end,
			isNotRadio = true,
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Always resummon companion",
			func = function() self.db.global.AutoSummonPet = not self.db.global.AutoSummonPet; addon:UpdateDatabrokerText(); end,
			checked = function() return self.db.global.AutoSummonPet; end,
			isNotRadio = true,
			hasArrow = true,
			menuList = {
				{
					text = "Resummon Options", isTitle = true, notCheckable = true,
				},
				{
					text = "Last used pet",
					func = function() self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.LAST_PET; addon:UpdateAutoResummon(true); end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.LAST_PET; end,
				},
				{
					text = "Random favorite pet",
					func = function() self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.FAVORITE; addon:UpdateAutoResummon(true); end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.FAVORITE; end,
				},
				{
					text = "Any random pet",
					func = function() self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.ANY; addon:UpdateAutoResummon(true); end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.ANY; end,
				},
			},
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Pet Buddy Options",
			notCheckable = true,
			hasArrow = true,
			menuList = addon:GetPrimaryMenuData(),
		},
	};
end

function addon:InitializeDatabroker()
	addon.databroker = LDB:NewDataObject(ADDON_NAME, {
		type = "data source",
		label = "Pet Buddy",
		text = "Pet Buddy",
		icon = PET_BUDDY_ICON,
		OnClick = function(frame, button)
			if(button == "LeftButton") then
				TogglePetBuddy();
			elseif(button == "RightButton") then
				GameTooltip:Hide();
				addon:OpenContextMenu(addon:GetDatabrokerMenuData(), frame, frame, "BOTTOM", "BOTTOM");
			end
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then return end
			tooltip:AddLine(TEX_PET_BUDDY_ICON .. " Pet Buddy")
			
			tooltip:AddLine(" ");
			tooltip:AddLine("Active Pets");
			
			for slotIndex=1, 3 do
				local petID, ability1, ability2, ability3, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
				local speciesID, customName, level, xp, maxXp, _, _, speciesName, icon, petType = C_PetJournal.GetPetInfoByPetID(petID);
				local health, maxHealth, power, speed, rarity = C_PetJournal.GetPetStats(petID);
				
				local isHurt = health < maxHealth;
				
				local rarityColor = ITEM_QUALITY_COLORS[rarity-1];
				
				local petTypeIcon = PET_TYPE_ICON_PATTERN:format(PET_TYPE_SUFFIX[petType]);
			
				local ability1_name = C_PetJournal.GetPetAbilityInfo(ability1);
				local ability2_name = C_PetJournal.GetPetAbilityInfo(ability2);
				local ability3_name = C_PetJournal.GetPetAbilityInfo(ability3);
				
				-- local name, subname = customName or speciesName;
				-- if(customName) then subname = string.format(" |cff999999(%s)|r", speciesName); end
				
				tooltip:AddDoubleLine(
					string.format("%s %s[%d] %s|r", ICON_PATTERN_16:format(icon), rarityColor.hex, level, customName or speciesName),
					string.format("|cffffffff%s|r %s", _G["BATTLE_PET_NAME_"..petType], petTypeIcon)
				);
				
				local weakType = BATTLE_PET_COUNTERS[petType][1];
				local strongType = BATTLE_PET_COUNTERS[petType][2];
				
				local statsLine = "";
				
				if(not isHurt) then
					statsLine = string.format("%s |cffffffff%d|r %s |cffffffff%d|r %s |cffffffff%d|r", TEX_HEALTH_ICON, maxHealth, TEX_POWER_ICON, power, TEX_SPEED_ICON, speed);
				else
					statsLine = string.format("%s |cffff5555%d|r %s |cffffffff%d|r %s |cffffffff%d|r", TEX_HEALTH_ICON, health, TEX_POWER_ICON, power, TEX_SPEED_ICON, speed);
				end
				
				tooltip:AddDoubleLine(
					statsLine,
					string.format("%s%s %s%s",
						TEX_WEAK_ICON, PET_TYPE_ICON_PATTERN:format(PET_TYPE_SUFFIX[weakType]),
						TEX_STRONG_ICON, PET_TYPE_ICON_PATTERN:format(PET_TYPE_SUFFIX[strongType])
					));
				
				-- if(level < 25) then
				-- 	tooltip:AddDoubleLine(
				-- 		"|cff6fd509HP|r / |cff49daf3XP|r",
				-- 		string.format("|cff6fd509%d/%d|r / |cff49daf3%d/%d|r", health, maxHealth, xp, maxXp)
				-- 	);
				-- else
				-- 	tooltip:AddDoubleLine(
				-- 		"|cff6fd509HP|r",
				-- 		string.format("|cff6fd509%d/%d|r", health, maxHealth)
				-- 	);
				-- end

				-- tooltip:AddLine(string.format("%s / %s / %s", ability1_name, ability2_name, ability3_name));

			end
				tooltip:AddLine(" ");
			
			if(addon.db.global.AutoSummonPet) then
				if(addon.db.char.AutoSummonLastPetID) then
					local speciesID, customName, level, _, _, _, _, speciesName = C_PetJournal.GetPetInfoByPetID(addon.db.char.AutoSummonLastPetID);
					if(speciesID) then
						local _, _, _, _, rarity = C_PetJournal.GetPetStats(addon.db.char.AutoSummonLastPetID);
						local rarityColor = ITEM_QUALITY_COLORS[rarity-1];
						
						tooltip:AddDoubleLine("Current Auto Summon Companion", string.format("%s[%d] %s|r", rarityColor.hex, level, customName or speciesName));
					else
						self.db.char.AutoSummonLastPetID = nil;
						tooltip:AddDoubleLine("Current Auto Summon Companion", "|cffff5555No companion|r");
					end
				else
					tooltip:AddDoubleLine("Current Auto Summon Companion", "|cffff5555No companion|r");
				end
				tooltip:AddLine(" ");
			end
			
			tooltip:AddLine("Left-Click |cffffffffToggle Pet Buddy|h");
			tooltip:AddLine("Right-Click |cffffffffShow options|h");
			
			-- addon.tooltip_open = true;
		end,
		OnLeave = function(frame)
			-- addon.tooltip_open = false;
		end,
	});

	addon:UpdateDatabrokerText();
end

function addon:UpdateDatabrokerText()
	if(not addon.databroker) then return end
	
	local strings = {};
	
	if(self.db.global.Broker.ShowWoundedPets) then
		local woundedPets = addon:GetNumWoundedPets();
		
		if(woundedPets > 0) then
			tinsert(strings, string.format("%d |cffff5555wounded|r", woundedPets));
		end
	end
	
	if(addon.db.global.AutoSummonPet and not self.db.char.AutoSummonLastPetID) then
		tinsert(strings, string.format("|cffff5555No companion|r", woundedPets));
	end
	
	if(self.db.global.Broker.ShowPetCharms) then
		local charmsAmount = GetItemCount(PET_CHARM_ID);
		tinsert(strings, string.format("%d %s", charmsAmount, TEX_PET_CHARM));
	end
	
	if(#strings == 0) then
		tinsert(strings, "Pet Buddy");
	end
	
	addon.databroker.text = table.concat(strings, "  ");
end