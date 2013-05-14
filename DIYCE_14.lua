-- DIY Combat Engine version 1.4

g_skill = {}

function Msg(outstr,a1,a2,a3)
	DEFAULT_CHAT_FRAME:AddMessage(tostring(outstr),a1,a2,a3)
end

function ReadSkills()
	g_skill = {}
	local skillname,slot

	Msg("- Reading Class Skills")
	for page = 1,4 do
		slot = 1
		skillname = GetSkillDetail(page,slot)
		repeat
			local a1,a2,a3,a4,a5,a6,a7,a8,skillusable = GetSkillDetail(page,slot)
			if skillusable then
				g_skill[skillname] = { ["page"] = page, ["slot"] = slot }
			end
			slot = slot + 1
			skillname = GetSkillDetail(page,slot)
		until skillname == nil
	end
end
ReadSkills() -- Read skills into g_skill table at login

function PctH(tgt)
	return (UnitHealth(tgt)/UnitMaxHealth(tgt))
end

function PctM(tgt)
	return (UnitMana(tgt)/UnitMaxMana(tgt))
end

function PctS(tgt)
	return (UnitSkill(tgt)/UnitMaxSkill(tgt))
end

function CancelBuff(buffname)
	local i = 1
	local buff = UnitBuff("player",i)

	while buff ~= nil do
		if buff == buffname then
			CancelPlayerBuff(i)
			return true
		end

		i = i + 1
		buff = UnitBuff("player",i)
	end
	return false
end

function BuffTimeLeft(tgt, buffname)
    local cnt = 1
    local buffcmd, bufftimecmd, buff

    if UnitCanAttack("player", tgt) then
        buffcmd = UnitDebuff
        bufftimecmd = UnitDebuffLeftTime
    else
        buffcmd = UnitBuff
        bufftimecmd = UnitBuffLeftTime
    end

    buff = buffcmd(tgt, cnt)

    while buff ~= nil do
        if string.find(buff, buffname) then
            return bufftimecmd(tgt, cnt)
        end
        cnt = cnt + 1
        buff = buffcmd(tgt, cnt)
    end

    return 0
end

function ChkBuff(tgt,buffname)
	local cnt = 1
	local buffcmd = UnitBuff

	if UnitCanAttack("player",tgt) then
		buffcmd = UnitDebuff
	end
	local buff = buffcmd(tgt,cnt)

	while buff ~= nil do
		if string.gsub(buff, "(%()(.)(%))", "%2") == buffname then
			return true
		end
		cnt = cnt + 1
		buff = buffcmd(tgt,cnt)
	end
	return false
end

function BuffList(tgt)
    local cnt = 1
    local buffcmd = UnitBuff
    local buffstr = "/"

    if UnitCanAttack("player",tgt) then
        buffcmd = UnitDebuff
    end
    local buff = buffcmd(tgt,cnt)

    while buff ~= nil do
        buffstr = buffstr..buff.."/"
        cnt = cnt + 1
        buff = buffcmd(tgt,cnt)
    end

    return string.gsub(buffstr, "(%()(.)(%))", "%2")
end

function CD(skillname)
	local firstskill = GetSkillDetail(2,1)
	if (g_skill[firstskill] == nil) or (g_skill[firstskill].page ~= 2) then
		ReadSkills()
	end

	if g_skill[skillname] ~= nil then
		local tt,cd = GetSkillCooldown(g_skill[skillname].page,g_skill[skillname].slot)
		return cd==0
	elseif skillname == nil then
		return false
	else
		Msg("Skill not available: "..skillname)
		return false
	end
end

function MyCombat(Skill, arg1, onself)
	local spell_name = UnitCastingTime("player")
	local talktome = ((arg1 == "v1") or (arg1 == "v2"))
	local action,actioncd,actiondef,actioncnt
	
	if spell_name ~= nil then
		if (arg1 == "v2") then Msg("- ["..spell_name.."]", 0, 1, 1) end
		return true
	end

	for x,tbl in ipairs(Skill) do
		if Skill[x].use then
			if string.find(Skill[x].name, "Action:") then
				action = tonumber((string.gsub(Skill[x].name, "(Action:)( *)(%d+)(.*)", "%3")))
				_1,actioncd = GetActionCooldown(action)
				actiondef,_1,actioncnt = GetActionInfo(action)
				if GetActionUsable(action) and (actioncd == 0) and (actiondef ~= nil) and (actioncnt > 0) then
					if talktome then Msg("- "..Skill[x].name) end
					UseAction(action)
					return true
				end
			elseif string.find(Skill[x].name, "Custom:") then
				action = string.gsub(Skill[x].name, "(Custom:)( *)(.*)", "%3")
				if CustomAction(action) then
					return true
				end
			elseif string.find(Skill[x].name, "Item:") then
				action = string.gsub(Skill[x].name, "(Item:)( *)(.*)", "%3")
				if talktome then Msg("- "..Skill[x].name) end
				UseItemByName(action)
				return true
			elseif CD(Skill[x].name) then
				if talktome then Msg("- "..Skill[x].name) end
				if((nil ~= onself ) and (onself == true)) then
					CastSpellByName(Skill[x].name,1)
				else
					CastSpellByName(Skill[x].name)
				end
				return true
			end
		end
	end
	if (arg1 == "v2") then Msg("- [IDLE]", 0, 1, 1) end

	return false
end
