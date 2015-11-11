--[[
	Pet Buddy by Sonaza
	Battle Pet management addon
	
	All rights reserved
	Questions can be sent to temu92@gmail.com
--]]

local ADDON_NAME, SHARED_DATA = ...;
local A, E = unpack(SHARED_DATA);

local LibStub = LibStub;
local AceDB = LibStub("AceDB-3.0");

local LSM = LibStub("LibSharedMedia-3.0");

-- Adding default media to LSM if they're not already added
LSM:Register("font", "DorisPP", [[Interface\AddOns\PetBuddy\media\DORISPP.ttf]]);
LSM:Register("statusbar", "RenAscensionL", [[Interface\AddOns\PetBuddy\media\RenAscensionL.tga]]);

E.VISIBILITY_MODE = {
	DO_NOTHING 	= 0x1,
	SHOW 		= 0x2,
	HIDE 		= 0x3,
};

E.AUTO_SUMMON_MODE = {
	LAST_PET	= 0x1,
	FAVORITE	= 0x2,
	ANY			= 0x3,	
};

function A:InitializeDatabase()
	local defaults = {
		char = {
			AutoSummonLastPetID = nil,
		},
		
		global = {
			Visible = true,
			Position = {
				Point = "CENTER",
				RelativePoint = "CENTER",
				x = 0,
				y = 0,
			},
			
			fontSize = 10,
			fontFace = "DorisPP",
			barTexture = "RenAscensionL",
			
			SavedLoadouts = {},
			
			WindowScale = 1.0,
			
			IsFrameLocked = false,
			
			PetBattleVisiblityMode = E.VISIBILITY_MODE.SHOW,
			
			HideInCombat = true,
			
			ShowPetTooltips = true,
			ShowPetCharms = true,
			
			PetStatsText = {
				Enabled = true,
				ShowHealthPercentage = false,
				ShowExperiencePercentage = true,
				RemainingExperience = true,
			},			
			
			PetUtilityMenuState = 1,
			
			ShowPepe = true,
			
			ShowPetItems = true,
			ShowPetLoadouts = false,
			
			AutoHealPets = true,
			AutoHealPetsFee = true,
			
			AutoSummonPet = true,
			AutoSummonMode = E.AUTO_SUMMON_MODE.LAST_PET,
			
			Broker = {
				ShowWoundedPets = true,
				ShowPetCharms = true,	
			},
		}
	};
	
	self.db = AceDB:New("PetBuddyDB", defaults);
	A:RestoreSavedSettings();
end

function PetBuddyFrame_SavePosition()
	if(not A.db) then return end
	
	local point, _, relativePoint, x, y = PetBuddyFrame:GetPoint()
	A.db.global.Position = {
		Point = point,
		RelativePoint = relativePoint,
		x = x,
		y = y,
	};
end

function A:RestoreSavedSettings()
	if(InCombatLockdown()) then return end
	
	A:UpdateUtilityMenuState();
	
	PetBuddyFrameTitlePetCharms:SetShown(self.db.global.ShowPetCharms);
	
	for i=1,3 do
		local petFrame = _G['PetBuddyFramePet'..i];
		petFrame.stats.petHealth.text:SetShown(self.db.global.PetStatsText.Enabled);
		petFrame.stats.petExperience.text:SetShown(self.db.global.PetStatsText.Enabled);
	end
	
	A:RefreshMedia();
	
	if(self.db.global.ShowPepe) then
		PetBuddyFrameTitle.pepeFrame:Show();
	else
		PetBuddyFrameTitle.pepeFrame:Hide();
	end
	
	local position = self.db.global.Position;
	PetBuddyFrame:SetPoint(position.Point, UIParent, position.RelativePoint, position.x, position.y);
	
	if(self.db.global.Visible) then
		PetBuddyFrame:Show();
	else
		PetBuddyFrame:Hide();
	end
	
	A:SetWindowScale(self.db.global.WindowScale);
end

function A:RefreshMedia(font, barTexture)
	local fontPath = LSM:Fetch("font", font or self.db.global.fontFace);
	local statusBarPath = LSM:Fetch("statusbar", barTexture or self.db.global.barTexture);
	
	local fontSize = self.db.global.fontSize;
	
	PetBuddyFontTitle:SetFont(fontPath, fontSize + 2, "OUTLINE");
	PetBuddyFontNormal:SetFont(fontPath, fontSize, "OUTLINE");
	PetBuddyFontSmall:SetFont(fontPath, math.max(8, fontSize - 1), "OUTLINE");
	
	for i=1,3 do
		local petFrame = _G['PetBuddyFramePet'..i];
		
		petFrame.stats.petHealth:SetStatusBarTexture(statusBarPath);
		petFrame.stats.petExperience:SetStatusBarTexture(statusBarPath);
	end
end

function A:SetWindowScale(scale)
	self.db.global.WindowScale = scale or 1.0;
	PetBuddyFrame:SetScale(self.db.global.WindowScale);
end

