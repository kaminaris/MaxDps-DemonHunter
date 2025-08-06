local _, addonTable = ...
local DemonHunter = addonTable.DemonHunter
local MaxDps = _G.MaxDps
if not MaxDps then return end
local LibStub = LibStub
local setSpell

local ceil = ceil
local floor = floor
local fmod = fmod
local format = format
local max = max
local min = min
local pairs = pairs
local select = select
local strsplit = strsplit
local GetTime = GetTime

local UnitAffectingCombat = UnitAffectingCombat
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitGUID = UnitGUID
local UnitName = UnitName
local UnitSpellHaste = UnitSpellHaste
local UnitThreatSituation = UnitThreatSituation
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
local GetSpellCastCount = C_Spell.GetSpellCastCount
local GetUnitSpeed = GetUnitSpeed
local GetCritChance = GetCritChance
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = C_Item.GetItemInfo
local GetItemSpell = C_Item.GetItemSpell
local GetNamePlates = C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates or GetNamePlates
local GetPowerRegenForPowerType = GetPowerRegenForPowerType
local GetSpellName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName or GetSpellInfo
local GetTotemInfo = GetTotemInfo
local IsStealthed = IsStealthed
local IsCurrentSpell = C_Spell and C_Spell.IsCurrentSpell
local CombatLogGetCurrentEventInfo = CombatLogGetCurrentEventInfo

local ManaPT = Enum.PowerType.Mana
local RagePT = Enum.PowerType.Rage
local FocusPT = Enum.PowerType.Focus
local EnergyPT = Enum.PowerType.Energy
local ComboPointsPT = Enum.PowerType.ComboPoints
local RunesPT = Enum.PowerType.Runes
local RunicPowerPT = Enum.PowerType.RunicPower
local SoulShardsPT = Enum.PowerType.SoulShards
local DemonicFuryPT = Enum.PowerType.DemonicFury
local BurningEmbersPT = Enum.PowerType.BurningEmbers
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
local classtable
local LibRangeCheck = LibStub('LibRangeCheck-3.0', true)

local Fury
local FuryMax
local FuryDeficit
local FuryPerc
local FuryRegen
local FuryRegenCombined
local FuryTimeToMax
local Pain
local PainMax
local PainDeficit
local PainPerc
local PainRegen
local PainRegenCombined
local PainTimeToMax
local SoulFragments
local SoulFragmentsMax
local SoulFragmentsDeficit
local SoulFragmentsPerc
local SoulFragmentsRegen
local SoulFragmentsRegenCombined
local SoulFragmentsTimeToMax
local SoulFragments

local Vengeance = {}

local single_target = false
local small_aoe = false
local big_aoe = false
local trinket_1_buffs = false
local trinket_2_buffs = false
local num_spawnable_souls = 0
local spb_threshold = false
local can_spb = false
local can_spb_soon = false
local can_spb_one_gcd = false
local double_rm_expires = 0
local double_rm_remains = 0
local trigger_overflow = false
local rg_enhance_cleave = 0
local souls_before_next_rg_sequence = 0
local crit_pct = false
local fel_dev_sequence_time = false
local fel_dev_passive_fury_gen = 0
local spbomb_threshold = false
local can_spbomb = false
local can_spbomb_soon = false
local can_spbomb_one_gcd = false
local spburst_threshold = false
local can_spburst = false
local can_spburst_soon = false
local can_spburst_one_gcd = false
local meta_prep_time = false
local dont_soul_cleave = false
local fiery_brand_back_before_meta = false
local hold_sof_for_meta = false
local hold_sof_for_fel_dev = false
local hold_sof_for_student = false
local hold_sof_for_dot = false
local hold_sof_for_precombat = false


local function GetNumSoulFragments()
    local auraData = UnitAuraByName('player','Soul Fragments')
    if auraData and auraData.applications then
        return auraData.applications
    end
    return 0
end


