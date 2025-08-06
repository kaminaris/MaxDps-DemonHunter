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

local Havoc = {}

local trinket1_steroids = false
local trinket2_steroids = false
local trinket1_crit = false
local trinket2_crit = false
local rg_ds = 0
local fury_gen = 0
local tier33_4piece = false
local double_on_use = false
local opened = false
local rg_inc = false
local fel_barrage = false
local special_trinket = false
local generator_up = false
local gcd_drain = 0


local function GetNumSoulFragments()
    local auraData = UnitAuraByName('player','Soul Fragments')
    if auraData and auraData.applications then
        return auraData.applications
    end
    return 0
end


function Havoc:precombat()
    trinket1_steroids = MaxDps:CheckTrinketNames('ImprovisedSeaforiumPacemaker')
    trinket2_steroids = MaxDps:CheckTrinketNames('ImprovisedSeaforiumPacemaker')
    trinket1_crit = MaxDps:CheckTrinketNames('MadQueensMandate') or MaxDps:CheckTrinketNames('JunkmaestrosMegaMagnet') or MaxDps:CheckTrinketNames('GeargrindersSpareKeys') or MaxDps:CheckTrinketNames('RavenousHoneyBuzzer') or MaxDps:CheckTrinketNames('GrimCodex')
    trinket2_crit = MaxDps:CheckTrinketNames('MadQueensMandate') or MaxDps:CheckTrinketNames('JunkmaestrosMegaMagnet') or MaxDps:CheckTrinketNames('GeargrindersSpareKeys') or MaxDps:CheckTrinketNames('RavenousHoneyBuzzer') or MaxDps:CheckTrinketNames('GrimCodex')
    rg_ds = 0
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready and not UnitAffectingCombat('player') then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and cooldown[classtable.ImmolationAura].ready and not UnitAffectingCombat('player') then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
end
function Havoc:ar()
    opened = false
    rg_inc = not buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up and cooldown[classtable.BladeDance].ready and gcd == 0 or rg_inc and (MaxDps.spellHistory[1] == classtable.DeathSweep)
    fel_barrage = talents[classtable.FelBarrage] and (cooldown[classtable.FelBarrage].remains <gcd*7 and (targets >= 1+targets or math.huge <gcd*7 or math.huge >90) and (not cooldown[classtable.Metamorphosis].ready or targets >2) or buff[classtable.FelBarrageBuff].up) and not (targets == 1 and not (targets >1))
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up and (rg_ds == 2 or targets >2) and timeInCombat >10) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up and (rg_ds == 2 or targets >2)) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and (not buff[classtable.GlaiveFlurryBuff].up and not buff[classtable.RendingStrikeBuff].up and buff[classtable.ThrilloftheFightDamageBuff].remains <gcd*4+((rg_ds == 2) and 1 or 0)+((cooldown[classtable.TheHunt].remains <gcd*3) and 1 or 0)*3+((cooldown[classtable.EyeBeam].remains <gcd*3 and talents[classtable.ShatteredDestiny]) and 1 or 0)*3 and (rg_ds == 0 or rg_ds == 1 and cooldown[classtable.BladeDance].ready or rg_ds == 2 and not cooldown[classtable.BladeDance].ready) and (buff[classtable.ThrilloftheFightDamageBuff].up or not (MaxDps.spellHistory[1] == classtable.DeathSweep) or not rg_inc) and targets <3 and not debuff[classtable.EssenceBreakDeBuff].up and (buff[classtable.ArtoftheGlaiveBuff].count >3 or buff[classtable.MetamorphosisBuff].remains >2 or cooldown[classtable.EyeBeam].remains <10 or ttd <10)) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and (not buff[classtable.GlaiveFlurryBuff].up and not buff[classtable.RendingStrikeBuff].up and buff[classtable.ThrilloftheFightDamageBuff].remains <4 and (buff[classtable.ThrilloftheFightDamageBuff].up or not (MaxDps.spellHistory[1] == classtable.DeathSweep) or not rg_inc) and targets >2 or MaxDps:boss() and ttd <10) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    Havoc:ar_cooldown()
    if (timeInCombat <15 and true and (cooldown[classtable.EyeBeam].ready or cooldown[classtable.Metamorphosis].ready or talents[classtable.EssenceBreak] and cooldown[classtable.EssenceBreak].ready)) then
        Havoc:ar_opener()
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (not debuff[classtable.EssenceBreakDeBuff].up and (not talents[classtable.ReaversMark] or MaxDps:DebuffCounter(classtable.ReaversMarkDeBuff) >0 or debuff[classtable.ReaversMarkDeBuff].remains >= 2-(talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0))) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (fel_barrage and (targets >1)) then
        Havoc:ar_fel_barrage()
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (targets >2 and talents[classtable.Ragefire] and (not talents[classtable.FelBarrage] or cooldown[classtable.FelBarrage].remains >cooldown[classtable.ImmolationAura].partialRecharge) and not debuff[classtable.EssenceBreakDeBuff].up and (not buff[classtable.MetamorphosisBuff].up or buff[classtable.MetamorphosisBuff].remains >5)) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (targets >2 and talents[classtable.Ragefire] and (targets >1) and targets <15 and targets >5 and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and (cooldown[classtable.EyeBeam].remains >15 and gcd <0.3 or gcd <0.2 and cooldown[classtable.EyeBeam].remains <= gcd and cooldown[classtable.Metamorphosis].remains >10) and (not trinket1_steroids and not trinket2_steroids or trinket1_steroids and true and MaxDps:HasOnUseEffect('13') and (MaxDps:CheckTrinketCooldown('13') <gcd*3 or MaxDps:CheckTrinketCooldown('13') >30) or trinket2_steroids and true and MaxDps:HasOnUseEffect('13') and (MaxDps:CheckTrinketCooldown('14') <gcd*3 or MaxDps:CheckTrinketCooldown('13') >30)) and timeInCombat >20 and (not talents[classtable.Inertia] and not buff[classtable.UnboundChaosBuff].up or not buff[classtable.InertiaTriggerBuff].up and not buff[classtable.MetamorphosisBuff].up)) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (fel_barrage or not talents[classtable.DemonBlades] and talents[classtable.FelBarrage] and (buff[classtable.FelBarrageBuff].up or cooldown[classtable.FelBarrage].ready) and not buff[classtable.MetamorphosisBuff].up) then
        Havoc:ar_fel_barrage()
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (not talents[classtable.Inertia] and targets == 1 and buff[classtable.UnboundChaosBuff].up and buff[classtable.InitiativeBuff].up and not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and cooldown[classtable.EyeBeam].remains <= 0.5 and (not cooldown[classtable.Metamorphosis].ready and talents[classtable.LooksCanKill] or targets >1)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (buff[classtable.MetamorphosisBuff].up) then
        Havoc:ar_meta()
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and not buff[classtable.InertiaBuff].up and cooldown[classtable.BladeDance].remains <4 and (cooldown[classtable.EyeBeam].remains >5 and cooldown[classtable.EyeBeam].remains >buff[classtable.UnboundChaosBuff].remains or cooldown[classtable.EyeBeam].remains <= gcd and cooldown[classtable.VengefulRetreat].remains <= gcd+1)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.AFireInside] and talents[classtable.BurningWound] and cooldown[classtable.ImmolationAura].fullRecharge <gcd*2 and (math.huge >cooldown[classtable.ImmolationAura].fullRecharge or targets >1)) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (targets >1 and (targets >= 1+targets or math.huge >cooldown[classtable.ImmolationAura].fullRecharge)) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (ttd <15 and not cooldown[classtable.BladeDance].ready and talents[classtable.Ragefire]) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and ((cooldown[classtable.BladeDance].remains <7 or (targets >1)) and (not trinket1_steroids and not trinket2_steroids or trinket1_steroids and true and MaxDps:HasOnUseEffect('13') and (MaxDps:CheckTrinketCooldown('13') <gcd*3 or MaxDps:CheckTrinketCooldown('13') >30) or trinket2_steroids and true and MaxDps:HasOnUseEffect('13') and (MaxDps:CheckTrinketCooldown('14') <gcd*3 or MaxDps:CheckTrinketCooldown('13') >30)) or MaxDps:boss() and ttd <10) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (cooldown[classtable.EyeBeam].remains >= gcd*3 and not buff[classtable.RendingStrikeBuff].up) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (buff[classtable.RendingStrikeBuff].up) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (targets >3 or not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (FuryDeficit >= 40+fury_gen * 0.5 and not buff[classtable.InertiaTriggerBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.GlaiveTempest, 'GlaiveTempest')) and (targets >= 1+targets or math.huge >10) and cooldown[classtable.GlaiveTempest].ready then
        if not setSpell then setSpell = classtable.GlaiveTempest end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (targets >1 and talents[classtable.FuriousThrows] and (not talents[classtable.ScreamingBrutality] or cooldown[classtable.ThrowGlaive].charges == 2 or cooldown[classtable.ThrowGlaive].fullRecharge <cooldown[classtable.BladeDance].remains)) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (cooldown[classtable.EyeBeam].remains >gcd*2 or Fury >80) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (targets == 1 and not talents[classtable.AFireInside] and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (math.huge >cooldown[classtable.ImmolationAura].fullRecharge or targets >1 and targets >2) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (true and not debuff[classtable.EssenceBreakDeBuff].up and (not talents[classtable.FelBarrage] or cooldown[classtable.FelBarrage].remains >25 or targets == 1 and not (targets >1))) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.ThrowGlaive].partialRecharge <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.ThrowGlaive].charges >1.01) and true and targets >1) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.FelRush].partialRecharge <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.FelRush].charges >1.01) and targets >1) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
