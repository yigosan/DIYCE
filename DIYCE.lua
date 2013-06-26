-- DIY Combat Engine version 2.2

local g_skill  = {}
local g_lastaction = ""

function Msg(outstr,a1,a2,a3)
   DEFAULT_CHAT_FRAME:AddMessage(tostring(outstr),a1,a2,a3)
end

function ReadSkills()
   g_skill = {}
   local skillname,slot

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

-- Read Skills on Log-In/Class Change/Level-Up
       local DIYCE_EventFrame = CreateUIComponent("Frame","DIYCE_EventFrame","UIParent")
           DIYCE_EventFrame:SetScripts("OnEvent", [=[
                   if event == "PLAYER_SKILLED_CHANGED" then
                       ReadSkills()
                       end
                   ]=] )
           DIYCE_EventFrame:RegisterEvent("PLAYER_SKILLED_CHANGED")

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

function BuffList(tgt)
   local list = {}
   local buffcmd = UnitBuff
   local infocmd = UnitBuffLeftTime

   if UnitCanAttack("player",tgt) then
       buffcmd = UnitDebuff
       infocmd = UnitDebuffLeftTime
   end

   -- There is a max of 100 buffs/debuffs per unit apparently
   for i = 1,100 do
       local buff, _, stackSize, ID = buffcmd(tgt, i)
       local timeRemaining = infocmd(tgt,i)
       if buff then
           -- Ad to list by name
           local buffname = buff:gsub("(%()(.)(%))", "%2");
		   PrintDebugMessage("ADDING BUFF TO LIST : "..buffname);
		   -- local buffname = tostring(buff);
		   list[buffname] = { stack = stackSize, time = timeRemaining, id = ID }
           -- We also list by ID in case two different buffs/debuffs have the same name.
           list[ID] = {stack = stackSize, time = timeRemaining, name = buffname }
       else
           break
       end
   end

   return list
end

function CD(skillname)
   local firstskill = GetSkillDetail(2,1)
   if (g_skill[firstskill] == nil) or (g_skill[firstskill].page ~= 2) then
       ReadSkills()
   end

   if g_skill[skillname] ~= nil then
       local tt,cd = GetSkillCooldown(g_skill[skillname].page,g_skill[skillname].slot)
       return cd <= 0.4
   elseif skillname == nil then
       return false
   else
       -- Msg("Skill not available: "..skillname)        --Comment this line out if you do not wish to recieve this error message.
       return false
   end
end

function MyCombat(Skill, arg1)
   local spell_name = UnitCastingTime("player")
   local talktome = ((arg1 == "v1") or (arg1 == "v2"))
   local action,actioncd,actiondef,actioncnt

   if spell_name ~= nil then
       if (arg1 == "v2") then Msg("- ["..spell_name.."]", 0, 1, 1) end
       return true
   end

   for x,tbl in ipairs(Skill) do

   local useit = type(Skill[x].use) ~= "function" and Skill[x].use or (type(Skill[x].use) == "function" and Skill[x].use() or false)
       if useit then
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
               CastSpellByName(Skill[x].name)
               return true
           elseif string.find(Skill[x].name, "Pet Skill:") then
               action = string.gsub(Skill[x].name, "(Pet Skill:)( *)(%d+)(.*)", "%3")
                   UsePetAction(action)
               if (arg1 == "v2") then Msg(Skill[x].name.." has been fully processed") end
               return true
           end
       end
   end
   if (arg1 == "v2") then Msg("- [IDLE]", 0, 1, 1) end

   return false
end

-- function CustomAction(action)
--   if CD(action) then
--       if IsShiftKeyDown() then Msg("- "..action) end
--       g_lastaction = action
--       CastSpellByName(action)
--       return true
--   else
--       return false
--   end
-- end

function BuffTimeLeft(tgt, buffname)
   local cnt = 1
   local buff = UnitBuff(tgt,cnt)

   while buff ~= nil do
       if string.find(buff,buffname) then
           return UnitBuffLeftTime(tgt,cnt)
       end
       cnt = cnt + 1
       buff = UnitBuff(tgt,cnt)
   end

   return 0