function Vengeance:precombat()
    single_target = targets == 1
    small_aoe = targets >= 2 and targets <= 5
    big_aoe = targets >= 6
    trinket_1_buffs = MaxDps:HasOnUseEffect('13') or (MaxDps:HasBuffEffect('13', 'agility') or MaxDps:HasBuffEffect('13', 'mastery') or MaxDps:HasBuffEffect('13', 'versatility') or MaxDps:HasBuffEffect('13', 'haste') or MaxDps:HasBuffEffect('13', 'crit'))
    trinket_2_buffs = MaxDps:HasOnUseEffect('14') or (MaxDps:HasBuffEffect('14', 'agility') or MaxDps:HasBuffEffect('14', 'mastery') or MaxDps:HasBuffEffect('14', 'versatility') or MaxDps:HasBuffEffect('14', 'haste') or MaxDps:HasBuffEffect('14', 'crit'))
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and ((MaxDps.ActiveHeroTree == 'aldrachireaver') or ((MaxDps.ActiveHeroTree == 'felscarred') and talents[classtable.StudentofSuffering])) and cooldown[classtable.SigilofFlame].ready and not UnitAffectingCombat('player') then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready and not UnitAffectingCombat('player') then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
end
function Vengeance:ar()
    if talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up then
        spb_threshold = ((single_target and 1 or 0) * 5)+((small_aoe and 1 or 0) * 5)+((big_aoe and 1 or 0) * 4)
    else
        spb_threshold = ((single_target and 1 or 0) * 5)+((small_aoe and 1 or 0) * 5)+((big_aoe and 1 or 0) * 4)
    end
    if talents[classtable.SpiritBomb] then
        can_spb = SoulFragments >= spb_threshold
    else
        can_spb = false
    end
    if talents[classtable.SpiritBomb] then
        can_spb_soon = SoulFragments >= spb_threshold
    else
        can_spb_soon = false
    end
    if talents[classtable.SpiritBomb] then
        can_spb_one_gcd = (SoulFragments + num_spawnable_souls)>=spb_threshold
    else
        can_spb_one_gcd = false
    end
    if not buff[classtable.GlaiveFlurryBuff].up and buff[classtable.RendingStrikeBuff].up then
        double_rm_expires = timeInCombat + 2+20
    end
    if (double_rm_expires - timeInCombat)>0 then
        double_rm_remains = double_rm_expires - timeInCombat
    else
        double_rm_remains = 0
    end
    if not buff[classtable.GlaiveFlurryBuff].up and not buff[classtable.RendingStrikeBuff].up and not (MaxDps.spellHistory[1] == classtable.ReaversGlaive) then
        trigger_overflow = 0
    end
    if trigger_overflow or (targets >= 4) or (ttd <10 or ttd <10) then
        rg_enhance_cleave = 1
    else
        rg_enhance_cleave = 0
    end
    souls_before_next_rg_sequence = SoulFragments + buff[classtable.ArtoftheGlaiveBuff].count
    souls_before_next_rg_sequence = souls_before_next_rg_sequence+(1.1*(1 + SpellHaste))*(double_rm_remains-(2 + 2+2 + gcd+(0.5 * gcd)))
    if cooldown[classtable.SigilofSpite].remains<(double_rm_remains - gcd-(2 - (talents[classtable.SoulSigils] and talents[classtable.SoulSigils] or 0))) then
        souls_before_next_rg_sequence = souls_before_next_rg_sequence+3 + (talents[classtable.SoulSigils] and talents[classtable.SoulSigils] or 0)
    end
    if cooldown[classtable.SoulCarver].remains<(double_rm_remains - gcd) then
        souls_before_next_rg_sequence = souls_before_next_rg_sequence+3
    end
    if cooldown[classtable.SoulCarver].remains<(double_rm_remains - gcd-3) then
        souls_before_next_rg_sequence = souls_before_next_rg_sequence+3
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket1, 'trinket1')) and (not trinket_1_buffs or (trinket_1_buffs and ((buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up) or ((MaxDps.spellHistory[1] == classtable.ReaversGlaive)) or (buff[classtable.ThrilloftheFightDamageBuff].remains >8) or (buff[classtable.ReaversGlaiveBuff].up and cooldown[classtable.TheHunt].remains <5)))) and cooldown[classtable.trinket1].ready then
        MaxDps:GlowCooldown(classtable.trinket1, cooldown[classtable.trinket1].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket2, 'trinket2')) and (not trinket_2_buffs or (trinket_2_buffs and ((buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up) or ((MaxDps.spellHistory[1] == classtable.ReaversGlaive)) or (buff[classtable.ThrilloftheFightDamageBuff].remains >8) or (buff[classtable.ReaversGlaiveBuff].up and cooldown[classtable.TheHunt].remains <5)))) and cooldown[classtable.trinket2].ready then
        MaxDps:GlowCooldown(classtable.trinket2, cooldown[classtable.trinket2].ready)
    end
    if (buff[classtable.GlaiveFlurryBuff].up or buff[classtable.RendingStrikeBuff].up or (MaxDps.spellHistory[1] == classtable.ReaversGlaive)) then
        Vengeance:rg_sequence()
    end
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (timeInCombat <5 or cooldown[classtable.FelDevastation].remains >= 20) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not buff[classtable.ReaversGlaiveBuff].up and (buff[classtable.ArtoftheGlaiveBuff].count + SoulFragments)<20) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBomb, 'SpiritBomb') and talents[classtable.SpiritBomb]) and (can_spb and (SoulFragments >2 or (MaxDps.spellHistory[1] == classtable.SigilofSpite) or (MaxDps.spellHistory[1] == classtable.SoulCarver) or (targets >= 4 and talents[classtable.Fallout] and cooldown[classtable.ImmolationAura].remains <gcd))) and cooldown[classtable.SpiritBomb].ready then
        if not setSpell then setSpell = classtable.SpiritBomb end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and ((targets >= 4) or (not buff[classtable.ReaversGlaiveBuff].up or (double_rm_remains>((2 + 2+2 + gcd+(0.5 * gcd))+gcd)))) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and ((talents[classtable.AscendingFlame] or (not (MaxDps.spellHistory[1] == classtable.SigilofFlame) and debuff[classtable.SigilofFlameDeBuff].remains<(4 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0)))) and (not buff[classtable.ReaversGlaiveBuff].up or (double_rm_remains>((2 + 2+2 + gcd+(0.5 * gcd))+gcd)))) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (buff[classtable.ReaversGlaiveBuff].up and targets <4 and debuff[classtable.ReaversMarkDeBuff].up and (double_rm_remains>(2 + 2+2 + gcd+(0.5 * gcd))) and (not buff[classtable.ThrilloftheFightDamageBuff].up or (buff[classtable.ThrilloftheFightDamageBuff].remains<(2 + 2+2 + gcd+(0.5 * gcd)))) and ((double_rm_remains-(2 + 2+2 + gcd+(0.5 * gcd)))>(2 + 2+2 + gcd+(0.5 * gcd))) and ((souls_before_next_rg_sequence >= 20) or (double_rm_remains>((2 + 2+2 + gcd+(0.5 * gcd))+cooldown[classtable.TheHunt].remains + 2)))) then
        Vengeance:rg_overflow()
    end
    if (MaxDps:boss() and (ttd <10 or ttd <10)) then
        Vengeance:ar_execute()
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (not buff[classtable.ReaversGlaiveBuff].up and (double_rm_remains<=(timeShift+(2 + 2+2 + gcd+(0.5 * gcd)))) and (SoulFragments <3 and ((buff[classtable.ArtoftheGlaiveBuff].count + SoulFragments)>=20))) and cooldown[classtable.SoulCleave].ready then
        if not setSpell then setSpell = classtable.SoulCleave end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBomb, 'SpiritBomb') and talents[classtable.SpiritBomb]) and (not buff[classtable.ReaversGlaiveBuff].up and (double_rm_remains<=(timeShift+(2 + 2+2 + gcd+(0.5 * gcd)))) and ((buff[classtable.ArtoftheGlaiveBuff].count + SoulFragments)>=20)) and cooldown[classtable.SpiritBomb].ready then
        if not setSpell then setSpell = classtable.SpiritBomb end
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (not buff[classtable.ReaversGlaiveBuff].up and (double_rm_remains<=(timeShift+(2 + 2+2 + gcd+(0.5 * gcd)))) and ((buff[classtable.ArtoftheGlaiveBuff].count+(math.max(targets , 5)))>=20)) and cooldown[classtable.BulkExtraction].ready then
        if not setSpell then setSpell = classtable.BulkExtraction end
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and ((Fury+(rg_enhance_cleave * 25)+((talents[classtable.KeenEngagement] and talents[classtable.KeenEngagement] or 0) * 20))>=30 and ((not buff[classtable.ThrilloftheFightAttackSpeedBuff].up or (double_rm_remains<=(2 + 2+2 + gcd+(0.5 * gcd)))) or (targets >= 4)) and not (buff[classtable.RendingStrikeBuff].up or buff[classtable.GlaiveFlurryBuff].up)) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    if ((Fury+(rg_enhance_cleave * 25)+((talents[classtable.KeenEngagement] and talents[classtable.KeenEngagement] or 0) * 20))<30 and ((not buff[classtable.ThrilloftheFightAttackSpeedBuff].up or (double_rm_remains<=(2 + 2+2 + gcd+(0.5 * gcd)))) or (targets >= 4))) then
        Vengeance:rg_prep()
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and ((not talents[classtable.FieryDemise] and MaxDps:DebuffCounter(classtable.FieryBrandDeBuff) == 0) or (talents[classtable.DownInFlames] and (cooldown[classtable.FieryBrand].fullRecharge <gcd)) or (talents[classtable.FieryDemise] and MaxDps:DebuffCounter(classtable.FieryBrandDeBuff) == 0 and (buff[classtable.ReaversGlaiveBuff].up or cooldown[classtable.TheHunt].remains <5 or buff[classtable.ArtoftheGlaiveBuff].count >= 15 or buff[classtable.ThrilloftheFightDamageBuff].remains >5))) and cooldown[classtable.FieryBrand].ready then
        if not setSpell then setSpell = classtable.FieryBrand end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (buff[classtable.ThrilloftheFightDamageBuff].up or (Fury >= 80 and (can_spb or can_spb_soon)) or ((SoulFragments + buff[classtable.ArtoftheGlaiveBuff].count+((1.1*(1 + format('%.0f',UnitSpellHaste('player'))))*(double_rm_remains-(2 + 2+2 + gcd+(0.5 * gcd)))))<20)) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBomb, 'SpiritBomb') and talents[classtable.SpiritBomb]) and (can_spb) and cooldown[classtable.SpiritBomb].ready then
        if not setSpell then setSpell = classtable.SpiritBomb end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and ((can_spb or can_spb_soon) and Fury <40) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and ((can_spb or can_spb_soon) and Fury <40 and not cooldown[classtable.Felblade].ready and talents[classtable.UnhinderedAssault]) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and ((can_spb or can_spb_soon or can_spb_one_gcd) and Fury <40) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver') and talents[classtable.SoulCarver]) and (buff[classtable.ThrilloftheFightDamageBuff].up or ((SoulFragments + buff[classtable.ArtoftheGlaiveBuff].count+((1.1*(1 + format('%.0f',UnitSpellHaste('player'))))*(double_rm_remains-(2 + 2+2 + gcd+(0.5 * gcd)))))<20)) and cooldown[classtable.SoulCarver].ready then
        if not setSpell then setSpell = classtable.SoulCarver end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and (not buff[classtable.MetamorphosisBuff].up and ((double_rm_remains>((2 + 2+2 + gcd+(0.5 * gcd))+2)) or (targets >= 4)) and ((cooldown[classtable.Fracture].fullRecharge<(2 + gcd)) or (not single_target and buff[classtable.ThrilloftheFightDamageBuff].up))) and cooldown[classtable.FelDevastation].ready then
        if not setSpell then setSpell = classtable.FelDevastation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (cooldown[classtable.FelDevastation].remains <gcd and Fury <50) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (cooldown[classtable.FelDevastation].remains <gcd and Fury <50 and not cooldown[classtable.Felblade].ready and talents[classtable.UnhinderedAssault]) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (cooldown[classtable.FelDevastation].remains <gcd and Fury <50) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and ((cooldown[classtable.Fracture].fullRecharge <gcd) or buff[classtable.MetamorphosisBuff].up or can_spb or can_spb_soon or buff[classtable.WarbladesHungerBuff].count >= 5) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (SoulFragments >= 1) and cooldown[classtable.SoulCleave].ready then
        if not setSpell then setSpell = classtable.SoulCleave end
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (targets >= 3) and cooldown[classtable.BulkExtraction].ready then
        if not setSpell then setSpell = classtable.BulkExtraction end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and cooldown[classtable.SoulCleave].ready then
        if not setSpell then setSpell = classtable.SoulCleave end
    end
    if (MaxDps:CheckSpellUsable(classtable.Shear, 'Shear')) and cooldown[classtable.Shear].ready then
        if not setSpell then setSpell = classtable.Shear end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