end
function Havoc:ar_cooldown()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and ((((cooldown[classtable.EyeBeam].remains >= 20 or talents[classtable.CycleofHatred] and cooldown[classtable.EyeBeam].remains >= 13) and (not talents[classtable.EssenceBreak] or debuff[classtable.EssenceBreakDeBuff].up) and not buff[classtable.FelBarrageBuff].up and (math.huge >40 or (targets >8 or not talents[classtable.FelBarrage]) and targets >2) or not talents[classtable.ChaoticTransformation] or MaxDps:boss() and ttd <30) and not buff[classtable.InnerDemonBuff].up and (not talents[classtable.RestlessHunter] and cooldown[classtable.BladeDance].remains >gcd*3 or (MaxDps.spellHistory[1] == classtable.DeathSweep))) and not talents[classtable.Inertia] and not talents[classtable.EssenceBreak] and (opened or timeInCombat >15)) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and ((not cooldown[classtable.BladeDance].ready and (((MaxDps.spellHistory[1] == classtable.DeathSweep) or (MaxDps.spellHistory[1] == classtable.DeathSweep) or (MaxDps.spellHistory[1] == classtable.DeathSweep) or buff[classtable.MetamorphosisBuff].up and buff[classtable.MetamorphosisBuff].remains <gcd) and not cooldown[classtable.EyeBeam].ready and (not talents[classtable.EssenceBreak] or debuff[classtable.EssenceBreakDeBuff].up or talents[classtable.ShatteredDestiny]) and not buff[classtable.FelBarrageBuff].up and (math.huge >40 or (targets >8 or not talents[classtable.FelBarrage]) and targets >2) or not talents[classtable.ChaoticTransformation] or MaxDps:boss() and ttd <30) and (not buff[classtable.InnerDemonBuff].up and (not buff[classtable.RendingStrikeBuff].up or not talents[classtable.RestlessHunter] or (MaxDps.spellHistory[1] == classtable.DeathSweep)))) and (talents[classtable.Inertia] or talents[classtable.EssenceBreak]) and (opened or timeInCombat >15)) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    special_trinket = MaxDps:CheckEquipped('MadQueensMandate') or MaxDps:CheckEquipped('TreacherousTransmitter') or MaxDps:CheckEquipped('SkardynsGrace') or MaxDps:CheckEquipped('SignetofthePriory') or MaxDps:CheckEquipped('JunkmaestrosMegaMagnet') or MaxDps:CheckEquipped('GeargrindersSpareKeys') or MaxDps:CheckEquipped('MisterLocknstalk') or MaxDps:CheckEquipped('RavenousHoneyBuzzer') or MaxDps:CheckEquipped('GrimCodex')
    if (MaxDps:CheckSpellUsable(classtable.mad_queens_mandate, 'mad_queens_mandate')) and (((not talents[classtable.Initiative] or buff[classtable.InitiativeBuff].up or timeInCombat >5) and (buff[classtable.MetamorphosisBuff].remains >5 or not buff[classtable.MetamorphosisBuff].up) and (MaxDps:CheckTrinketNames('MadQueensMandate') and (MaxDps:CheckTrinketCooldownDuration('14') <10 or MaxDps:CheckTrinketCooldown('14') >10 or not MaxDps:HasBuffEffect('14', 'any')) or MaxDps:CheckTrinketNames('MadQueensMandate') and (MaxDps:CheckTrinketCooldownDuration('13') <10 or MaxDps:CheckTrinketCooldown('13') >10 or not MaxDps:HasBuffEffect('13', 'any'))) and ttd >120 or MaxDps:boss() and ttd <10 and ttd <buff[classtable.MetamorphosisBuff].remains) and not debuff[classtable.EssenceBreakDeBuff].up or ttd <5) and cooldown[classtable.mad_queens_mandate].ready then
        MaxDps:GlowCooldown(classtable.mad_queens_mandate, cooldown[classtable.mad_queens_mandate].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.treacherous_transmitter, 'treacherous_transmitter')) and (not MaxDps:CheckEquipped('MadQueensMandate') or MaxDps:CheckEquipped('MadQueensMandate') and (MaxDps:CheckTrinketNames('MadQueensMandate') and MaxDps:CheckTrinketCooldown('13') >ttd or MaxDps:CheckTrinketNames('MadQueensMandate') and MaxDps:CheckTrinketCooldown('14') >ttd) or ttd >25) and cooldown[classtable.treacherous_transmitter].ready then
        MaxDps:GlowCooldown(classtable.treacherous_transmitter, cooldown[classtable.treacherous_transmitter].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.skardyns_grace, 'skardyns_grace')) and ((not MaxDps:CheckEquipped('MadQueensMandate') or ttd >25 or MaxDps:CheckTrinketNames('SkardynsGrace') and MaxDps:CheckTrinketCooldown('13') >ttd or MaxDps:CheckTrinketNames('SkardynsGrace') and MaxDps:CheckTrinketCooldown('14') >ttd or MaxDps:CheckTrinketCooldownDuration('13') <10 or MaxDps:CheckTrinketCooldownDuration('14') <10) and buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.skardyns_grace].ready then
        MaxDps:GlowCooldown(classtable.skardyns_grace, cooldown[classtable.skardyns_grace].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.house_of_cards, 'house_of_cards')) and ((cooldown[classtable.EyeBeam].ready or buff[classtable.MetamorphosisBuff].up) or MaxDps:boss() and ttd <20) and cooldown[classtable.house_of_cards].ready then
        MaxDps:GlowCooldown(classtable.house_of_cards, cooldown[classtable.house_of_cards].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.signet_of_the_priory, 'signet_of_the_priory')) and (timeInCombat <20 and (not talents[classtable.Inertia] or buff[classtable.InertiaBuff].up) or buff[classtable.MetamorphosisBuff].up and timeInCombat >20 or MaxDps:boss() and ttd <20) and cooldown[classtable.signet_of_the_priory].ready then
        MaxDps:GlowCooldown(classtable.signet_of_the_priory, cooldown[classtable.signet_of_the_priory].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.junkmaestros_mega_magnet, 'junkmaestros_mega_magnet')) and (tier33_4piece and double_on_use or ttd <20) and cooldown[classtable.junkmaestros_mega_magnet].ready then
        MaxDps:GlowCooldown(classtable.junkmaestros_mega_magnet, cooldown[classtable.junkmaestros_mega_magnet].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.geargrinders_spare_keys, 'geargrinders_spare_keys')) and (tier33_4piece and double_on_use or ttd <20) and cooldown[classtable.geargrinders_spare_keys].ready then
        MaxDps:GlowCooldown(classtable.geargrinders_spare_keys, cooldown[classtable.geargrinders_spare_keys].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.grim_codex, 'grim_codex')) and (tier33_4piece and double_on_use or MaxDps:boss() and ttd <10) and cooldown[classtable.grim_codex].ready then
        MaxDps:GlowCooldown(classtable.grim_codex, cooldown[classtable.grim_codex].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ravenous_honey_buzzer, 'ravenous_honey_buzzer')) and ((tier33_4piece and (not buff[classtable.InertiaBuff].up and (not cooldown[classtable.EssenceBreak].ready and not debuff[classtable.EssenceBreakDeBuff].up or not talents[classtable.EssenceBreak])) and (MaxDps:CheckTrinketNames('RavenousHoneyBuzzer') and (MaxDps:CheckTrinketCooldownDuration('14') <10 or MaxDps:CheckTrinketCooldown('14') >10 or not MaxDps:HasBuffEffect('14', 'any')) or MaxDps:CheckTrinketNames('RavenousHoneyBuzzer') and (MaxDps:CheckTrinketCooldownDuration('13') <10 or MaxDps:CheckTrinketCooldown('13') >10 or not MaxDps:HasBuffEffect('13', 'any'))) and ttd >120 or MaxDps:boss() and ttd <10 and ttd <buff[classtable.MetamorphosisBuff].remains) or ttd <5) and cooldown[classtable.ravenous_honey_buzzer].ready then
        MaxDps:GlowCooldown(classtable.ravenous_honey_buzzer, cooldown[classtable.ravenous_honey_buzzer].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket1, 'trinket1')) and (((cooldown[classtable.EyeBeam].remains <gcd and targets >1 or buff[classtable.MetamorphosisBuff].up) and (math.huge >MaxDps:CheckTrinketCooldownDuration('13')-15 or targets >8) or not MaxDps:HasBuffEffect('13', 'any') or MaxDps:boss() and ttd <25) and not MaxDps:CheckTrinketNames('MisterLocknstalk') and not trinket1_crit and not MaxDps:CheckTrinketNames('SkardynsGrace') and not MaxDps:CheckTrinketNames('TreacherousTransmitter') and (not special_trinket or MaxDps:CheckTrinketCooldown('14') >20)) and cooldown[classtable.trinket1].ready then
        MaxDps:GlowCooldown(classtable.trinket1, cooldown[classtable.trinket1].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket2, 'trinket2')) and (((cooldown[classtable.EyeBeam].remains <gcd and targets >1 or buff[classtable.MetamorphosisBuff].up) and (math.huge >MaxDps:CheckTrinketCooldownDuration('14')-15 or targets >8) or not MaxDps:HasBuffEffect('14', 'any') or MaxDps:boss() and ttd <25) and not MaxDps:CheckTrinketNames('MisterLocknstalk') and not trinket2_crit and not MaxDps:CheckTrinketNames('SkardynsGrace') and not MaxDps:CheckTrinketNames('TreacherousTransmitter') and (not special_trinket or MaxDps:CheckTrinketCooldown('13') >20)) and cooldown[classtable.trinket2].ready then
        MaxDps:GlowCooldown(classtable.trinket2, cooldown[classtable.trinket2].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not debuff[classtable.EssenceBreakDeBuff].up and (targets >= 1+targets or math.huge >90) and (not talents[classtable.ReaversMark] or debuff[classtable.ReaversMarkDeBuff].up) and not buff[classtable.ReaversGlaiveBuff].up and (buff[classtable.MetamorphosisBuff].remains >5 or not buff[classtable.MetamorphosisBuff].up) and (not talents[classtable.Initiative] or buff[classtable.InitiativeBuff].up or timeInCombat >5) and timeInCombat >5 and (not talents[classtable.Inertia] and not buff[classtable.UnboundChaosBuff].up or not buff[classtable.InertiaTriggerBuff].up)) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (not debuff[classtable.EssenceBreakDeBuff].up and (not talents[classtable.ReaversMark] or MaxDps:DebuffCounter(classtable.ReaversMarkDeBuff) >0 or debuff[classtable.ReaversMarkDeBuff].remains >= 2-(talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0)) and not cooldown[classtable.BladeDance].ready and timeInCombat >15) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
