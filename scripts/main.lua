-- GuildListAddon: при загрузке — сообщение в чат, кнопка — список ников гильдии (string[])

local ADDON_STATE_LOADED = 3  -- ADDON_STATE_LOADED из EnumAddonState

local ADDON_NAME = common.GetAddonSysName()

-- Отладка: true = писать в чат, false = отключить
local DEBUG = true
local function Dbg(msg)
	if DEBUG then LogToChat("[DBG] " .. tostring(msg)) end
end

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

-- Общая инициализация: показать окно, DnD, текст кнопки. Вызывать при загрузке аддона и при входе в мир.
local function DoAddonInit()
	LogToChat("init")
	LogToChat("hello world")
	Dbg("DoAddonInit start")
	local form = common.GetAddonMainForm()
	Dbg("form=" .. (form and ("ok") or "nil"))
	if not form then return end
	if form.Show then form:Show(true); Dbg("form:Show(true)") end
	-- Текст кнопки из Lua (как в LabMap: SetVal на дочерний TextView или на кнопку)
	local panel = form:GetChildChecked("GuildListPanel", false) or form:GetChildChecked("MainPanel", false)
	if panel then
		local btn = panel:GetChildChecked("GuildListBtn", false)
		if btn then
			if btn.SetVal and userMods and userMods.ToWString then
				pcall(function() btn:SetVal("btn_label", userMods.ToWString("MoG")) end)
				Dbg("btn:SetVal(btn_label, MoG)")
			end
			local txt = btn:GetChildChecked("GuildListBtnText", false)
			if txt and txt.SetVal and userMods and userMods.ToWString then
				pcall(function() txt:SetVal("value", userMods.ToWString("MoG")) end)
				Dbg("btnText:SetVal(value, MoG)")
			end
		else
			Dbg("btn=nil")
		end
		-- DnD сразу (форма уже есть)
		if DnD and DnD.Init then
			local ok, err = pcall(function() DnD.Init(panel, panel, true) end)
			Dbg("DnD.Init " .. (ok and "ok" or ("err=" .. tostring(err))))
		else
			Dbg("DnD or DnD.Init nil")
		end
	else
		Dbg("panel=nil")
	end
end

local function OnAddonLoadStateChanged(ev)
	if ev.state ~= ADDON_STATE_LOADED then return end
	if ev.name ~= ADDON_NAME then return end
	Dbg("EVENT_ADDON_LOAD_STATE_CHANGED")
	DoAddonInit()
end

-- При входе в игру (как в LabMap) — инициализация снова, чтобы окно и DnD работали
local function OnAvatarCreated(ev)
	Dbg("EVENT_AVATAR_CREATED")
	DoAddonInit()
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
	Dbg("кнопка guildlist нажата")
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
common.RegisterEventHandler(OnAvatarCreated, "EVENT_AVATAR_CREATED")
common.RegisterReactionHandler(OnGuildListButton, "guildlist")

-- Сразу при загрузке скрипта — чтобы видеть, что скрипт выполнился (логируем в чат при первой возможности)
pcall(function()
	if common and common.LogInfo then common.LogInfo(ADDON_NAME, "script loaded") end
	LogToChat("script loaded")
end)
