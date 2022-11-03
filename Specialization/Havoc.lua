local _, addonTable = ...

--- @type MaxDps
if not MaxDps then return end

local DemonHunter = addonTable.DemonHunter
local MaxDps = MaxDps
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax

local HV = {
	Annihilation = 201427,
	BladeDance = 188499,
	ChaosStrike = 162794,
	ChaoticTransformation = 388112,
	DeathSweep = 210152,
	DemonBlades = 203555,
	DemonsBite = 162243,
	EssenceBreak = 258860,
	EyeBeam = 198013,
	FelBarrage = 258925,
	FelRush = 195072,
	Felblade = 232893,
	FodderToTheFlame = 391429,
	FodderToTheFlameBuff = 391430,
	FuriousThrows = 393029,
	GlaiveTempest = 342817,
	ImmolationAura = 258920,
	Initiative = 388108,
	Metamorphosis = 191427,
	Momentum = 206476,
	MomentumBuff = 208628,
	SigilOfFlame = 204596,
	Soulrend = 388106,
	TheHunt = 370965,
	ThrowGlaive = 185123,
	UnboundChaosBuff = 347462,
	UnstoppableConflictDebuff = 328605,
	VengefulRetreat = 198793
}

setmetatable(HV, DemonHunter.spellMeta)

local colorRed = {
	r = 1,
	g = 0,
	b = 0,
	a = 1
}

---@return number
local function GetFury()
	return UnitPower('player', Enum.PowerType.Fury)
end

local function IsUnstoppableConflictUp()
	local fd = MaxDps.FrameData
	local up = MaxDps:UnitAura(HV.UnstoppableConflictDebuff, fd.timeShift, "player", "HARMFUL")
	return up ~= nil and up
end

function DemonHunter:Havoc()
	local fd = MaxDps.FrameData
	local cooldown = fd.cooldown
	local talents = fd.talents
	local buff = fd.buff
	local fury = GetFury()
	local furyMax = UnitPowerMax('player', Enum.PowerType.Fury)
	local furyDeficit = furyMax - fury
	fd.fury = fury
	fd.furyMax = furyMax
	fd.furyDeficit = furyDeficit

	local saveGlaiveForFodderToTheFlameDemon = buff[HV.FodderToTheFlameBuff].up and IsUnstoppableConflictUp()
	fd.saveGlaiveForFodderToTheFlameDemon = saveGlaiveForFodderToTheFlameDemon

	local furyGenerator
	if talents[HV.Felblade] and cooldown[HV.Felblade].ready then
		furyGenerator = HV.Felblade
	elseif not talents[HV.DemonBlades] then
		furyGenerator = HV.DemonsBite
	end
	fd.furyGenerator = furyGenerator

	local poolingForMeta = cooldown[HV.Metamorphosis].remains < 6 and furyDeficit > 30
	fd.poolingForMeta = poolingForMeta

	local ChaosStrike = MaxDps:FindSpell(HV.Annihilation) and HV.Annihilation or HV.ChaosStrike
	fd.ChaosStrike = ChaosStrike

	local BladeDance = MaxDps:FindSpell(HV.DeathSweep) and HV.DeathSweep or HV.BladeDance
	fd.BladeDance = BladeDance

	local targets = MaxDps:SmartAoe()

	local isSingle = targets <= 1
	DemonHunter:HavocCooldowns(isSingle)
	return DemonHunter:HavocRotation()
end

---@param spellId number
local function IsCastable(spellId)
	local cost = GetSpellPowerCost(spellId)[1].cost or 0
	return MaxDps.FrameData.cooldown[spellId].ready and cost <= GetFury()
end