end
function Havoc:ar_fel_barrage()
    generator_up = cooldown[classtable.Felblade].remains <gcd or cooldown[classtable.SigilofFlame].remains <gcd
    gcd_drain = gcd * 32
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.InnerDemonBuff].up) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not buff[classtable.FelBarrageBuff].up and (targets >1 and (targets >1) or math.huge >40)) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (not buff[classtable.FelBarrageBuff].up and buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (not buff[classtable.FelBarrageBuff].up) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and ((targets >2 or buff[classtable.FelBarrageBuff].up) and (cooldown[classtable.EyeBeam].remains >cooldown[classtable.ImmolationAura].partialRecharge+3)) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.GlaiveTempest, 'GlaiveTempest')) and (not buff[classtable.FelBarrageBuff].up and targets >1) and cooldown[classtable.GlaiveTempest].ready then
        if not setSpell then setSpell = classtable.GlaiveTempest end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (not buff[classtable.FelBarrageBuff].up) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelBarrage, 'FelBarrage') and talents[classtable.FelBarrage]) and (Fury >100 and (math.huge >90 or math.huge <gcd or targets >4 and targets >2)) and cooldown[classtable.FelBarrage].ready then
        if not setSpell then setSpell = classtable.FelBarrage end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.InertiaTriggerBuff].up and buff[classtable.FelBarrageBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (FuryDeficit >40 and buff[classtable.FelBarrageBuff].up) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.FelBarrageBuff].up and FuryDeficit >40) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (Fury - gcd_drain-35 >0 and (buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18)) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.GlaiveTempest, 'GlaiveTempest')) and (Fury - gcd_drain-30 >0 and (buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18)) and cooldown[classtable.GlaiveTempest].ready then
        if not setSpell then setSpell = classtable.GlaiveTempest end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (Fury - gcd_drain-35 >0 and (buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18)) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (Fury >40 and (targets >= 1+targets or math.huge >80)) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (Fury - gcd_drain-40 >20 and (buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18)) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (Fury - gcd_drain-40 >20 and (not cooldown[classtable.FelBarrage].ready and cooldown[classtable.FelBarrage].remains <10 and Fury >100 or buff[classtable.FelBarrageBuff].up and (buff[classtable.FelBarrageBuff].remains * fury_gen-buff[classtable.FelBarrageBuff].remains * 32)>0)) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
