local _, addonTable = ...
local DemonHunter = addonTable.DemonHunter
local MaxDps = _G.MaxDps
if not MaxDps then return end

local UnitPower = UnitPower
local UnitHealth = UnitHealth
local UnitAura = C_UnitAuras.GetAuraDataByIndex
local UnitAuraByName = C_UnitAuras.GetAuraDataBySpellName
local GetSpellDescription = GetSpellDescription
local GetSpellPowerCost = C_Spell.GetSpellPowerCost
local UnitHealthMax = UnitHealthMax
local UnitPowerMax = UnitPowerMax
local SpellHaste
local SpellCrit

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

local SoulFragments = 0
local Fury
local FuryMax
local FuryDeficit
local Pain
local PainMax
local PainDeficit

local Vengeance = {}

local fd_ready
local dont_cleave
local single_target
local small_aoe
local big_aoe
local can_spb

local function CheckSpellCosts(spell,spellstring)
    if not IsSpellKnownOrOverridesKnown(spell) then return false end
    if spellstring == 'TouchofDeath' then
        if targethealthPerc < 15 then
            return true
        else
            return false
        end
    end
    if spellstring == 'KillShot' then
        if targethealthPerc < 15 then
            return true
        else
            return false
        end
    end
    local costs = GetSpellPowerCost(spell)
    if type(costs) ~= 'table' and spellstring then return true end
    for i,costtable in pairs(costs) do
        if UnitPower('player', costtable.type) < costtable.cost then
            return false
        end
    end
    return true
end
local function MaxGetSpellCost(spell,power)
    local costs = GetSpellPowerCost(spell)
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




local function GetNumSoulFragments()
    local auraData = UnitAuraByName('player','Soul Fragments')
    if auraData and auraData.applications then
        return auraData.applications
    end
    return 0
end


function Vengeance:precombat()
    --if (MaxDps:FindSpell(classtable.Flask) and CheckSpellCosts(classtable.Flask, 'Flask')) and cooldown[classtable.Flask].ready then
    --    return classtable.Flask
    --end
    --if (MaxDps:FindSpell(classtable.Augmentation) and CheckSpellCosts(classtable.Augmentation, 'Augmentation')) and cooldown[classtable.Augmentation].ready then
    --    return classtable.Augmentation
    --end
    --if (MaxDps:FindSpell(classtable.Food) and CheckSpellCosts(classtable.Food, 'Food')) and cooldown[classtable.Food].ready then
    --    return classtable.Food
    --end
    --if (MaxDps:FindSpell(classtable.SnapshotStats) and CheckSpellCosts(classtable.SnapshotStats, 'SnapshotStats')) and cooldown[classtable.SnapshotStats].ready then
    --    return classtable.SnapshotStats
    --end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
end
function Vengeance:big_aoe()
    if (MaxDps:FindSpell(classtable.FelDevastation) and CheckSpellCosts(classtable.FelDevastation, 'FelDevastation')) and (talents[classtable.CollectiveAnguish] or talents[classtable.StoketheFlames]) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:FindSpell(classtable.TheHunt) and CheckSpellCosts(classtable.TheHunt, 'theHunt')) and cooldown[classtable.TheHunt].ready then
        return classtable.TheHunt
    end
    if (MaxDps:FindSpell(classtable.ElysianDecree) and CheckSpellCosts(classtable.ElysianDecree, 'ElysianDecree')) and (Fury >= 40 and ( SoulFragments <= 1 or SoulFragments >= 4 ) and not (MaxDps.spellHistory[1] == classtable.ElysianDecree)) and cooldown[classtable.ElysianDecree].ready then
        return classtable.ElysianDecree
    end
    if (MaxDps:FindSpell(classtable.FelDevastation) and CheckSpellCosts(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:FindSpell(classtable.SoulCarver) and CheckSpellCosts(classtable.SoulCarver, 'SoulCarver')) and (SoulFragments <3) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:FindSpell(classtable.SpiritBomb) and CheckSpellCosts(classtable.SpiritBomb, 'SpiritBomb')) and (SoulFragments >= 4) and cooldown[classtable.SpiritBomb].ready then
        return classtable.SpiritBomb
    end
    if (MaxDps:FindSpell(classtable.SoulCleave) and CheckSpellCosts(classtable.SoulCleave, 'SoulCleave')) and (not talents[classtable.SpiritBomb] and not dont_cleave) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
    if (MaxDps:FindSpell(classtable.Fracture) and CheckSpellCosts(classtable.Fracture, 'Fracture')) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:FindSpell(classtable.SoulCleave) and CheckSpellCosts(classtable.SoulCleave, 'SoulCleave')) and (not dont_cleave) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
    local fillerCheck = Vengeance:filler()
    if fillerCheck then
        return fillerCheck
    end
