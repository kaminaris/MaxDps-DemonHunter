local _, addonTable = ...
local DemonHunter = addonTable.DemonHunter
local MaxDps = _G.MaxDps
if not MaxDps then return end

local UnitPower = UnitPower
local UnitHealth = UnitHealth
local UnitAura = C_UnitAuras.GetAuraDataByIndex
local UnitAuraByName = C_UnitAuras.GetAuraDataBySpellName
local UnitHealthMax = UnitHealthMax
local UnitPowerMax = UnitPowerMax
local SpellHaste
local SpellCrit
local GetSpellInfo = C_Spell.GetSpellInfo
local GetSpellCooldown = C_Spell.GetSpellCooldown
local GetSpellCount = C_Spell.GetSpellCastCount

local ManaPT = Enum.PowerType.Mana
local RagePT = Enum.PowerType.Rage
local FocusPT = Enum.PowerType.Focus
local EnergyPT = Enum.PowerType.Energy
local ComboPointsPT = Enum.PowerType.ComboPoints
local RunesPT = Enum.PowerType.Runes
local RunicPowerPT = Enum.PowerType.RunicPower
local SoulShardsPT = Enum.PowerType.SoulShards
local LunarPowerPT = Enum.PowerType.LunarPower
local HolyPowerPT = Enum.PowerType.HolyPower
local MaelstromPT = Enum.PowerType.Maelstrom
local ChiPT = Enum.PowerType.Chi
local InsanityPT = Enum.PowerType.Insanity
local ArcaneChargesPT = Enum.PowerType.ArcaneCharges
local FuryPT = Enum.PowerType.Fury
local PainPT = Enum.PowerType.Pain
local EssencePT = Enum.PowerType.Essence
local RuneBloodPT = Enum.PowerType.RuneBlood
local RuneFrostPT = Enum.PowerType.RuneFrost
local RuneUnholyPT = Enum.PowerType.RuneUnholy

local fd
local ttd
local timeShift
local gcd
local cooldown
local buff
local debuff
local talents
local targets
local targetHP
local targetmaxHP
local targethealthPerc
local curentHP
local maxHP
local healthPerc
local timeInCombat
local className, classFilename, classId = UnitClass('player')
local currentSpec = GetSpecialization()
local currentSpecName = currentSpec and select(2, GetSpecializationInfo(currentSpec)) or 'None'
local classtable
local LibRangeCheck = LibStub('LibRangeCheck-3.0', true)

local Fury
local FuryMax
local FuryDeficit
local Pain
local PainMax
local PainDeficit

local Havoc = {}

--local 3min_trinket
local trinket_sync_slot
local fel_barrage
local generator_up
local fury_gen
local gcd_drain

local function CheckSpellCosts(spell,spellstring)
    if not IsSpellKnownOrOverridesKnown(spell) then return false end
    if spellstring == 'TouchofDeath' then
        if targethealthPerc > 15 then
            return false
        end
    end
    if spellstring == 'KillShot' then
        if (classtable.SicEmBuff and not buff[classtable.SicEmBuff].up) and targethealthPerc > 15 then
            return false
        end
    end
    if spellstring == 'HammerofWrath' then
        if ( (classtable.AvengingWrathBuff and not buff[classtable.AvengingWrathBuff].up) or (classtable.FinalVerdictBuff and not buff[classtable.FinalVerdictBuff].up) ) and targethealthPerc > 20 then
            return false
        end
    end
    if spellstring == 'Execute' then
        if (classtable.SuddenDeathBuff and not buff[classtable.SuddenDeathBuff].up) and targethealthPerc > 35 then
            return false
        end
    end
    local costs = C_Spell.GetSpellPowerCost(spell)
    if type(costs) ~= 'table' and spellstring then return true end
    for i,costtable in pairs(costs) do
        if UnitPower('player', costtable.type) < costtable.cost then
            return false
        end
    end
    return true
end
local function MaxGetSpellCost(spell,power)
    local costs = C_Spell.GetSpellPowerCost(spell)
    if type(costs) ~= 'table' then return 0 end
    for i,costtable in pairs(costs) do
        if costtable.name == power then
            return costtable.cost
        end
    end
    return 0
end