end
function Havoc:ar_meta()
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (buff[classtable.MetamorphosisBuff].remains <gcd or debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and (opened or timeInCombat >15 or not cooldown[classtable.DeathSweep].ready) and (not cooldown[classtable.Metamorphosis].ready and (not talents[classtable.EssenceBreak] or cooldown[classtable.EssenceBreak].remains <= 0.6 or cooldown[classtable.EssenceBreak].remains >10) or cooldown[classtable.Metamorphosis].ready and talents[classtable.EssenceBreak] and cooldown[classtable.EssenceBreak].remains <= 0.6 and not buff[classtable.InnerDemonBuff].up and cooldown[classtable.BladeDance].remains <= gcd+0.5 or talents[classtable.RestlessHunter]) and not cooldown[classtable.EyeBeam].ready and (not talents[classtable.Inertia] and not buff[classtable.UnboundChaosBuff].up or not buff[classtable.InertiaTriggerBuff].up)) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (talents[classtable.Inertia] and buff[classtable.InertiaTriggerBuff].up and cooldown[classtable.EssenceBreak].remains <= 1 and cooldown[classtable.BladeDance].remains <= gcd*2 and cooldown[classtable.Metamorphosis].remains <= gcd*3) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (Fury >= 30 and talents[classtable.RestlessHunter] and cooldown[classtable.Metamorphosis].ready and (talents[classtable.Inertia] and buff[classtable.InertiaBuff].up or not talents[classtable.Inertia]) and cooldown[classtable.BladeDance].remains <= gcd) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.MetamorphosisBuff].remains <gcd or debuff[classtable.EssenceBreakDeBuff].up and debuff[classtable.EssenceBreakDeBuff].remains <0.5 and not cooldown[classtable.BladeDance].ready or buff[classtable.InnerDemonBuff].up and cooldown[classtable.EssenceBreak].ready and cooldown[classtable.Metamorphosis].ready) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and not cooldown[classtable.Metamorphosis].ready and (cooldown[classtable.EyeBeam].remains <= 0.5 or cooldown[classtable.EssenceBreak].remains <= 0.5 or cooldown[classtable.BladeDance].remains <= 5.5 or buff[classtable.InitiativeBuff].remains <gcd)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and ((not cooldown[classtable.Metamorphosis].ready and targets >2) or (cooldown[classtable.BladeDance].remains <gcd*3 and not cooldown[classtable.Metamorphosis].ready and targets >2))) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (cooldown[classtable.ImmolationAura].charges == 2 and targets >1 and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.InnerDemonBuff].up and (cooldown[classtable.EyeBeam].remains <gcd*3 and not cooldown[classtable.BladeDance].ready or cooldown[classtable.Metamorphosis].remains <gcd*3)) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (timeInCombat <20 and buff[classtable.ThrilloftheFightDamageBuff].remains >gcd*4 and buff[classtable.MetamorphosisBuff].remains >= gcd*2 and cooldown[classtable.Metamorphosis].ready and cooldown[classtable.DeathSweep].remains <= gcd and buff[classtable.InertiaBuff].up) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (Fury >20 and (cooldown[classtable.BladeDance].remains <gcd*3 or cooldown[classtable.BladeDance].ready) and (not buff[classtable.UnboundChaosBuff].up and not talents[classtable.Inertia] or buff[classtable.InertiaBuff].up) and 0 <gcd and (not talents[classtable.ShatteredDestiny] or cooldown[classtable.EyeBeam].remains >4) or MaxDps:boss() and ttd <10) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.GlaiveTempest, 'GlaiveTempest')) and (not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.BladeDance].remains >gcd*2 or Fury >60) and (targets >= 1+targets or math.huge >10)) and cooldown[classtable.GlaiveTempest].ready then
        if not setSpell then setSpell = classtable.GlaiveTempest end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (targets >2 and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (talents[classtable.Soulscar] and talents[classtable.FuriousThrows] and targets >1 and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.ThrowGlaive].charges == 2 or cooldown[classtable.ThrowGlaive].fullRecharge <cooldown[classtable.BladeDance].remains)) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (cooldown[classtable.BladeDance].remains or Fury >60 or buff[classtable.MetamorphosisBuff].remains <5 and cooldown[classtable.Felblade].ready) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (buff[classtable.MetamorphosisBuff].remains >5 and true) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (FuryDeficit >40 and not buff[classtable.InertiaTriggerBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (not debuff[classtable.EssenceBreakDeBuff].up and true) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (true and cooldown[classtable.ImmolationAura].partialRecharge<(math.min(cooldown[classtable.EyeBeam].remains , buff[classtable.MetamorphosisBuff].remains)) and (targets >= 1+targets or math.huge >cooldown[classtable.ImmolationAura].fullRecharge)) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (cooldown[classtable.FelRush].partialRecharge <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.FelRush].charges >1.01) and true and targets >1) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
