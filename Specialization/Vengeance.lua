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

local SoulFragments = 0
local Fury
local FuryMax
local FuryDeficit
local Pain
local PainMax
local PainDeficit

local Vengeance = {}

local single_target
local small_aoe
local big_aoe
local num_spawnable_souls
local spb_threshold
local can_spb
local can_spb_soon
local can_spb_one_gcd
local dont_soul_cleave
local rg_enhance_cleave
local cooldown_sync
local spbomb_threshold
local can_spbomb
local can_spbomb_soon
local can_spbomb_one_gcd
local spburst_threshold
local can_spburst
local can_spburst_soon
local can_spburst_one_gcd
local fiery_brand_back_before_meta
local hold_sof

local function GetNumSoulFragments()
    local auraData = UnitAuraByName('player','Soul Fragments')
    if auraData and auraData.applications then
        return auraData.applications
    end
    return 0
end

function Vengeance:precombat()
    single_target = targets == 1 and 1 or 0
    small_aoe = targets >= 2 and targets <= 5  and 1 or 0
    big_aoe = targets >= 6  and 1 or 0
    --if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (talents[classtable.AldrachiReaver] or UnitLevel('player') <71 or ( talents[classtable.Felscarred] and talents[classtable.StudentofSuffering] )) and cooldown[classtable.SigilofFlame].ready then
    --    return classtable.SigilofFlame
    --end
    --if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
    --    return classtable.ImmolationAura
    --end