end
function Vengeance:ar_execute()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and ((Fury+(rg_enhance_cleave * 25)+((talents[classtable.KeenEngagement] and talents[classtable.KeenEngagement] or 0) * 20))>=30 and not (buff[classtable.RendingStrikeBuff].up or buff[classtable.GlaiveFlurryBuff].up)) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    if (buff[classtable.ReaversGlaiveBuff].up and (Fury+(rg_enhance_cleave * 25)+((talents[classtable.KeenEngagement] and talents[classtable.KeenEngagement] or 0) * 20))<30) then
        Vengeance:rg_prep()
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not buff[classtable.ReaversGlaiveBuff].up) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (targets >= 3 and buff[classtable.ArtoftheGlaiveBuff].count >= 20) and cooldown[classtable.BulkExtraction].ready then
        if not setSpell then setSpell = classtable.BulkExtraction end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and cooldown[classtable.FieryBrand].ready then
        if not setSpell then setSpell = classtable.FieryBrand end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver') and talents[classtable.SoulCarver]) and cooldown[classtable.SoulCarver].ready then
        if not setSpell then setSpell = classtable.SoulCarver end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        if not setSpell then setSpell = classtable.FelDevastation end
    end
end
function Vengeance:fel_dev()
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (buff[classtable.DemonsurgeSpiritBurstBuff].up and (can_spburst or SoulFragments >= 4 or (buff[classtable.MetamorphosisBuff].remains<(gcd * 2)))) and cooldown[classtable.SpiritBurst].ready then
        if not setSpell then setSpell = classtable.SpiritBurst end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (buff[classtable.DemonsurgeSoulSunderBuff].up and (not buff[classtable.DemonsurgeSpiritBurstBuff].up or (buff[classtable.MetamorphosisBuff].remains<(gcd * 2)))) and cooldown[classtable.SoulSunder].ready then
        if not setSpell then setSpell = classtable.SoulSunder end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and ((not talents[classtable.CycleofBinding] or (cooldown[classtable.SigilofSpite].duration<(cooldown[classtable.Metamorphosis].remains + 18))) and (SoulFragments <= 2 and buff[classtable.DemonsurgeSpiritBurstBuff].up)) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver') and talents[classtable.SoulCarver]) and (SoulFragments <= 2 and not (MaxDps.spellHistory[1] == classtable.SigilofSpite) and buff[classtable.DemonsurgeSpiritBurstBuff].up) and cooldown[classtable.SoulCarver].ready then
        if not setSpell then setSpell = classtable.SoulCarver end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (SoulFragments <= 2 and buff[classtable.DemonsurgeSpiritBurstBuff].up) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.DemonsurgeSpiritBurstBuff].up or buff[classtable.DemonsurgeSoulSunderBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (buff[classtable.DemonsurgeSpiritBurstBuff].up or buff[classtable.DemonsurgeSoulSunderBuff].up) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
end
function Vengeance:fel_dev_prep()
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (not hold_sof_for_precombat and not hold_sof_for_student and not hold_sof_for_dot) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and (talents[classtable.FieryDemise] and ((Fury + fel_dev_passive_fury_gen)>=120) and (can_spburst or can_spburst_soon or SoulFragments >= 4) and MaxDps:DebuffCounter(classtable.FieryBrandDeBuff) == 0 and ((cooldown[classtable.Metamorphosis].remains<(timeShift + 2+(gcd * 2))) or fiery_brand_back_before_meta)) and cooldown[classtable.FieryBrand].ready then
        if not setSpell then setSpell = classtable.FieryBrand end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and (((Fury + fel_dev_passive_fury_gen)>=120) and (can_spburst or can_spburst_soon or SoulFragments >= 4)) and cooldown[classtable.FelDevastation].ready then
        if not setSpell then setSpell = classtable.FelDevastation end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and ((not talents[classtable.CycleofBinding] or (cooldown[classtable.SigilofSpite].duration<(cooldown[classtable.Metamorphosis].remains + 18))) and (SoulFragments <= 1 or (not (can_spburst or can_spburst_soon or SoulFragments >= 4) and cooldown[classtable.Fracture].charges <1))) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver') and talents[classtable.SoulCarver]) and ((not talents[classtable.CycleofBinding] or cooldown[classtable.Metamorphosis].remains >20) and (SoulFragments <= 1 or (not (can_spburst or can_spburst_soon or SoulFragments >= 4) and cooldown[classtable.Fracture].charges <1)) and not (MaxDps.spellHistory[1] == classtable.SigilofSpite) and not (MaxDps.spellHistory[1] == classtable.SigilofSpite)) and cooldown[classtable.SoulCarver].ready then
        if not setSpell then setSpell = classtable.SoulCarver end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and ((Fury + fel_dev_passive_fury_gen)<120 and (can_spburst or can_spburst_soon or SoulFragments >= 4)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (not (can_spburst or can_spburst_soon or SoulFragments >= 4) or (Fury + fel_dev_passive_fury_gen)<120) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        if not setSpell then setSpell = classtable.FelDevastation end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (((Fury + fel_dev_passive_fury_gen)>=150)) and cooldown[classtable.SoulCleave].ready then
        if not setSpell then setSpell = classtable.SoulCleave end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
end
function Vengeance:fs()
    if MaxDps:DebuffCounter(classtable.SigilofFlameDeBuff) >0 and talents[classtable.VolatileFlameblood] then
        crit_pct = (SpellCrit+((talents[classtable.AuraofPain] and talents[classtable.AuraofPain] or 0) * 6))%100
    end
    fel_dev_sequence_time = 2+(2 * gcd)
    if talents[classtable.FieryDemise] and cooldown[classtable.FieryBrand].ready then
        fel_dev_sequence_time = fel_dev_sequence_time+gcd
    end
    if cooldown[classtable.SigilofFlame].ready or cooldown[classtable.SigilofFlame].remains <fel_dev_sequence_time then
        fel_dev_sequence_time = fel_dev_sequence_time+gcd
    end
    if cooldown[classtable.ImmolationAura].ready or cooldown[classtable.ImmolationAura].remains <fel_dev_sequence_time then
        fel_dev_sequence_time = fel_dev_sequence_time+gcd
    end
    fel_dev_passive_fury_gen = 0
    if (talents[classtable.StudentofSuffering] and true or false) and (buff[classtable.StudentofSufferingBuff].remains >1 or (MaxDps.spellHistory[1] == classtable.SigilofFlame)) then
        fel_dev_passive_fury_gen = fel_dev_passive_fury_gen+2.5 * floor((math.max(buff[classtable.StudentofSufferingBuff].remains , fel_dev_sequence_time)))
    end
    if (cooldown[classtable.SigilofFlame].remains <fel_dev_sequence_time) then
        fel_dev_passive_fury_gen = fel_dev_passive_fury_gen+30+(2 * (talents[classtable.FlamesofFury] and talents[classtable.FlamesofFury] or 0)*targets)
    end
    if cooldown[classtable.ImmolationAura].remains <fel_dev_sequence_time then
        fel_dev_passive_fury_gen = fel_dev_passive_fury_gen+8
    end
    if buff[classtable.ImmolationAuraBuff].remains >1 then
        fel_dev_passive_fury_gen = fel_dev_passive_fury_gen+2 * floor((math.max(buff[classtable.ImmolationAuraBuff].remains , fel_dev_sequence_time)))
    end
    if talents[classtable.VolatileFlameblood] and buff[classtable.ImmolationAuraBuff].remains >1 then
        fel_dev_passive_fury_gen = fel_dev_passive_fury_gen+7.5 * crit_pct*floor((math.max(buff[classtable.ImmolationAuraBuff].remains , fel_dev_sequence_time)))
    end
    if (talents[classtable.DarkglareBoon] and true or false) then
        fel_dev_passive_fury_gen = fel_dev_passive_fury_gen+22
    end
    if talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up then
        spbomb_threshold = ((single_target and 1 or 0) * 5)+((small_aoe and 1 or 0) * 5)+((big_aoe and 1 or 0) * 4)
    else
        spbomb_threshold = ((single_target and 1 or 0) * 5)+((small_aoe and 1 or 0) * 5)+((big_aoe and 1 or 0) * 4)
    end
    if talents[classtable.SpiritBomb] then
        can_spbomb = SoulFragments >= spbomb_threshold
    else
        can_spbomb = false
    end
    if talents[classtable.SpiritBomb] then
        can_spbomb_soon = SoulFragments >= spbomb_threshold
    else
        can_spbomb_soon = false
    end
    if talents[classtable.SpiritBomb] then
        can_spbomb_one_gcd = (SoulFragments + num_spawnable_souls)>=spbomb_threshold
    else
        can_spbomb_one_gcd = false
    end
    if talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up then
        spburst_threshold = ((single_target and 1 or 0) * 5)+((small_aoe and 1 or 0) * 5)+((big_aoe and 1 or 0) * 4)
    else
        spburst_threshold = ((single_target and 1 or 0) * 5)+((small_aoe and 1 or 0) * 5)+((big_aoe and 1 or 0) * 4)
    end
    if talents[classtable.SpiritBomb] then
        can_spburst = SoulFragments >= spburst_threshold
    else
        can_spburst = false
    end
    if talents[classtable.SpiritBomb] then
        can_spburst_soon = SoulFragments >= spburst_threshold
    else
        can_spburst_soon = false
    end
    if talents[classtable.SpiritBomb] then
        can_spburst_one_gcd = (SoulFragments + num_spawnable_souls)>=spburst_threshold
    else
        can_spburst_one_gcd = false
    end
    meta_prep_time = 0
    if talents[classtable.FieryDemise] and cooldown[classtable.FieryBrand].ready then
        meta_prep_time = meta_prep_time+2
    end
    meta_prep_time = meta_prep_time+2 * cooldown[classtable.SigilofFlame].charges
    if buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeHardcastBuff].up then
        dont_soul_cleave = buff[classtable.DemonsurgeSpiritBurstBuff].up or (buff[classtable.MetamorphosisBuff].remains<(gcd * 2) and ((Fury + fel_dev_passive_fury_gen)<120 or not (can_spburst or can_spburst_soon or SoulFragments >= 4)))
    else
        dont_soul_cleave = (cooldown[classtable.FelDevastation].remains<(gcd * 3) and ((Fury + fel_dev_passive_fury_gen)<120) or not (can_spburst or can_spburst_soon or SoulFragments >= 4))
    end
    if talents[classtable.DownInFlames] then
        fiery_brand_back_before_meta = cooldown[classtable.FieryBrand].charges >= cooldown[classtable.FieryBrand].maxCharges or (cooldown[classtable.FieryBrand].charges >= 1 and cooldown[classtable.FieryBrand].fullRecharge <= gcd+timeShift) or (cooldown[classtable.FieryBrand].charges >= 1 and ((1-(cooldown[classtable.FieryBrand].charges - 1))*cooldown[classtable.FieryBrand].duration)<=cooldown[classtable.Metamorphosis].remains)
    else
        fiery_brand_back_before_meta = (cooldown[classtable.FieryBrand].duration <= cooldown[classtable.Metamorphosis].remains)
    end
    if talents[classtable.IlluminatedSigils] then
        hold_sof_for_meta = (cooldown[classtable.SigilofFlame].charges >= 1 and ((1-(cooldown[classtable.SigilofFlame].charges - 1))*cooldown[classtable.SigilofFlame].duration)>cooldown[classtable.Metamorphosis].remains)
    else
        hold_sof_for_meta = cooldown[classtable.SigilofFlame].duration >cooldown[classtable.Metamorphosis].remains
    end
    if talents[classtable.IlluminatedSigils] then
        hold_sof_for_fel_dev = (cooldown[classtable.SigilofFlame].charges >= 1 and ((1-(cooldown[classtable.SigilofFlame].charges - 1))*cooldown[classtable.SigilofFlame].duration)>cooldown[classtable.FelDevastation].remains)
    else
        hold_sof_for_fel_dev = cooldown[classtable.SigilofFlame].duration >cooldown[classtable.FelDevastation].remains
    end
    if talents[classtable.StudentofSuffering] then
        hold_sof_for_student = (MaxDps.spellHistory[1] == classtable.SigilofFlame) or (buff[classtable.StudentofSufferingBuff].remains>(4 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0)))
    else
        hold_sof_for_student = false
    end
    if talents[classtable.AscendingFlame] then
        hold_sof_for_dot = 0
    else
        hold_sof_for_dot = (MaxDps.spellHistory[1] == classtable.SigilofFlame) or (debuff[classtable.SigilofFlameDeBuff].remains>(4 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0)))
    end
    hold_sof_for_precombat = (talents[classtable.IlluminatedSigils] and timeInCombat<(2 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0)))
    if (MaxDps:CheckSpellUsable(classtable.trinket1, 'trinket1')) and (not trinket_1_buffs or (trinket_1_buffs and ((buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeHardcastBuff].up) or (buff[classtable.MetamorphosisBuff].up and not buff[classtable.DemonsurgeHardcastBuff].up and cooldown[classtable.Metamorphosis].remains <10) or (cooldown[classtable.Metamorphosis].remains >MaxDps:CheckTrinketCooldown('13').duration) or (trinket_2_buffs and MaxDps:CheckTrinketCooldown('14').remains <cooldown[classtable.Metamorphosis].remains)))) and cooldown[classtable.trinket1].ready then
        MaxDps:GlowCooldown(classtable.trinket1, cooldown[classtable.trinket1].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket2, 'trinket2')) and (not trinket_2_buffs or (trinket_2_buffs and ((buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeHardcastBuff].up) or (buff[classtable.MetamorphosisBuff].up and not buff[classtable.DemonsurgeHardcastBuff].up and cooldown[classtable.Metamorphosis].remains <10) or (cooldown[classtable.Metamorphosis].remains >MaxDps:CheckTrinketCooldown('14').duration) or (trinket_1_buffs and MaxDps:CheckTrinketCooldown('13').remains <cooldown[classtable.Metamorphosis].remains)))) and cooldown[classtable.trinket2].ready then
        MaxDps:GlowCooldown(classtable.trinket2, cooldown[classtable.trinket2].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (timeInCombat <4) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (not (cooldown[classtable.Metamorphosis].ready and (MaxDps.spellHistory[1] == classtable.SigilofFlame)) and not (talents[classtable.Fallout] and talents[classtable.SpiritBomb] and targets >= 3 and ((buff[classtable.MetamorphosisBuff].up and (can_spburst or can_spburst_soon)) or (not buff[classtable.MetamorphosisBuff].up and (can_spbomb or can_spbomb_soon)))) and not (buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeHardcastBuff].up)) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (not talents[classtable.StudentofSuffering] and not hold_sof_for_dot and not hold_sof_for_precombat) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (not hold_sof_for_precombat and (cooldown[classtable.SigilofFlame].charges == cooldown[classtable.SigilofFlame].maxCharges or (not hold_sof_for_student and not hold_sof_for_dot and not hold_sof_for_meta and not hold_sof_for_fel_dev))) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and (MaxDps:DebuffCounter(classtable.FieryBrandDeBuff) == 0 and (not talents[classtable.FieryDemise] or ((talents[classtable.DownInFlames] and cooldown[classtable.FieryBrand].charges >= cooldown[classtable.FieryBrand].maxCharges) or fiery_brand_back_before_meta))) and cooldown[classtable.FieryBrand].ready then
        if not setSpell then setSpell = classtable.FieryBrand end
    end
    if (ttd <20) then
        Vengeance:fs_execute()
    end
    if (buff[classtable.MetamorphosisBuff].up and not buff[classtable.DemonsurgeHardcastBuff].up and (buff[classtable.DemonsurgeSoulSunderBuff].up or buff[classtable.DemonsurgeSpiritBurstBuff].up)) then
        Vengeance:fel_dev()
    end
    if (buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeHardcastBuff].up) then
        Vengeance:metamorphosis()
    end
    if (not buff[classtable.DemonsurgeHardcastBuff].up and (cooldown[classtable.FelDevastation].ready or (cooldown[classtable.FelDevastation].remains<=(gcd * 3)))) then
        Vengeance:fel_dev_prep()
    end
    if ((cooldown[classtable.Metamorphosis].remains <= meta_prep_time) and not cooldown[classtable.FelDevastation].ready and not (cooldown[classtable.FelDevastation].remains <10) and not buff[classtable.DemonsurgeSoulSunderBuff].up and not buff[classtable.DemonsurgeSpiritBurstBuff].up) then
        Vengeance:meta_prep()
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (((cooldown[classtable.SigilofSpite].remains <timeShift or cooldown[classtable.SoulCarver].remains <timeShift) and cooldown[classtable.FelDevastation].remains<(timeShift + gcd) and Fury <50)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver') and talents[classtable.SoulCarver]) and ((not talents[classtable.FieryDemise] or talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up) and ((not talents[classtable.SpiritBomb] or single_target) or (talents[classtable.SpiritBomb] and not (MaxDps.spellHistory[1] == classtable.SigilofSpite) and ((SoulFragments + 3<=5 and Fury >= 40) or (SoulFragments == 0 and Fury >= 15))))) and cooldown[classtable.SoulCarver].ready then
        if not setSpell then setSpell = classtable.SoulCarver end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and ((not talents[classtable.CycleofBinding] or (cooldown[classtable.SigilofSpite].duration<(cooldown[classtable.Metamorphosis].remains + 18))) and (not talents[classtable.SpiritBomb] or (Fury >= 80 and (can_spbomb or can_spbomb_soon)) or (SoulFragments<=(2 - (talents[classtable.SoulSigils] and talents[classtable.SoulSigils] or 0))))) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (can_spburst and talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up and cooldown[classtable.FelDevastation].remains>=(gcd * 3)) and cooldown[classtable.SpiritBurst].ready then
        if not setSpell then setSpell = classtable.SpiritBurst end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBomb, 'SpiritBomb') and talents[classtable.SpiritBomb]) and (can_spbomb and talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up and cooldown[classtable.FelDevastation].remains>=(gcd * 3)) and cooldown[classtable.SpiritBomb].ready then
        if not setSpell then setSpell = classtable.SpiritBomb end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (single_target and not dont_soul_cleave) and cooldown[classtable.SoulSunder].ready then
        if not setSpell then setSpell = classtable.SoulSunder end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (single_target and not dont_soul_cleave) and cooldown[classtable.SoulCleave].ready then
        if not setSpell then setSpell = classtable.SoulCleave end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (can_spburst and cooldown[classtable.FelDevastation].remains>=(gcd * 3)) and cooldown[classtable.SpiritBurst].ready then
        if not setSpell then setSpell = classtable.SpiritBurst end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBomb, 'SpiritBomb') and talents[classtable.SpiritBomb]) and (can_spbomb and cooldown[classtable.FelDevastation].remains>=(gcd * 3)) and cooldown[classtable.SpiritBomb].ready then
        if not setSpell then setSpell = classtable.SpiritBomb end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (((Fury <40 and ((buff[classtable.MetamorphosisBuff].up and (can_spburst or can_spburst_soon)) or (not buff[classtable.MetamorphosisBuff].up and (can_spbomb or can_spbomb_soon)))))) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (((Fury <40 and ((buff[classtable.MetamorphosisBuff].up and (can_spburst or can_spburst_soon)) or (not buff[classtable.MetamorphosisBuff].up and (can_spbomb or can_spbomb_soon)))) or (buff[classtable.MetamorphosisBuff].up and can_spburst_one_gcd) or (not buff[classtable.MetamorphosisBuff].up and can_spbomb_one_gcd))) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (FuryDeficit >= 40) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (not dont_soul_cleave) and cooldown[classtable.SoulSunder].ready then
        if not setSpell then setSpell = classtable.SoulSunder end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (not dont_soul_cleave) and cooldown[classtable.SoulCleave].ready then
        if not setSpell then setSpell = classtable.SoulCleave end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
