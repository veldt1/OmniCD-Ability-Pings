------------------------------------------------------------------------------
--
--  Ability Ping plugin for OmniCD
--  © 2025 Veldt
--
--  Allows clicking OmniCD abilities to send a message to party chat with the status of the ability.
--  Does not work in raid groups. Rate limited to 3 messages every 5 seconds.
--  OmniCD must be enabled for this to work.
--
--  https://github.com/veldt1/OmniCD-Ability-Pings
--
------------------------------------------------------------------------------

local E, L = OmniCD:unpack()
if E.preWOTLKC then
	return
end

------------------------------
--- Rate Limiting
------------------------------
local rate_limit = {}

-- If the length of rate_limit is below 3, we can send a message
-- If it is 3 or more, we need to check the time of the first message.
-- If the time of the first message is more than 5 seconds ago, we can send a new message, and reset rate_limit
local function SendMessage(str)
    -- We don't want to send messages in a raid
    if IsInRaid() then return false end

	if rate_limit and #rate_limit < 3 then
		table.insert(rate_limit, GetTime())
		SendChatMessage(str, "PARTY")
	else
		local now = GetTime()
		if rate_limit[1] and rate_limit[1] + 5 < now then
			rate_limit = {}
			table.insert(rate_limit, now)
			SendChatMessage(str, "PARTY")
		end
	end
end

------------------------------
--- OnClick Function
------------------------------

local function OmniCD_OnClick(this)
    local id = this.tooltipID or this.spellID
    local cd = this.cooldown
    local info = E.Party.groupInfo[this.guid]
    local active = info.active[id]

    local spellLink = C_Spell.GetSpellLink(id)

    local unit_name = UnitName(this.unit or "player")

    -- If the cooldown is not active, the spell is ready.
    if not active then
        -- Example for available spells: "(Player): Divine Protection - 1m12s"
        local str = ""
        if unit_name == UnitName("player") then
            str = string.format("%s - Ready", spellLink)
        else
            str = string.format("(%s): %s - Ready", unit_name, spellLink)
        end
        SendMessage(str)
        return
    end

    local maxcharges = this.maxcharges
    local charges = active.charges
    if charges and charges > 0 then
        -- Example for charge spells: "(Player): Divine Protection - Ready (2 charges)"
        local str = ""
        if unit_name == UnitName("player") then
            str = string.format("%s - Ready (%d charges)", spellLink, charges)
        else
            str = string.format("(%s): %s - Ready (%d charges)", unit_name, spellLink, charges)
        end
        SendMessage(str)
    end

    if cd:GetCooldownTimes() > 0 then
        local start, duration = cd:GetCooldownTimes()
        local remaining = (start / 1000) + (duration / 1000) - GetTime()
        -- Example for unavailable spells: "(Player): Divine Protection - 5s {cross}" (1m12s, etc)
        local str = ""
        if unit_name == UnitName("player") then
            str = string.format("%s - %ds {cross}", spellLink, remaining)
        else
            str = string.format("(%s): %s - %ds {cross}", unit_name, spellLink, remaining)
        end
        SendMessage(str)
    end
end

------------------------------
--- Hooks
------------------------------
local function HookOnClickFunc(icon)
    icon:SetScript("OnClick", OmniCD_OnClick)

    if icon.SetPassThroughButtons then
        if not E.Party.inLockdown then
            icon:SetPassThroughButtons("RightButton")
            icon.isPassThrough = true
        end
    end
end

-- This hooks the OnStartup event that is fired by OmniCD.
-- Dev Note: If the player is in a party when they reload, spec-specific spells 
-- will NOT work for the player if you only use this hook.
local function HookOnStartup()
    for icon in E.Party.IconPool:EnumerateActive() do
        HookOnClickFunc(icon)
    end
end

-- This is how we get around the player, spec-specific spells not working when the player is in a party.
local function HookInitializeFunc(framePool, icon)
    HookOnClickFunc(icon)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, is_login, is_reload)
	if is_login or is_reload then
        E.RegisterCallback(self, "OnStartup", HookOnStartup)
        E.Party:SecureHook(E.Party.IconPool, "initializeFunc", HookInitializeFunc)
	end
end)