end
function Vengeance:ar()
    if talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up then
        spb_threshold = ( single_target * 5 ) + ( small_aoe * 5 ) + ( big_aoe * 4 )
    else
        spb_threshold = ( single_target * 5 ) + ( small_aoe * 5 ) + ( big_aoe * 4 )
    end
    can_spb = SoulFragments >= spb_threshold
    can_spb_soon = SoulFragments >= spb_threshold
    can_spb_one_gcd = ( SoulFragments + num_spawnable_souls ) >= spb_threshold
    dont_soul_cleave = can_spb or can_spb_soon or can_spb_one_gcd or (MaxDps.spellHistory[1] == classtable.Fracture)
    if targets >= 6 or ttd <10 then
        rg_enhance_cleave = 1
    else
        rg_enhance_cleave = 0
    end
    cooldown_sync = ( debuff[classtable.ReaversMarkDeBuff].up and buff[classtable.ThrilloftheFightDamageBuff].up ) or ttd <20
    if (buff[classtable.GlaiveFlurryBuff].up or buff[classtable.RendingStrikeBuff].up) then
        local rg_activeCheck = Vengeance:rg_active()
        if rg_activeCheck then
            return Vengeance:rg_active()
        end
    end
    if (ttd <20) then
        local ar_executeCheck = Vengeance:ar_execute()
        if ar_executeCheck then
            return Vengeance:ar_execute()
        end
    end
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (not buff[classtable.MetamorphosisBuff].up and not ( cooldown[classtable.TheHunt].ready or buff[classtable.ReaversGlaiveBuff].up )) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.UnhinderedAssault] and not cooldown[classtable.Felblade].ready and ( ( ( talents[classtable.SpiritBomb] and ( Fury <40 and ( can_spb or can_spb_soon ) ) ) or ( talents[classtable.SpiritBomb] and ( cooldown[classtable.SigilofSpite].ready or cooldown[classtable.SoulCarver].ready ) and cooldown[classtable.FelDevastation].ready and Fury <50 ) ) or Fury <30 )) and cooldown[classtable.VengefulRetreat].ready then
        return classtable.VengefulRetreat
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (talents[classtable.AscendingFlame] or ( not talents[classtable.AscendingFlame] and not (MaxDps.spellHistory[1] == classtable.SigilofFlame) and ( debuff[classtable.SigilofFlameDeBuff].remains <( 1 + (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0) ) ) )) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (( debuff[classtable.ReaversMarkDeBuff].remains <= ( gcd + timeShift + ( gcd * 2 ) ) ) and ( buff[classtable.ArtoftheGlaiveBuff].count + SoulFragments >= 30 and buff[classtable.ArtoftheGlaiveBuff].count >= 28 ) and ( Fury <40 or not can_spb )) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBomb, 'SpiritBomb')) and (( debuff[classtable.ReaversMarkDeBuff].remains <= ( gcd + timeShift + ( gcd * 2 ) ) ) and ( buff[classtable.ArtoftheGlaiveBuff].count + SoulFragments >= 30 )) and cooldown[classtable.SpiritBomb].ready then
        return classtable.SpiritBomb
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (( debuff[classtable.ReaversMarkDeBuff].remains <= ( gcd + timeShift + ( gcd * 2 ) ) ) and ( buff[classtable.ArtoftheGlaiveBuff].count + ( targets >5 and 1 or 0) >= 30 )) and cooldown[classtable.BulkExtraction].ready then
        return classtable.BulkExtraction
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and (( buff[classtable.ArtoftheGlaiveBuff].count + SoulFragments >= 30 ) or ( debuff[classtable.ReaversMarkDeBuff].remains <= ( gcd + timeShift + ( gcd * 4 ) ) ) or cooldown[classtable.TheHunt].remains <( gcd + timeShift + ( gcd * 4 ) ) or rg_enhance_cleave) and cooldown[classtable.ReaversGlaive].ready then
        return classtable.ReaversGlaive
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not buff[classtable.ReaversGlaiveBuff].up) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and (not talents[classtable.FieryDemise] or ( talents[classtable.FieryDemise] and ( ( talents[classtable.DownInFlames] and cooldown[classtable.FieryBrand].charges >= cooldown[classtable.FieryBrand].maxCharges ) or ( debuff[classtable.FieryBrandDeBuff].count  == 0 ) ) )) and cooldown[classtable.FieryBrand].ready then
        return classtable.FieryBrand
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and (talents[classtable.SpiritBomb] and not can_spb and ( can_spb_soon or SoulFragments >= 2 )) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBomb, 'SpiritBomb')) and (can_spb) and cooldown[classtable.SpiritBomb].ready then
        return classtable.SpiritBomb
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and (talents[classtable.SpiritBomb] and ( ( Fury <40 and ( not cooldown[classtable.Felblade].ready and ( not talents[classtable.UnhinderedAssault] or not cooldown[classtable.VengefulRetreat].ready ) ) ) or ( Fury <40 and can_spb_one_gcd ) )) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver')) and (not talents[classtable.SpiritBomb] or ( ( ( SoulFragments + 3 ) <= 6 ) and Fury >= 15 and not (MaxDps.spellHistory[1] == classtable.SigilofSpite) )) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (not talents[classtable.SpiritBomb] or ( ( can_spb and Fury >= 40 ) or can_spb_soon or SoulFragments <= 1 )) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and (not single_target or buff[classtable.ThrilloftheFightDamageBuff].up) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (targets >= 5) and cooldown[classtable.BulkExtraction].ready then
        return classtable.BulkExtraction
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (( ( ( talents[classtable.SpiritBomb] and ( Fury <40 and ( can_spb or can_spb_soon ) ) ) or ( talents[classtable.SpiritBomb] and ( cooldown[classtable.SigilofSpite].ready or cooldown[classtable.SoulCarver].ready ) and cooldown[classtable.FelDevastation].ready and Fury <50 ) ) or Fury <30 )) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (FuryDeficit <= 25 or ( not talents[classtable.SpiritBomb] or not dont_soul_cleave )) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:CheckSpellUsable(classtable.Shear, 'Shear')) and cooldown[classtable.Shear].ready then
        return classtable.Shear
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and cooldown[classtable.ThrowGlaive].ready then
        return classtable.ThrowGlaive
    end
