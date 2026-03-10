-- GuildListAddon

local ADDON_NAME = common.GetAddonSysName():match("/([^/]+)$")

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

local function LogToChat(msg, color)
    local color = color or "LogColorYellow"
    local vtChat = common.CreateValuedText()
    local fmt = "<html fontname='AllodsSystem' shadow='1'><rs class='color'><r name='addon'/><r name='text'/></rs></html>"
    vtChat:SetFormat(userMods.ToWString(fmt))
    vtChat:ClearValues()
    vtChat:SetClassVal("color", color)
    local msgStr = type(msg) == "string" and msg or tostring(msg)
    local msgWS = (userMods and userMods.ToWString) and userMods.ToWString(msgStr) or msgStr
    vtChat:SetVal("text", msgWS)
    local prefixWS = (userMods and userMods.ToWString) and userMods.ToWString(ADDON_NAME .. ": ") or (ADDON_NAME .. ": ")
    vtChat:SetVal("addon", prefixWS)
    local wtChat = GetSysChatContainer()
    if wtChat then
        wtChat:PushFrontText(vtChat)
    end
end

function GetConfig( name )
	local cfg = userMods.GetGlobalConfigSection( common.GetAddonName() )
	if not name then return cfg end
	return cfg and cfg[ name ]
end

function SetConfig( name, value )
	local cfg = userMods.GetGlobalConfigSection( common.GetAddonName() ) or {}
	if type( name ) == "table" then
		for i, v in pairs( name ) do cfg[ i ] = v end
	elseif name ~= nil then
		cfg[ name ] = value
	end
	userMods.SetGlobalConfigSection( common.GetAddonName(), cfg )
end

local function TableToString(tbl)
    if type(tbl) == "string" then
        return '"' .. tbl:gsub('"', '\\"') .. '"'
    elseif type(tbl) == "number" then
        return tostring(tbl)
    elseif type(tbl) == "boolean" then
        return tbl and "true" or "false"
    elseif type(tbl) == "table" then
        local parts = {}
        for k, v in pairs(tbl) do
            table.insert(parts, TableToString(k) .. "=" .. TableToString(v))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else
        return '"???"'
    end
end

local function SafeExecute(func, description)
    local success, result = pcall(func)
    if success then
		LogToChat("empty")
        return result
    else
        LogToChat("Error in " .. description .. ": " .. tostring(result), "LogColorRed")
        return nil
    end
end

-- Функция-обработчик события EventGuildAppeared
local function OnGuildAppeared()
    local members = guild.GetMembers()
	local playerNames = {}

	for i = 0, #members do
		local memberId = members[i]
		if memberId then
			local memberInfo = guild.GetMemberInfo(memberId)
			if memberInfo then
				local name = userMods.FromWString(memberInfo.name)
				table.insert(playerNames, name)
			end
		end
	end

	-- Преобразуем список в строку формата ['Name1', 'Name2']
	local namesString = "['" .. table.concat(playerNames, "', '") .. "']"

	-- Сохраняем в конфиг
	SetConfig("GuildPlayers", namesString)
	LogToChat("Saved  players to data/Mods/Configs/GuildListAddon/user.cfg", "LogColorGreen")
end

-- Основная функция инициализации
local function DoAddonInit()
    -- LogToChat("GuildListAddon initializing", "LogColorYellow")

    if guild.IsExist() then
        OnGuildAppeared() -- Вызовем обработчик сразу, если гильдия уже есть
    else
    end

    -- LogToChat("========================")
    -- LogToChat("GuildListAddon initialization complete", "LogColorGreen") 
end

common.RegisterEventHandler(OnGuildAppeared, "EVENT_GUILD_APPEARED")

-- Запускаем инициализацию
DoAddonInit()