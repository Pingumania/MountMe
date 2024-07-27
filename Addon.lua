--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright 2014-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/phanx-wow/MountMe
------------------------------------------------------------------------
	TODO:
	- Cancel transformation buffs that block mounting?
	- Ignore garrison stables training mounts
----------------------------------------------------------------------]]

local MOD_FORCE_FLYING = "ctrl"
local MOD_DISMOUNT_FLYING = "alt"
local MOD_REPAIR_MOUNT = "shift"

------------------------------------------------------------------------

local _, PLAYER_CLASS = UnitClass("player")

local LibFlyable = LibStub("LibFlyable")

-- Don't use combat macro conditional because it also considers pets and this sometimes prevents us from mounting even if we are not in combat
local MOUNT_CONDITION = "[outdoors,nomounted,novehicleui,nomod:" .. MOD_REPAIR_MOUNT .. "]"
local FORCE_FLYING_MOUNT_CONDITION = "[outdoors,nomounted,novehicleui,mod:" .. MOD_FORCE_FLYING .. ",nomod:" .. MOD_REPAIR_MOUNT .. "]"
local COMBAT_MOUNT_CONDITION = "[outdoors,nomounted,novehicleui]"
local GARRISON_MOUNT_CONDITION = "[outdoors,nomounted,novehicleui,nomod:" .. MOD_REPAIR_MOUNT .. "]"
local REPAIR_MOUNT_CONDITION = "[outdoors,nomounted,novehicleui,nomod:" .. MOD_FORCE_FLYING .. ",mod:" .. MOD_REPAIR_MOUNT .. "]"

local SAFE_DISMOUNT = "/stopmacro [flying,nomod:" .. MOD_DISMOUNT_FLYING .. "]"
local DISMOUNT = [[
/leavevehicle [canexitvehicle]
/dismount [mounted]
]]

local SpellID = {
	["Cat Form"] = 768,
	["Darkflight"] = 68992,
	["Garrison Ability"] = 161691,
	["Ghost Wolf"] = 2645,
	["Flight Form"] = 165962,
	["Summon Mechashredder 5000"] = 164050,
	["Travel Form"] = 783,
}

local SpellName = {}
for name, id in pairs(SpellID) do
	SpellName[name] = C_Spell.GetSpellInfo(id).name
end

local ItemID = {
	["Magic Broom"] = 37011,
}

local ItemName = {}
for name, id in pairs(ItemID) do
	local item = Item:CreateFromItemID(id)
	item:ContinueOnItemLoad(function()
		ItemName[name] = item:GetItemName()
	end)
end

------------------------------------------------------------------------
------------------------------------------------------------------------

local function GetOverrideMount()
	local combat = UnitAffectingCombat("player")

	-- Magic Broom
	-- Instant but not usable in combat
	if ItemName["Magic Broom"] and not combat and C_Item.GetItemCount(ItemID["Magic Broom"]) > 0 then
		return "/use " .. ItemName["Magic Broom"]
	end

	-- Nagrand garrison mounts: Frostwolf War Wolf, Telaari Talbuk
	-- Can be summoned in combat
	for _, zoneAbility in ipairs(C_ZoneAbility.GetActiveAbilities()) do
		if zoneAbility.spellID == SpellID["Garrison Ability"] then
			local id = C_Spell.GetSpellInfo(SpellName["Garrison Ability"]).spellID
			if (id == 164222 or id == 165803)
			and SecureCmdOptionParse(GARRISON_MOUNT_CONDITION)
			and (combat or not LibFlyable:IsFlyableArea()) then
				return "/cast " .. SpellName["Garrison Ability"]
			end
			break
		end
	end
end

------------------------------------------------------------------------
------------------------------------------------------------------------

local GetMount