end

function BuffParty(arg1,arg2)
--    arg1 = Quickbar slot # for targetable, instant-cast buff without a cooldown (eg. Amp Attack) for range checking.
--    arg2 = buff expiration time cutoff (in seconds) for refreshing buffs, default is 45 seconds.

   local firstskill = GetSkillDetail(2,1)
   if (g_skill[firstskill] == nil) or (g_skill[firstskill].page ~= 2) then
       ReadSkills()
	   if vocal then Msg("Skills were empty, re-read the skills..") end
   end
   
   local selfbuffs = { "Ruh Bağı", "Geliştirilmiş Zırh", "Holy Seal", "Magic Turmoil"}
   -- local groupbuffs = { "Yaşama Arzusu", "Güçlendirilmiş Saldırı", "Angel's Blessing", "Essence of Magic", "Büyü Engeli", "Yağmurun Kutsaması", "Fire Ward", "Savage Blessing", "Concentration Prayer", "Shadow Fury"  }
   local groupbuffs = { "Güçlendirilmiş Saldırı", "Angel's Blessing", "Essence of Magic", "Büyü Engeli", "Yağmurun Kutsaması", "Vahşi Kutsama", "Konsantrasyon Duası", "Shadow Fury", "Yaşama Arzusu", "Kutsal Koruma", "Gizli Zarafet"  }
   local raidbuffs = { "Vahşi Kutsama", "Güçlendirilmiş Saldırı", "Kutsal Koruma"  }

   local buffrefresh = arg2 or 45           -- Refresh buff time (seconds)
   local spell = UnitCastingTime("player")  -- Spell being cast?
   local vocal = IsShiftKeyDown()           -- Generate feedback if Shift key held

   if (spell ~= nil) then
       return
   end

   if vocal then Msg("- Checking self buffs on "..UnitName("player")) end
   for i,buff in ipairs(selfbuffs) do
	   local buffself = buff;
	   if (buff == "Geliştirilmiş Zırh") then buffself = "Gelişmiş Zırh"; end
       
	   if (g_skill[buff] ~= nil) and CD(buff) and (BuffTimeLeft("player",buffself) <= buffrefresh) then
           if vocal then Msg("- Casting "..buff.." on "..UnitName("player")) end
           TargetUnit("player")
           CastSpellByName(buff)
           return
       end
   end

   if vocal then Msg("- Checking group buffs on "..UnitName("player")) end
   for i,buff in ipairs(groupbuffs) do
	   local buffown = buff;
	   if (buff == "Yaşama Arzusu") then buffown = "Gelişmiş Yaşama Arzusu"; 
	   elseif (buff == "Vahşi Kutsama") then buffown = "Yabani Kutsama"; 
	   elseif (buff == "Gizli Zarafet") then buffown = "Gizemli Zarafet"; 
	   end
       if (g_skill[buff] ~= nil) and CD(buff) and (BuffTimeLeft("player",buffown) <= buffrefresh) then
           TargetUnit("player")
           if( buff == "Kutsal Koruma") then
				local mainclass, sideclass = UnitClass("player");
				if vocal then Msg("- Kutsal Koruma kendimize atılacakmı kontrol ediliyor. "..mainclass.." , "..sideclass) end
				if ( not ((mainclass == "Şövalye") or (mainclass == "Gardiyan" and sideclass == "Savaşçı") or (mainclass == "Savaşçı" and sideclass == "Şövalye"))) then
					if vocal then Msg("- Kutsal Koruma buffı atılıcak ve sınıflar uygun : "..UnitName("target")) end
					CastSpellByName(buff)
					return
				end
			else
				if vocal then Msg("- Casting "..buff.." on "..UnitName("player")) end
				CastSpellByName(buff)
				return
			end
       end
   end

   for num=1,GetNumPartyMembers()-1 do
       TargetUnit("party"..num)
       if GetActionUsable(arg1) and (UnitHealth("party"..num) > 0) then
           if vocal then Msg("- Checking group buffs2 on "..UnitName("party"..num)) end
		   for i,buff in ipairs(groupbuffs) do
				local buffown = buff;
				if (buff == "Yaşama Arzusu") then buffown = "Gelişmiş Yaşama Arzusu";        
				elseif (buff == "Vahşi Kutsama") then buffown = "Yabani Kutsama"; 
				elseif (buff == "Gizli Zarafet") then buffown = "Gizemli Zarafet";
				end
			   if (g_skill[buff] ~= nil) and CD(buff) and (BuffTimeLeft("target",buffown) <= buffrefresh) then
                   if UnitIsUnit("target","party"..num) then
                       if( buff == "Kutsal Koruma") then 
							local mainclass, sideclass = UnitClass("target");
							if vocal then Msg("- Kutsal Koruma "..UnitName("target").." atılacakmı kontrol ediliyor. "..mainclass.." , "..sideclass) end
							if ( not ((mainclass == "Şövalye") or (mainclass == "Gardiyan" and sideclass == "Savaşçı") or (mainclass == "Savaşçı" and sideclass == "Şövalye"))) then
								if vocal then Msg("- Casting "..buff.." on "..UnitName("target")) end
								CastSpellByName(buff)
								return
							end
						else
							if vocal then Msg("- Casting "..buff.." on "..UnitName("target")) end
							CastSpellByName(buff)
							return
						end
                   else
                       if vocal then Msg("- Error: "..UnitName("target").." != "..UnitName("party"..num)) end
                   end
               end
           end
       else
           if vocal then Msg("- Player "..UnitName("party"..num).." out of range or dead.") end
       end
   end

	if(GetNumRaidMembers() > 0) then
	   for num=1,35 do
		   TargetUnit("raid"..num)
		   local unitName = UnitName("target");
		   if (nil == unitName) then unitName = "NIL"; end
		   if nil ~= unitName and GetActionUsable(arg1) and (UnitHealth("raid"..num) > 0) then
				
			   if vocal then Msg("- Checking raid buffs on "..unitName) end
			   for i,buff in ipairs(raidbuffs) do
			   		local buffown = buff;
					if (buff == "Vahşi Kutsama") then buffown = "Yabani Kutsama"; end 
				   if (g_skill[buff] ~= nil) and CD(buff) and (BuffTimeLeft("target",buffown) <= buffrefresh) then
					   if UnitIsUnit("target","raid"..num) then
						   
						   if( buff == "Kutsal Koruma") then 
								local mainclass, sideclass = UnitClass("target");
								if vocal then Msg(UnitName("target").." MainClass = "..mainclass.." , SecondClass = "..sideclass) end
								if ( not ((mainclass == "Şövalye") or (mainclass == "Gardiyan" and sideclass == "Savaşçı") or (mainclass == "Savaşçı" and sideclass == "Şövalye"))) then
									if vocal then Msg("- Casting "..buff.." on "..UnitName("target")) end
									CastSpellByName(buff)
									return
								end
							else
								if vocal then Msg("- Casting "..buff.." on "..UnitName("target")) end
								CastSpellByName(buff)
								return
							end
					   else
						   if vocal then Msg("- Error: "..UnitName("target").." != "..unitName) end
					   end
				   end
			   end
		   else
			   if vocal then Msg("- Player "..unitName.." out of range or dead.") end
		   end
	   end
   end
   
   if vocal then Msg("- Nothing to do.") end
end

function CDLeft(skillname)
   local firstskill = GetSkillDetail(2,1)
   if (g_skill[firstskill] == nil) or (g_skill[firstskill].page ~= 2) then
       ReadSkills()
   end
   
   local tt,cd = 999,999;
   if g_skill[skillname] ~= nil then
       tt,cd = GetSkillCooldown(g_skill[skillname].page,g_skill[skillname].slot)
   elseif skillname == nil then
       return tt,cd;
   else
       Msg("Skill not available: "..skillname)        --Comment this line out if you do not wish to recieve this error message.
       return tt,cd;
   end
   return tt,cd;
end