end
function Havoc:ar_opener()
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not buff[classtable.ReaversGlaiveBuff].up and not buff[classtable.GlaiveFlurryBuff].up and not buff[classtable.RendingStrikeBuff].up) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and timeInCombat >4 and buff[classtable.MetamorphosisBuff].up and (not talents[classtable.Inertia] or not buff[classtable.InertiaTriggerBuff].up) and not buff[classtable.InnerDemonBuff].up and not cooldown[classtable.BladeDance].ready and gcd <0.1) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.RendingStrikeBuff].up and not buff[classtable.ThrilloftheFightDamageBuff].up) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (not talents[classtable.Inertia] and talents[classtable.UnboundChaos] and buff[classtable.UnboundChaosBuff].up and buff[classtable.InitiativeBuff].up and not debuff[classtable.EssenceBreakDeBuff].up and targets <= 2) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (not talents[classtable.Inertia] and talents[classtable.UnboundChaos] and buff[classtable.UnboundChaosBuff].up and buff[classtable.InitiativeBuff].up and not debuff[classtable.EssenceBreakDeBuff].up and targets >2) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (talents[classtable.InnerDemon] and buff[classtable.InnerDemonBuff].up and cooldown[classtable.EssenceBreak].ready) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and ((buff[classtable.InertiaBuff].up or not talents[classtable.Inertia]) and buff[classtable.MetamorphosisBuff].up and cooldown[classtable.BladeDance].remains <= gcd and (not talents[classtable.ReaversMark] or MaxDps:DebuffCounter(classtable.ReaversMarkDeBuff) >0 or debuff[classtable.ReaversMarkDeBuff].remains >= 2-(talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0))) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and talents[classtable.RestlessHunter] and cooldown[classtable.EssenceBreak].ready and cooldown[classtable.Metamorphosis].ready and buff[classtable.MetamorphosisBuff].up and cooldown[classtable.BladeDance].remains <= gcd) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (talents[classtable.Inertia] and buff[classtable.InertiaTriggerBuff].up and (not buff[classtable.InertiaBuff].up and buff[classtable.MetamorphosisBuff].up) and not debuff[classtable.EssenceBreakDeBuff].up and targets <= 2) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Inertia] and buff[classtable.InertiaTriggerBuff].up and (not buff[classtable.InertiaBuff].up and buff[classtable.MetamorphosisBuff].up) and not debuff[classtable.EssenceBreakDeBuff].up and (not cooldown[classtable.Felblade].ready or targets >2)) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (talents[classtable.Inertia] and buff[classtable.InertiaTriggerBuff].up and buff[classtable.MetamorphosisBuff].up and not cooldown[classtable.Metamorphosis].ready and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and ((buff[classtable.MetamorphosisBuff].up and (MaxDps.ActiveHeroTree == 'aldrachireaver') and talents[classtable.ShatteredDestiny] or not talents[classtable.ShatteredDestiny] and (MaxDps.ActiveHeroTree == 'aldrachireaver') or (MaxDps.ActiveHeroTree == 'felscarred')) and (not talents[classtable.Initiative] or talents[classtable.Inertia] or buff[classtable.InitiativeBuff].up or timeInCombat >5)) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (Fury <40 and not buff[classtable.InertiaTriggerBuff].up and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and (not debuff[classtable.ReaversMarkDeBuff].up and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (buff[classtable.RendingStrikeBuff].up and targets >2) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (buff[classtable.GlaiveFlurryBuff].up and targets >2) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.AFireInside] and talents[classtable.BurningWound] and not buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (buff[classtable.MetamorphosisBuff].up and cooldown[classtable.BladeDance].remains >gcd*2 and not buff[classtable.InnerDemonBuff].up and (not talents[classtable.RestlessHunter] or (MaxDps.spellHistory[1] == classtable.DeathSweep)) and (not cooldown[classtable.EssenceBreak].ready or not talents[classtable.EssenceBreak])) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and ((not talents[classtable.ReaversMark] or MaxDps:DebuffCounter(classtable.ReaversMarkDeBuff) >0 or debuff[classtable.ReaversMarkDeBuff].up) and (not cooldown[classtable.EyeBeam].ready and not cooldown[classtable.Metamorphosis].ready)) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not buff[classtable.MetamorphosisBuff].up or not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up and (not cooldown[classtable.BladeDance].ready or talents[classtable.EssenceBreak] and cooldown[classtable.EssenceBreak].ready)) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (cooldown[classtable.BladeDance].remains <gcd and not (MaxDps.ActiveHeroTree == 'felscarred') and not talents[classtable.ShatteredDestiny] and buff[classtable.MetamorphosisBuff].up or not cooldown[classtable.EyeBeam].ready and not cooldown[classtable.Metamorphosis].ready) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
    opened = true
end
function Havoc:fs()
    Havoc:fs_cooldown()
    if (timeInCombat <15 and true and (cooldown[classtable.EyeBeam].ready or cooldown[classtable.Metamorphosis].ready or talents[classtable.EssenceBreak] and cooldown[classtable.EssenceBreak].ready or buff[classtable.DemonsurgeBuff].count <3+(talents[classtable.StudentofSuffering] and talents[classtable.StudentofSuffering] or 0) + (talents[classtable.AFireInside] and talents[classtable.AFireInside] or 0))) then
        Havoc:fs_opener()
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (talents[classtable.UnboundChaos] and buff[classtable.UnboundChaosBuff].up and not talents[classtable.Inertia] and targets <= 2 and (talents[classtable.StudentofSuffering] and cooldown[classtable.EyeBeam].remains - gcd*2 <= buff[classtable.UnboundChaosBuff].remains or (MaxDps.ActiveHeroTree == 'aldrachireaver'))) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.UnboundChaos] and buff[classtable.UnboundChaosBuff].up and not talents[classtable.Inertia] and targets >3 and (talents[classtable.StudentofSuffering] and cooldown[classtable.EyeBeam].remains - gcd*2 <= buff[classtable.UnboundChaosBuff].remains)) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (buff[classtable.MetamorphosisBuff].up) then
        Havoc:fs_meta()
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and (cooldown[classtable.EyeBeam].remains >15 and gcd <0.3 or gcd <0.2 and cooldown[classtable.EyeBeam].remains <= gcd and (cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd*3)) and (not talents[classtable.StudentofSuffering] or not cooldown[classtable.SigilofFlame].ready) and (cooldown[classtable.EssenceBreak].remains <= gcd*2 and talents[classtable.StudentofSuffering] and not cooldown[classtable.SigilofFlame].ready or cooldown[classtable.EssenceBreak].remains >= 18 or not talents[classtable.StudentofSuffering]) and (cooldown[classtable.Metamorphosis].remains >10 or (MaxDps.ActiveHeroTree == 'aldrachireaver')) and timeInCombat >20) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (talents[classtable.StudentofSuffering] and cooldown[classtable.EyeBeam].remains <= gcd and (cooldown[classtable.EssenceBreak].remains <gcd*3) and (cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd*2)) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and ((not talents[classtable.Initiative] or buff[classtable.InitiativeBuff].up or cooldown[classtable.VengefulRetreat].remains >= 10 or cooldown[classtable.Metamorphosis].ready) and (cooldown[classtable.BladeDance].remains <7 or (targets >1)) or MaxDps:boss() and ttd <10) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (cooldown[classtable.EyeBeam].remains >= gcd*4 or debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.AFireInside] and talents[classtable.IsolatedPrey] and talents[classtable.Flamebound] and targets == 1 and cooldown[classtable.EyeBeam].remains >= gcd) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (FuryDeficit >40+fury_gen*(0.5%gcd) and (cooldown[classtable.VengefulRetreat].remains >= cooldown[classtable.Felblade].remains+0.5 and talents[classtable.Inertia] and targets == 1 or not talents[classtable.Inertia] or (MaxDps.ActiveHeroTree == 'aldrachireaver') or not cooldown[classtable.EssenceBreak].ready) and not cooldown[classtable.Metamorphosis].ready and cooldown[classtable.EyeBeam].remains >= 0.5+gcd*(((talents[classtable.StudentofSuffering] and talents[classtable.StudentofSuffering] or 0) and cooldown[classtable.SigilofFlame].remains <= gcd) and 1 or 0)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (cooldown[classtable.EyeBeam].remains >= gcd*4 or (Fury >= 70-30*((talents[classtable.StudentofSuffering] and talents[classtable.StudentofSuffering] or 0) and (cooldown[classtable.SigilofFlame].remains <= gcd or cooldown[classtable.SigilofFlame].ready) and 1 or 0)-buff[classtable.ChaosTheoryBuff].upMath * 20-fury_gen)) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (math.huge >cooldown[classtable.ImmolationAura].fullRecharge and cooldown[classtable.EyeBeam].remains >= gcd*(1 + (talents[classtable.StudentofSuffering] and talents[classtable.StudentofSuffering] or 0) and (cooldown[classtable.SigilofFlame].remains <= gcd or cooldown[classtable.SigilofFlame].ready) and 1 or 0) or targets >1 and targets >2) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (true and not buff[classtable.InertiaTriggerBuff].up and cooldown[classtable.EyeBeam].remains >= gcd*(1 + (talents[classtable.StudentofSuffering] and talents[classtable.StudentofSuffering] or 0) and (cooldown[classtable.SigilofFlame].remains <= gcd or cooldown[classtable.SigilofFlame].ready) and 1 or 0)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (true and not debuff[classtable.EssenceBreakDeBuff].up and not talents[classtable.StudentofSuffering] and (not talents[classtable.FelBarrage] or cooldown[classtable.FelBarrage].remains >25 or (targets == 1 and not (targets >1)))) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (cooldown[classtable.ThrowGlaive].partialRecharge <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.ThrowGlaive].charges >1.01) and true and targets >1) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.FelRush].partialRecharge <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.FelRush].charges >1.01) and targets >1) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
end
function Havoc:fs_cooldown()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (((cooldown[classtable.EyeBeam].remains >= 20 and (not talents[classtable.EssenceBreak] or debuff[classtable.EssenceBreakDeBuff].up) and not buff[classtable.FelBarrageBuff].up and (math.huge >40 or (targets >8 or not talents[classtable.FelBarrage]) and targets >2) or not talents[classtable.ChaoticTransformation] or MaxDps:boss() and ttd <30) and not buff[classtable.InnerDemonBuff].up and (not talents[classtable.RestlessHunter] and cooldown[classtable.BladeDance].remains >gcd*3 or (MaxDps.spellHistory[1] == classtable.DeathSweep))) and not talents[classtable.Inertia] and not talents[classtable.EssenceBreak] and ((MaxDps.ActiveHeroTree == 'aldrachireaver') or not buff[classtable.MetamorphosisBuff].up) and (opened or timeInCombat >15)) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and ((not cooldown[classtable.BladeDance].ready and (buff[classtable.MetamorphosisBuff].up and not cooldown[classtable.EyeBeam].ready and (not talents[classtable.EssenceBreak] or debuff[classtable.EssenceBreakDeBuff].up or talents[classtable.ShatteredDestiny] or (MaxDps.ActiveHeroTree == 'felscarred')) and not buff[classtable.FelBarrageBuff].up and (math.huge >40 or (targets >8 or not talents[classtable.FelBarrage]) and targets >2) or not talents[classtable.ChaoticTransformation] or MaxDps:boss() and ttd <30) and (not buff[classtable.InnerDemonBuff].up and (not talents[classtable.RestlessHunter] or (MaxDps.spellHistory[1] == classtable.DeathSweep)))) and (talents[classtable.Inertia] or talents[classtable.EssenceBreak]) and ((MaxDps.ActiveHeroTree == 'aldrachireaver') or (not buff[classtable.MetamorphosisBuff].up and buff[classtable.MetamorphosisBuff].up or buff[classtable.MetamorphosisBuff].remains <gcd) and (not buff[classtable.MetamorphosisBuff].up)) and (opened or timeInCombat >15)) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    special_trinket = MaxDps:CheckEquipped('MadQueensMandate') or MaxDps:CheckEquipped('TreacherousTransmitter') or MaxDps:CheckEquipped('SkardynsGrace') or MaxDps:CheckEquipped('SignetofthePriory') or MaxDps:CheckEquipped('JunkmaestrosMegaMagnet') or MaxDps:CheckEquipped('GeargrindersSpareKeys') or MaxDps:CheckEquipped('MisterLocknstalk') or MaxDps:CheckEquipped('RavenousHoneyBuzzer')
    if (MaxDps:CheckSpellUsable(classtable.mad_queens_mandate, 'mad_queens_mandate')) and (((not talents[classtable.Initiative] or buff[classtable.InitiativeBuff].up or timeInCombat >5) and (buff[classtable.MetamorphosisBuff].remains >5 or not buff[classtable.MetamorphosisBuff].up) and (MaxDps:CheckTrinketNames('MadQueensMandate') and (MaxDps:CheckTrinketCooldownDuration('14') <10 or MaxDps:CheckTrinketCooldown('14') >10 or not MaxDps:HasBuffEffect('14', 'any')) or MaxDps:CheckTrinketNames('MadQueensMandate') and (MaxDps:CheckTrinketCooldownDuration('13') <10 or MaxDps:CheckTrinketCooldown('13') >10 or not MaxDps:HasBuffEffect('13', 'any'))) and ttd >120 or MaxDps:boss() and ttd <10 and ttd <buff[classtable.MetamorphosisBuff].remains) and not debuff[classtable.EssenceBreakDeBuff].up or ttd <5) and cooldown[classtable.mad_queens_mandate].ready then
        MaxDps:GlowCooldown(classtable.mad_queens_mandate, cooldown[classtable.mad_queens_mandate].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.treacherous_transmitter, 'treacherous_transmitter')) and (not MaxDps:CheckEquipped('MadQueensMandate') or MaxDps:CheckEquipped('MadQueensMandate') and (MaxDps:CheckTrinketNames('MadQueensMandate') and MaxDps:CheckTrinketCooldown('13') >ttd or MaxDps:CheckTrinketNames('MadQueensMandate') and MaxDps:CheckTrinketCooldown('14') >ttd) or ttd >25) and cooldown[classtable.treacherous_transmitter].ready then
        MaxDps:GlowCooldown(classtable.treacherous_transmitter, cooldown[classtable.treacherous_transmitter].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.skardyns_grace, 'skardyns_grace')) and ((not MaxDps:CheckEquipped('MadQueensMandate') or ttd >25 or MaxDps:CheckTrinketNames('SkardynsGrace') and MaxDps:CheckTrinketCooldown('13') >ttd or MaxDps:CheckTrinketNames('SkardynsGrace') and MaxDps:CheckTrinketCooldown('14') >ttd or MaxDps:CheckTrinketCooldownDuration('13') <10 or MaxDps:CheckTrinketCooldownDuration('14') <10) and buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.skardyns_grace].ready then
        MaxDps:GlowCooldown(classtable.skardyns_grace, cooldown[classtable.skardyns_grace].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.signet_of_the_priory, 'signet_of_the_priory')) and (timeInCombat <20 and (not talents[classtable.Inertia] or buff[classtable.InertiaBuff].up) or (buff[classtable.MetamorphosisBuff].up and cooldown[classtable.EssenceBreak].ready or MaxDps:boss() and ttd <20) and timeInCombat >20) and cooldown[classtable.signet_of_the_priory].ready then
        MaxDps:GlowCooldown(classtable.signet_of_the_priory, cooldown[classtable.signet_of_the_priory].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.junkmaestros_mega_magnet, 'junkmaestros_mega_magnet')) and (buff[classtable.InitiativeBuff].up) and cooldown[classtable.junkmaestros_mega_magnet].ready then
        MaxDps:GlowCooldown(classtable.junkmaestros_mega_magnet, cooldown[classtable.junkmaestros_mega_magnet].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.geargrinders_spare_keys, 'geargrinders_spare_keys')) and (buff[classtable.InitiativeBuff].up) and cooldown[classtable.geargrinders_spare_keys].ready then
        MaxDps:GlowCooldown(classtable.geargrinders_spare_keys, cooldown[classtable.geargrinders_spare_keys].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket1, 'trinket1')) and (((cooldown[classtable.EyeBeam].remains <gcd and targets >1 or buff[classtable.MetamorphosisBuff].up) and (math.huge >MaxDps:CheckTrinketCooldownDuration('13')-15 or targets >8) or not MaxDps:HasBuffEffect('13', 'any') or MaxDps:boss() and ttd <25) and not MaxDps:CheckTrinketNames('SkardynsGrace') and not MaxDps:CheckTrinketNames('MadQueensMandate') and not MaxDps:CheckTrinketNames('TreacherousTransmitter') and (not special_trinket or MaxDps:CheckTrinketCooldown('14') >20)) and cooldown[classtable.trinket1].ready then
        MaxDps:GlowCooldown(classtable.trinket1, cooldown[classtable.trinket1].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.trinket2, 'trinket2')) and (((cooldown[classtable.EyeBeam].remains <gcd and targets >1 or buff[classtable.MetamorphosisBuff].up) and (math.huge >MaxDps:CheckTrinketCooldownDuration('14')-15 or targets >8) or not MaxDps:HasBuffEffect('14', 'any') or MaxDps:boss() and ttd <25) and not MaxDps:CheckTrinketNames('SkardynsGrace') and not MaxDps:CheckTrinketNames('MadQueensMandate') and not MaxDps:CheckTrinketNames('TreacherousTransmitter') and (not special_trinket or MaxDps:CheckTrinketCooldown('13') >20)) and cooldown[classtable.trinket2].ready then
        MaxDps:GlowCooldown(classtable.trinket2, cooldown[classtable.trinket2].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not debuff[classtable.EssenceBreakDeBuff].up and (MaxDps:DebuffCounter(classtable.ReaversMarkDeBuff) >0 or debuff[classtable.ReaversMarkDeBuff].up or not talents[classtable.ReaversMark]) and not buff[classtable.ReaversGlaiveBuff].up and (buff[classtable.MetamorphosisBuff].remains >5 or not buff[classtable.MetamorphosisBuff].up) and (not talents[classtable.Initiative] or buff[classtable.InitiativeBuff].up or timeInCombat >5) and timeInCombat >5 and (not talents[classtable.Inertia] and not buff[classtable.UnboundChaosBuff].up or not buff[classtable.InertiaTriggerBuff].up) and ((MaxDps.ActiveHeroTree == 'aldrachireaver') or not buff[classtable.MetamorphosisBuff].up) or MaxDps:boss() and ttd <= 30) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (not debuff[classtable.EssenceBreakDeBuff].up and not cooldown[classtable.BladeDance].ready and (opened or timeInCombat >15)) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
