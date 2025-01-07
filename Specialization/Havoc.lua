local _, addonTable = ...
local DemonHunter = addonTable.DemonHunter
local MaxDps = _G.MaxDps
if not MaxDps then return end
local setSpell

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

local trinket1_steroids
local trinket2_steroids
local rg_ds = 0
local rg_inc
local fel_barrage
local special_trinket
local generator_up
local fury_gen
local gcd_drain

local function GetNumSoulFragments()
    local auraData = UnitAuraByName('player','Soul Fragments')
    if auraData and auraData.applications then
        return auraData.applications
    end
    return 0
end

function Havoc:precombat()
    rg_ds = 0
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and cooldown[classtable.SigilofFlame].ready and not UnitAffectingCombat('player') then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (not buff[classtable.ImmolationAuraBuff].up) and cooldown[classtable.ImmolationAura].ready and not UnitAffectingCombat('player') then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
end
function Havoc:cooldown()
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (( ( cooldown[classtable.EyeBeam].remains >= 20 and ( not talents[classtable.EssenceBreak] or debuff[classtable.EssenceBreakDeBuff].up ) and not buff[classtable.FelBarrageBuff].up and ( math.huge >40 or ( targets >8 or not talents[classtable.FelBarrage] ) and targets >2 ) or not talents[classtable.ChaoticTransformation] or MaxDps:boss() and ttd <30 ) and not buff[classtable.InnerDemonBuff].up and ( not talents[classtable.RestlessHunter] and cooldown[classtable.BladeDance].remains >gcd * 3 or (MaxDps.spellHistory[1] == classtable.DeathSweep) ) ) and not talents[classtable.Inertia] and not talents[classtable.EssenceBreak] and ( (MaxDps.ActiveHeroTree == 'aldrachireaver') or not buff[classtable.DemonsurgeDeathSweepBuff].up ) and timeInCombat >15) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (( cooldown[classtable.BladeDance].ready==false and ( ( (MaxDps.spellHistory[1] == classtable.DeathSweep) or (MaxDps.spellHistory[2] == classtable.DeathSweep) or (MaxDps.spellHistory[3] == classtable.DeathSweep) or buff[classtable.MetamorphosisBuff].up and buff[classtable.MetamorphosisBuff].remains <gcd ) and cooldown[classtable.EyeBeam].ready==false and ( not talents[classtable.EssenceBreak] or debuff[classtable.EssenceBreakDeBuff].up or talents[classtable.ShatteredDestiny] or (MaxDps.ActiveHeroTree == 'felscarred') ) and not buff[classtable.FelBarrageBuff].up and ( math.huge >40 or ( targets >8 or not talents[classtable.FelBarrage] ) and targets >2 ) or not talents[classtable.ChaoticTransformation] or MaxDps:boss() and ttd <30 ) and ( not buff[classtable.InnerDemonBuff].up and ( not buff[classtable.RendingStrikeBuff].up or not talents[classtable.RestlessHunter] or (MaxDps.spellHistory[1] == classtable.DeathSweep) ) ) ) and ( talents[classtable.Inertia] or talents[classtable.EssenceBreak] ) and ( (MaxDps.ActiveHeroTree == 'aldrachireaver') or ( not buff[classtable.DemonsurgeDeathSweepBuff].up or buff[classtable.MetamorphosisBuff].remains <gcd ) and ( not buff[classtable.DemonsurgeAnnihilationBuff].up ) ) and timeInCombat >15) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (not debuff[classtable.EssenceBreakDeBuff].up and ( targets >= 1 + 1 or math.huge >90 ) and ( debuff[classtable.ReaversMarkDeBuff].up or not (MaxDps.ActiveHeroTree == 'aldrachireaver') ) and not buff[classtable.ReaversGlaiveBuff].up and ( buff[classtable.MetamorphosisBuff].remains >5 or not buff[classtable.MetamorphosisBuff].up ) and ( not talents[classtable.Initiative] or buff[classtable.InitiativeBuff].up or timeInCombat >5 ) and timeInCombat >5) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (not debuff[classtable.EssenceBreakDeBuff].up and ( debuff[classtable.ReaversMarkDeBuff].remains >= 2 - (talents[classtable.QuickenedSigils] and talents[classtable.QuickenedSigils] or 0) or not (MaxDps.ActiveHeroTree == 'aldrachireaver') ) and cooldown[classtable.BladeDance].ready==false and timeInCombat >15) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
end
function Havoc:fel_barrage()
    generator_up = cooldown[classtable.Felblade].remains <gcd or cooldown[classtable.SigilofFlame].remains <gcd
    fury_gen = (talents[classtable.DemonBlades] and talents[classtable.DemonBlades] or 0) * ( 1 % ( 2.6 * SpellHaste ) * 12 * ( ( (MaxDps.ActiveHeroTree == 'felscarred') and buff[classtable.MetamorphosisBuff].up and 1 or 0) * 0.33 + 1 ) ) + buff[classtable.ImmolationAuraBuff].count * 6 + buff[classtable.TacticalRetreatBuff].duration * 10
    gcd_drain = gcd * 32
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.InnerDemonBuff].up) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not buff[classtable.FelBarrageBuff].up and ( targets >1 and (targets >1) or math.huge >40 )) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.AbyssalGaze, 'AbyssalGaze')) and (not buff[classtable.FelBarrageBuff].up and ( targets >1 and (targets >1) or math.huge >40 )) and cooldown[classtable.AbyssalGaze].ready then
        if not setSpell then setSpell = classtable.AbyssalGaze end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (not buff[classtable.FelBarrageBuff].up and buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (not buff[classtable.FelBarrageBuff].up) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (not buff[classtable.UnboundChaosBuff].up and ( targets >2 or buff[classtable.FelBarrageBuff].up ) and ( not talents[classtable.Inertia] or cooldown[classtable.EyeBeam].remains >cooldown[classtable.ImmolationAura].duration + 3 )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.GlaiveTempest, 'GlaiveTempest')) and (not buff[classtable.FelBarrageBuff].up and targets >1) and cooldown[classtable.GlaiveTempest].ready then
        if not setSpell then setSpell = classtable.GlaiveTempest end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (not buff[classtable.FelBarrageBuff].up) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelBarrage, 'FelBarrage') and talents[classtable.FelBarrage]) and (Fury >100 and ( math.huge >90 or math.huge <gcd or targets >4 and targets >2 )) and cooldown[classtable.FelBarrage].ready then
        if not setSpell then setSpell = classtable.FelBarrage end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and Fury >20 and buff[classtable.FelBarrageBuff].up) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (FuryDeficit >40 and buff[classtable.FelBarrageBuff].up and ( not talents[classtable.StudentofSuffering] or cooldown[classtable.EyeBeam].remains >30 )) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (FuryDeficit >40 and buff[classtable.FelBarrageBuff].up) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (buff[classtable.FelBarrageBuff].up and FuryDeficit >40) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (Fury - gcd_drain - 35 >0 and ( buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18 )) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.GlaiveTempest, 'GlaiveTempest')) and (Fury - gcd_drain - 30 >0 and ( buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18 )) and cooldown[classtable.GlaiveTempest].ready then
        if not setSpell then setSpell = classtable.GlaiveTempest end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (Fury - gcd_drain - 35 >0 and ( buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18 )) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (Fury >40 and ( targets >= 1 + 1 or math.huge >80 )) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (Fury - gcd_drain - 40 >20 and ( buff[classtable.FelBarrageBuff].remains <3 or generator_up or Fury >80 or fury_gen >18 )) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (Fury - gcd_drain - 40 >20 and ( cooldown[classtable.FelBarrage].ready==false and cooldown[classtable.FelBarrage].remains <10 and Fury >100 or buff[classtable.FelBarrageBuff].up and ( buff[classtable.FelBarrageBuff].remains * fury_gen - buff[classtable.FelBarrageBuff].remains * 32 ) >0 )) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and not talents[classtable.DemonBlades] and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
