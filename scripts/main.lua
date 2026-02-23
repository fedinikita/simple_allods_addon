-- GuildListAddon: при загрузке — сообщение в чат, кнопка — список ников гильдии (string[])

local ADDON_STATE_LOADED = 3  -- ADDON_STATE_LOADED из EnumAddonState

local ADDON_NAME = common.GetAddonSysName()

local function ToStr(wstr)
	if wstr == nil then return "" end
	if type(wstr) == "string" then return wstr end
	if userMods and userMods.FromWString then
		return userMods.FromWString(wstr)
	end
	return tostring(wstr)
end

-- Вывод в системный чат как у AddonsTools (ValuedText + PushFrontText)
local vtChat
local wtChat

local function GetSysChatContainer()
	if not stateMainForm or not stateMainForm.GetChildUnchecked then return nil end
	local w = stateMainForm:GetChildUnchecked("Chat", false)
	if not w then
		w = stateMainForm:GetChildUnchecked("Chat", true)
	else
		w = w:GetChildUnchecked("Chat", true)
	end
	if not w then
		w = stateMainForm:GetChildUnchecked("ChatLog", false)
		if w then w = w:GetChildUnchecked("Container", true) end
	end
	return w
end

local function LogToChat(msg)
	if not vtChat then
		vtChat = common.CreateValuedText()
		local fmt = "<html fontname='AllodsSystem' shadow='1'><rs class='color'><r name='addon'/><r name='text'/></rs></html>"
		vtChat:SetFormat(userMods.ToWString(fmt))
	end
	vtChat:ClearValues()
	vtChat:SetClassVal("color", "LogColorYellow")
	local msgStr = type(msg) == "string" and msg or tostring(msg)
	local msgWS = (userMods and userMods.ToWString) and userMods.ToWString(msgStr) or msgStr
	vtChat:SetVal("text", msgWS)
	local prefixWS = (userMods and userMods.ToWString) and userMods.ToWString(ADDON_NAME .. ": ") or (ADDON_NAME .. ": ")
	vtChat:SetVal("addon", prefixWS)
	if not wtChat then wtChat = GetSysChatContainer() end
	if wtChat and wtChat.PushFrontText then
		wtChat:PushFrontText(vtChat)
	else
		common.LogInfo(ADDON_NAME, msgStr)
	end
end

local function LogAddon(msg)
	common.LogInfo(ADDON_NAME, msg)
	LogToChat(msg)
end

local function OnAddonLoadStateChanged(ev)
	if ev.state ~= ADDON_STATE_LOADED then return end
	if ev.name ~= ADDON_NAME then return end
	LogToChat("загружено")
	LogToChat("hello world")
	-- Показать окно аддона с кнопкой (как у других аддонов при AutoStart)
	local form = common.GetAddonMainForm()
	if form and form.Show then form:Show(true) end
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
		LogAddon("Не удалось сохранить names.txt: " .. tostring(err))
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
		LogAddon("Вы не в гильдии или список пуст.")
		return
	end
	if SaveNicknamesToFile(nicknames) then
		LogAddon("Сохранено " .. #nicknames .. " ников в names.txt")
	end
	LogAddon("Участники гильдии (" .. #nicknames .. "):")
	for i, name in ipairs(nicknames) do
		LogAddon("  " .. i .. ". " .. name)
	end
end

common.RegisterEventHandler(OnAddonLoadStateChanged, "EVENT_ADDON_LOAD_STATE_CHANGED")
common.RegisterReactionHandler(OnGuildListButton, "guildlist")
