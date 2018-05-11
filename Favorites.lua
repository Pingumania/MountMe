--[[--------------------------------------------------------------------
	MountMe
	One button to mount, dismount, and use travel forms.
	Copyright 2014-2018 Phanx <addons@phanx.net>. All rights reserved.
	https://github.com/phanx-wow/MountMe
----------------------------------------------------------------------]]

local Favorites = CreateFrame("Frame")
Favorites:SetScript("OnEvent", function(f, e, ...) return f[e](f, ...) end)
Favorites:RegisterEvent("PLAYER_LOGIN")

function Favorites:PLAYER_LOGIN()
	MountMeSettings = MountMeSettings or {}

	if MountMeSettings.favoritesPerChar then
		if not MountMeFavorites then
			MountMeFavorites = self:GetFavoriteMounts()
		else
			self:SetFavoriteMounts(MountMeFavorites)
		end
		hooksecurefunc(C_MountJournal, "SetIsFavorite", self.SetIsFavorite)
		self.hooked = true
		self.active = true
	end
end

function Favorites:MOUNT_JOURNAL_SEARCH_UPDATED()
	if self.settingFavorites then
		self:SetFavoriteMounts(MountMeFavorites)
	end
end

function Favorites:GetFavoriteMounts()
	local favorites = {}
	for i = 1, C_MountJournal.GetNumDisplayedMounts() do
		local _, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i)
		if not isFavorite then
			break
		end
		favorites[mountID] = true
	end
	return favorites
end

function Favorites:SetFavoriteMounts(favorites)
	self.settingFavorites = true
	self:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
	MountJournal:UnregisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")

	for i = 1, C_MountJournal.GetNumDisplayedMounts() do
		local name, _, _, _, _, _, isFavorite, _, _, _, _, mountID = C_MountJournal.GetDisplayedMountInfo(i)
		if isFavorite and not favorites[mountID] then
			return C_MountJournal.SetIsFavorite(i, false)
		elseif favorites[mountID] and not isFavorite then
			return C_MountJournal.SetIsFavorite(i, true)
		end
	end

	self.settingFavorites = false
	self:UnregisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
	MountJournal:RegisterEvent("MOUNT_JOURNAL_SEARCH_UPDATED")
	if MountJournal:IsVisible() then
		MountJournal_FullUpdate(MountJournal)
	end
end

function Favorites.SetIsFavorite(index, isFavorite)
	local self = Favorites
	if self.settingFavorites or not self.active then return end

	-- By the time this post-hook is running, the indices have already changed,
	-- and the index passed to SetIsFavorite doesn't map to the mount that was
	-- added or removed as a favorite. We'll just get the new list and compare.

	local favorites = self:GetFavoriteMounts()
	local a = isFavorite and favorites or MountMeFavorites
	local b = isFavorite and MountMeFavorites or favorites

	for mountID in pairs(a) do
		if not b[mountID] then
			MountMeFavorites[mountID] = isFavorite and true or nil
			local name = C_MountJournal.GetMountInfoByID(mountID)
		end
	end
end

function Favorites:Enable()
	MountMeFavorites = self:GetFavoriteMounts()
	if not self.hooked then
		hooksecurefunc(C_MountJournal, "SetIsFavorite", self.SetIsFavorite)
		self.hooked = true
	end
	self.active = true
end

function Favorites:Disable()
	self.active = false
end

------------------------------------------------------------------------

local L = {
	AVAILABLE_COMMANDS = "Available commands:",
	OFF = "OFF",
	ON = "ON",
	PER_CHAR_DESC = "Save favorite mounts per character",
	PER_CHAR_OFF = "Now saving favorite mounts account-wide.",
	PER_CHAR_ON = "Now saving favorite mounts per character.",
	VERSION_INFO_S = "Version %s loaded.",
}

if GetLocale() == "deDE" then
	L.AVAILABLE_COMMANDS = "Verfügbare Befehle:"
	L.OFF = "AUS"
	L.ON = "AN"
	L.PER_CHAR_DESC = "Speichern Lieblingsreittiere pro Charakter"
	L.PER_CHAR_OFF = "Lieblingsreittiere wird nun kontoweit gespeichert."
	L.PER_CHAR_ON = "Lieblingsreittiere wird nun pro Charakter gespeichert."
	L.VERSION_INFO_S = "Version %s geladen."
elseif GetLocale():match("^es") then
	L.AVAILABLE_COMMANDS = "Comandos disponibles:"
	L.OFF = "INACTIVO"
	L.ON = "ACTIVO"
	L.PER_CHAR_DESC = "Guardar monturas favoritas por personaje"
	L.PER_CHAR_OFF = "Monturas favoritas ahora se guardan para toda la cuenta."
	L.PER_CHAR_ON = "Monturas favoritas ahora se guardan por personaje."
	L.VERSION_INFO_S = "Versión %s cargada."
end

SLASH_MOUNTME1 = "/mountme"
SlashCmdList["MOUNTME"] = function(cmd)
	cmd = (cmd or ""):lower()

	if cmd == "char" then
		local v = not MountMeSettings.favoritesPerChar
		MountMeSettings.favoritesPerChar = v
		if v then
			Favorites:Enable()
			DEFAULT_CHAT_FRAME:AddMessage(string.format("%sMountMe:|r %s", NORMAL_FONT_COLOR_CODE,
				L.PER_CHAR_ON))
		else
			Favorites:Disable()
			DEFAULT_CHAT_FRAME:AddMessage(string.format("%sMountMe:|r %s", NORMAL_FONT_COLOR_CODE,
				L.PER_CHAR_OFF))
		end
	return end

	DEFAULT_CHAT_FRAME:AddMessage(string.format("%sMountMe:|r %s %s", NORMAL_FONT_COLOR_CODE,
		string.format(L.VERSION_INFO_S, GetAddOnMetadata("MountMe", "Version")),
		L.AVAILABLE_COMMANDS))
	DEFAULT_CHAT_FRAME:AddMessage(string.format("- %s%s|r - %s (%s%s|r)", NORMAL_FONT_COLOR_CODE,
		"char", L.PER_CHAR_DESC,
		MountMeSettings.favoritesPerChar and GREEN_FONT_COLOR_CODE or GRAY_FONT_COLOR_CODE,
		MountMeSettings.favoritesPerChar and L.ON or L.OFF))
end