end
function Vengeance:ar_execute()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and cooldown[classtable.ReaversGlaive].ready then
        return classtable.ReaversGlaive
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not buff[classtable.ReaversGlaiveBuff].up) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (targets >= 3 and buff[classtable.ArtoftheGlaiveBuff].count >= 20) and cooldown[classtable.BulkExtraction].ready then
        return classtable.BulkExtraction
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and cooldown[classtable.FieryBrand].ready then
        return classtable.FieryBrand
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver')) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
end
function Vengeance:fel_dev()
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (talents[classtable.SpiritBomb] and ( can_spburst or ( buff[classtable.MetamorphosisBuff].remains <( gcd + timeShift + 1 ) and buff[classtable.DemonsurgeSpiritBurstBuff].up ) )) and cooldown[classtable.SpiritBurst].ready then
        return classtable.SpiritBurst
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (buff[classtable.DemonsurgeSoulSunderBuff].up or not dont_soul_cleave or ( buff[classtable.MetamorphosisBuff].remains <( gcd + timeShift + 1 ) and buff[classtable.DemonsurgeSoulSunderBuff].up )) and cooldown[classtable.SoulSunder].ready then
        return classtable.SoulSunder
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (SoulFragments <= 2 and buff[classtable.DemonsurgeSpiritBurstBuff].up) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver')) and (SoulFragments <= 2 and not (MaxDps.spellHistory[1] == classtable.SigilofSpite) and buff[classtable.DemonsurgeSpiritBurstBuff].up) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (not hold_sof) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
end
function Vengeance:fel_dev_prep()
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and (talents[classtable.FieryDemise] and ( ( talents[classtable.DarkglareBoon] and Fury >= 70 ) or ( not talents[classtable.DarkglareBoon] and Fury >= 100 ) ) and ( can_spburst or can_spburst_soon ) and debuff[classtable.FieryBrandDeBuff].count  == 0 and ( cooldown[classtable.Metamorphosis].ready or cooldown[classtable.Metamorphosis].remains <( gcd + timeShift + 2 + ( gcd * 2 ) ) )) and cooldown[classtable.FieryBrand].ready then
        return classtable.FieryBrand
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and (( ( talents[classtable.DarkglareBoon] and Fury >= 70 ) or ( not talents[classtable.DarkglareBoon] and Fury >= 100 ) ) and ( can_spburst or can_spburst_soon )) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (not ( can_spburst or can_spburst_soon ) and SoulFragments <= 2 and ( ( talents[classtable.DarkglareBoon] and Fury >= 70 ) or ( not talents[classtable.DarkglareBoon] and Fury >= 100 ) )) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (not ( ( talents[classtable.DarkglareBoon] and Fury >= 70 ) or ( not talents[classtable.DarkglareBoon] and Fury >= 100 ) )) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and (not ( can_spburst or can_spburst_soon ) or not ( ( talents[classtable.DarkglareBoon] and Fury >= 70 ) or ( not talents[classtable.DarkglareBoon] and Fury >= 100 ) )) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
end
function Vengeance:fs()
    if talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up then
        spbomb_threshold = ( single_target * 5 ) + ( small_aoe * 4 ) + ( big_aoe * 3 )
    else
        spbomb_threshold = ( single_target * 5 ) + ( small_aoe * 4 ) + ( big_aoe * 4 )
    end
    can_spbomb = SoulFragments >= spbomb_threshold
    can_spbomb_soon = SoulFragments >= spbomb_threshold
    can_spbomb_one_gcd = ( SoulFragments + num_spawnable_souls ) >= spbomb_threshold
    if talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up then
        spburst_threshold = ( single_target * 4 ) + ( small_aoe * 4 ) + ( big_aoe * 3 )
    else
        spburst_threshold = ( single_target * 5 ) + ( small_aoe * 4 ) + ( big_aoe * 3 )
    end
    can_spburst = SoulFragments >= spburst_threshold
    can_spburst_soon = SoulFragments >= spburst_threshold
    can_spburst_one_gcd = ( SoulFragments + num_spawnable_souls ) >= spburst_threshold
    if buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeHardcastBuff].up then
        dont_soul_cleave = ( ( cooldown[classtable.FelDesolation].remains <= gcd + timeShift ) and Fury <80 ) or ( can_spburst or can_spburst_soon ) or ( (MaxDps.spellHistory[1] == classtable.SigilofSpite) or (MaxDps.spellHistory[1] == classtable.SoulCarver) )
    else
        dont_soul_cleave = ( ( cooldown[classtable.FelDevastation].remains <= gcd + timeShift ) and Fury <80 ) or ( can_spbomb or can_spbomb_soon ) or ( buff[classtable.MetamorphosisBuff].up and not buff[classtable.DemonsurgeHardcastBuff].up and buff[classtable.DemonsurgeSpiritBurstBuff].up ) or ( (MaxDps.spellHistory[1] == classtable.SigilofSpite) or (MaxDps.spellHistory[1] == classtable.SoulCarver) )
    end
    if talents[classtable.DownInFlames] then
        fiery_brand_back_before_meta = cooldown[classtable.FieryBrand].charges >= cooldown[classtable.FieryBrand].maxCharges or ( cooldown[classtable.FieryBrand].charges >= 1 and cooldown[classtable.FieryBrand].fullRecharge <= gcd + timeShift ) or ( cooldown[classtable.FieryBrand].charges >= 1 and ( ( cooldown[classtable.FieryBrand].maxCharges - ( cooldown[classtable.FieryBrand].charges - 1 ) ) * cooldown[classtable.FieryBrand].duration ) <= cooldown[classtable.Metamorphosis].remains )
    else
        fiery_brand_back_before_meta = cooldown[classtable.FieryBrand].duration <= cooldown[classtable.Metamorphosis].remains
    end
    if talents[classtable.StudentofSuffering] then
        hold_sof = ( buff[classtable.StudentofSufferingBuff].remains >( 1 + (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0) ) ) or ( not talents[classtable.AscendingFlame] and ( debuff[classtable.SigilofFlameDeBuff].remains >( 1 + (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0) ) ) ) or (MaxDps.spellHistory[1] == classtable.SigilofFlame) or ( talents[classtable.IlluminatedSigils] and cooldown[classtable.IlluminatedSigils].charges == 1 and timeInCombat <( 2 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0) ) ) or cooldown[classtable.Metamorphosis].ready
    else
        hold_sof = cooldown[classtable.Metamorphosis].ready or ( cooldown[classtable.SigilofFlame].maxCharges >1 and talents[classtable.AscendingFlame] and ( ( cooldown[classtable.SigilofFlame].maxCharges - ( cooldown[classtable.SigilofFlame].charges - 1 ) ) * cooldown[classtable.SigilofFlame].duration ) >cooldown[classtable.Metamorphosis].remains ) or ( ( (MaxDps.spellHistory[1] == classtable.SigilofFlame) or debuff[classtable.SigilofFlameDeBuff].remains >( 1 + (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0) ) ) )
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (not ( (MaxDps.spellHistory[1] == classtable.SigilofFlame) and cooldown[classtable.Metamorphosis].ready )) and cooldown[classtable.ImmolationAura].ready then
        return classtable.ImmolationAura
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (not hold_sof) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and (not talents[classtable.FieryDemise] or talents[classtable.FieryDemise] and ( ( talents[classtable.DownInFlames] and cooldown[classtable.FieryBrand].charges >= cooldown[classtable.FieryBrand].maxCharges ) or ( debuff[classtable.FieryBrandDeBuff].count  == 0 and fiery_brand_back_before_meta ) )) and cooldown[classtable.FieryBrand].ready then
        return classtable.FieryBrand
    end
    if (ttd <20) then
        local fs_executeCheck = Vengeance:fs_execute()
        if fs_executeCheck then
            return Vengeance:fs_execute()
        end
    end
    if (buff[classtable.MetamorphosisBuff].up and not buff[classtable.DemonsurgeHardcastBuff].up and ( buff[classtable.DemonsurgeSoulSunderBuff].up or buff[classtable.DemonsurgeSpiritBurstBuff].up )) then
        local fel_devCheck = Vengeance:fel_dev()
        if fel_devCheck then
            return Vengeance:fel_dev()
        end
    end
    if (buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeHardcastBuff].up) then
        local metamorphosisCheck = Vengeance:metamorphosis()
        if metamorphosisCheck then
            return Vengeance:metamorphosis()
        end
    end
    if (not buff[classtable.DemonsurgeHardcastBuff].up and ( cooldown[classtable.FelDevastation].ready or ( cooldown[classtable.FelDevastation].remains <= ( gcd * 2 ) ) )) then
        local fel_dev_prepCheck = Vengeance:fel_dev_prep()
        if fel_dev_prepCheck then
            return Vengeance:fel_dev_prep()
        end
    end
    if (( cooldown[classtable.Metamorphosis].ready or cooldown[classtable.Metamorphosis].remains <= ( gcd * 3 ) ) and not cooldown[classtable.FelDevastation].ready and not buff[classtable.DemonsurgeSoulSunderBuff].up and not buff[classtable.DemonsurgeSpiritBurstBuff].up) then
        local meta_prepCheck = Vengeance:meta_prep()
        if meta_prepCheck then
            return Vengeance:meta_prep()
        end
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver')) and (( not talents[classtable.FieryDemise] or talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].up ) and ( ( ( SoulFragments + 3 ) <= 6 ) and Fury >= 15 and not (MaxDps.spellHistory[1] == classtable.SigilofSpite) )) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (( ( ( can_spbomb or ( buff[classtable.MetamorphosisBuff].up and can_spburst ) ) and Fury >= 40 ) ) or ( ( can_spbomb_soon or ( buff[classtable.MetamorphosisBuff].up and can_spburst_soon ) ) or SoulFragments <= 1 )) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (targets >= 5) and cooldown[classtable.BulkExtraction].ready then
        return classtable.BulkExtraction
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (talents[classtable.SpiritBomb] and can_spburst) and cooldown[classtable.SpiritBurst].ready then
        return classtable.SpiritBurst
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBomb, 'SpiritBomb')) and (can_spbomb) and cooldown[classtable.SpiritBomb].ready then
        return classtable.SpiritBomb
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (( Fury <40 and ( ( buff[classtable.MetamorphosisBuff].up and ( can_spburst or can_spburst_soon ) ) or ( not buff[classtable.MetamorphosisBuff].up and ( can_spbomb or can_spbomb_soon ) ) ) ) or Fury <30) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and (( Fury <40 and ( ( buff[classtable.MetamorphosisBuff].up and ( can_spburst or can_spburst_soon ) ) or ( not buff[classtable.MetamorphosisBuff].up and ( can_spbomb or can_spbomb_soon ) ) ) ) or ( ( buff[classtable.MetamorphosisBuff].up and can_spburst_one_gcd ) or ( not buff[classtable.MetamorphosisBuff].up and can_spbomb_one_gcd ) )) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (not dont_soul_cleave) and cooldown[classtable.SoulSunder].ready then
        return classtable.SoulSunder
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (not dont_soul_cleave) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and cooldown[classtable.ThrowGlaive].ready then
        return classtable.ThrowGlaive
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
        return classtable.SigilofFlame
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and cooldown[classtable.FieryBrand].ready then
        return classtable.FieryBrand
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver')) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDevastation, 'FelDevastation')) and cooldown[classtable.FelDevastation].ready then
        return classtable.FelDevastation
    end