end
function Havoc:fs_meta()
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (buff[classtable.MetamorphosisBuff].remains <gcd or debuff[classtable.EssenceBreakDeBuff].up or (MaxDps.spellHistory[1] == classtable.Metamorphosis)) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (talents[classtable.StudentofSuffering] and not buff[classtable.MetamorphosisBuff].up and not debuff[classtable.EssenceBreakDeBuff].up and (talents[classtable.StudentofSuffering] and ((talents[classtable.EssenceBreak] and cooldown[classtable.EssenceBreak].remains >30-gcd or cooldown[classtable.EssenceBreak].remains <= gcd+(talents[classtable.Inertia] and talents[classtable.Inertia] or 0) and (cooldown[classtable.VengefulRetreat].remains <= gcd or buff[classtable.InitiativeBuff].up)+gcd*((cooldown[classtable.EyeBeam].remains <= gcd) and 1 or 0)) or (not talents[classtable.EssenceBreak] and (cooldown[classtable.EyeBeam].remains >= 10 or cooldown[classtable.EyeBeam].remains <= gcd))))) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and (gcd <0.3 or talents[classtable.Inertia] and cooldown[classtable.EyeBeam].remains >gcd and (buff[classtable.CycleofHatredBuff].count == 2 or buff[classtable.CycleofHatredBuff].count == 3)) and (not cooldown[classtable.Metamorphosis].ready and (not buff[classtable.MetamorphosisBuff].up and not buff[classtable.MetamorphosisBuff].up) or talents[classtable.RestlessHunter] and (not (MaxDps.ActiveHeroTree == 'felscarred') or not buff[classtable.MetamorphosisBuff].up)) and (not talents[classtable.Inertia] and not buff[classtable.UnboundChaosBuff].up or not buff[classtable.InertiaTriggerBuff].up) and (not talents[classtable.EssenceBreak] or cooldown[classtable.EssenceBreak].remains >18 or cooldown[classtable.EssenceBreak].remains <= gcd+(talents[classtable.Inertia] and talents[classtable.Inertia] or 0) * 1.5 and (not talents[classtable.StudentofSuffering] or (buff[classtable.StudentofSufferingBuff].up or cooldown[classtable.SigilofFlame].remains >5))) and (cooldown[classtable.EyeBeam].remains >5 or cooldown[classtable.EyeBeam].remains <= gcd or cooldown[classtable.EyeBeam].ready)) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and ((MaxDps.ActiveHeroTree == 'felscarred') and talents[classtable.EssenceBreak] and buff[classtable.MetamorphosisBuff].up and (buff[classtable.InertiaBuff].up and (cooldown[classtable.EssenceBreak].remains >buff[classtable.InertiaBuff].remains or not talents[classtable.EssenceBreak]) or cooldown[classtable.Metamorphosis].remains <= 5 and not buff[classtable.InertiaTriggerBuff].up or buff[classtable.InertiaBuff].up and buff[classtable.MetamorphosisBuff].up) or talents[classtable.Inertia] and not buff[classtable.InertiaTriggerBuff].up and cooldown[classtable.VengefulRetreat].remains >= gcd and not buff[classtable.InertiaBuff].up) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.MetamorphosisBuff].remains <gcd and cooldown[classtable.BladeDance].remains <buff[classtable.MetamorphosisBuff].remains or debuff[classtable.EssenceBreakDeBuff].up and debuff[classtable.EssenceBreakDeBuff].remains <0.5 or talents[classtable.RestlessHunter] and (buff[classtable.MetamorphosisBuff].up or (MaxDps.ActiveHeroTree == 'aldrachireaver') and buff[classtable.InnerDemonBuff].up) and cooldown[classtable.EssenceBreak].ready and cooldown[classtable.Metamorphosis].ready) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (((MaxDps.ActiveHeroTree == 'felscarred') and buff[classtable.MetamorphosisBuff].up and talents[classtable.RestlessHunter]) and (cooldown[classtable.EyeBeam].remains <gcd*3 and not cooldown[classtable.BladeDance].ready or cooldown[classtable.Metamorphosis].remains <gcd*3)) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and not debuff[classtable.EssenceBreakDeBuff].up and not cooldown[classtable.Metamorphosis].ready and (not (MaxDps.ActiveHeroTree == 'felscarred') or not cooldown[classtable.EyeBeam].ready) and (cooldown[classtable.BladeDance].remains <= 5.5 and (talents[classtable.EssenceBreak] and cooldown[classtable.EssenceBreak].remains <= 0.5 or not talents[classtable.EssenceBreak] or cooldown[classtable.EssenceBreak].remains >= buff[classtable.InertiaTriggerBuff].remains and cooldown[classtable.BladeDance].remains <= 4.5 and (not cooldown[classtable.BladeDance].ready or cooldown[classtable.BladeDance].remains <= 0.5)) or buff[classtable.MetamorphosisBuff].remains <= 5.5+(talents[classtable.ShatteredDestiny] and talents[classtable.ShatteredDestiny] or 0) * 2)) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and not debuff[classtable.EssenceBreakDeBuff].up and not cooldown[classtable.Metamorphosis].ready and (not (MaxDps.ActiveHeroTree == 'felscarred') or not cooldown[classtable.EyeBeam].ready) and (targets >2 or (MaxDps.ActiveHeroTree == 'felscarred')) and (not cooldown[classtable.Felblade].ready and cooldown[classtable.EssenceBreak].remains <= 0.6)) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.InnerDemonBuff].up and not cooldown[classtable.BladeDance].ready and (cooldown[classtable.EyeBeam].remains <gcd*3 or cooldown[classtable.Metamorphosis].remains <gcd*3)) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (Fury >20 and (cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd*2) and (not buff[classtable.InertiaTriggerBuff].up or buff[classtable.InertiaBuff].up and buff[classtable.InertiaBuff].remains >= gcd*3 or not talents[classtable.Inertia]) and 0 <gcd and (not talents[classtable.ShatteredDestiny] or cooldown[classtable.EyeBeam].remains >4) and (not (MaxDps.ActiveHeroTree == 'felscarred') or targets >1 or cooldown[classtable.Metamorphosis].remains >5 and not cooldown[classtable.EyeBeam].ready) and (not buff[classtable.CycleofHatredBuff].count == 3 or buff[classtable.InitiativeBuff].up) or ttd <5) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (cooldown[classtable.BladeDance].remains and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.EyeBeam].remains >= 20 or cooldown[classtable.EyeBeam].remains <= gcd) and (not talents[classtable.StudentofSuffering] or buff[classtable.MetamorphosisBuff].up)) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (buff[classtable.DemonsurgeBuff].up and not debuff[classtable.EssenceBreakDeBuff].up and buff[classtable.MetamorphosisBuff].up and cooldown[classtable.BladeDance].remains >= gcd and cooldown[classtable.EyeBeam].remains >= gcd and FuryDeficit >10+fury_gen) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.AbyssalGaze, 'AbyssalGaze')) and (not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up and (buff[classtable.CycleofHatredBuff].count <4 or cooldown[classtable.EssenceBreak].remains >= 20-gcd * (talents[classtable.StudentofSuffering] and talents[classtable.StudentofSuffering] or 0) or not cooldown[classtable.SigilofFlame].ready and talents[classtable.StudentofSuffering] or cooldown[classtable.EssenceBreak].remains <= gcd)) and cooldown[classtable.AbyssalGaze].ready then
        if not setSpell then setSpell = classtable.AbyssalGaze end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (cooldown[classtable.EssenceBreak].remains >= gcd*2 + (talents[classtable.StudentofSuffering] and talents[classtable.StudentofSuffering] or 0)*gcd or debuff[classtable.EssenceBreakDeBuff].up or not talents[classtable.EssenceBreak]) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (cooldown[classtable.BladeDance].remains or Fury >60 or buff[classtable.MetamorphosisBuff].remains <5) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (true and cooldown[classtable.ImmolationAura].partialRecharge<(math.min(cooldown[classtable.EyeBeam].remains , buff[classtable.MetamorphosisBuff].remains)) and (targets >= 1+targets or math.huge >cooldown[classtable.ImmolationAura].fullRecharge)) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and ((true or FuryDeficit >40+fury_gen*(0.5%gcd)) and not buff[classtable.InertiaTriggerBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.ThrowGlaive].partialRecharge <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.ThrowGlaive].charges >1.01) and true and targets >1) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (cooldown[classtable.FelRush].partialRecharge <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and (cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.FelRush].charges >1.01) and true and targets >1) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
