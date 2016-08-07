--[[
	Pet Buddy by Sonaza
	Battle Pet management addon
	
	All rights reserved
	Questions can be sent to temu92@gmail.com
--]]

local ADDON_NAME, addon = ...;

function AutoHealButton_OnShow(self)
	self:SetChecked(addon.db.global.AutoHealPets);
end

function AutoHealButton_OnClick(self)
	addon.db.global.AutoHealPets = self:GetChecked();
end

local savedJournalFilters = {
	types = {},
	sources = {},
	search = "",
	hasSave = false,
}

function addon:ResetJournalFiltering()
	if(not PetJournalSearchBox) then return end
	
	local numTypes = C_PetJournal.GetNumPetTypes();
	for typeIndex = 1, numTypes do
		savedJournalFilters.types[typeIndex] = not C_PetJournal.IsPetTypeChecked(typeIndex);
	end
	
	local numSources = C_PetJournal.GetNumPetSources();
	for sourceIndex = 1, numSources do
		savedJournalFilters.sources[sourceIndex] = not C_PetJournal.IsPetSourceChecked(sourceIndex);
	end
	
	C_PetJournal.SetAllPetSourcesChecked(true);
	C_PetJournal.SetAllPetTypesChecked(true);
	C_PetJournal.ClearSearchFilter();
	
	savedJournalFilters.search = PetJournalSearchBox:GetText();
	PetJournalSearchBox:SetText("");
	
	savedJournalFilters.hasSave = true;
end

function addon:RestoreJournalFiltering()
	if(not savedJournalFilters.hasSave) then return end
	
	C_PetJournal.SetAllPetSourcesChecked(true);
	C_PetJournal.SetAllPetTypesChecked(true);
	C_PetJournal.ClearSearchFilter();
	
	local numTypes = C_PetJournal.GetNumPetTypes();
	for typeIndex = 1, numTypes do
		if(savedJournalFilters.types[typeIndex] ~= nil) then
			C_PetJournal.SetPetTypeFilter(typeIndex, not savedJournalFilters.types[typeIndex]);
		end
	end
	
	local numSources = C_PetJournal.GetNumPetSources();
	for sourceIndex = 1, numSources do
		if(savedJournalFilters.sources[sourceIndex] ~= nil) then
			C_PetJournal.SetPetSourceChecked(sourceIndex, not savedJournalFilters.sources[sourceIndex]);
		end
	end
	
	if(PetJournalSearchBox) then
		C_PetJournal.SetSearchFilter(savedJournalFilters.search or "");
		PetJournalSearchBox:SetText(savedJournalFilters.search or "");
	end
end

local numWoundedPets, numWoundedActivePets = nil, nil;
function addon:UpdateNumWoundedPets()
	numWoundedPets = 0;
	numWoundedActivePets = 0;
	
	if(PetJournal and not PetJournal:IsVisible() or not PetJournal) then
		addon:ResetJournalFiltering();
		
		local _, numPets = C_PetJournal.GetNumPets();
		for index = 1, numPets do
			local petID = C_PetJournal.GetPetInfoByIndex(index);
			
			if(petID) then
				local health, maxHealth = C_PetJournal.GetPetStats(petID);
				if(health < maxHealth) then
					numWoundedPets = numWoundedPets + 1;
				end
			end
		end
		
		addon:RestoreJournalFiltering();
	end
	
	for slotIndex = 1,3 do
		local petID, _, _, _, locked = C_PetJournal.GetPetLoadOutInfo(slotIndex);
		if(locked or not petID) then break end
		
		local health, maxHealth = C_PetJournal.GetPetStats(petID);
		if(health < maxHealth) then
			numWoundedActivePets = numWoundedActivePets + 1;
		end
	end
end

function addon:GetNumWoundedPets(all_pets)
	if(numWoundedPets == nil or numWoundedActivePets == nil) then
		addon:UpdateNumWoundedPets();
	end
	
	local all_pets = all_pets;
	if(all_pets == nil) then all_pets = true; end
	
	if(not all_pets) then
		return numWoundedActivePets;
	else
		return numWoundedPets;
	end