end
function Vengeance:meta_prep()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (cooldown[classtable.SigilofFlame].charges <1) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FieryBrand, 'FieryBrand')) and (talents[classtable.FieryDemise] and debuff[classtable.FieryBrandDeBuff].count  == 0) and cooldown[classtable.FieryBrand].ready then
        return classtable.FieryBrand
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready then
        return classtable.SigilofFlame
    end
end
function Vengeance:metamorphosis()
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (talents[classtable.SpiritBomb] and ( buff[classtable.MetamorphosisBuff].remains <( gcd + timeShift + 1 ) ) and buff[classtable.DemonsurgeSpiritBurstBuff].up) and cooldown[classtable.SpiritBurst].ready then
        return classtable.SpiritBurst
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (( ( can_spburst and Fury >= 40 ) or can_spburst_soon )) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (talents[classtable.SpiritBomb] and can_spburst and buff[classtable.DemonsurgeSpiritBurstBuff].up or SoulFragments >= 5) and cooldown[classtable.SpiritBurst].ready then
        return classtable.SpiritBurst
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCarver, 'SoulCarver')) and (SoulFragments <= 2 and not (MaxDps.spellHistory[1] == classtable.SigilofSpite)) and cooldown[classtable.SoulCarver].ready then
        return classtable.SoulCarver
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (SoulFragments <= 1) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelDesolation, 'FelDesolation')) and ((MaxDps.spellHistory[2] == classtable.SigilofSpite) or (MaxDps.spellHistory[2] == classtable.SoulCarver) or not can_spburst and ( can_spburst_soon or SoulFragments >= 2 ) or ( not buff[classtable.DemonsurgeSoulSunderBuff].up and not buff[classtable.DemonsurgeSpiritBurstBuff].up and not buff[classtable.DemonsurgeConsumingFireBuff].up and not buff[classtable.DemonsurgeSigilofDoomBuff].up and cooldown[classtable.SigilofDoom].charges <1 and buff[classtable.DemonsurgeFelDesolationBuff].up )) and cooldown[classtable.FelDesolation].ready then
        return classtable.FelDesolation
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (talents[classtable.AscendingFlame] or ( not talents[classtable.AscendingFlame] and ( debuff[classtable.SigilofDoomDeBuff].remains <( 1 + (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0) ) and not (MaxDps.spellHistory[1] == classtable.SigilofDoom) ) )) and cooldown[classtable.SigilofDoom].ready then
        return classtable.SigilofDoom
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (( can_spburst or can_spburst_soon ) and not buff[classtable.SoulFurnaceDamageAmpBuff].up and buff[classtable.SoulFurnaceStackBuff].count <= 6 and buff[classtable.SoulFurnaceStackBuff].count + ( targets >5 and 1 or 0) >= 10) and cooldown[classtable.BulkExtraction].ready then
        return classtable.BulkExtraction
    end
    if (MaxDps:CheckSpellUsable(classtable.SpiritBurst, 'SpiritBurst')) and (( talents[classtable.SpiritBomb] and can_spburst )) and cooldown[classtable.SpiritBurst].ready then
        return classtable.SpiritBurst
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and (targets >= 6 and ( SoulFragments >= 2 and SoulFragments <= 3 )) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (( Fury <40 and ( can_spburst or can_spburst_soon ) ) or Fury <30) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulSunder, 'SoulSunder')) and (not dont_soul_cleave) and cooldown[classtable.SoulSunder].ready then
        return classtable.SoulSunder
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
end
function Vengeance:rg_active()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (not buff[classtable.MetamorphosisBuff].up and ( buff[classtable.RendingStrikeBuff].up and not buff[classtable.GlaiveFlurryBuff].up ) and SoulFragments <= 1) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (Fury <30 and not rg_enhance_cleave and buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not buff[classtable.ReaversGlaiveBuff].up and ( debuff[classtable.ReaversMarkDeBuff].remains >( gcd + timeShift + 2 + ( talents[classtable.Fracture] and 2 or not talents[classtable.Fracture] and 2 ) + gcd ) )) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and (rg_enhance_cleave and buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up or not rg_enhance_cleave and not buff[classtable.GlaiveFlurryBuff].up) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
    if (MaxDps:CheckSpellUsable(classtable.Shear, 'Shear')) and (rg_enhance_cleave and buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up or not rg_enhance_cleave and not buff[classtable.GlaiveFlurryBuff].up) and cooldown[classtable.Shear].ready then
        return classtable.Shear
    end
    if (MaxDps:CheckSpellUsable(classtable.BulkExtraction, 'BulkExtraction')) and (not buff[classtable.SoulFurnaceDamageAmpBuff].up and buff[classtable.SoulFurnaceStackBuff].count + ( targets >5 and 1 or 0) >= 10) and cooldown[classtable.BulkExtraction].ready then
        return classtable.BulkExtraction
    end
    if (MaxDps:CheckSpellUsable(classtable.SoulCleave, 'SoulCleave')) and (not rg_enhance_cleave and buff[classtable.GlaiveFlurryBuff].up and buff[classtable.RendingStrikeBuff].up or rg_enhance_cleave and not buff[classtable.RendingStrikeBuff].up) and cooldown[classtable.SoulCleave].ready then
        return classtable.SoulCleave
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and cooldown[classtable.Felblade].ready then
        return classtable.Felblade
    end
    if (MaxDps:CheckSpellUsable(classtable.Fracture, 'Fracture')) and (not buff[classtable.RendingStrikeBuff].up) and cooldown[classtable.Fracture].ready then
        return classtable.Fracture
    end
