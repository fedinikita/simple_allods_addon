-- GuildListAddon: при входе "hello world", кнопка — список ников гильдии (string[])

local ADDON_STATE_LOADED = 3  -- ADDON_STATE_LOADED из EnumAddonState

local function ToStr(wstr)
	if wstr == nil then return "" end
	if type(wstr) == "string" then return wstr end
	if userMods and userMods.FromWString then
		return userMods.FromWString(wstr)
	end
	return tostring(wstr)
end

local function OnAddonLoadStateChanged(ev)
	if ev.state ~= ADDON_STATE_LOADED then return end
	if ev.name ~= common.GetAddonSysName() then return end
	-- Сообщение в чат при входе в игру
	common.LogInfo("common", "hello world")
end

-- Возвращает массив никнеймов участников гильдии (string[])
local function GetGuildMemberNicknames()
	local nicknames = {}
	if not guild or not guild.IsExist then return nicknames end
	if not guild.IsExist() then return nicknames end
	local members = guild.GetMembers()
	if not members then return nicknames end
	-- Индексация с 0 (по документации)
	local i = 0
	while members[i] do
		local info = guild.GetMemberInfo(members[i])
		if info and info.name then
			nicknames[#nicknames + 1] = ToStr(info.name)
		end
		i = i + 1
	end
	return nicknames
end

-- Путь к папке аддона (для записи names.txt)
local function GetAddonFolderPath()
	local info = debug.getinfo(1, "S")
	if info and info.source and type(info.source) == "string" then
		local s = info.source:gsub("^@", "")
		local folder = s:match("^(.*[\\/])scripts[\\/]") or s:match("^(.*[\\/])")
		if folder then return folder end
	end
	return "Mods/Addons/GuildListAddon/"
end

-- Сохраняет массив ников в names.txt в папке аддона
local function SaveNicknamesToFile(nicknames)
	local folder = GetAddonFolderPath()
	local path = folder .. "names.txt"
	local f, err = io.open(path, "w")
	if not f then
		-- Пробуем путь относительно Personal (если аддон в персональных модах)
		path = "Personal/Mods/Addons/GuildListAddon/names.txt"
		f, err = io.open(path, "w")
	end
	if not f then
		common.LogInfo("common", "Не удалось сохранить names.txt: " .. tostring(err))
		return false
	end
	for i, name in ipairs(nicknames) do
		f:write(name .. "\n")
	end
	f:close()
	return true
end

local function OnGuildListButton(params)
	local nicknames = GetGuildMemberNicknames()
	if #nicknames == 0 then
		common.LogInfo("common", "Вы не в гильдии или список пуст.")
		return
	end
	if SaveNicknamesToFile(nicknames) then
		common.LogInfo("common", "Сохранено " .. #nicknames .. " ников в names.txt")
	end
	common.LogInfo("common", "Участники гильдии (" .. #nicknames .. "):")
	for i, name in ipairs(nicknames) do
		common.LogInfo("common", "  " .. i .. ". " .. name)
	end
end

common.RegisterEventHandler(OnAddonLoadStateChanged, "EVENT_ADDON_LOAD_STATE_CHANGED")
common.RegisterReactionHandler(OnGuildListButton, "guildlist")