end
function Vengeance:fs_execute()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and cooldown[classtable.FieryBrand].ready then
        if not setSpell then setSpell = classtable.FieryBrand end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver') and talents[classtable.SoulCarver]) and cooldown[classtable.SoulCarver].ready then
        if not setSpell then setSpell = classtable.SoulCarver end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        if not setSpell then setSpell = classtable.FelDevastation end
    end
end
function Vengeance:meta_prep()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (cooldown[classtable.SigilofFlame].charges <1) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and (talents[classtable.FieryDemise] and ((talents[classtable.DownInFlames] and cooldown[classtable.FieryBrand].charges >= cooldown[classtable.FieryBrand].maxCharges) or MaxDps:DebuffCounter(classtable.FieryBrandDeBuff) == 0)) and cooldown[classtable.FieryBrand].ready then
        if not setSpell then setSpell = classtable.FieryBrand end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
end
function Vengeance:metamorphosis()
    if (MaxDps:CheckSpellUsable(classtable.FelDesolation, 'FelDesolation')) and (buff[classtable.MetamorphosisBuff].remains<(gcd * 3)) and cooldown[classtable.FelDesolation].ready then
        if not setSpell then setSpell = classtable.FelDesolation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (Fury <50 and (buff[classtable.MetamorphosisBuff].remains<(gcd * 3)) and cooldown[classtable.FelDesolation].ready) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (Fury <50 and not cooldown[classtable.Felblade].ready and (buff[classtable.MetamorphosisBuff].remains<(gcd * 3)) and cooldown[classtable.FelDesolation].ready) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (talents[classtable.IlluminatedSigils] and talents[classtable.CycleofBinding] and cooldown[classtable.SigilofDoom].charges == cooldown[classtable.SigilofDoom].maxCharges) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (not talents[classtable.StudentofSuffering] and (talents[classtable.AscendingFlame] or (not talents[classtable.AscendingFlame] and not (MaxDps.spellHistory[1] == classtable.SigilofDoom) and (debuff[classtable.SigilofDoomDeBuff].remains<(4 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0)))))) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (talents[classtable.StudentofSuffering] and not (MaxDps.spellHistory[1] == classtable.SigilofFlame) and not (MaxDps.spellHistory[1] == classtable.SigilofDoom) and (buff[classtable.StudentofSufferingBuff].remains<(4 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0)))) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (buff[classtable.MetamorphosisBuff].remains<((2 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0))+(cooldown[classtable.SigilofDoom].charges * gcd))) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDesolation, 'FelDesolation')) and (SoulFragments <= 3 and (SoulFragments >= 2 or (MaxDps.spellHistory[1] == classtable.SigilofSpite))) and cooldown[classtable.FelDesolation].ready then
        if not setSpell then setSpell = classtable.FelDesolation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (((cooldown[classtable.SigilofSpite].remains <timeShift or cooldown[classtable.SoulCarver].remains <timeShift) and cooldown[classtable.FelDesolation].remains<(timeShift + gcd) and Fury <50)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver') and talents[classtable.SoulCarver]) and ((not talents[classtable.SpiritBomb] or (single_target and not buff[classtable.DemonsurgeSpiritBurstBuff].up)) or (((SoulFragments + 3)<=6) and Fury >= 40 and not (MaxDps.spellHistory[1] == classtable.SigilofSpite))) and cooldown[classtable.SoulCarver].ready then
        if not setSpell then setSpell = classtable.SoulCarver end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (not talents[classtable.SpiritBomb] or (Fury >= 80 and (can_spburst or can_spburst_soon)) or (SoulFragments<=(2 - (talents[classtable.SoulSigils] and talents[classtable.SoulSigils] or 0)))) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (can_spburst and buff[classtable.DemonsurgeSpiritBurstBuff].up) and cooldown[classtable.SpiritBurst].ready then
        if not setSpell then setSpell = classtable.SpiritBurst end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDesolation, 'FelDesolation')) and cooldown[classtable.FelDesolation].ready then
        if not setSpell then setSpell = classtable.FelDesolation end
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (buff[classtable.DemonsurgeSoulSunderBuff].up and not buff[classtable.DemonsurgeSpiritBurstBuff].up and not can_spburst_one_gcd) and cooldown[classtable.SoulSunder].ready then
        if not setSpell then setSpell = classtable.SoulSunder end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (can_spburst and (talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up or big_aoe) and buff[classtable.MetamorphosisBuff].remains>(gcd * 2)) and cooldown[classtable.SpiritBurst].ready then
        if not setSpell then setSpell = classtable.SpiritBurst end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (Fury <40 and (can_spburst or can_spburst_soon) and (buff[classtable.DemonsurgeSpiritBurstBuff].up or talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up or big_aoe)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (Fury <40 and (can_spburst or can_spburst_soon or can_spburst_one_gcd) and (buff[classtable.DemonsurgeSpiritBurstBuff].up or talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up or big_aoe)) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (can_spburst_one_gcd and (buff[classtable.DemonsurgeSpiritBurstBuff].up or big_aoe) and not (MaxDps.spellHistory[1] == classtable.Fracture)) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (single_target and not dont_soul_cleave) and cooldown[classtable.SoulSunder].ready then
        if not setSpell then setSpell = classtable.SoulSunder end
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (can_spburst and buff[classtable.MetamorphosisBuff].remains>(gcd * 2)) and cooldown[classtable.SpiritBurst].ready then
        if not setSpell then setSpell = classtable.SpiritBurst end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (FuryDeficit >= 40) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (not dont_soul_cleave and not (big_aoe and (can_spburst or can_spburst_soon))) and cooldown[classtable.SoulSunder].ready then
        if not setSpell then setSpell = classtable.SoulSunder end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (not (MaxDps.spellHistory[1] == classtable.Fracture)) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
end
function Vengeance:rg_overflow()
    trigger_overflow = 1
    rg_enhance_cleave = 1
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and ((Fury+(rg_enhance_cleave * 25)+((talents[classtable.KeenEngagement] and talents[classtable.KeenEngagement] or 0) * 20))>=30 and not buff[classtable.RendingStrikeBuff].up and not buff[classtable.GlaiveFlurryBuff].up) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    if ((Fury+(rg_enhance_cleave * 25)+((talents[classtable.KeenEngagement] and talents[classtable.KeenEngagement] or 0) * 20))<30) then
        Vengeance:rg_prep()
    end
end
function Vengeance:rg_prep()
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (not cooldown[classtable.Felblade].ready and talents[classtable.UnhinderedAssault]) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
end
function Vengeance:rg_sequence()
    if ((Fury <30 and ((not rg_enhance_cleave and buff[classtable.GlaiveFlurryBuff].up and buff[classtable.RendingStrikeBuff].up) or (rg_enhance_cleave and not buff[classtable.RendingStrikeBuff].up))) or (cooldown[classtable.Fracture].charges <1 and ((rg_enhance_cleave and buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up) or (not rg_enhance_cleave and not buff[classtable.GlaiveFlurryBuff].up)))) then
        Vengeance:rg_sequence_filler()
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (((rg_enhance_cleave and buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up) or (not rg_enhance_cleave and not buff[classtable.GlaiveFlurryBuff].up))) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.Shear, 'Shear')) and (((rg_enhance_cleave and buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up) or (not rg_enhance_cleave and not buff[classtable.GlaiveFlurryBuff].up))) and cooldown[classtable.Shear].ready then
        if not setSpell then setSpell = classtable.Shear end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (((not rg_enhance_cleave and buff[classtable.GlaiveFlurryBuff].up and buff[classtable.RendingStrikeBuff].up) or (rg_enhance_cleave and not buff[classtable.RendingStrikeBuff].up))) and cooldown[classtable.SoulCleave].ready then
        if not setSpell then setSpell = classtable.SoulCleave end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (buff[classtable.RendingStrikeBuff].up and not buff[classtable.GlaiveFlurryBuff].up) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.Shear, 'Shear')) and (buff[classtable.RendingStrikeBuff].up and not buff[classtable.GlaiveFlurryBuff].up) and cooldown[classtable.Shear].ready then
        if not setSpell then setSpell = classtable.Shear end
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (not buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up) and cooldown[classtable.SoulCleave].ready then
        if not setSpell then setSpell = classtable.SoulCleave end
    end