function A:GetWindowScaleMenu()
	local windowScales = { 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, };
	local menu = {};
	
	for index, scale in ipairs(windowScales) do
		tinsert(menu, {
			text = string.format("%d%%", scale * 100),
			func = function() A:SetWindowScale(scale); CloseMenus(); end,
			checked = function() return self.db.global.WindowScale == scale end,
		});
	end
	
	return menu;
end

function A:GetPrimaryMenuData()
	local sharedMediaFonts = {};
	for index, font in ipairs(LSM:List("font")) do
		tinsert(sharedMediaFonts, {
			text = font,
			func = function()
				self.db.global.fontFace = font;
				A:RefreshMedia();
			end,
			checked = function() return self.db.global.fontFace == font; end,
		});
	end
	
	local fontSizes = {};
	for size = 8, 16 do
		tinsert(fontSizes, {
			text = tostring(size),
			func = function() self.db.global.fontSize = size; A:RefreshMedia(); end,
			checked = function() return self.db.global.fontSize == size; end,
		});
	end
	
	local sharedMediaBarTextures = {};
	for index, statusbar in ipairs(LSM:List("statusbar")) do
		tinsert(sharedMediaBarTextures, {
			text = statusbar,
			func = function() self.db.global.barTexture = statusbar; A:RefreshMedia(); end,
			checked = function() return self.db.global.barTexture == statusbar; end,
		});
	end
	
	local data = {
		{
			text = "Pet Buddy Options", isTitle = true, notCheckable = true,
		},
		{
			text = "Lock Pet Buddy",
			func = function() self.db.global.IsFrameLocked = not self.db.global.IsFrameLocked; end,
			checked = function() return self.db.global.IsFrameLocked; end,
			isNotRadio = true,
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Toggle Displays", isTitle = true, notCheckable = true,
		},
		{
			text = "Show Pet Tooltips",
			func = function() self.db.global.ShowPetTooltips = not self.db.global.ShowPetTooltips; end,
			checked = function() return self.db.global.ShowPetTooltips; end,
			isNotRadio = true,
		},
		{
			text = "Show Pet Charms",
			func = function() self.db.global.ShowPetCharms = not self.db.global.ShowPetCharms; A:RestoreSavedSettings() end,
			checked = function() return self.db.global.ShowPetCharms; end,
			isNotRadio = true,
		},
		{
			text = "Show Pet Health and Experience Text",
			func = function() self.db.global.PetStatsText.Enabled = not self.db.global.PetStatsText.Enabled; A:RestoreSavedSettings() end,
			checked = function() return self.db.global.PetStatsText.Enabled; end,
			isNotRadio = true,
			hasArrow = true,
			menuList = {
				{
					text = "Health Text", notCheckable = true, isTitle = true,
				},
				{
					text = "Show Percentage",
					func = function() self.db.global.PetStatsText.ShowHealthPercentage = not self.db.global.PetStatsText.ShowHealthPercentage; A:UpdatePets() end,
					checked = function() return self.db.global.PetStatsText.ShowHealthPercentage; end,
					isNotRadio = true,
				},
				{
					text = "", isTitle = true, notCheckable = true, disabled = true,
				},
				{
					text = "Experience Text", notCheckable = true, isTitle = true,
				},
				{
					text = "Show Percentage",
					func = function() self.db.global.PetStatsText.ShowExperiencePercentage = not self.db.global.PetStatsText.ShowExperiencePercentage; A:UpdatePets() end,
					checked = function() return self.db.global.PetStatsText.ShowExperiencePercentage; end,
					isNotRadio = true,
				},
				{
					text = "Display Current Experience",
					func = function() self.db.global.PetStatsText.RemainingExperience = false; A:UpdatePets() end,
					checked = function() return not self.db.global.PetStatsText.RemainingExperience; end,
				},
				{
					text = "Display Experience to Level",
					func = function() self.db.global.PetStatsText.RemainingExperience = true; A:UpdatePets() end,
					checked = function() return self.db.global.PetStatsText.RemainingExperience; end,
				},
			},
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Automation", isTitle = true, notCheckable = true,
		},
		{
			text = "Always Resummon Companion Pet",
			func = function() self.db.global.AutoSummonPet = not self.db.global.AutoSummonPet; A:UpdateDatabrokerText(); CloseMenus(); end,
			checked = function() return self.db.global.AutoSummonPet; end,
			isNotRadio = true,
			hasArrow = true,
			menuList = {
				{
					text = "Resummon Options", isTitle = true, notCheckable = true,
				},
				{
					text = "Last Used Pet",
					func = function() self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.LAST_PET; A:UpdateAutoResummon(true); end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.LAST_PET; end,
				},
				{
					text = "Random Favorite Pet",
					func = function() self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.FAVORITE; A:UpdateAutoResummon(true); end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.FAVORITE; end,
				},
				{
					text = "Any Random Pet",
					func = function() self.db.global.AutoSummonMode = E.AUTO_SUMMON_MODE.ANY; A:UpdateAutoResummon(true); end,
					checked = function() return self.db.global.AutoSummonMode == E.AUTO_SUMMON_MODE.ANY; end,
				},
			},
		},
		{
			text = "Automatically Heal Pets at Stables",
			func = function() self.db.global.AutoHealPets = not self.db.global.AutoHealPets; AutoHealButton_OnShow(PetBuddyAutoHealButton) end,
			checked = function() return self.db.global.AutoHealPets; end,
			isNotRadio = true,
			hasArrow = true,
			menuList = {
				{
					text = "Auto Pet Healer", isTitle = true, notCheckable = true,
				},
				{
					text = "Also Automatically Accept the Healing Fee",
					func = function() self.db.global.AutoHealPetsFee = not self.db.global.AutoHealPetsFee; end,
					checked = function() return self.db.global.AutoHealPetsFee; end,
					isNotRadio = true,
				},
			}
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Visibility Options", isTitle = true, notCheckable = true,
		},
		{
			text = "When Starting Pet Battle",
			notCheckable = true,
			hasArrow = true,
			menuList = {
				{
					text = "Show",
					func = function() self.db.global.PetBattleVisiblityMode = E.VISIBILITY_MODE.SHOW; end,
					checked = function() return self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.SHOW; end,
				},
				{
					text = "Hide",
					func = function() self.db.global.PetBattleVisiblityMode = E.VISIBILITY_MODE.HIDE; end,
					checked = function() return self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.HIDE; end,
				},
				{
					text = "Do Nothing",
					func = function() self.db.global.PetBattleVisiblityMode = E.VISIBILITY_MODE.DO_NOTHING; end,
					checked = function() return self.db.global.PetBattleVisiblityMode == E.VISIBILITY_MODE.DO_NOTHING; end,
				},
			},
		},
		{
			text = "Hide When Entering Combat",
			func = function() self.db.global.HideInCombat = not self.db.global.HideInCombat; end,
			checked = function() return self.db.global.HideInCombat; end,
			isNotRadio = true,
		},
		{
			text = "Enable Cuteness",
			func = function()
				self.db.global.ShowPepe = not self.db.global.ShowPepe;
				if(self.db.global.ShowPepe) then
					PetBuddyFrameTitle.pepeFrame:Show();
				else
					PetBuddyFrameTitle.pepeFrame:Hide();
				end
			end,
			checked = function() return self.db.global.ShowPepe; end,
			isNotRadio = true,
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Pet Utility", isTitle = true, notCheckable = true,
		},
		{
			text = "Hide Utility Menu",
			func = function() self.db.global.PetUtilityMenuState = 0; A:RestoreSavedSettings(); end,
			checked = function() return self.db.global.PetUtilityMenuState == 0 end,
			disabled = C_PetBattles.IsInBattle(),
		},
		{
			text = "Show Pet Related Items",
			func = function() self.db.global.PetUtilityMenuState = 1; A:RestoreSavedSettings(); end,
			checked = function() return self.db.global.PetUtilityMenuState == 1 end,
			disabled = C_PetBattles.IsInBattle(),
		},
		{
			text = "Show Pet Loadouts Menu",
			func = function() self.db.global.PetUtilityMenuState = 2; A:RestoreSavedSettings(); end,
			checked = function() return self.db.global.PetUtilityMenuState == 2 end,
			disabled = C_PetBattles.IsInBattle(),
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Frame Options", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = string.format("Change Scale (%d%%)", self.db.global.WindowScale * 100),
			notCheckable = true,
			hasArrow = true,
			menuList = A:GetWindowScaleMenu(),
		},
		{
			text = "Font Face",
			notCheckable = true,
			hasArrow = true,
			menuList = sharedMediaFonts,
		},
		{
			text = "Font Size",
			notCheckable = true,
			hasArrow = true,
			menuList = fontSizes,
		},
		{
			text = "Bar Texture",
			notCheckable = true,
			hasArrow = true,
			menuList = sharedMediaBarTextures,
		},
		{
			text = "", isTitle = true, notCheckable = true, disabled = true,
		},
		{
			text = "Other Options", isTitle = true, notCheckable = true,
		},
	};
	
	if(PetBuddyFrame:IsShown()) then
		tinsert(data, {
			text = "Hide Pet Buddy",
			func = function()
				PetBuddyFrame:Hide(); CloseMenus();
			end,
			notCheckable = true,
		});
	else
		tinsert(data, {
			text = "Show Pet Buddy",
			func = function()
				PetBuddyFrame:Show(); CloseMenus();
			end,
			notCheckable = true,
		});
	end
	
	return data;
end

function A:OpenContextMenu(contextMenuData, parentframe, anchor, point, relativePoint)
	
	if(not A.ContextMenu) then
		A.ContextMenu = CreateFrame("Frame", "PetBuddyContextMenuFrame", PetBuddyFrame, "UIDropDownMenuTemplate");
	end
	
	if(not contextMenuData) then
		contextMenuData = A:GetPrimaryMenuData();
	end
	
	A.ContextMenu:SetPoint(point or "TOPLEFT", parentframe or PetBuddyFrame, relativePoint or "CENTER", 0, 5);
	EasyMenu(contextMenuData, A.ContextMenu, anchor or "cursor", 0, 0, "MENU", 5);
end