end
function Havoc:fs_opener()
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (cooldown[classtable.TheHunt].ready and not talents[classtable.AFireInside] and Fury <40) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (talents[classtable.Inertia] or buff[classtable.InitiativeBuff].up or not talents[classtable.Initiative]) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (talents[classtable.Inertia] and buff[classtable.InertiaTriggerBuff].up and targets == 1 and buff[classtable.MetamorphosisBuff].up and cooldown[classtable.Metamorphosis].ready and cooldown[classtable.EssenceBreak].ready and not buff[classtable.InnerDemonBuff].up and not buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Inertia] and buff[classtable.InertiaTriggerBuff].up and (not cooldown[classtable.Felblade].ready or targets >1) and buff[classtable.MetamorphosisBuff].up and cooldown[classtable.Metamorphosis].ready and cooldown[classtable.EssenceBreak].ready and not buff[classtable.InnerDemonBuff].up and not buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (buff[classtable.MetamorphosisBuff].up and (not talents[classtable.Inertia] or buff[classtable.InertiaBuff].up) and not buff[classtable.InnerDemonBuff].up and not buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and timeInCombat >4 and buff[classtable.MetamorphosisBuff].up and (not talents[classtable.Inertia] or not buff[classtable.InertiaTriggerBuff].up) and talents[classtable.EssenceBreak] and not buff[classtable.InnerDemonBuff].up and (not buff[classtable.InitiativeBuff].up or gcd <0.1) and not cooldown[classtable.BladeDance].ready) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (talents[classtable.Inertia] and buff[classtable.InertiaTriggerBuff].up and (MaxDps.ActiveHeroTree == 'felscarred') and not debuff[classtable.EssenceBreakDeBuff].up and talents[classtable.EssenceBreak] and not cooldown[classtable.Metamorphosis].ready and targets <= 2 and not cooldown[classtable.SigilofFlame].ready) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and ((not buff[classtable.InnerDemonBuff].up or false) and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and ((buff[classtable.InnerDemonBuff].up or buff[classtable.MetamorphosisBuff].up) and (cooldown[classtable.Metamorphosis].ready or not talents[classtable.EssenceBreak] and not cooldown[classtable.BladeDance].ready)) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and ((MaxDps.ActiveHeroTree == 'felscarred') and buff[classtable.MetamorphosisBuff].up and not talents[classtable.RestlessHunter]) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and ((MaxDps.ActiveHeroTree == 'felscarred') and buff[classtable.MetamorphosisBuff].up and (not talents[classtable.EssenceBreak] or buff[classtable.InnerDemonBuff].up)) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.AFireInside] and talents[classtable.BurningWound] and not buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (Fury <40 and not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InertiaTriggerBuff].up and cooldown[classtable.Metamorphosis].ready) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (buff[classtable.MetamorphosisBuff].up and not buff[classtable.InnerDemonBuff].up and not buff[classtable.MetamorphosisBuff].up and not cooldown[classtable.BladeDance].ready) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not buff[classtable.MetamorphosisBuff].up or not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up and (not cooldown[classtable.BladeDance].ready or talents[classtable.EssenceBreak] and cooldown[classtable.EssenceBreak].ready) and (not talents[classtable.AFireInside] or cooldown[classtable.ImmolationAura].charges == 0)) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.AbyssalGaze, 'AbyssalGaze')) and (not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up) and cooldown[classtable.AbyssalGaze].ready then
        if not setSpell then setSpell = classtable.AbyssalGaze end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
    opened = true