end
function Vengeance:externals()
end
function Vengeance:fiery_demise()
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and (talents[classtable.AscendingFlame] or debuff[classtable.SigilofFlame].count == 0) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.Felblade) and CheckSpellCosts(classtable.Felblade, 'Felblade')) and (( not talents[classtable.SpiritBomb] or ( cooldown[classtable.FelDevastation].remains <= ( timeShift + gcd ) ) ) and Fury <50) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:FindSpell(classtable.FelDevastation) and CheckSpellCosts(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:FindSpell(classtable.SoulCarver) and CheckSpellCosts(classtable.SoulCarver, 'SoulCarver')) and (SoulFragments <3) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:FindSpell(classtable.TheHunt) and CheckSpellCosts(classtable.TheHunt, 'theHunt')) and cooldown[classtable.TheHunt].ready then
        return classtable.TheHunt
    end
    if (MaxDps:FindSpell(classtable.ElysianDecree) and CheckSpellCosts(classtable.ElysianDecree, 'ElysianDecree')) and (Fury >= 40 and not (MaxDps.spellHistory[1] == classtable.ElysianDecree)) and cooldown[classtable.ElysianDecree].ready then
        return classtable.ElysianDecree
    end
    if (MaxDps:FindSpell(classtable.SpiritBomb) and CheckSpellCosts(classtable.SpiritBomb, 'SpiritBomb')) and (can_spb) and cooldown[classtable.SpiritBomb].ready then
        return classtable.SpiritBomb
    end
end
function Vengeance:filler()
    --if (MaxDps:FindSpell(classtable.SigilofChains) and CheckSpellCosts(classtable.SigilofChains, 'SigilofChains')) and (talents[classtable.CycleofBinding] and talents[classtable.SigilofChains]) and cooldown[classtable.SigilofChains].ready then
    --    return classtable.SigilofChains
    --end
    --if (MaxDps:FindSpell(classtable.SigilofMisery) and CheckSpellCosts(classtable.SigilofMisery, 'SigilofMisery')) and (talents[classtable.CycleofBinding] and talents[classtable.SigilofMisery]) and cooldown[classtable.SigilofMisery].ready then
    --    return classtable.SigilofMisery
    --end
    --if (MaxDps:FindSpell(classtable.SigilofSilence) and CheckSpellCosts(classtable.SigilofSilence, 'SigilofSilence')) and (talents[classtable.CycleofBinding] and talents[classtable.SigilofSilence]) and cooldown[classtable.SigilofSilence].ready then
    --    return classtable.SigilofSilence
    --end
    if (MaxDps:FindSpell(classtable.Felblade) and CheckSpellCosts(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:FindSpell(classtable.Shear) and CheckSpellCosts(classtable.Shear, 'Shear')) and cooldown[classtable.Shear].ready then
        return classtable.Shear
    end
    if (MaxDps:FindSpell(classtable.ThrowGlaive) and CheckSpellCosts(classtable.ThrowGlaive, 'ThrowGlaive')) and cooldown[classtable.ThrowGlaive].ready then
        return classtable.ThrowGlaive
    end
end
function Vengeance:maintenance()
    if (MaxDps:FindSpell(classtable.FieryBrand) and CheckSpellCosts(classtable.FieryBrand, 'FieryBrand')) and (talents[classtable.FieryBrand] and ( ( debuff[classtable.FieryBrand].count == 0 and ( cooldown[classtable.SigilofFlame].remains <= ( timeShift + gcd ) or cooldown[classtable.SoulCarver].remains <= ( timeShift + gcd ) or cooldown[classtable.FelDevastation].remains <= ( timeShift + gcd ) ) ) or ( talents[classtable.DownInFlames] ) )) and cooldown[classtable.FieryBrand].ready then
        return classtable.FieryBrand
    end
    if (MaxDps:FindSpell(classtable.SigilofFlame) and CheckSpellCosts(classtable.SigilofFlame, 'SigilofFlame')) and (talents[classtable.AscendingFlame] or ( debuff[classtable.SigilofFlame].count == 0 and not (MaxDps.spellHistory and MaxDps.spellHistory[1] and MaxDps.spellHistory[1] ~= classtable.SigilofFlame) )) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:FindSpell(classtable.ImmolationAura) and CheckSpellCosts(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:FindSpell(classtable.BulkExtraction) and CheckSpellCosts(classtable.BulkExtraction, 'BulkExtraction')) and (( ( 5 - SoulFragments ) <= targets ) and SoulFragments <= 2) and cooldown[classtable.BulkExtraction].ready then
        return classtable.BulkExtraction
    end
    if (MaxDps:FindSpell(classtable.SpiritBomb) and CheckSpellCosts(classtable.SpiritBomb, 'SpiritBomb')) and (can_spb) and cooldown[classtable.SpiritBomb].ready then
        return classtable.SpiritBomb
    end
    if (MaxDps:FindSpell(classtable.Felblade) and CheckSpellCosts(classtable.Felblade, 'Felblade')) and (( ( not talents[classtable.SpiritBomb] or targets == 1 ) and FuryDeficit >= 40 ) or ( ( cooldown[classtable.FelDevastation].remains <= ( timeShift + gcd ) ) and Fury <50 )) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:FindSpell(classtable.Fracture) and CheckSpellCosts(classtable.Fracture, 'Fracture')) and (( cooldown[classtable.FelDevastation].remains <= ( timeShift + gcd ) ) and Fury <50) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:FindSpell(classtable.Shear) and CheckSpellCosts(classtable.Shear, 'Shear')) and (( cooldown[classtable.FelDevastation].remains <= ( timeShift + gcd ) ) and Fury <50) and cooldown[classtable.Shear].ready then
        return classtable.Shear
    end
    if (MaxDps:FindSpell(classtable.SpiritBomb) and CheckSpellCosts(classtable.SpiritBomb, 'SpiritBomb')) and (FuryDeficit <= 30 and targets >1 and SoulFragments >= 4) and cooldown[classtable.SpiritBomb].ready then
        return classtable.SpiritBomb
    end
    if (MaxDps:FindSpell(classtable.SoulCleave) and CheckSpellCosts(classtable.SoulCleave, 'SoulCleave')) and (FuryDeficit <= 40) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