end
function Havoc:meta()
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (buff[classtable.MetamorphosisBuff].remains <gcd or ( (MaxDps.ActiveHeroTree == 'felscarred') and talents[classtable.Chaostheory] and talents[classtable.EssenceBreak] and ( cooldown[classtable.Metamorphosis].ready or (MaxDps.spellHistory[1] == classtable.Metamorphosis) ) and buff[classtable.DemonsurgeBuff].count == 0 ) and ( not talents[classtable.RestlessHunter] or cooldown[classtable.Metamorphosis].ready==false and cooldown[classtable.EssenceBreak].ready==false )) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and cooldown[classtable.Metamorphosis].ready==false and cooldown[classtable.EyeBeam].remains) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.MetamorphosisBuff].remains <gcd or debuff[classtable.EssenceBreakDeBuff].remains and debuff[classtable.EssenceBreakDeBuff].remains <0.5 or talents[classtable.RestlessHunter] and buff[classtable.DemonsurgeAnnihilationBuff].up and cooldown[classtable.EssenceBreak].ready and cooldown[classtable.Metamorphosis].ready) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (( (MaxDps.ActiveHeroTree == 'felscarred') and buff[classtable.DemonsurgeAnnihilationBuff].up and ( talents[classtable.RestlessHunter] or not talents[classtable.Chaostheory] or buff[classtable.ChaostheoryBuff].up ) ) and ( cooldown[classtable.EyeBeam].remains <gcd * 3 and cooldown[classtable.BladeDance].ready==false or cooldown[classtable.Metamorphosis].remains <gcd * 3 )) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and cooldown[classtable.Metamorphosis].ready==false and ( not (MaxDps.ActiveHeroTree == 'felscarred') or cooldown[classtable.EyeBeam].ready==false )) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and cooldown[classtable.BladeDance].remains <gcd * 3 and ( not (MaxDps.ActiveHeroTree == 'felscarred') or cooldown[classtable.EyeBeam].ready==false ) and cooldown[classtable.Metamorphosis].remains) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Momentum] and buff[classtable.MomentumBuff].remains <gcd * 2) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (cooldown[classtable.ImmolationAura].charges == 2 and targets >1 and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (( buff[classtable.InnerDemonBuff].up ) and ( cooldown[classtable.EyeBeam].remains <gcd * 3 and cooldown[classtable.BladeDance].ready==false or cooldown[classtable.Metamorphosis].remains <gcd * 3 )) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (Fury >20 and ( cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd * 2 ) and ( not buff[classtable.UnboundChaosBuff].up or buff[classtable.InertiaBuff].up or not talents[classtable.Inertia] ) and buff.out_of_range.remains <gcd and ( not talents[classtable.ShatteredDestiny] or cooldown[classtable.EyeBeam].remains >4 ) and ( not (MaxDps.ActiveHeroTree == 'felscarred') or targets >1 or cooldown[classtable.Metamorphosis].remains >5 and cooldown[classtable.EyeBeam].ready==false ) or ttd <10) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (cooldown[classtable.BladeDance].remains and talents[classtable.Inertia] and buff[classtable.MetamorphosisBuff].remains >10 and (MaxDps.ActiveHeroTree == 'felscarred') and cooldown[classtable.ImmolationAura].fullRecharge <gcd * 2 and not buff[classtable.UnboundChaosBuff].up and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (Fury >20 and ( cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd * 2 ) and ( not buff[classtable.UnboundChaosBuff].up or buff[classtable.InertiaBuff].up or not talents[classtable.Inertia] ) and buff.out_of_range.remains <gcd and ( not talents[classtable.ShatteredDestiny] or cooldown[classtable.EyeBeam].remains >4 ) or ttd <10) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (cooldown[classtable.BladeDance].remains and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (buff[classtable.DemonsurgeBuff].up and buff[classtable.DemonsurgeBuff].remains <gcd * 3 and buff[classtable.DemonsurgeConsumingFireBuff].up) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (not debuff[classtable.EssenceBreakDeBuff].up and cooldown[classtable.BladeDance].remains >gcd + 0.5 and not buff[classtable.UnboundChaosBuff].up and talents[classtable.Inertia] and not buff[classtable.InertiaBuff].up and cooldown[classtable.ImmolationAura].fullRecharge + 3 <cooldown[classtable.EyeBeam].remains and buff[classtable.MetamorphosisBuff].remains >5) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (not talents[classtable.CycleofHatred]) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and (( debuff[classtable.EssenceBreakDeBuff].up or cooldown[classtable.EssenceBreak].remains >= gcd * 2 or ( cooldown[classtable.Metamorphosis].ready and cooldown[classtable.EyeBeam].ready==false and not talents[classtable.RestlessHunter] ) or not talents[classtable.EssenceBreak] or ( (MaxDps.spellHistory[1] == classtable.Metamorphosis) and talents[classtable.ChaoticTransformation] ) ) and talents[classtable.CycleofHatred]) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.AbyssalGaze, 'AbyssalGaze')) and (not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up) and cooldown[classtable.AbyssalGaze].ready then
        if not setSpell then setSpell = classtable.AbyssalGaze end
    end
    if (MaxDps:CheckSpellUsable(classtable.GlaiveTempest, 'GlaiveTempest')) and (not debuff[classtable.EssenceBreakDeBuff].up and ( cooldown[classtable.BladeDance].remains >gcd * 2 or Fury >60 ) and ( targets >= 1 + 1 or math.huge >10 )) and cooldown[classtable.GlaiveTempest].ready then
        if not setSpell then setSpell = classtable.GlaiveTempest end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (targets >2 and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (talents[classtable.Soulscar] and talents[classtable.FuriousThrows] and targets >1 and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (cooldown[classtable.BladeDance].remains or Fury >60 or SoulFragments >0 or buff[classtable.MetamorphosisBuff].remains <5 and cooldown[classtable.Felblade].ready) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (buff[classtable.MetamorphosisBuff].remains >5 and true) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (( true or FuryDeficit >40 )) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (not debuff[classtable.EssenceBreakDeBuff].up and true) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (true and cooldown[classtable.ImmolationAura].duration <( cooldown[classtable.EyeBeam].remains <buff[classtable.MetamorphosisBuff].remains and 1 or 0) and ( targets >= 1 + 1 or math.huge >cooldown[classtable.ImmolationAura].fullRecharge )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Momentum]) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.ThrowGlaive].duration <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and ( cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.ThrowGlaive].charges >1.01 ) and true and targets >1) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.FelRush].duration <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and ( cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.FelRush].charges >1.01 ) and true and targets >1) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and not talents[classtable.DemonBlades] and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
