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

-- Один раз инициализируем (не трижды из скрипта + событий)
local addonInited = false

-- DnD: клик без перетаскивания = действие кнопки (список гильдии)
local panelDndId = nil
local panelDndPendingClick = false

local function OnDndPickAttempt(params)
	if panelDndId and params.srcId == panelDndId then
		panelDndPendingClick = true
	end
end
local function OnDndDragTo()
	if panelDndId and DnD and DnD.Dragging == panelDndId then
		panelDndPendingClick = false
	end
end
local function OnDndEnd()
	if panelDndPendingClick then
		panelDndPendingClick = false
		OnGuildListButton()
	end
end

-- Общая инициализация: показать окно, DnD, текст кнопки.
local function DoAddonInit(form)
	if addonInited then return end
	form = form or mainForm or (common and common.GetAddonMainForm and common.GetAddonMainForm())
	if not form then
		LogToChat("hello world (form=nil)")
		return
	end
	addonInited = true
	LogToChat("hello world")
	if form.Show then form:Show(true) end
	local panel = form:GetChildChecked("GuildListPanel", false) or form:GetChildChecked("MainPanel", false)
	local status = "form=ok"
	if panel then
		status = status .. " panel=ok"
		local txt = panel:GetChildChecked("GuildListBtnText", false)
		if txt and txt.SetVal and userMods and userMods.ToWString then
			pcall(function() txt:SetVal("value", userMods.ToWString("MoG")) end)
		end
		-- DnD по всей панели: потянул — двигается, кликнул и отпустил — срабатывает кнопка
		if DnD and DnD.Init then
			pcall(function() DnD.Init(panel, panel, true) end)
			panelDndId = DnD.GetWidgetID and DnD.GetWidgetID(panel)
			status = status .. (panelDndId and " DnD=ok" or " DnD=ok(id=nil)")
			common.RegisterEventHandler(OnDndPickAttempt, "EVENT_DND_PICK_ATTEMPT")
			common.RegisterEventHandler(OnDndDragTo, "EVENT_DND_DRAG_TO")
			common.RegisterEventHandler(OnDndEnd, "EVENT_DND_DROP_ATTEMPT")
			common.RegisterEventHandler(OnDndEnd, "EVENT_DND_DRAG_CANCELLED")
		else
			status = status .. " DnD=nil"
		end
	else
		status = status .. " panel=nil"
	end
	LogToChat(status)
end

local function OnAddonLoadStateChanged(ev)
	if ev.state ~= ADDON_STATE_LOADED or ev.name ~= ADDON_NAME then return end
	DoAddonInit()
end

local function OnAvatarCreated(ev)
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
		LogToChat("Failed to save names.txt: " .. tostring(err))
		return false
	end
	for i, name in ipairs(nicknames) do
		f:write(name .. "\n")
	end
	f:close()
	return true
end

local function OnGuildListButton(params)
	LogToChat("Button clicked!")
	local nicknames = GetGuildMemberNicknames()
	if #nicknames == 0 then
		LogToChat("Not in guild or list empty.")
		return
	end
	if SaveNicknamesToFile(nicknames) then
		LogToChat("Saved " .. #nicknames .. " names to names.txt")
	end
	LogToChat("Guild members (" .. #nicknames .. "):")
	for i, name in ipairs(nicknames) do
		LogToChat("  " .. i .. ". " .. name)
	end
end

common.RegisterEventHandler(OnAddonLoadStateChanged, "EVENT_ADDON_LOAD_STATE_CHANGED")
common.RegisterEventHandler(OnAvatarCreated, "EVENT_AVATAR_CREATED")
common.RegisterReactionHandler(OnGuildListButton, "guildlist")

pcall(function()
	if common and common.LogInfo then common.LogInfo(ADDON_NAME, "script loaded") end
	LogToChat("script loaded")
end)
-- Инициализация при первой возможности (форма может быть готова в конце скрипта или по событию)
DoAddonInit()