end
function Vengeance:rg_sequence_filler()
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture') and talents[classtable.Fracture]) and (not buff[classtable.RendingStrikeBuff].up) and cooldown[classtable.Fracture].ready then
        if not setSpell then setSpell = classtable.Fracture end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver') and talents[classtable.SoulCarver]) and cooldown[classtable.SoulCarver].ready then
        if not setSpell then setSpell = classtable.SoulCarver end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        if not setSpell then setSpell = classtable.FelDevastation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
end


local function ClearCDs()
    MaxDps:GlowCooldown(classtable.Disrupt, false)
    MaxDps:GlowCooldown(classtable.DemonSpikes, false)
    MaxDps:GlowCooldown(classtable.trinket1, false)
    MaxDps:GlowCooldown(classtable.trinket2, false)
    MaxDps:GlowCooldown(classtable.Metamorphosis, false)
    MaxDps:GlowCooldown(classtable.TheHunt, false)
    MaxDps:GlowCooldown(classtable.SigilofSpite, false)
    MaxDps:GlowCooldown(classtable.VengefulRetreat, false)
end

function Vengeance:callaction()
    if (MaxDps:CheckSpellUsable(classtable.Disrupt, 'Disrupt')) and cooldown[classtable.Disrupt].ready then
        MaxDps:GlowCooldown(classtable.Disrupt, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonSpikes, 'DemonSpikes')) and (not buff[classtable.DemonSpikesBuff].up and ((UnitThreatSituation('player') == 2 or UnitThreatSituation('player') == 3) or timeInCombat <5)) and cooldown[classtable.DemonSpikes].ready then
        MaxDps:GlowCooldown(classtable.DemonSpikes, cooldown[classtable.DemonSpikes].ready)
    end
    num_spawnable_souls = 0

    if talents[classtable.SoulSigils] and cooldown[classtable.SigilofFlame].ready then
        num_spawnable_souls = max(1)
    end
    if talents[classtable.Fracture] and cooldown[classtable.Fracture].charges >= 1 and not buff[classtable.MetamorphosisBuff].up then
        num_spawnable_souls = max(2)
    end
    if talents[classtable.Fracture] and cooldown[classtable.Fracture].charges >= 1 and buff[classtable.MetamorphosisBuff].up then
        num_spawnable_souls = max(3)
    end
    if talents[classtable.SoulCarver] and (cooldown[classtable.SoulCarver].remains>(cooldown[classtable.SoulCarver].duration - 3)) then
        num_spawnable_souls = num_spawnable_souls+1
    end
    if (MaxDps:CheckSpellUsable(classtable.InfernalStrike, 'InfernalStrike')) and cooldown[classtable.InfernalStrike].ready then
        if not setSpell then setSpell = classtable.InfernalStrike end
    end
    if (not (MaxDps.ActiveHeroTree == 'felscarred')) then
        Vengeance:ar()
    end
    if ((MaxDps.ActiveHeroTree == 'felscarred')) then
        Vengeance:fs()
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
    targetHP = UnitHealth('target')
    targetmaxHP = UnitHealthMax('target')
    targethealthPerc = (targetHP >0 and targetmaxHP >0 and (targetHP / targetmaxHP) * 100) or 100
    curentHP = UnitHealth('player')
    maxHP = UnitHealthMax('player')
    healthPerc = (curentHP / maxHP) * 100
    timeInCombat = MaxDps.combatTime or 0
    classtable = MaxDps.SpellTable
    local trinket1ID = GetInventoryItemID('player', 13)
    local trinket2ID = GetInventoryItemID('player', 14)
    classtable.trinket1 = (trinket1ID and select(2,GetItemSpell(trinket1ID)) ) or 0
    classtable.trinket2 = (trinket2ID and select(2,GetItemSpell(trinket2ID)) ) or 0
    Fury = UnitPower('player', FuryPT)
    FuryMax = UnitPowerMax('player', FuryPT)
    FuryDeficit = FuryMax - Fury
    FuryPerc = (Fury / FuryMax) * 100
    FuryRegen = GetPowerRegenForPowerType(FuryPT)
    FuryTimeToMax = FuryDeficit / FuryRegen
    Pain = UnitPower('player', PainPT)
    PainMax = UnitPowerMax('player', PainPT)
    PainDeficit = PainMax - Pain
    PainPerc = (Pain / PainMax) * 100
    PainRegen = GetPowerRegenForPowerType(PainPT)
    PainTimeToMax = PainDeficit / PainRegen
    --SoulFragments = UnitPower('player', SoulFragmentsPT)
    --SoulFragmentsMax = UnitPowerMax('player', SoulFragmentsPT)
    --SoulFragmentsDeficit = SoulFragmentsMax - SoulFragments
    --SoulFragmentsPerc = (SoulFragments / SoulFragmentsMax) * 100
    --SoulFragmentsRegen = GetPowerRegenForPowerType(SoulFragmentsPT)
    --SoulFragmentsTimeToMax = SoulFragmentsDeficit / SoulFragmentsRegen
    SpellHaste = UnitSpellHaste('player')
    SpellCrit = GetCritChance()
    SoulFragments = GetNumSoulFragments()
    --for spellId in pairs(MaxDps.Flags) do
    --    self.Flags[spellId] = false
    --    self:ClearGlowIndependent(spellId, spellId)
    --end
    classtable.DemonSpikesBuff = 203819
    classtable.MetamorphosisBuff = 162264
    classtable.GlaiveFlurryBuff = 442435
    classtable.RendingStrikeBuff = 442442
    classtable.ArtoftheGlaiveBuff = 444661
    classtable.ThrilloftheFightDamageBuff = 442688
    classtable.ReaversGlaiveBuff = 442294
    classtable.ThrilloftheFightAttackSpeedBuff = 442695
    classtable.WarbladesHungerBuff = 442503
    classtable.DemonsurgeSpiritBurstBuff = 0
    classtable.DemonsurgeSoulSunderBuff = 0
    classtable.StudentofSufferingBuff = 453239
    classtable.ImmolationAuraBuff = 258920
    classtable.DemonsurgeHardcastBuff = 452489
    classtable.FieryBrandDeBuff = 207771
    classtable.SigilofFlameDeBuff = 204598
    classtable.ReaversMarkDeBuff = 442624
    classtable.SigilofDoomDeBuff = 462030
    classtable.ReaversGlaive = 442294
    classtable.SpiritBurst = 452437
    classtable.SoulSunder = 452436
    classtable.FelDesolation = 452486
    classtable.SigilofDoom = 452490

    local function debugg()
        talents[classtable.StudentofSuffering] = 1
        talents[classtable.SoulSigils] = 1
        talents[classtable.Fracture] = 1
        talents[classtable.SoulCarver] = 1
        talents[classtable.Fallout] = 1
        talents[classtable.AscendingFlame] = 1
        talents[classtable.FieryDemise] = 1
        talents[classtable.DownInFlames] = 1
        talents[classtable.UnhinderedAssault] = 1
        talents[classtable.CycleofBinding] = 1
        talents[classtable.VolatileFlameblood] = 1
        talents[classtable.DarkglareBoon] = 1
        talents[classtable.SpiritBomb] = 1
        talents[classtable.IlluminatedSigils] = 1
    end


    --if MaxDps.db.global.debugMode then
    --   debugg()
    --end

    setSpell = nil
    ClearCDs()

    Vengeance:precombat()

    Vengeance:callaction()
    if setSpell then return setSpell end
end