end
function Vengeance:single_target()
    if (MaxDps:FindSpell(classtable.TheHunt) and CheckSpellCosts(classtable.TheHunt, 'theHunt')) and cooldown[classtable.TheHunt].ready then
        return classtable.TheHunt
    end
    if (MaxDps:FindSpell(classtable.SoulCarver) and CheckSpellCosts(classtable.SoulCarver, 'SoulCarver')) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:FindSpell(classtable.FelDevastation) and CheckSpellCosts(classtable.FelDevastation, 'FelDevastation')) and (talents[classtable.CollectiveAnguish] or ( talents[classtable.StoketheFlames] and talents[classtable.BurningBlood] )) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:FindSpell(classtable.ElysianDecree) and CheckSpellCosts(classtable.ElysianDecree, 'ElysianDecree')) and (not (MaxDps.spellHistory[1] == classtable.ElysianDecree)) and cooldown[classtable.ElysianDecree].ready then
        return classtable.ElysianDecree
    end
    if (MaxDps:FindSpell(classtable.FelDevastation) and CheckSpellCosts(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:FindSpell(classtable.SoulCleave) and CheckSpellCosts(classtable.SoulCleave, 'SoulCleave')) and (not dont_cleave) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
    if (MaxDps:FindSpell(classtable.Fracture) and CheckSpellCosts(classtable.Fracture, 'Fracture')) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    local fillerCheck = Vengeance:filler()
    if fillerCheck then
        return fillerCheck
    end
end
function Vengeance:small_aoe()
    if (MaxDps:FindSpell(classtable.TheHunt) and CheckSpellCosts(classtable.TheHunt, 'theHunt')) and cooldown[classtable.TheHunt].ready then
        return classtable.TheHunt
    end
    if (MaxDps:FindSpell(classtable.FelDevastation) and CheckSpellCosts(classtable.FelDevastation, 'FelDevastation')) and (talents[classtable.CollectiveAnguish] or ( talents[classtable.StoketheFlames] and talents[classtable.BurningBlood] )) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:FindSpell(classtable.ElysianDecree) and CheckSpellCosts(classtable.ElysianDecree, 'ElysianDecree')) and (Fury >= 40 and ( SoulFragments <= 1 or SoulFragments >= 4 ) and not (MaxDps.spellHistory[1] == classtable.ElysianDecree)) and cooldown[classtable.ElysianDecree].ready then
        return classtable.ElysianDecree
    end
    if (MaxDps:FindSpell(classtable.FelDevastation) and CheckSpellCosts(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:FindSpell(classtable.SoulCarver) and CheckSpellCosts(classtable.SoulCarver, 'SoulCarver')) and (SoulFragments <3) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:FindSpell(classtable.SoulCleave) and CheckSpellCosts(classtable.SoulCleave, 'SoulCleave')) and (( SoulFragments <= 1 or not talents[classtable.SpiritBomb] ) and not dont_cleave) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
    if (MaxDps:FindSpell(classtable.Fracture) and CheckSpellCosts(classtable.Fracture, 'Fracture')) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    local fillerCheck = Vengeance:filler()
    if fillerCheck then
        return fillerCheck
    end