do
	local GROUND, ADVFLYING, FLYING, SWIMMING = 1, 2, 3, 4

	local GetMountInfoByID = C_MountJournal.GetMountInfoByID
	local GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID
	-- local GetAppliedMountEquipmentID = C_MountJournal.GetAppliedMountEquipmentID()

	local mountTypeInfo = {
		[230] = {100,0,99,0}, -- ground -- 99 flying to use in flying areas if the player doesn't have any flying mounts as favorites
		[231] = {20,0,0,60},  -- aquatic
		[232] = {0,0,0,450},  -- Abyssal Seahorse -- only in Vashj'ir
		[241] = {101,0,0,0},  -- Qiraji Battle Tanks -- only in Temple of Ahn'Qiraj
		[247] = {99,0,310,0}, -- Red Flying Cloud
		[248] = {99,0,310,0}, -- flying -- 99 ground to deprioritize in non-flying zones if any non-flying mounts are favorites
		[254] = {0,0,0,60},   -- Subdued Seahorse -- +300% swim speed in Vashj'ir, +60% swim speed elsewhere
		[269] = {100,0,0,0},  -- Water Striders
		[284] = {60,0,0,0},   -- Chauffeured Chopper
		[398] = {100,0,99,0}, -- Kua'fon's Harness
		[402] = {0,830,0,0},  -- Dragonriding
		[407] = {99,0,310,60}, -- Deepstar Polyp
		[408] = {100,0,99,0}, -- Unsuccessful Prototype Fleetpod
		[412] = {100,0,99,0}, -- Ottuks
		[424] = {100,830,0,0}, -- Dragonriding
		[436] = {100,830,0,0}, -- Dragonriding
		[437] = {100,830,0,0}, -- Dragonriding
	}

	local flexMounts = { -- flying mounts that look OK on the ground
		[219] = true, -- Headless Horseman's Mount
		[363] = true, -- Invincible
		[376] = true, -- Celestial Steed
		[421] = true, -- Winged Guardian
		[439] = true, -- Tyrael's Charger
		[451] = true, -- Jeweled Onyx Panther
		[455] = true, -- Obsidian Panther
		[456] = true, -- Sapphire Panther
		[457] = true, -- Jade Panther
		[458] = true, -- Ruby Panther
		[459] = true, -- Sunstone Panther
		[468] = true, -- Imperial Quilen
		[522] = true, -- Sky Golem
		[523] = true, -- Swift Windsteed
		[530] = true, -- Armored Skyscreamer
		[532] = true, -- Ghastly Charger
		[547] = true, -- Hearthsteed
		[552] = true, -- Ironbound Wraithcharger
		[593] = true, -- Warforged Nightmare
		[594] = true, -- Grinning Reaver
		[600] = true, -- Dread Raven
		[741] = true, -- Mystic Runesaber
		[751] = true, -- Felsteel Annihilator
		[763] = true, -- Illidari Felstalker
		[773] = true, -- Grove Defiler
		[779] = true, -- Spirit of Eche'ro
		[845] = true, -- Mechanized Lumber Extractor
		[864] = true, -- Ban-Lu, Grandmaster's Companion
		[868] = true, -- SLayer's Felbroken Shrieker
		[881] = true, -- Arcanist's Manasaber
		[885] = true, -- Highlord's Golden Charger
		[888] = true, -- Fraseer's Raging Tempest
		[892] = true, -- Highlord's Vengeful Charger
		[894] = true, -- Highlord's Valorous Charger
		[898] = true, -- Netherlord's Chaotic Wrathsteed
		[930] = true, -- Netherlord's Brimstone Wrathsteed
		[931] = true, -- Netherlord's Accursed Wrathsteed
		[932] = true, -- Lightforged Warframe
		[949] = true, -- Luminous Starseeker
		[954] = true, -- Shackled Ur'zul
		[983] = true, -- Highlord's Vigilant Charger
		[1011] = true, -- Shu-Zen, the Divine Sentinel
		[1216] = true, -- Priestess' Moonsaber
		[1217] = true, -- G.M.O.D.
		[1221] = true, -- Hogrus, Swine of Good Fortune
		[1222] = true, -- Vulpine Familiar
		[1291] = true, -- Lucky Yun
		[1306] = true, -- Swift Gloomhoof
		[1307] = true, -- Sundancer
		[1330] = true, -- Sunwarmed Furline
		[1360] = true, -- Shimmermist Runner
		[1413] = true, -- Dauntless Duskrunner
		[1426] = true, -- Ascended Skymane
		[1511] = true, -- Maelie, the Wanderer
		[1577] = true, -- Ash'adar, Harbinger of Dawn
		[1580] = true, -- Heartbond Lupine
	}

	local zoneMounts = { -- special mounts that don't need to be favorites
		[117] = true, -- Blue Qiraji Battle Tank
		[118] = true, -- Red Qiraji Battle Tank
		[119] = true, -- Yellow Qiraji Battle Tank
		[120] = true, -- Green Qiraji Battle Tank
		[125] = true, -- Riding Turtle
		[312] = true, -- Sea Turtle
		[373] = true, -- Vashj'ir Seahorse
		[420] = true, -- Subdued Seahorse
		[678] = true, -- Chauffeured Mechano-Hog
		[679] = true, -- Chauffeured Mekgineer's Chopper
		[838] = true, -- Fathom Dweller
		[855] = true, -- Darkwater Skate
		[982] = true, -- Pond Nettle
		[1166] = true, -- Great Sea Ray
		[1169] = true, -- Surf Jelly
		[1208] = true, -- Saltwater Seahorse
		[1258] = true, -- Fabious
		[1260] = true, -- Crimson Tidestallion
		[1262] = true, -- Inkscale Deepseeker
		[1304] = true, -- Mawsworn Soulhunter
		[1442] = true, -- Corridor Creeper
	}

	local repairMounts = {
		[280] = true, -- Traveler's Tundra Mammoth
		[284] = true, -- Traveler's Tundra Mammoth
		[460] = true, -- Grand Expedition Yak
		[1039] = true, -- Mighty Caravan Brutosaur
	}

	local mawMounts = {
		[1304] = true, -- Mawsworn Soulhunter
		[1442] = true, -- Corridor Creeper
	}

	local vashjirMaps = {
		[201] = true, -- Kelp'thar Forest
		[203] = true, -- Vashj'ir
		[204] = true, -- Abyssal Depths
		[205] = true, -- Shimmering Expanse
	}

	local mawMaps = {
		[1543] = true,
		[1961] = true,
	}

	local mountIDs = C_MountJournal.GetMountIDs()
	local randoms = {}

	local function IsUnderwater()
		local B, b, _, _, a = "BREATH", GetMirrorTimerInfo(2)
		return (IsSwimming() and ((b==B and a <= -1)))
	end

	local function FillMountList(targetType)
		-- print("Looking for:", targetType == SWIMMING and "SWIMMING" or targetType == FLYING and "FLYING" or "GROUND")
		wipe(randoms)

		local bestSpeed = 0
		local mapID = C_Map.GetBestMapForUnit("player")
		local mawRiding = C_QuestLog.IsQuestFlaggedCompleted(63994)
		for i = 1, #mountIDs do
			local mountID = mountIDs[i]
			local name, spellID, _, _, isUsable, _, isFavorite = GetMountInfoByID(mountID)
			if isUsable and (isFavorite or zoneMounts[mountID]) then
				local _, _, _, _, mountType = GetMountInfoExtraByID(mountID)
				local speed = mountTypeInfo[mountType][targetType]
				if mountType == 232 and not vashjirMaps[mapID] then -- Abyssal Seahorse only works in Vashj'ir
					speed = -1
				elseif mountType == 402 and not isFavorite then -- Dragonriding
					speed = speed - 1
				elseif mawMounts[mountID] then -- The Maw needs special treatment
					if mawMaps[mapID] and not mawRiding then
						speed = 101
					elseif not isFavorite then
						speed = -1
					end
				elseif speed == 99 and flexMounts[mountID] then
					speed = 100
				elseif mountType == 254 and vashjirMaps[mapID] then -- Subdued Seahorse is faster in Vashj'ir
					speed = 300
				end
				-- print("Checking:", targetType, name, mountType, "@", speed, "vs", bestSpeed)
				if speed > 0 and speed >= bestSpeed then
					if speed > bestSpeed then
						bestSpeed = speed
						wipe(randoms)
					end
					tinsert(randoms, spellID)
				end
			end
		end
		-- print("Found", #randoms, "possibilities")
		return randoms
	end

	function GetMount(forceFlying)
		local mapID = C_Map.GetBestMapForUnit("player")
		local advancedFlyable = IsAdvancedFlyableArea() and not forceFlying
		local targetType = IsUnderwater() and SWIMMING or advancedFlyable and ADVFLYING or LibFlyable:IsFlyableArea() and FLYING or GROUND
		if vashjirMaps[mapID] then targetType = SWIMMING end
		FillMountList(targetType)
		if #randoms == 0 and targetType == SWIMMING then
			-- Fall back to non-swimming mounts
			targetType = LibFlyable:IsFlyableArea() and FLYING or GROUND
			FillMountList(targetType)
		end

		if #randoms > 0 then
			local spellID = randoms[random(#randoms)]
			return "/cast " .. C_Spell.GetSpellInfo(spellID).name
		end
	end

	function GetRepairMount()
		local highestID = 0
		local preferredSpellID
		for k in pairs(repairMounts) do
			local _, spellID, _, _, isUsable = GetMountInfoByID(k)
			if isUsable then
				if k > highestID then
					highestID = k
					preferredSpellID = spellID
				end
			end
		end

		if preferredSpellID then
			return "/use " .. C_Spell.GetSpellInfo(preferredSpellID).name
		end
	end
end

------------------------------------------------------------------------
------------------------------------------------------------------------

local GetAction

local function HasRidingSkill(flyingOnly)
	local hasSkill = IsSpellKnown(90265) and 310 or IsSpellKnown(34091) and 280 or IsSpellKnown(34090) and 150
	if flyingOnly then
		return hasSkill
	end
	return hasSkill or IsSpellKnown(33391) and 100 or IsSpellKnown(33388) and 60
end

local function HasGlyph(id)
	for i = 1, NUM_GLYPH_SLOTS do
		local _, _, _, _, _, glyphID = GetGlyphSocketInfo(i)
		if id == glyphID then
			return true
		end
	end
end

------------------------------------------------------------------------

if PLAYER_CLASS == "DRUID" then
	--[[
	Travel Form
	- outdoors,nocombat,flyable +310%
	- outdoors,nocombat +100% (level 38, new in 7.1)
	- outdoors +40%
	--]]

	local BLOCKING_FORMS
	local orig_DISMOUNT = DISMOUNT

	MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform,novehicleui,nomod:" .. MOD_FORCE_FLYING .. ",nomod:" .. MOD_REPAIR_MOUNT .. "]"
	DISMOUNT = DISMOUNT .. "\n/cancelform [form]"

	function GetAction(force)
		if SecureCmdOptionParse(REPAIR_MOUNT_CONDITION) then
			return GetRepairMount()
		end

		if force or not BLOCKING_FORMS then
			BLOCKING_FORMS = "" -- in case of force
			for i = 1, GetNumShapeshiftForms() do
				local icon = strlower(GetShapeshiftFormInfo(i))
				if not strmatch(icon, "spell_nature_forceofnature") then -- Moonkin Form OK
					if BLOCKING_FORMS == "" then
						BLOCKING_FORMS = ":" .. i
					else
						BLOCKING_FORMS = BLOCKING_FORMS .. "/" .. i
					end
				end
			end
			MOUNT_CONDITION = "[outdoors,nocombat,nomounted,noform" .. BLOCKING_FORMS .. ",novehicleui,nomod:" .. MOD_FORCE_FLYING .. ",nomod:" .. MOD_REPAIR_MOUNT .. "]"
			DISMOUNT = orig_DISMOUNT .. "\n/cancelform [form" .. BLOCKING_FORMS .. "]"
		end

		local mountOK, flightOK = SecureCmdOptionParse(MOUNT_CONDITION), LibFlyable:IsFlyableArea()
		if mountOK and flightOK and IsPlayerSpell(SpellID["Travel Form"]) then
			return "/cast " .. SpellName["Travel Form"]
		end

		local mount = mountOK and not IsPlayerMoving() and GetMount()
		if mount then
			return mount
		elseif IsPlayerSpell(SpellID["Travel Form"]) and (IsOutdoors() or IsSubmerged()) then
			return "/cast [nomounted] " .. SpellName["Travel Form"]
		elseif IsPlayerSpell(SpellID["Cat Form"]) then
			return "/cast [nomounted" .. BLOCKING_FORMS .. "] " .. SpellName["Cat Form"]
		end
	end
else
	function GetAction()
		local action
		local moving = IsPlayerMoving() -- Not available in combat
		local combat = UnitAffectingCombat("player")

		if not (moving and combat) then
			if SecureCmdOptionParse(REPAIR_MOUNT_CONDITION) then
				action = GetRepairMount()
			elseif SecureCmdOptionParse(MOUNT_CONDITION) then
				action = GetMount(SecureCmdOptionParse(FORCE_FLYING_MOUNT_CONDITION))
			end
		elseif combat then
			if SecureCmdOptionParse(COMBAT_MOUNT_CONDITION) then
				action = GetMount()
			end
		end

		return action
	end
end

------------------------------------------------------------------------

local button = CreateFrame("Button", "MountMeButton", nil, "SecureActionButtonTemplate")
button:RegisterForClicks("AnyDown")
button:SetAttribute("type", "macro")

function button:Update()
	if InCombatLockdown() then return end

	self:SetAttribute("macrotext", strtrim(strjoin("\n",
		(not IsModifierKeyDown() and GetOverrideMount()) or GetAction() or "",
		GetCVarBool("autoDismountFlying") and "" or SAFE_DISMOUNT,
		DISMOUNT
	)))
end

button:SetScript("PreClick", button.Update)

------------------------------------------------------------------------

button:RegisterEvent("PLAYER_LOGIN")
button:RegisterEvent("PLAYER_ENTERING_WORLD")
button:RegisterEvent("UPDATE_BINDINGS")
button:RegisterEvent("LEARNED_SPELL_IN_TAB")
button:RegisterEvent("PLAYER_REGEN_DISABLED")
button:RegisterEvent("PLAYER_REGEN_ENABLED")
button:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
button:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
button:RegisterEvent("ZONE_CHANGED_NEW_AREA") -- zone changed
button:RegisterEvent("ZONE_CHANGED") -- indoor/outdoor transition

button:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		if not MountJournalSummonRandomFavoriteButton then
			CollectionsJournal_LoadUI()
		end
	elseif event == "UPDATE_BINDINGS" or event == "PLAYER_ENTERING_WORLD" then
		ClearOverrideBindings(self)
		local a, b = GetBindingKey("DISMOUNT")
		if a then
			SetOverrideBinding(self, false, a, "CLICK MountMeButton:LeftButton")
		end
		if b then
			SetOverrideBinding(self, false, b, "CLICK MountMeButton:LeftButton")
		end
	else
		self:Update(event == "UPDATE_SHAPESHIFT_FORMS") -- force extra update for druids
	end
end)