end

function addon:GetRemainingHealCooldown()
	return math.floor(math.max(0, 180 - (GetTime() - addon.PetHealTime)));
end

local MIN_ABBR, SEC_ABBR = gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", ""), gsub(SECOND_ONELETTER_ABBR, "%%d%s*", "");

local   MS = format("%s%s %s%s", "%d", MIN_ABBR, "%02d", SEC_ABBR);
local    S = format("%s%s", "%d", SEC_ABBR);

local function FormatTime(t)
	if not t then return end

	local m, s = floor((t % 3600) / 60), floor(t % 60);
	
	if m > 0 then
		return format(MS, m, s);
	else
		return format(S, s);
	end
end

function addon:UpdateWoundedText()
	if(not addon.PetHealer.GossipID) then return end
	
	local wounded = addon:GetNumWoundedPets();
	
	local text;
	local remainingCooldown = addon:GetRemainingHealCooldown();
	
	if(addon.PetHealer.IsGarrisonNPC and remainingCooldown > 0) then
		text = string.format("Heal and Revive Pets (%s / %d wounded)", FormatTime(remainingCooldown), wounded);
	elseif(addon.PetHealer.IsGarrisonNPC and addon.PetHealer.IsFreeNPC) then
		text = string.format("Heal and Revive Pets (free / %d wounded)", wounded);
	else
		text = string.format("Heal and Revive Pets (%s / %d wounded)", GetCoinTextureString(1000), wounded);
	end
	
	_G['GossipTitleButton' .. addon.PetHealer.GossipID]:SetText(text);
end

function addon:GOSSIP_SHOW()
	addon:UpdateNumWoundedPets();
	
	addon.PetHealer = {
		GossipID = nil,
	};
	
	local num_gossip = GetNumGossipOptions();
	if(num_gossip == 0) then return end
	
	local gossip = { GetGossipOptions() };
	
	local healingGossipID = 0;
	
	for key, value in pairs(gossip) do
		if(key % 2 == 1 and value == "I'd like to heal and revive my battle pets.") then
			healingGossipID = tonumber((key + 1) / 2);
		end
	end
	
	if(healingGossipID == 0) then return end;
	
	local targetGUID = UnitGUID("target");
	local type, _, _, _, _, npc_id = strsplit("-", targetGUID);
	
	local isGarrisonNPC = type == "Creature" and C_Garrison.IsOnGarrisonMap();
	local isFreeNPC = type == "Creature" and (npc_id == "85418" or npc_id == "79858");
	
	PetBuddyAutoHealButton:Show();
	
	local numQuests = GetNumGossipAvailableQuests() + GetNumGossipActiveQuests();
	if(GetNumGossipAvailableQuests() > 0) then numQuests = numQuests + 1 end
	if(GetNumGossipActiveQuests() > 0) then numQuests = numQuests + 1 end
	
	addon.PetHealer = {
		GossipID = healingGossipID + numQuests,
		IsGarrisonNPC = isGarrisonNPC,
		IsFreeNPC = isFreeNPC,
	}
	
	addon:UpdateWoundedText();
	
	local remainingCooldown = addon:GetRemainingHealCooldown();
	if(self.db.global.AutoHealPets and addon:GetNumWoundedPets() > 0 and remainingCooldown == 0) then
		SelectGossipOption(healingGossipID);
	end
end

function addon:GOSSIP_CLOSED()
	if(PetBuddyAutoHealButton) then
		PetBuddyAutoHealButton:Hide();
	end
end

function addon:GOSSIP_CONFIRM(event, index, message, cost)
	if(not self.db.global.AutoHealPetsFee) then return end
	
	if(message == "addon small fee for supplies is required." and cost == 1000) then
		if(addon:GetNumWoundedPets() > 0) then
			StaticPopup1Button1:Click();
		else
			StaticPopup1Button2:Click();
		end
	end
end