end

function Vengeance:callaction()
    num_spawnable_souls = 0
    if talents[classtable.Fracture] and cooldown[classtable.Fracture].charges >= 1 and not buff[classtable.MetamorphosisBuff].up then
        num_spawnable_souls = 2
    end
    if talents[classtable.Fracture] and cooldown[classtable.Fracture].charges >= 1 and buff[classtable.MetamorphosisBuff].up then
        num_spawnable_souls = 3
    end
    if talents[classtable.SoulSigils] and cooldown[classtable.SigilofFlame].ready then
        num_spawnable_souls = 1
    end
    if talents[classtable.SoulCarver] and ( cooldown[classtable.SoulCarver].remains >( cooldown[classtable.SoulCarver].duration - 3 ) ) then
        num_spawnable_souls = 1
    end
    if (MaxDps:CheckSpellUsable(classtable.Disrupt, 'Disrupt')) and (UnitCastingInfo('target') and select(8,UnitCastingInfo('target')) == false) and cooldown[classtable.Disrupt].ready then
        MaxDps:GlowCooldown(classtable.Disrupt, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    if (MaxDps:CheckSpellUsable(classtable.InfernalStrike, 'InfernalStrike')) and cooldown[classtable.InfernalStrike].ready then
        MaxDps:GlowCooldown(classtable.InfernalStrike, cooldown[classtable.InfernalStrike].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonSpikes, 'DemonSpikes')) and (not buff[classtable.DemonSpikesBuff].up and (UnitThreatSituation('player') == 2 or UnitThreatSituation('player') == 3)) and cooldown[classtable.DemonSpikes].ready then
        MaxDps:GlowCooldown(classtable.DemonSpikes, cooldown[classtable.DemonSpikes].ready)
    end
    if ((MaxDps.ActiveHeroTree == 'aldrachireaver') or UnitLevel('player') <71) then
        local arCheck = Vengeance:ar()
        if arCheck then
            return Vengeance:ar()
        end
    end
    if ((MaxDps.ActiveHeroTree == 'felscarred')) then
        local fsCheck = Vengeance:fs()
        if fsCheck then
            return Vengeance:fs()
        end
    end
    if (buff[classtable.GlaiveFlurryBuff].up or buff[classtable.RendingStrikeBuff].up) then
        local rg_activeCheck = Vengeance:rg_active()
        if rg_activeCheck then
            return Vengeance:rg_active()
        end
    end
    if (ttd <20) then
        local ar_executeCheck = Vengeance:ar_execute()
        if ar_executeCheck then
            return Vengeance:ar_execute()
        end
    end
    if (ttd <20) then
        local fs_executeCheck = Vengeance:fs_execute()
        if fs_executeCheck then
            return Vengeance:fs_execute()
        end
    end
    if (buff[classtable.MetamorphosisBuff].up and not buff[classtable.DemonsurgeHardcastBuff].up and ( buff[classtable.DemonsurgeSoulSunderBuff].up or buff[classtable.DemonsurgeSpiritBurstBuff].up )) then
        local fel_devCheck = Vengeance:fel_dev()
        if fel_devCheck then
            return Vengeance:fel_dev()
        end
    end
    if (buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeHardcastBuff].up) then
        local metamorphosisCheck = Vengeance:metamorphosis()
        if metamorphosisCheck then
            return Vengeance:metamorphosis()
        end
    end
    if (not buff[classtable.DemonsurgeHardcastBuff].up and ( cooldown[classtable.FelDevastation].ready or ( cooldown[classtable.FelDevastation].remains <= ( gcd * 2 ) ) )) then
        local fel_dev_prepCheck = Vengeance:fel_dev_prep()
        if fel_dev_prepCheck then
            return Vengeance:fel_dev_prep()
        end
    end
    if (( cooldown[classtable.Metamorphosis].ready or cooldown[classtable.Metamorphosis].remains <= ( gcd * 3 ) ) and not cooldown[classtable.FelDevastation].ready and not buff[classtable.DemonsurgeSoulSunderBuff].up and not buff[classtable.DemonsurgeSpiritBurstBuff].up) then
        local meta_prepCheck = Vengeance:meta_prep()
        if meta_prepCheck then
            return Vengeance:meta_prep()
        end
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
    SpellHaste = UnitSpellHaste('player')
    SpellCrit = GetCritChance()
    SoulFragments = GetNumSoulFragments()
    Fury = UnitPower('player', FuryPT)
    FuryMax = UnitPowerMax('player', FuryPT)
    FuryDeficit = FuryMax - Fury
    Pain = UnitPower('player', PainPT)
    PainMax = UnitPowerMax('player', PainPT)
    PainDeficit = PainMax - Pain
    classtable.ReaversGlaive = 442294
    classtable.SpiritBurst = 452437
    classtable.SoulSunder = 452436
    for spellId in pairs(MaxDps.Flags) do
        self.Flags[spellId] = false
        self:ClearGlowIndependent(spellId, spellId)
    end
    classtable.FieryBrandDeBuff = 207771
    classtable.ReaversMarkDeBuff = 442624
    classtable.ThrilloftheFightDamageBuff = 442695
    classtable.GlaiveFlurryBuff = 442435
    classtable.RendingStrikeBuff = 442442
    classtable.MetamorphosisBuff = 187827
    classtable.ReaversGlaiveBuff = 442294
    classtable.SigilofFlameDeBuff = 204598
    classtable.ArtoftheGlaiveBuff = 444661
    classtable.DemonsurgeSpiritBurstBuff = 0
    classtable.DemonsurgeSoulSunderBuff = 0
    classtable.DemonsurgeHardcastBuff = 0
    classtable.StudentofSufferingBuff = 453239
    classtable.DemonsurgeConsumingFireBuff = 0
    classtable.DemonsurgeSigilofDoomBuff = 0
    classtable.DemonsurgeFelDesolationBuff = 0
    classtable.SigilofDoomDeBuff = 462030
    classtable.SoulFurnaceDamageAmpBuff = 391172
    classtable.SoulFurnaceStackBuff = 391166
    classtable.DemonSpikesBuff = 203819

    local precombatCheck = Vengeance:precombat()
    if precombatCheck then
        return Vengeance:precombat()
    end

    local callactionCheck = Vengeance:callaction()
    if callactionCheck then
        return Vengeance:callaction()
    end
end