end


local function ClearCDs()
    MaxDps:GlowCooldown(classtable.Disrupt, false)
    MaxDps:GlowCooldown(classtable.SigilofSpite, false)
    MaxDps:GlowCooldown(classtable.VengefulRetreat, false)
    MaxDps:GlowCooldown(classtable.FelRush, false)
    MaxDps:GlowCooldown(classtable.Metamorphosis, false)
    MaxDps:GlowCooldown(classtable.mad_queens_mandate, false)
    MaxDps:GlowCooldown(classtable.treacherous_transmitter, false)
    MaxDps:GlowCooldown(classtable.skardyns_grace, false)
    MaxDps:GlowCooldown(classtable.house_of_cards, false)
    MaxDps:GlowCooldown(classtable.signet_of_the_priory, false)
    MaxDps:GlowCooldown(classtable.junkmaestros_mega_magnet, false)
    MaxDps:GlowCooldown(classtable.geargrinders_spare_keys, false)
    MaxDps:GlowCooldown(classtable.grim_codex, false)
    MaxDps:GlowCooldown(classtable.ravenous_honey_buzzer, false)
    MaxDps:GlowCooldown(classtable.trinket1, false)
    MaxDps:GlowCooldown(classtable.trinket2, false)
    MaxDps:GlowCooldown(classtable.TheHunt, false)
end

function Havoc:callaction()
    if (MaxDps:CheckSpellUsable(classtable.Disrupt, 'Disrupt')) and cooldown[classtable.Disrupt].ready then
        MaxDps:GlowCooldown(classtable.Disrupt, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    fury_gen = (talents[classtable.DemonBlades] and talents[classtable.DemonBlades] or 0)*(1%(2.6 * SpellHaste)*((talents[classtable.Demonsurge] and buff[classtable.MetamorphosisBuff].upMath or 0)*3 + 12))+buff[classtable.ImmolationAuraBuff].count * 6+buff[classtable.TacticalRetreatBuff].upMath * 10
    tier33_4piece = (buff[classtable.InitiativeBuff].up or not talents[classtable.Initiative]) and (buff[classtable.NecessarySacrificeBuff].up or not (MaxDps.tier and MaxDps.tier[33].count >= 4))
    double_on_use = not MaxDps:CheckEquipped('SignetofthePriory') and not MaxDps:CheckEquipped('HouseofCards') or (MaxDps:CheckTrinketNames('HouseofCards') or MaxDps:CheckTrinketNames('SignetofthePriory')) and MaxDps:CheckTrinketCooldown('13') >20 or (MaxDps:CheckTrinketNames('HouseofCards') or MaxDps:CheckTrinketNames('SignetofthePriory')) and MaxDps:CheckTrinketCooldown('14') >20
    if ((MaxDps.ActiveHeroTree == 'aldrachireaver')) then
        Havoc:ar()
    end
    if (not (MaxDps.ActiveHeroTree == 'aldrachireaver')) then
        Havoc:fs()
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
    classtable.DeathSweep = 210152
    classtable.Annihilation = 201427
    if buff[classtable.ImmolationAuraBuff].up then
        classtable.ImmolationAura = 427917
    else
        classtable.ImmolationAura = 258920
    end
    --for spellId in pairs(MaxDps.Flags) do
    --    self.Flags[spellId] = false
    --    self:ClearGlowIndependent(spellId, spellId)
    --end
    classtable.MetamorphosisBuff = 162264
    classtable.ImmolationAuraBuff = 258920
    classtable.TacticalRetreatBuff = 389890
    classtable.InitiativeBuff = 391215
    classtable.NecessarySacrificeBuff = 1217055
    classtable.RendingStrikeBuff = 442442
    classtable.GlaiveFlurryBuff = 442435
    classtable.FelBarrageBuff = 258925
    classtable.ThrilloftheFightDamageBuff = 442688
    classtable.ArtoftheGlaiveBuff = 444661
    classtable.UnboundChaosBuff = 347462
    classtable.InertiaTriggerBuff = 347462
    classtable.InertiaBuff = 427641
    classtable.OutofRangeBuff = 0
    classtable.InnerDemonBuff = 337313
    classtable.ReaversGlaiveBuff = 0
    classtable.DemonsurgeBuff = 452416
    classtable.ChaosTheoryBuff = 390195
    classtable.DemonsurgeDeathSweepBuff = 0
    classtable.DemonsurgeAnnihilationBuff = 0
    classtable.DemonsurgeSigilofDoomBuff = 0
    classtable.CycleofHatredBuff = 1214887
    classtable.StudentofSufferingBuff = 453239
    classtable.DemonsurgeAbyssalGazeBuff = 0
    classtable.DemonsurgeConsumingFireBuff = 0
    classtable.BurningWoundDeBuff = 391189
    classtable.EssenceBreakDeBuff = 320338
    classtable.ReaversMarkDeBuff = 442624
    classtable.DeathSweep = 210152
    classtable.Annihilation = 201427
    classtable.ReaversGlaive = 442294
    classtable.SigilofDoom = 452490
    classtable.AbyssalGaze = 452497

    local function debugg()
        talents[classtable.ShatteredDestiny] = 1
        talents[classtable.EssenceBreak] = 1
        talents[classtable.ReaversMark] = 1
        talents[classtable.Ragefire] = 1
        talents[classtable.FelBarrage] = 1
        talents[classtable.Initiative] = 1
        talents[classtable.Inertia] = 1
        talents[classtable.DemonBlades] = 1
        talents[classtable.LooksCanKill] = 1
        talents[classtable.AFireInside] = 1
        talents[classtable.BurningWound] = 1
        talents[classtable.FuriousThrows] = 1
        talents[classtable.ScreamingBrutality] = 1
        talents[classtable.CycleofHatred] = 1
        talents[classtable.ChaoticTransformation] = 1
        talents[classtable.RestlessHunter] = 1
        talents[classtable.Soulscar] = 1
        talents[classtable.UnboundChaos] = 1
        talents[classtable.InnerDemon] = 1
        talents[classtable.StudentofSuffering] = 1
        talents[classtable.IsolatedPrey] = 1
        talents[classtable.Flamebound] = 1
    end


    --if MaxDps.db.global.debugMode then
    --   debugg()
    --end

    setSpell = nil
    ClearCDs()

    Havoc:precombat()

    Havoc:callaction()
    if setSpell then return setSpell end
end