end
function Havoc:opener()
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and ( not buff[classtable.InitiativeBuff].up or talents[classtable.RestlessHunter] and buff[classtable.InitiativeBuff].remains <= 0.1 ) and timeInCombat >4 and ( ( talents[classtable.EssenceBreak] and not talents[classtable.RestlessHunter] and cooldown[classtable.Metamorphosis].ready==false and cooldown[classtable.EyeBeam].ready==false ) or ( talents[classtable.EssenceBreak] and talents[classtable.RestlessHunter] and ( not buff[classtable.DemonsurgeAnnihilationBuff].up or (MaxDps.spellHistory[1] == classtable.DeathSweep) ) and ( cooldown[classtable.EyeBeam].ready==false or debuff[classtable.EssenceBreakDeBuff].up ) and buff[classtable.MetamorphosisBuff].up ) or not talents[classtable.EssenceBreak] )) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Inertia] and buff[classtable.InertiaTriggerBuff].up and talents[classtable.EssenceBreak] and cooldown[classtable.Metamorphosis].ready==false and buff[classtable.DemonsurgeBuff].count == 4 and buff[classtable.DemonsurgeAbyssalGazeBuff].up) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.DemonsurgeAnnihilationBuff].up and talents[classtable.RestlessHunter]) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (not (MaxDps.ActiveHeroTree == 'felscarred') and buff[classtable.InnerDemonBuff].up and not talents[classtable.ShatteredDestiny]) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.InertiaTriggerBuff].up and talents[classtable.Inertia] and talents[classtable.RestlessHunter] and cooldown[classtable.EssenceBreak].ready and cooldown[classtable.Metamorphosis].ready and not buff[classtable.DemonsurgeAnnihilationBuff].up and buff[classtable.MetamorphosisBuff].up) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Momentum] and buff[classtable.MomentumBuff].remains <6 and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Inertia] and buff[classtable.UnboundChaosBuff].up and talents[classtable.AFireInside] and ( not buff[classtable.InertiaBuff].up and buff[classtable.MetamorphosisBuff].up and not (MaxDps.ActiveHeroTree == 'felscarred') or (MaxDps.ActiveHeroTree == 'felscarred') and ( not buff[classtable.MetamorphosisBuff].up and cooldown[classtable.FelRush].charges >1 or (MaxDps.spellHistory[1] == classtable.EyeBeam) or buff[classtable.DemonsurgeBuff].count >= 5 or cooldown[classtable.FelRush].charges == 2 and not buff[classtable.UnboundChaosBuff].up ) ) and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Inertia] and buff[classtable.UnboundChaosBuff].up and not talents[classtable.AFireInside] and buff[classtable.MetamorphosisBuff].up and cooldown[classtable.Metamorphosis].remains) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Inertia] and buff[classtable.UnboundChaosBuff].up and (MaxDps.spellHistory[1] == classtable.SigilofDoom) and ( targets >1 or talents[classtable.AFireInside] )) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.TheHunt, 'TheHunt')) and (( buff[classtable.MetamorphosisBuff].up and (MaxDps.ActiveHeroTree == 'aldrachireaver') and talents[classtable.ShatteredDestiny] or not talents[classtable.ShatteredDestiny] and (MaxDps.ActiveHeroTree == 'aldrachireaver') or (MaxDps.ActiveHeroTree == 'felscarred') ) and ( not talents[classtable.Initiative] or buff[classtable.InitiativeBuff].up or timeInCombat >5 )) and cooldown[classtable.TheHunt].ready then
        MaxDps:GlowCooldown(classtable.TheHunt, cooldown[classtable.TheHunt].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and ((MaxDps.ActiveHeroTree == 'felscarred') and talents[classtable.Chaostheory] and buff[classtable.MetamorphosisBuff].up and buff[classtable.DemonsurgeBuff].count == 0 and not talents[classtable.RestlessHunter]) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and ((MaxDps.ActiveHeroTree == 'felscarred') and buff[classtable.DemonsurgeAnnihilationBuff].up and ( not talents[classtable.EssenceBreak] or buff[classtable.InnerDemonBuff].up )) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (Fury <40 and ( not talents[classtable.AFireInside] or (MaxDps.ActiveHeroTree == 'aldrachireaver') )) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and (not debuff[classtable.ReaversMarkDeBuff].up and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.AFireInside] and ( talents[classtable.Inertia] or talents[classtable.Ragefire] or talents[classtable.BurningWound] ) and not buff[classtable.MetamorphosisBuff].up and ( not buff[classtable.UnboundChaosBuff].up or (MaxDps.ActiveHeroTree == 'felscarred') )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.Inertia] and not buff[classtable.UnboundChaosBuff].up and buff[classtable.MetamorphosisBuff].up and not debuff[classtable.EssenceBreakDeBuff].up and cooldown[classtable.BladeDance].ready==false and ( not buff[classtable.InnerDemonBuff].up or (MaxDps.ActiveHeroTree == 'felscarred') and not buff[classtable.DemonsurgeAnnihilationBuff].up ) and buff[classtable.DemonsurgeBuff].count <5) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (buff[classtable.GlaiveFlurryBuff].up and not talents[classtable.ShatteredDestiny]) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (buff[classtable.RendingStrikeBuff].up and not talents[classtable.ShatteredDestiny]) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.Metamorphosis, 'Metamorphosis')) and (buff[classtable.MetamorphosisBuff].up and cooldown[classtable.BladeDance].remains >gcd * 2 and not buff[classtable.InnerDemonBuff].up and ( not (MaxDps.ActiveHeroTree == 'felscarred') and ( not talents[classtable.RestlessHunter] or (MaxDps.spellHistory[1] == classtable.DeathSweep) ) or buff[classtable.DemonsurgeBuff].count == 2 ) and ( cooldown[classtable.EssenceBreak].ready==false or (MaxDps.ActiveHeroTree == 'felscarred') or talents[classtable.ShatteredDestiny] or not talents[classtable.EssenceBreak] )) and cooldown[classtable.Metamorphosis].ready then
        MaxDps:GlowCooldown(classtable.Metamorphosis, cooldown[classtable.Metamorphosis].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and ((MaxDps.ActiveHeroTree == 'felscarred') or debuff[classtable.ReaversMarkDeBuff].up and ( not talents[classtable.CycleofHatred] or cooldown[classtable.EyeBeam].ready==false and cooldown[classtable.Metamorphosis].ready==false )) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofDoom, 'SigilofDoom')) and (not buff[classtable.InnerDemonBuff].up and not debuff[classtable.EssenceBreakDeBuff].up and cooldown[classtable.BladeDance].remains) and cooldown[classtable.SigilofDoom].ready then
        if not setSpell then setSpell = classtable.SigilofDoom end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not buff[classtable.MetamorphosisBuff].up or not debuff[classtable.EssenceBreakDeBuff].up and not buff[classtable.InnerDemonBuff].up and ( cooldown[classtable.BladeDance].ready==false or talents[classtable.EssenceBreak] and cooldown[classtable.EssenceBreak].ready )) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.AbyssalGaze, 'AbyssalGaze')) and (not debuff[classtable.EssenceBreakDeBuff].up and cooldown[classtable.BladeDance].ready==false and not buff[classtable.InnerDemonBuff].up) and cooldown[classtable.AbyssalGaze].ready then
        if not setSpell then setSpell = classtable.AbyssalGaze end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (( cooldown[classtable.BladeDance].remains <gcd and not (MaxDps.ActiveHeroTree == 'felscarred') and not talents[classtable.ShatteredDestiny] and buff[classtable.MetamorphosisBuff].up or ( cooldown[classtable.EyeBeam].ready==false or not buff[classtable.DemonsurgeAbyssalGazeBuff].up and ( buff[classtable.DemonsurgeBuff].count == 5 or buff[classtable.DemonsurgeBuff].count == 4 and not talents[classtable.InnerDemon] ) ) and cooldown[classtable.Metamorphosis].ready==false ) and ( not (MaxDps.ActiveHeroTree == 'felscarred') or not buff[classtable.InnerDemonBuff].up )) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.EssenceBreak, 'EssenceBreak') and talents[classtable.EssenceBreak]) and (talents[classtable.RestlessHunter] and buff[classtable.MetamorphosisBuff].up and not buff[classtable.InnerDemonBuff].up and ( not (MaxDps.ActiveHeroTree == 'felscarred') or not buff[classtable.DemonsurgeAnnihilationBuff].up )) and cooldown[classtable.EssenceBreak].ready then
        if not setSpell then setSpell = classtable.EssenceBreak end
    end
    if (MaxDps:CheckSpellUsable(classtable.DeathSweep, 'DeathSweep')) and cooldown[classtable.DeathSweep].ready then
        if not setSpell then setSpell = classtable.DeathSweep end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and not talents[classtable.DemonBlades] and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