local function CheckEquipped(checkName)
    for i=1,14 do
        local itemID = GetInventoryItemID('player', i)
        local itemName = itemID and C_Item.GetItemInfo(itemID) or ''
        if checkName == itemName then
            return true
        end
    end
    return false
end




local function CheckTrinketNames(checkName)
    --if slot == 1 then
    --    slot = 13
    --end
    --if slot == 2 then
    --    slot = 14
    --end
    for i=13,14 do
        local itemID = GetInventoryItemID('player', i)
        local itemName = C_Item.GetItemInfo(itemID)
        if checkName == itemName then
            return true
        end
    end
    return false
end


local function CheckTrinketCooldown(slot)
    if slot == 1 then
        slot = 13
    end
    if slot == 2 then
        slot = 14
    end
    if slot == 13 or slot == 14 then
        local itemID = GetInventoryItemID('player', slot)
        local _, duration, _ = C_Item.GetItemCooldown(itemID)
        if duration == 0 then return true else return false end
    else
        local tOneitemID = GetInventoryItemID('player', 13)
        local tTwoitemID = GetInventoryItemID('player', 14)
        local tOneitemName = C_Item.GetItemInfo(tOneitemID)
        local tTwoitemName = C_Item.GetItemInfo(tTwoitemID)
        if tOneitemName == slot then
            local _, duration, _ = C_Item.GetItemCooldown(tOneitemID)
            if duration == 0 then return true else return false end
        end
        if tTwoitemName == slot then
            local _, duration, _ = C_Item.GetItemCooldown(tTwoitemID)
            if duration == 0 then return true else return false end
        end
    end
end


