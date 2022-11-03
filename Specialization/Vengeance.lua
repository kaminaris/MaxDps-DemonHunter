local _, addonTable = ...

--- @type MaxDps
if not MaxDps then
	return
end

local DemonHunter = addonTable.DemonHunter
local MaxDps = MaxDps
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local GetSpellCount = GetSpellCount

local VG = {
	BulkExtraction = 320341,
	DemonSpikes = 203720,
	DemonSpikesBuff = 203819,
	Fallout = 227174,
	Felblade = 232893,
	FelDevastation = 212084,
	FieryBrand = 204021,
	FieryDemise = 389220,
	Fracture = 263642,
	ImmolationAura = 258920,
	InfernalStrike = 189110,
	Metamorphosis = 187827,
	Shear = 203782,
	SigilOfFlame = 204596,
	SoulCarver = 207407,
	SoulCleave = 228477,
	SoulSigils = 395446,
	SoulFragments = 203981,
	SpiritBomb = 247454,
	TheHunt = 370965,
	ThrowGlaive = 204157
}

setmetatable(VG, DemonHunter.spellMeta)

---@return number
local function GetFury()
	return UnitPower('player', Enum.PowerType.Fury)
end

function DemonHunter:Vengeance()
	local fd = MaxDps.FrameData
	fd.fury = GetFury()

	return (fd.talents[VG.FieryDemise] and DemonHunter:VengeanceBrand())
			or DemonHunter:VengeanceDefensives()
			or DemonHunter:VengeanceCooldowns()
			or DemonHunter:VengeanceNormal()
end

---@param spellId number
local function IsCastable(spellId, fury)
	local cost = GetSpellPowerCost(spellId)[1].cost or 0
	return MaxDps.FrameData.cooldown[spellId].ready and cost <= fury
end

function DemonHunter:VengeanceCooldowns()
	local fd = MaxDps.FrameData
	local cooldown = fd.cooldown
	local buff = fd.buff
	local talents = fd.talents
	MaxDps:GlowCooldown(VG.Metamorphosis, cooldown[VG.Metamorphosis].ready)
	MaxDps:GlowCooldown(VG.TheHunt, cooldown[VG.TheHunt].ready)
	if talents[VG.BulkExtraction] then
		MaxDps:GlowCooldown(VG.BulkExtraction, cooldown[VG.BulkExtraction].ready)
	end
	MaxDps:GlowCooldown(VG.DemonSpikes, cooldown[VG.DemonSpikes].ready and buff[VG.DemonSpikesBuff].remains < 1)
	MaxDps:GlowCooldown(VG.InfernalStrike, cooldown[VG.InfernalStrike].charges == cooldown[VG.InfernalStrike].maxCharges)
end

function DemonHunter:VengeanceBrand()
	local fd = MaxDps.FrameData
	local cooldown = fd.cooldown
	local debuff = fd.debuff
	local talents = fd.talents
	local fury = fd.fury

	if cooldown[VG.FieryBrand].ready then
		return VG.FieryBrand
	end

	if debuff[VG.FieryBrand].up then
		if cooldown[VG.ImmolationAura].ready then
			return VG.ImmolationAura
		end

		if IsCastable(VG.FelDevastation, fury) then
			return VG.FelDevastation
		end

		if talents[VG.SoulCarver] and cooldown[VG.SoulCarver].ready then
			return VG.SoulCarver
		end
	end
end

function DemonHunter:VengeanceDefensives()
	local fd = MaxDps.FrameData
	local cooldown = fd.cooldown

	if cooldown[VG.FieryBrand].ready then
		return VG.FieryBrand
	end
end

function DemonHunter:VengeanceNormal()
	local fd = MaxDps.FrameData
	local cooldown = fd.cooldown
	local talents = fd.talents
	local buff = fd.buff
	local fury = fd.fury
	local furyMax = UnitPowerMax('player', Enum.PowerType.Fury)
	local furyDeficit = furyMax - fury
	local soulFragments = buff[VG.SoulFragments].count

	local shear = VG.Shear
	if talents[VG.Fracture] then
		shear = VG.Fracture
	end

	if IsCastable(VG.FelDevastation, fury) then
		return VG.FelDevastation
	end

	if furyDeficit >= 20 and cooldown[VG.ImmolationAura].ready and (not talents[VG.Fallout] or soulFragments <= 3) then
		return VG.ImmolationAura
	end

	if talents[VG.Felblade] and cooldown[VG.Felblade].ready and furyDeficit <= 40 then
		return VG.Felblade
	end

	if cooldown[shear].ready then
		local castAsFallback = fury == furyMax or cooldown[shear].charges == cooldown[shear].maxCharges

		if buff[VG.Metamorphosis].up then
			if soulFragments <= 2 and (furyDeficit >= 45 or castAsFallback) then
				return shear
			end
		else
			if soulFragments <= 3 and (furyDeficit >= 25 or castAsFallback) then
				return shear
			end
		end
	end

	if cooldown[VG.SigilOfFlame].ready and furyDeficit >= 30 and (not talents[VG.SoulSigils] or soulFragments <= 4) then
		return VG.SigilOfFlame
	end

	if soulFragments >= 4 and talents[VG.SpiritBomb] and IsCastable(VG.SpiritBomb, fury) then
		return VG.SpiritBomb
	end

	if talents[VG.SpiritBomb] then
		if soulFragments == 0 and cooldown[VG.SoulCleave].ready then
			return VG.SoulCleave
		end
	else
		if IsCastable(VG.SoulCleave, fury) then
			return VG.SoulCleave
		end
	end

	return VG.ThrowGlaive
end