---@param isSingle boolean
function DemonHunter:HavocCooldowns(isSingle)
	local fd = MaxDps.FrameData
	local cooldown = fd.cooldown
	local talents = fd.talents
	local buff = fd.buff
	local gcd = fd.gcd
	local saveGlaiveForFodderToTheFlameDemon = fd.saveGlaiveForFodderToTheFlameDemon

	if talents[HV.Initiative] then
		MaxDps:GlowCooldown(HV.VengefulRetreat, not buff[HV.MomentumBuff].up and cooldown[HV.VengefulRetreat].ready)
	end

	if talents[HV.FodderToTheFlame] then
		MaxDps:GlowCooldown(HV.ThrowGlaive, saveGlaiveForFodderToTheFlameDemon and buff[HV.FodderToTheFlameBuff].remains <= 5, colorRed)
	end

	if talents[HV.Momentum] then
		MaxDps:GlowCooldown(HV.FelRush, not buff[HV.MomentumBuff].up and cooldown[HV.FelRush].fullRecharge <= gcd * 2)
	end

	if not isSingle and talents[HV.FelBarrage] then
		MaxDps:GlowCooldown(HV.FelBarrage, cooldown[HV.FelBarrage].ready)
	end
end

---@return boolean
local function CanThrowGlaive()
	local fd = MaxDps.FrameData
	local saveGlaiveForFodderToTheFlameDemon = fd.saveGlaiveForFodderToTheFlameDemon

	if not saveGlaiveForFodderToTheFlameDemon then
		return IsCastable(HV.ThrowGlaive)
	end

	local buff = fd.buff
	local fodderToTheFlameRemains = buff[HV.FodderToTheFlameBuff].remains
	local throwGlaiveCharges = fd.cooldown[HV.ThrowGlaive].charges
	local throwGlaivePartialRecharge = fd.cooldown[HV.ThrowGlaive].partialRecharge

	if throwGlaiveCharges > 1 or fodderToTheFlameRemains > throwGlaivePartialRecharge then
		return IsCastable(HV.ThrowGlaive)
	end

	return false
end

function DemonHunter:HavocRotation()
	local fd = MaxDps.FrameData
	local cooldown = fd.cooldown
	local talents = fd.talents
	local buff = fd.buff
	local furyGenerator = fd.furyGenerator
	local ChaosStrike = fd.ChaosStrike
	local BladeDance = fd.BladeDance
	local fury = fd.fury
	local gcd = fd.gcd
	local poolingForMeta = fd.poolingForMeta
	local currentSpell = fd.currentSpell

	if cooldown[HV.Metamorphosis].ready and not poolingForMeta then
		if talents[HV.ChaoticTransformation] then
			if not cooldown[HV.EyeBeam].ready and cooldown[HV.EyeBeam].remains > 24 then
				return HV.Metamorphosis
			end
		else
			return HV.Metamorphosis
		end
	end

	if buff[HV.UnboundChaosBuff].up and cooldown[HV.FelRush].ready then
		return HV.FelRush
	end

	if IsCastable(HV.EyeBeam) then
		return HV.EyeBeam
	end

	if talents[HV.EssenceBreak] and cooldown[HV.EssenceBreak].ready then
		return HV.EssenceBreak
	end

	if IsCastable(BladeDance) and not poolingForMeta then
		return BladeDance
	end

	if CanThrowGlaive() and talents[HV.Soulrend] and talents[HV.FuriousThrows] and cooldown[HV.ThrowGlaive].fullRecharge <= gcd * 2 then
		return HV.ThrowGlaive
	end

	if talents[HV.TheHunt] and cooldown[HV.TheHunt].ready and currentSpell ~= HV.TheHunt then
		return HV.TheHunt
	end

	if talents[HV.GlaiveTempest] and IsCastable(HV.GlaiveTempest) and not poolingForMeta then
		return HV.GlaiveTempest
	end

	if cooldown[HV.ImmolationAura].ready then
		return HV.ImmolationAura
	end

	if talents[HV.Felblade] and cooldown[HV.Felblade].ready and fury < 80 then
		return HV.Felblade
	end

	if fury >= 50 and not poolingForMeta then
		return ChaosStrike
	end

	if talents[HV.SigilOfFlame] and cooldown[HV.SigilOfFlame].ready and fury < 40 then
		return HV.SigilOfFlame
	end

	if furyGenerator ~= nil then
		return furyGenerator
	end

	if CanThrowGlaive() then
		return HV.ThrowGlaive
	end

	return furyGenerator
end