function Havoc:precombat()
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
end
function Havoc:cooldown()
    if (MaxDps:FindSpell(classtable.Metamorphosis) and CheckSpellCosts(classtable.Metamorphosis, 'Metamorphosis')) and (( not talents[classtable.Initiative] or cooldown[classtable.VengefulRetreat].remains ) and ( ( not talents[classtable.Demonic] or (MaxDps.spellHistory[1] == classtable.DeathSweep) or (MaxDps.spellHistory[2] == classtable.DeathSweep) or (MaxDps.spellHistory[3] == classtable.DeathSweep) ) and cooldown[classtable.EyeBeam].remains and ( not talents[classtable.EssenceBreak] or debuff[classtable.EssenceBreakDeBuff].up ) and not buff[classtable.FelBarrageBuff].up and ( math.huge >40 or ( targets >8 or not talents[classtable.FelBarrage] ) and targets >2 ) or not talents[classtable.ChaoticTransformation] or ttd <30 )) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    else
        MaxDps:GlowCooldown(classtable.Metamorphosis, false)
    end
    if (MaxDps:FindSpell(classtable.TheHunt) and CheckSpellCosts(classtable.TheHunt, 'TheHunt')) and (not debuff[classtable.EssenceBreakDeBuff].up and ( targets >= 1 + targets or math.huge >( 1 + not (MaxDps.tier and MaxDps.tier[31].count >= 2) ) * 45 ) and timeInCombat >5) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    else
        MaxDps:GlowCooldown(classtable.TheHunt, false)
    end
    if (MaxDps:FindSpell(classtable.SigilofSpite) and CheckSpellCosts(classtable.SigilofSpite, 'SigilofSpite')) and (not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    else
        MaxDps:GlowCooldown(classtable.SigilofSpite, false)
    end
end
function Havoc:fel_barrage()
    generator_up = cooldown[classtable.Felblade].remains <gcd or cooldown[classtable.SigilofFlame].remains <gcd
    fury_gen = 1 % ( 2.6 * SpellHaste ) * 12 + buff[classtable.ImmolationAuraBuff].count * 6 + buff[classtable.TacticalRetreatBuff].duration * 10
    gcd_drain = gcd * 32
    if (MaxDps:FindSpell(classtable.Annihilation) and CheckSpellCosts(classtable.Annihilation, 'Annihilation')) and (buff[classtable.InnerDemonBuff].up) and cooldown[classtable.Annihilation].ready then
        return classtable.Annihilation
    end
    if (MaxDps:FindSpell(classtable.EyeBeam) and CheckSpellCosts(classtable.EyeBeam, 'EyeBeam')) and (not buff[classtable.FelBarrageBuff].up and ( targets >1 and (targets >1) or math.huge >40 )) and cooldown[classtable.EyeBeam].ready then
        return classtable.EyeBeam
    end
    if (MaxDps:FindSpell(classtable.EssenceBreak) and CheckSpellCosts(classtable.EssenceBreak, 'EssenceBreak')) and (not buff[classtable.FelBarrageBuff].up and buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.EssenceBreak].ready then
        return classtable.EssenceBreak
    end
    if (MaxDps:FindSpell(classtable.DeathSweep) and CheckSpellCosts(classtable.DeathSweep, 'DeathSweep')) and (not buff[classtable.FelBarrageBuff].up) and cooldown[classtable.DeathSweep].ready then
        return classtable.DeathSweep
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (not buff[classtable.UnboundChaosBuff].up and ( targets >2 or buff[classtable.FelBarrageBuff].up )) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.GlaiveTempest) and CheckSpellCosts(classtable.GlaiveTempest, 'GlaiveTempest')) and (not buff[classtable.FelBarrageBuff].up and targets >1) and cooldown[classtable.GlaiveTempest].ready then
        return classtable.GlaiveTempest
    end
    if (MaxDps:FindSpell(classtable.BladeDance) and CheckSpellCosts(classtable.BladeDance, 'BladeDance')) and (not buff[classtable.FelBarrageBuff].up) and cooldown[classtable.BladeDance].ready then
        return classtable.BladeDance
    end
    if (MaxDps:FindSpell(classtable.FelBarrage) and CheckSpellCosts(classtable.FelBarrage, 'FelBarrage')) and (Fury >100 and ( math.huge >90 or math.huge <gcd or targets >4 and targets >2 )) and cooldown[classtable.FelBarrage].ready then
        return classtable.FelBarrage
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and Fury >20 and buff[classtable.FelBarrageBuff].up) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and (FuryDeficit >40 and buff[classtable.FelBarrageBuff].up) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.Felblade) and CheckSpellCosts(classtable.Felblade, 'Felblade')) and (buff[classtable.FelBarrageBuff].up and FuryDeficit >40) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:FindSpell(classtable.DeathSweep) and CheckSpellCosts(classtable.DeathSweep, 'DeathSweep')) and (Fury - gcd_drain - 35 >0 and ( buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18 )) and cooldown[classtable.DeathSweep].ready then
        return classtable.DeathSweep
    end
    if (MaxDps:FindSpell(classtable.GlaiveTempest) and CheckSpellCosts(classtable.GlaiveTempest, 'GlaiveTempest')) and (Fury - gcd_drain - 30 >0 and ( buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18 )) and cooldown[classtable.GlaiveTempest].ready then
        return classtable.GlaiveTempest
    end
    if (MaxDps:FindSpell(classtable.BladeDance) and CheckSpellCosts(classtable.BladeDance, 'BladeDance')) and (Fury - gcd_drain - 35 >0 and ( buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18 )) and cooldown[classtable.BladeDance].ready then
        return classtable.BladeDance
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.TheHunt) and CheckSpellCosts(classtable.TheHunt, 'TheHunt')) and (Fury >40 and ( targets >= 1 )) and cooldown[classtable.TheHunt].ready then
        return classtable.TheHunt
    end
    if (MaxDps:FindSpell(classtable.DemonsBite) and CheckSpellCosts(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        return classtable.DemonsBite
    end
end
function Havoc:meta()
    if (MaxDps:FindSpell(classtable.DeathSweep) and CheckSpellCosts(classtable.DeathSweep, 'DeathSweep')) and (buff[classtable.MetamorphosisBuff].remains <gcd) and cooldown[classtable.DeathSweep].ready then
        return classtable.DeathSweep
    end
    if (MaxDps:FindSpell(classtable.Annihilation) and CheckSpellCosts(classtable.Annihilation, 'Annihilation')) and (buff[classtable.MetamorphosisBuff].remains <gcd) and cooldown[classtable.Annihilation].ready then
        return classtable.Annihilation
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and talents[classtable.Inertia]) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (talents[classtable.Momentum] and buff[classtable.MomentumBuff].remains <gcd * 2) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.Annihilation) and CheckSpellCosts(classtable.Annihilation, 'Annihilation')) and (buff[classtable.InnerDemonBuff].up and ( cooldown[classtable.EyeBeam].remains <gcd * 3 and cooldown[classtable.BladeDance].remains or cooldown[classtable.Metamorphosis].remains <gcd * 3 )) and cooldown[classtable.Annihilation].ready then
        return classtable.Annihilation
    end
    if (MaxDps:FindSpell(classtable.EssenceBreak) and CheckSpellCosts(classtable.EssenceBreak, 'EssenceBreak')) and (Fury >20 and ( cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd * 2 ) and ( not buff[classtable.UnboundChaosBuff].up or buff[classtable.InertiaBuff].up or not talents[classtable.Inertia] ) or ttd <10) and cooldown[classtable.EssenceBreak].ready then
        return classtable.EssenceBreak
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (not debuff[classtable.EssenceBreakDeBuff].up and cooldown[classtable.BladeDance].remains >gcd + 0.5 and not buff[classtable.UnboundChaosBuff].up and talents[classtable.Inertia] and not buff[classtable.InertiaBuff].up and buff[classtable.MetamorphosisBuff].remains >5) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.DeathSweep) and CheckSpellCosts(classtable.DeathSweep, 'DeathSweep')) and cooldown[classtable.DeathSweep].ready then
        return classtable.DeathSweep
    end
    if (MaxDps:FindSpell(classtable.EyeBeam) and CheckSpellCosts(classtable.EyeBeam, 'EyeBeam')) and (not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up) and cooldown[classtable.EyeBeam].ready then
        return classtable.EyeBeam
    end
    if (MaxDps:FindSpell(classtable.GlaiveTempest) and CheckSpellCosts(classtable.GlaiveTempest, 'GlaiveTempest')) and (not debuff[classtable.EssenceBreakDeBuff].up and ( cooldown[classtable.BladeDance].remains >gcd * 2 or Fury >60 ) and ( targets >= 1 + targets or math.huge >10 )) and cooldown[classtable.GlaiveTempest].ready then
        return classtable.GlaiveTempest
    end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and (targets >2) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.Annihilation) and CheckSpellCosts(classtable.Annihilation, 'Annihilation')) and (cooldown[classtable.BladeDance].remains >gcd * 2 or Fury >60 or buff[classtable.MetamorphosisBuff].remains <5 and cooldown[classtable.Felblade].up) and cooldown[classtable.Annihilation].ready then
        return classtable.Annihilation
    end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and (buff[classtable.MetamorphosisBuff].remains >5) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.Felblade) and CheckSpellCosts(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and (not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (cooldown[classtable.ImmolationAura].duration <( cooldown[classtable.EyeBeam].remains <buff[classtable.MetamorphosisBuff].remains ) and ( targets >= 2 )) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (talents[classtable.Momentum]) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.FelRush].duration <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and ( cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.FelRush].charges >1.01 )) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.DemonsBite) and CheckSpellCosts(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        return classtable.DemonsBite
    end
end
function Havoc:opener()
    if (MaxDps:FindSpell(classtable.VengefulRetreat) and CheckSpellCosts(classtable.VengefulRetreat, 'VengefulRetreat')) and ((MaxDps.spellHistory[1] == classtable.DeathSweep)) and cooldown[classtable.VengefulRetreat].ready then
        return classtable.VengefulRetreat
    end
    if (MaxDps:FindSpell(classtable.Metamorphosis) and CheckSpellCosts(classtable.Metamorphosis, 'Metamorphosis')) and ((MaxDps.spellHistory[1] == classtable.DeathSweep) or ( not talents[classtable.ChaoticTransformation] ) and ( not talents[classtable.Initiative] or cooldown[classtable.VengefulRetreat].remains >2 ) or not talents[classtable.Demonic]) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    else
        MaxDps:GlowCooldown(classtable.Metamorphosis, false)
    end
    if (MaxDps:FindSpell(classtable.Felblade) and CheckSpellCosts(classtable.Felblade, 'Felblade')) and (not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (cooldown[classtable.ImmolationAura].charges == 2 and not buff[classtable.UnboundChaosBuff].up and ( not buff[classtable.InertiaBuff].up or targets >2 )) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.Annihilation) and CheckSpellCosts(classtable.Annihilation, 'Annihilation')) and (buff[classtable.InnerDemonBuff].up and ( not talents[classtable.ChaoticTransformation] or cooldown[classtable.Metamorphosis].up )) and cooldown[classtable.Annihilation].ready then
        return classtable.Annihilation
    end
    if (MaxDps:FindSpell(classtable.EyeBeam) and CheckSpellCosts(classtable.EyeBeam, 'EyeBeam')) and (not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up and ( not buff[classtable.MetamorphosisBuff].up or cooldown[classtable.BladeDance].remains )) and cooldown[classtable.EyeBeam].ready then
        return classtable.EyeBeam
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (talents[classtable.Inertia] and ( not buff[classtable.InertiaBuff].up or targets >2 ) and buff[classtable.UnboundChaosBuff].up) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.TheHunt) and CheckSpellCosts(classtable.TheHunt, 'TheHunt')) and (targets >1) and cooldown[classtable.TheHunt].ready then
        return classtable.TheHunt
    end
    if (MaxDps:FindSpell(classtable.EssenceBreak) and CheckSpellCosts(classtable.EssenceBreak, 'EssenceBreak')) and cooldown[classtable.EssenceBreak].ready then
        return classtable.EssenceBreak
    end
    if (MaxDps:FindSpell(classtable.DeathSweep) and CheckSpellCosts(classtable.DeathSweep, 'DeathSweep')) and cooldown[classtable.DeathSweep].ready then
        return classtable.DeathSweep
    end
    if (MaxDps:FindSpell(classtable.Annihilation) and CheckSpellCosts(classtable.Annihilation, 'Annihilation')) and cooldown[classtable.Annihilation].ready then
        return classtable.Annihilation
    end
    if (MaxDps:FindSpell(classtable.DemonsBite) and CheckSpellCosts(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        return classtable.DemonsBite
    end
end

function DemonHunter:Havoc()
    fd = MaxDps.FrameData
    ttd = (fd.timeToDie and fd.timeToDie) or 500
    timeShift = fd.timeShift
    gcd = fd.gcd
    cooldown = fd.cooldown
    buff = fd.buff
    debuff = fd.debuff
    talents = fd.talents
    targets = MaxDps:SmartAoe()
    Mana = UnitPower('player', ManaPT)
    ManaMax = UnitPowerMax('player', ManaPT)
    ManaDeficit = ManaMax - Mana
    targetHP = UnitHealth('target')
    targetmaxHP = UnitHealthMax('target')
    targethealthPerc = (targetHP / targetmaxHP) * 100
    curentHP = UnitHealth('player')
    maxHP = UnitHealthMax('player')
    healthPerc = (curentHP / maxHP) * 100
    timeInCombat = MaxDps.combatTime or 0
    classtable = MaxDps.SpellTable
    SpellHaste = UnitSpellHaste('player')
    SpellCrit = GetCritChance()
    Fury = UnitPower('player', FuryPT)
    FuryMax = UnitPowerMax('player', FuryPT)
    FuryDeficit = FuryMax - Fury
    Pain = UnitPower('player', PainPT)
    PainMax = UnitPowerMax('player', PainPT)
    PainDeficit = PainMax - Pain
    classtable.EssenceBreakDeBuff = 320338
    classtable.FelBarrageBuff = 258925
    classtable.ImmolationAuraBuff = 258920
    classtable.TacticalRetreatBuff = 389890
    classtable.InnerDemonBuff = 390145
    classtable.MetamorphosisBuff = 162264
    classtable.UnboundChaosBuff = 347462
    classtable.MomentumBuff = 208628
    classtable.InertiaBuff = 427641
    if buff[classtable.ImmolationAuraBuff].up then
		classtable.ImmolationAura = 427917
	else
		classtable.ImmolationAura = 258920
	end

    fel_barrage = talents[classtable.FelBarrage] and ( cooldown[classtable.FelBarrage].remains <gcd * 7 and ( targets >= 1 + targets or math.huge <gcd * 7 or math.huge >90 ) and ( cooldown[classtable.Metamorphosis].remains or targets >2 ) or buff[classtable.FelBarrageBuff].up ) and not ( targets == 1 and (targets <2) )
    if (MaxDps:FindSpell(classtable.Disrupt) and CheckSpellCosts(classtable.Disrupt, 'Disrupt')) and cooldown[classtable.Disrupt].ready then
        MaxDps:GlowCooldown(classtable.Disrupt, select(8,UnitCastingInfo('target') == false) and cooldown[classtable.Disrupt].ready)
    else
        MaxDps:GlowCooldown(classtable.Disrupt, false)
    end
    local cooldownCheck = Havoc:cooldown()
    if cooldownCheck then
        return cooldownCheck
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and buff[classtable.UnboundChaosBuff].remains <gcd * 2) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (( cooldown[classtable.EyeBeam].up or cooldown[classtable.Metamorphosis].up ) and timeInCombat <15 and ( math.huge >40 )) then
        local openerCheck = Havoc:opener()
        if openerCheck then
            return Havoc:opener()
        end
    end
    if (fel_barrage and (targets >1)) then
        local fel_barrageCheck = Havoc:fel_barrage()
        if fel_barrageCheck then
            return Havoc:fel_barrage()
        end
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (targets >2 and talents[classtable.Ragefire] and not buff[classtable.UnboundChaosBuff].up and ( not talents[classtable.FelBarrage] or cooldown[classtable.FelBarrage].remains >cooldown[classtable.ImmolationAura].duration ) and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (targets >2 and talents[classtable.Ragefire] and (targets >1) and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and targets >2 and ( not talents[classtable.Inertia] or cooldown[classtable.EyeBeam].duration + 2 >buff[classtable.UnboundChaosBuff].remains )) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.VengefulRetreat) and CheckSpellCosts(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and ( cooldown[classtable.EyeBeam].remains >15 and gcd <0.3 or gcd <0.1 and cooldown[classtable.EyeBeam].remains <= gcd and ( cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd * 2 ) ) and timeInCombat >4) and cooldown[classtable.VengefulRetreat].ready then
        return classtable.VengefulRetreat
    end
    if (fel_barrage or not talents[classtable.DemonBlades] and talents[classtable.FelBarrage] and ( buff[classtable.FelBarrageBuff].up or cooldown[classtable.FelBarrage].up ) and not buff[classtable.MetamorphosisBuff].up) then
        local fel_barrageCheck = Havoc:fel_barrage()
        if fel_barrageCheck then
            return Havoc:fel_barrage()
        end
    end
    if (buff[classtable.MetamorphosisBuff].up) then
        local metaCheck = Havoc:meta()
        if metaCheck then
            return Havoc:meta()
        end
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and talents[classtable.Inertia] and not buff[classtable.InertiaBuff].up and cooldown[classtable.BladeDance].remains <4 and cooldown[classtable.EyeBeam].remains >5 and ( cooldown[classtable.ImmolationAura].charges >0 or cooldown[classtable.ImmolationAura].duration + 2 <cooldown[classtable.EyeBeam].remains or cooldown[classtable.EyeBeam].remains >buff[classtable.UnboundChaosBuff].remains - 2 )) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (talents[classtable.Momentum] and cooldown[classtable.EyeBeam].remains <gcd * 2) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (not buff[classtable.UnboundChaosBuff].up ) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.Inertia] and not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.EyeBeam].remains <5 and ( targets >= 2 )) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.Inertia] and not buff[classtable.InertiaBuff].up and not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.ImmolationAura].duration + 5 <cooldown[classtable.EyeBeam].duration and cooldown[classtable.BladeDance].remains and cooldown[classtable.BladeDance].remains <4 and ( targets >= 2 ) and cooldown[classtable.ImmolationAura].charges >1.00) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (ttd <15 and cooldown[classtable.BladeDance].remains) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.EyeBeam) and CheckSpellCosts(classtable.EyeBeam, 'EyeBeam')) and (not talents[classtable.EssenceBreak] and ( not talents[classtable.ChaoticTransformation] or cooldown[classtable.Metamorphosis].remains <5 + 3 * (talents[classtable.ShatteredDestiny] and talents[classtable.ShatteredDestiny] or 0) or cooldown[classtable.Metamorphosis].remains >15 ) and ( targets >2 )) and cooldown[classtable.EyeBeam].ready then
        return classtable.EyeBeam
    end
    if (MaxDps:FindSpell(classtable.EyeBeam) and CheckSpellCosts(classtable.EyeBeam, 'EyeBeam')) and (talents[classtable.EssenceBreak] and ( cooldown[classtable.EssenceBreak].remains <gcd * 2 + 5 * (talents[classtable.ShatteredDestiny] and talents[classtable.ShatteredDestiny] or 0) or talents[classtable.ShatteredDestiny] and cooldown[classtable.EssenceBreak].remains >10 ) and ( cooldown[classtable.BladeDance].remains <7 or (targets >1) ) and ( not talents[classtable.Initiative] or cooldown[classtable.VengefulRetreat].remains >10 or (targets >1) ) and ( not talents[classtable.Inertia] or buff[classtable.UnboundChaosBuff].up or cooldown[classtable.ImmolationAura].charges == 0 and cooldown[classtable.ImmolationAura].duration >5 ) and ( not (targets >1) or targets >8 ) or ttd <10) and cooldown[classtable.EyeBeam].ready then
        return classtable.EyeBeam
    end
    if (MaxDps:FindSpell(classtable.BladeDance) and CheckSpellCosts(classtable.BladeDance, 'BladeDance')) and (cooldown[classtable.EyeBeam].remains >gcd or cooldown[classtable.EyeBeam].up) and cooldown[classtable.BladeDance].ready then
        return classtable.BladeDance
    end
    if (MaxDps:FindSpell(classtable.GlaiveTempest) and CheckSpellCosts(classtable.GlaiveTempest, 'GlaiveTempest')) and (targets >= 1 + targets or math.huge >10) and cooldown[classtable.GlaiveTempest].ready then
        return classtable.GlaiveTempest
    end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and (targets >3) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.ChaosStrike) and CheckSpellCosts(classtable.ChaosStrike, 'ChaosStrike')) and (debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ChaosStrike].ready then
        return classtable.ChaosStrike
    end
    if (MaxDps:FindSpell(classtable.Felblade) and CheckSpellCosts(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:FindSpell(classtable.ThrowGlaive) and CheckSpellCosts(classtable.ThrowGlaive, 'ThrowGlaive')) and (cooldown[classtable.Metamorphosis].remains >5 and talents[classtable.Soulscar] and (MaxDps.tier and MaxDps.tier[31].count >= 2)) and cooldown[classtable.ThrowGlaive].ready then
        return classtable.ThrowGlaive
    end
    if (MaxDps:FindSpell(classtable.ThrowGlaive) and CheckSpellCosts(classtable.ThrowGlaive, 'ThrowGlaive')) and (not (MaxDps.tier and MaxDps.tier[31].count >= 2) and ( targets >1 or talents[classtable.Soulscar] )) and cooldown[classtable.ThrowGlaive].ready then
        return classtable.ThrowGlaive
    end
    if (MaxDps:FindSpell(classtable.ChaosStrike) and CheckSpellCosts(classtable.ChaosStrike, 'ChaosStrike')) and (cooldown[classtable.EyeBeam].remains >gcd * 2 or Fury >80) and cooldown[classtable.ChaosStrike].ready then
        return classtable.ChaosStrike
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and (not talents[classtable.Inertia] and ( targets >2 )) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and (not debuff[classtable.EssenceBreakDeBuff].up and ( not talents[classtable.FelBarrage] or cooldown[classtable.FelBarrage].remains >25 or ( targets == 1 and (targets <2) ) )) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.DemonsBite) and CheckSpellCosts(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        return classtable.DemonsBite
    end
    if (MaxDps:FindSpell(classtable.FelRush) and CheckSpellCosts(classtable.FelRush, 'FelRush')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.FelRush].duration <cooldown[classtable.EyeBeam].duration and not debuff[classtable.EssenceBreakDeBuff].up and ( cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.FelRush].charges >1.01 )) and cooldown[classtable.FelRush].ready then
        return classtable.FelRush
    end

end