end

function DemonHunter:Vengeance()
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
    SpellHaste = UnitSpellHaste('target')
    SpellCrit = GetCritChance()
    SoulFragments = GetNumSoulFragments()
    Fury = UnitPower('player', FuryPT)
    FuryMax = UnitPowerMax('player', FuryPT)
    FuryDeficit = FuryMax - Fury
    Pain = UnitPower('player', PainPT)
    PainMax = UnitPowerMax('player', PainPT)
    PainDeficit = PainMax - Pain
	classtable.DemonSpikesBuff = 203819
	classtable.MetamorphosisBuff = 187827

    fd_ready = talents[classtable.FieryBrand] and talents[classtable.FieryDemise] and debuff[classtable.FieryBrand].count >0
    dont_cleave = ( cooldown[classtable.FelDevastation].remains <= ( 1 + gcd ) ) and Fury <80
    single_target = targets == 1
    small_aoe = targets >= 2 and targets <= 5
    big_aoe = targets >= 6
    if fd_ready then
        can_spb = ( single_target and SoulFragments >= 5 ) or ( small_aoe and SoulFragments >= 4 ) or ( big_aoe and SoulFragments >= 3 )
    else
        can_spb = ( small_aoe and SoulFragments >= 4 ) or ( big_aoe and SoulFragments >= 3 )
    end
    --if (MaxDps:FindSpell(classtable.AutoAttack) and CheckSpellCosts(classtable.AutoAttack, 'AutoAttack')) and cooldown[classtable.AutoAttack].ready then
    --    return classtable.AutoAttack
    --end
    --if (MaxDps:FindSpell(classtable.Disrupt) and CheckSpellCosts(classtable.Disrupt, 'Disrupt')) and (target.debuff.casting.up) and cooldown[classtable.Disrupt].ready then
    --    return classtable.Disrupt
    --end
    if (MaxDps:FindSpell(classtable.InfernalStrike) and CheckSpellCosts(classtable.InfernalStrike, 'InfernalStrike')) and cooldown[classtable.InfernalStrike].ready then
        --return classtable.InfernalStrike
        MaxDps:GlowCooldown(classtable.InfernalStrike, cooldown[classtable.InfernalStrike].charges == cooldown[classtable.InfernalStrike].maxCharges)
    end
    if (MaxDps:FindSpell(classtable.DemonSpikes) and CheckSpellCosts(classtable.DemonSpikes, 'DemonSpikes')) and (not buff[classtable.DemonSpikesBuff].up) and cooldown[classtable.DemonSpikes].ready then
        --return classtable.DemonSpikes
		MaxDps:GlowCooldown(classtable.DemonSpikes, cooldown[classtable.DemonSpikes].ready)
    end
    if (MaxDps:FindSpell(classtable.Metamorphosis) and CheckSpellCosts(classtable.Metamorphosis, 'Metamorphosis')) and (not buff[classtable.MetamorphosisBuff].up and cooldown[classtable.FelDevastation].remains >12) and cooldown[classtable.Metamorphosis].ready then
        --return classtable.Metamorphosis
		MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    --if (MaxDps:FindSpell(classtable.Potion) and CheckSpellCosts(classtable.Potion, 'Potion')) and cooldown[classtable.Potion].ready then
    --    return classtable.Potion
    --end
    local externalsCheck = Vengeance:externals()
    if externalsCheck then
        return externalsCheck
    end
    if (talents[classtable.FieryBrand] and talents[classtable.FieryDemise] and debuff[classtable.FieryBrand].count >0) then
        local fiery_demiseCheck = Vengeance:fiery_demise()
        if fiery_demiseCheck then
            return Vengeance:fiery_demise()
        end
    end
    local maintenanceCheck = Vengeance:maintenance()
    if maintenanceCheck then
        return maintenanceCheck
    end
    if (single_target) then
        local single_targetCheck = Vengeance:single_target()
        if single_targetCheck then
            return Vengeance:single_target()
        end
    end
    if (small_aoe) then
        local small_aoeCheck = Vengeance:small_aoe()
        if small_aoeCheck then
            return Vengeance:small_aoe()
        end
    end
    if (big_aoe) then
        local big_aoeCheck = Vengeance:big_aoe()
        if big_aoeCheck then
            return Vengeance:big_aoe()
        end
    end
    local fillerCheck = Vengeance:filler()
    if fillerCheck then
        return fillerCheck
    end

end