end


local function ClearCDs()
    MaxDps:GlowCooldown(classtable.Disrupt, false)
    MaxDps:GlowCooldown(classtable.SigilofSpite, false)
    MaxDps:GlowCooldown(classtable.Metamorphosis, false)
    MaxDps:GlowCooldown(classtable.TheHunt, false)
end

function Havoc:callaction()
    rg_inc = not buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up and cooldown[classtable.BladeDance].ready and gcd == 0 or rg_inc and (MaxDps.spellHistory[1] == classtable.DeathSweep)
    fel_barrage = talents[classtable.FelBarrage] and ( cooldown[classtable.FelBarrage].remains <gcd * 7 and ( targets >= 1 + 1 or math.huge <gcd * 7 or math.huge >90 ) and ( cooldown[classtable.Metamorphosis].ready==false or targets >2 ) or buff[classtable.FelBarrageBuff].up ) and not ( targets == 1 and (targets <2) )
    if (MaxDps:CheckSpellUsable(classtable.Disrupt, 'Disrupt')) and cooldown[classtable.Disrupt].ready then
        MaxDps:GlowCooldown(classtable.Disrupt, ( select(8,UnitCastingInfo('target')) ~= nil and not select(8,UnitCastingInfo('target')) or select(7,UnitChannelInfo('target')) ~= nil and not select(7,UnitChannelInfo('target'))) )
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and buff[classtable.UnboundChaosBuff].remains <gcd * 2 and ( cooldown[classtable.ImmolationAura].charges >0 or cooldown[classtable.ImmolationAura].duration <5 ) and cooldown[classtable.Metamorphosis].remains >10) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up and ( rg_ds == 2 or targets >2 )) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.Annihilation, 'Annihilation')) and (buff[classtable.RendingStrikeBuff].up and buff[classtable.GlaiveFlurryBuff].up and ( rg_ds == 2 or targets >2 )) and cooldown[classtable.Annihilation].ready then
        if not setSpell then setSpell = classtable.Annihilation end
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and (not buff[classtable.GlaiveFlurryBuff].up and not buff[classtable.RendingStrikeBuff].up and buff[classtable.ThrilloftheFightDamageBuff].remains <gcd * 4 + ( rg_ds == 2 ) + ( cooldown[classtable.TheHunt].remains <gcd * 3 ) * 3 + ( cooldown[classtable.EyeBeam].remains <gcd * 3 and talents[classtable.ShatteredDestiny] ) * 3 and ( rg_ds == 0 or rg_ds == 1 and cooldown[classtable.BladeDance].ready or rg_ds == 2 and cooldown[classtable.BladeDance].ready==false ) and ( buff[classtable.ThrilloftheFightDamageBuff].up or not (MaxDps.spellHistory[1] == classtable.DeathSweep) or not rg_inc ) and targets <3 and not (MaxDps.spellHistoryTime and MaxDps.spellHistoryTime[classtable.ReaversGlaive] and MaxDps.spellHistoryTime[classtable.ReaversGlaive].last_used or 0) <5 and not debuff[classtable.EssenceBreakDeBuff].up or ttd <10) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.ReaversGlaive, 'ReaversGlaive')) and (not buff[classtable.GlaiveFlurryBuff].up and not buff[classtable.RendingStrikeBuff].up and buff[classtable.ThrilloftheFightDamageBuff].remains <4 and ( buff[classtable.ThrilloftheFightDamageBuff].up or not (MaxDps.spellHistory[1] == classtable.DeathSweep) or not rg_inc ) and targets >2 or ttd <10) and cooldown[classtable.ReaversGlaive].ready then
        if not setSpell then setSpell = classtable.ReaversGlaive end
    end
    Havoc:cooldown()
    if (( cooldown[classtable.EyeBeam].ready or cooldown[classtable.Metamorphosis].ready or cooldown[classtable.EssenceBreak].ready ) and timeInCombat <15 and ( math.huge >40 ) and buff[classtable.DemonsurgeBuff].count <5) then
        Havoc:opener()
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofSpite, 'SigilofSpite')) and (not debuff[classtable.EssenceBreakDeBuff].up and debuff[classtable.ReaversMarkDeBuff].remains >= 2 - talents[classtable.QuickenedSigils]) and cooldown[classtable.SigilofSpite].ready then
        MaxDps:GlowCooldown(classtable.SigilofSpite, cooldown[classtable.SigilofSpite].ready)
    end
    if (fel_barrage and (targets >1)) then
        Havoc:fel_barrage()
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (targets >2 and talents[classtable.Ragefire] and not buff[classtable.UnboundChaosBuff].up and ( not talents[classtable.FelBarrage] or cooldown[classtable.FelBarrage].remains >cooldown[classtable.ImmolationAura].duration ) and not debuff[classtable.EssenceBreakDeBuff].up and cooldown[classtable.EyeBeam].remains >cooldown[classtable.ImmolationAura].duration + 5 and ( not buff[classtable.MetamorphosisBuff].up or buff[classtable.MetamorphosisBuff].remains >5 )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and ((MaxDps.ActiveHeroTree == 'felscarred') and cooldown[classtable.Metamorphosis].remains <10 and cooldown[classtable.EyeBeam].remains <10 and ( not buff[classtable.UnboundChaosBuff].up or cooldown[classtable.FelRush].charges == 0 or ( cooldown[classtable.EyeBeam].remains <cooldown[classtable.Metamorphosis].remains ) <5 ) and talents[classtable.AFireInside]) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (targets >2 and talents[classtable.Ragefire] and (targets >1) and targets <15 and targets >5 and not debuff[classtable.EssenceBreakDeBuff].up) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and targets >2 and ( not talents[classtable.Inertia] or cooldown[classtable.EyeBeam].remains + 2 >buff[classtable.UnboundChaosBuff].remains )) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.VengefulRetreat, 'VengefulRetreat')) and (talents[classtable.Initiative] and ( cooldown[classtable.EyeBeam].remains >15 and gcd <0.3 or gcd <0.2 and cooldown[classtable.EyeBeam].remains <= gcd and ( buff[classtable.UnboundChaosBuff].up or cooldown[classtable.ImmolationAura].duration >6 or not talents[classtable.Inertia] or talents[classtable.Momentum] ) and ( cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd * 2 and ( talents[classtable.Inertia] or talents[classtable.Momentum] or buff[classtable.MetamorphosisBuff].up ) ) ) and ( not talents[classtable.StudentofSuffering] or cooldown[classtable.SigilofFlame].ready==false ) and timeInCombat >10 and ( not trinket1_steroids and not trinket2_steroids or trinket1_steroids and ( MaxDps:CheckTrinketCooldown('1') <gcd * 3 or MaxDps:CheckTrinketCooldown('1') >20 ) or trinket2_steroids and ( MaxDps:CheckTrinketCooldown('2') <gcd * 3 or MaxDps:CheckTrinketCooldown('2') >20 or talents[classtable.ShatteredDestiny] ) ) and ( cooldown[classtable.Metamorphosis].ready==false or (MaxDps.ActiveHeroTree == 'aldrachireaver') ) and timeInCombat >20) and cooldown[classtable.VengefulRetreat].ready then
        MaxDps:GlowCooldown(classtable.VengefulRetreat, cooldown[classtable.VengefulRetreat].ready)
    end
    if (fel_barrage or not talents[classtable.DemonBlades] and talents[classtable.FelBarrage] and ( buff[classtable.FelBarrageBuff].up or cooldown[classtable.FelBarrage].ready ) and not buff[classtable.MetamorphosisBuff].up) then
        Havoc:fel_barrage()
    end
    if (buff[classtable.MetamorphosisBuff].up) then
        Havoc:meta()
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (buff[classtable.UnboundChaosBuff].up and talents[classtable.Inertia] and not buff[classtable.InertiaBuff].up and cooldown[classtable.BladeDance].remains <4 and cooldown[classtable.EyeBeam].remains >5 and ( cooldown[classtable.ImmolationAura].charges >0 or cooldown[classtable.ImmolationAura].duration + 2 <cooldown[classtable.EyeBeam].remains or cooldown[classtable.EyeBeam].remains >buff[classtable.UnboundChaosBuff].remains - 2 )) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (talents[classtable.Momentum] and cooldown[classtable.EyeBeam].remains <gcd * 2) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.AFireInside] and ( talents[classtable.UnboundChaos] or talents[classtable.BurningWound] ) and not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.ImmolationAura].fullRecharge <gcd * 2 and ( math.huge >cooldown[classtable.ImmolationAura].fullRecharge or targets >1 )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (targets >1 and not buff[classtable.UnboundChaosBuff].up and ( targets >= 1 + 1 or math.huge >cooldown[classtable.ImmolationAura].fullRecharge )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.Inertia] and not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.EyeBeam].remains <5 and ( targets >= 1 + 1 or math.huge >cooldown[classtable.ImmolationAura].fullRecharge and ( not talents[classtable.EssenceBreak] or cooldown[classtable.EssenceBreak].remains <5 ) ) and ( not trinket1_steroids and not trinket2_steroids or trinket1_steroids and ( MaxDps:CheckTrinketCooldown('1') <gcd * 3 or MaxDps:CheckTrinketCooldown('1') >20 ) or trinket2_steroids and ( MaxDps:CheckTrinketCooldown('2') <gcd * 3 or MaxDps:CheckTrinketCooldown('2') >20 ) )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (talents[classtable.Inertia] and not buff[classtable.InertiaBuff].up and ( not talents[classtable.UnboundChaos] or not buff[classtable.UnboundChaosBuff].up ) and cooldown[classtable.ImmolationAura].duration + 5 <cooldown[classtable.EyeBeam].remains and cooldown[classtable.BladeDance].ready==false and cooldown[classtable.BladeDance].remains <4 and ( targets >= 1 + 1 or math.huge >cooldown[classtable.ImmolationAura].fullRecharge ) and cooldown[classtable.ImmolationAura].charges >1.00) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (MaxDps:boss() and ttd <15 and cooldown[classtable.BladeDance].ready==false and ( talents[classtable.Inertia] or talents[classtable.Ragefire] )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (talents[classtable.StudentofSuffering] and cooldown[classtable.EyeBeam].remains <gcd and ( not talents[classtable.Inertia] or buff[classtable.InertiaTriggerBuff].up ) and ( cooldown[classtable.EssenceBreak].remains <gcd * 4 or not talents[classtable.EssenceBreak] ) and ( cooldown[classtable.Metamorphosis].remains >10 or cooldown[classtable.BladeDance].remains <gcd * 3 ) and ( not trinket1_steroids and not trinket2_steroids or trinket1_steroids and ( MaxDps:CheckTrinketCooldown('1') <gcd * 3 or MaxDps:CheckTrinketCooldown('1') >20 ) or trinket2_steroids and ( MaxDps:CheckTrinketCooldown('2') <gcd * 3 or MaxDps:CheckTrinketCooldown('2') >20 ) )) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (cooldown[classtable.Metamorphosis].ready and talents[classtable.ChaoticTransformation]) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (not talents[classtable.EssenceBreak] and ( not talents[classtable.ChaoticTransformation] or cooldown[classtable.Metamorphosis].remains <5 + 3 * (talents[classtable.ShatteredDestiny] and talents[classtable.ShatteredDestiny] or 0) or cooldown[classtable.Metamorphosis].remains >10 ) and ( targets >1 * 2 or math.huge >30 - (talents[classtable.CycleofHatred] and talents[classtable.CycleofHatred] or 0) * 13 ) and ( not talents[classtable.Initiative] or cooldown[classtable.VengefulRetreat].remains >5 or cooldown[classtable.VengefulRetreat].ready or talents[classtable.ShatteredDestiny] ) and ( not talents[classtable.StudentofSuffering] or cooldown[classtable.SigilofFlame].ready==false )) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.EyeBeam, 'EyeBeam')) and (talents[classtable.EssenceBreak] and ( cooldown[classtable.EssenceBreak].remains <gcd * 2 + 5 * (talents[classtable.ShatteredDestiny] and talents[classtable.ShatteredDestiny] or 0) or talents[classtable.ShatteredDestiny] and cooldown[classtable.EssenceBreak].remains >10 ) and ( cooldown[classtable.BladeDance].remains <7 or (targets >1) ) and ( not talents[classtable.Initiative] or cooldown[classtable.VengefulRetreat].remains >10 or not talents[classtable.Inertia] and not talents[classtable.Momentum] or (targets >1) ) and ( targets + 3 >= 1 + 1 or math.huge >30 - (talents[classtable.CycleofHatred] and talents[classtable.CycleofHatred] or 0) * 6 ) and ( not talents[classtable.Inertia] or buff[classtable.InertiaTriggerBuff].up or cooldown[classtable.ImmolationAura].charges == 0 and cooldown[classtable.ImmolationAura].duration >5 ) and ( not (targets >1) or targets >8 ) and ( not trinket1_steroids and not trinket2_steroids or trinket1_steroids and ( MaxDps:CheckTrinketCooldown('1') <gcd * 3 or MaxDps:CheckTrinketCooldown('1') >20 ) or trinket2_steroids and ( MaxDps:CheckTrinketCooldown('2') <gcd * 3 or MaxDps:CheckTrinketCooldown('2') >20 ) ) or ttd <10) and cooldown[classtable.EyeBeam].ready then
        if not setSpell then setSpell = classtable.EyeBeam end
    end
    if (MaxDps:CheckSpellUsable(classtable.BladeDance, 'BladeDance')) and (cooldown[classtable.EyeBeam].remains >= gcd * 3 and not buff[classtable.RendingStrikeBuff].up) and cooldown[classtable.BladeDance].ready then
        if not setSpell then setSpell = classtable.BladeDance end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (buff[classtable.RendingStrikeBuff].up) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (not buff[classtable.MetamorphosisBuff].up and FuryDeficit >40) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.GlaiveTempest, 'GlaiveTempest')) and (targets >= 1 + 1 or math.huge >10) and cooldown[classtable.GlaiveTempest].ready then
        if not setSpell then setSpell = classtable.GlaiveTempest end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (targets >3 and not talents[classtable.StudentofSuffering] or true and talents[classtable.ArtoftheGlaive]) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (debuff[classtable.EssenceBreakDeBuff].up or cooldown[classtable.EssenceBreak].remains >cooldown[classtable.EssenceBreak].duration - debuff[classtable.EssenceBreakDeBuff].duration) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.Felblade, 'Felblade')) and (( true or FuryDeficit >40 )) and cooldown[classtable.Felblade].ready then
        if not setSpell then setSpell = classtable.Felblade end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (targets >1 and talents[classtable.FuriousThrows]) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.ChaosStrike, 'ChaosStrike')) and (cooldown[classtable.EyeBeam].remains >gcd * 2 or Fury >80 or talents[classtable.CycleofHatred]) and cooldown[classtable.ChaosStrike].ready then
        if not setSpell then setSpell = classtable.ChaosStrike end
    end
    if (MaxDps:CheckSpellUsable(classtable.ImmolationAura, 'ImmolationAura')) and (not talents[classtable.Inertia] and ( math.huge >cooldown[classtable.ImmolationAura].fullRecharge or targets >1 and targets >2 )) and cooldown[classtable.ImmolationAura].ready then
        if not setSpell then setSpell = classtable.ImmolationAura end
    end
    if (MaxDps:CheckSpellUsable(classtable.SigilofFlame, 'SigilofFlame')) and (true and not debuff[classtable.EssenceBreakDeBuff].up and not talents[classtable.StudentofSuffering] and ( not talents[classtable.FelBarrage] or cooldown[classtable.FelBarrage].remains >25 or ( targets == 1 and (targets <2) ) )) and cooldown[classtable.SigilofFlame].ready then
        if not setSpell then setSpell = classtable.SigilofFlame end
    end
    if (MaxDps:CheckSpellUsable(classtable.DemonsBite, 'DemonsBite')) and not talents[classtable.DemonBlades] and cooldown[classtable.DemonsBite].ready then
        if not setSpell then setSpell = classtable.DemonsBite end
    end
    if (MaxDps:CheckSpellUsable(classtable.ThrowGlaive, 'ThrowGlaive')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.ThrowGlaive].duration <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and ( cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.ThrowGlaive].charges >1.01 ) and true and targets >1) and cooldown[classtable.ThrowGlaive].ready then
        if not setSpell then setSpell = classtable.ThrowGlaive end
    end
    if (MaxDps:CheckSpellUsable(classtable.FelRush, 'FelRush')) and (not buff[classtable.UnboundChaosBuff].up and cooldown[classtable.FelRush].duration <cooldown[classtable.EyeBeam].remains and not debuff[classtable.EssenceBreakDeBuff].up and ( cooldown[classtable.EyeBeam].remains >8 or cooldown[classtable.FelRush].charges >1.01 ) and targets >1) and cooldown[classtable.FelRush].ready then
        MaxDps:GlowCooldown(classtable.FelRush, cooldown[classtable.FelRush].ready)
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
    targethealthPerc = (targetHP >0 and targetmaxHP >0 and (targetHP / targetmaxHP) * 100) or 100
    curentHP = UnitHealth('player')
    maxHP = UnitHealthMax('player')
    healthPerc = (curentHP / maxHP) * 100
    timeInCombat = MaxDps.combatTime or 0
    classtable = MaxDps.SpellTable
    SpellHaste = UnitSpellHaste('player')
    SpellCrit = GetCritChance()
    SoulFragments = GetNumSoulFragments()
    classtable.DeathSweep = 210152
    classtable.Annihilation = 201427
    classtable.Chaostheory = 389687
    classtable.ReaversGlaive = 442294
    if buff[classtable.ImmolationAuraBuff].up then
        classtable.ImmolationAura = 427917
    else
        classtable.ImmolationAura = 258920
    end
    Fury = UnitPower('player', FuryPT)
    FuryMax = UnitPowerMax('player', FuryPT)
    FuryDeficit = FuryMax - Fury
    Pain = UnitPower('player', PainPT)
    PainMax = UnitPowerMax('player', PainPT)
    PainDeficit = PainMax - Pain
    --for spellId in pairs(MaxDps.Flags) do
    --    self.Flags[spellId] = false
    --    self:ClearGlowIndependent(spellId, spellId)
    --end
    classtable.ImmolationAuraBuff = 258920
    classtable.EssenceBreakDeBuff = 320338
    classtable.FelBarrageBuff = 258925
    classtable.InnerDemonBuff = 390145
    classtable.DemonsurgeDeathSweepBuff = 0
    classtable.MetamorphosisBuff = 162264
    classtable.RendingStrikeBuff = 0
    classtable.DemonsurgeAnnihilationBuff = 0
    classtable.ReaversMarkDeBuff = 442679
    classtable.ReaversGlaiveBuff = 444661
    classtable.InitiativeBuff = 388108
    classtable.TacticalRetreatBuff = 389890
    classtable.UnboundChaosBuff = 347462
    classtable.DemonsurgeBuff = 452402
    classtable.ChaostheoryBuff = 390195
    classtable.InertiaTriggerBuff = 0
    classtable.MomentumBuff = 208628
    classtable.InertiaBuff = 427641
    classtable.DemonsurgeConsumingFireBuff = 0
    classtable.DemonsurgeAbyssalGazeBuff = 0
    classtable.GlaiveFlurryBuff = 442435
    classtable.ThrilloftheFightDamageBuff = 442688

    local function debugg()
        talents[classtable.BurningWound] = 1
        talents[classtable.DemonBlades] = 1
        talents[classtable.ShatteredDestiny] = 1
        talents[classtable.QuickenedSigils] = 1
        talents[classtable.Ragefire] = 1
        talents[classtable.FelBarrage] = 1
        talents[classtable.AFireInside] = 1
        talents[classtable.Inertia] = 1
        talents[classtable.Initiative] = 1
        talents[classtable.Momentum] = 1
        talents[classtable.StudentofSuffering] = 1
        talents[classtable.UnboundChaos] = 1
        talents[classtable.EssenceBreak] = 1
        talents[classtable.ChaoticTransformation] = 1
        talents[classtable.CycleofHatred] = 1
        talents[classtable.ArtoftheGlaive] = 1
        talents[classtable.FuriousThrows] = 1
        talents[classtable.RestlessHunter] = 1
        talents[classtable.Chaostheory] = 1
        talents[classtable.Soulscar] = 1
        talents[classtable.InnerDemon] = 1
    end


    if MaxDps.db.global.debugMode then
        debugg()
    end

    setSpell = nil
    ClearCDs()

    Havoc:precombat()

    Havoc:callaction()
    if setSpell then return setSpell end
end
