local _, addonTable = ...;

--- @type MaxDps
if not MaxDps then return end

local DemonHunter = addonTable.DemonHunter;
local MaxDps = MaxDps;
local UnitPower = UnitPower;
local UnitPowerMax = UnitPowerMax;

local HV = {
	DemonsBite        = 162243,
	DemonBlades       = 203555,
	ChaosStrike       = 162794,
	VengefulRetreat   = 198793,
	Momentum          = 208628,
	MomentumTalent    = 206476,
	FelRush           = 195072,
	FelBarrage        = 258925,
	DarkSlash         = 258860,
	EyeBeam           = 198013,
	Nemesis           = 206491,
	Metamorphosis     = 191427,
	MetamorphosisAura = 162264,
	BladeDance        = 188499,
	DeathSweep        = 210152,
	ImmolationAura    = 258920,
	Felblade          = 232893,
	Annihilation      = 201427,
	ThrowGlaive       = 185123,
	FirstBlood        = 206416,
	Demonic           = 213410,
	BlindFury         = 203550,
	FelMastery        = 192939,
	TrailOfRuin       = 258881,
	RevolvingBlades   = 279581,
};

setmetatable(HV, DemonHunter.spellMeta);

function DemonHunter:Havoc()
	local fd = MaxDps.FrameData;
	local cooldown, buff, debuff, talents, azerite, currentSpell = fd.cooldown, fd.buff, fd.debuff, fd.talents, fd.azerite, fd.currentSpell;

	local fury = UnitPower('player', Enum.PowerType.Fury);
	local furyMax = UnitPowerMax('player', Enum.PowerType.Fury);
	local furyDeficit = furyMax - fury;

	local chaosStrike = MaxDps:FindSpell(HV.Annihilation) and HV.Annihilation or HV.ChaosStrike;
	local bladeDance = MaxDps:FindSpell(HV.DeathSweep) and HV.DeathSweep or HV.BladeDance;

	-- Auras
	local canEyeBeam = cooldown[HV.EyeBeam].ready and fury >= 30;

	if talents[HV.Demonic] then
		-- it was extended at some point
		if self.prevMetamorphosisRemains and buff[HV.Metamorphosis].remains > self.prevMetamorphosisRemains then
			self.buffMetamorphosisExtended = true;
		end

		-- once it goes down, flag down
		if not buff[HV.Metamorphosis].up then
			self.buffMetamorphosisExtended = false;
			self.prevMetamorphosisRemains = nil;
		else
			self.prevMetamorphosisRemains = buff[HV.Metamorphosis].remains;
		end
	end

	-- Cooldowns
	if talents[HV.MomentumTalent] then
		MaxDps:GlowCooldown(HV.FelRush, not buff[HV.Momentum].up and cooldown[HV.FelRush].ready);
		MaxDps:GlowCooldown(HV.VengefulRetreat, not buff[HV.Momentum].up and cooldown[HV.VengefulRetreat].ready);
	end

	local nemesis, nemesisCd;
	if talents[HV.Nemesis] then
		MaxDps:GlowCooldown(HV.Nemesis, cooldown[HV.Nemesis].ready);
	end

	MaxDps:GlowCooldown(HV.Metamorphosis, cooldown[HV.Metamorphosis].ready);

	local targets = MaxDps:TargetsInRange(HV.ChaosStrike);

	local varBladeDance = talents[HV.FirstBlood] or targets >= (3 - (talents[HV.TrailOfRuin] and 1 or 0));
	local varWaitingForNemesis = not (not talents[HV.Nemesis] or cooldown[HV.Nemesis].ready or cooldown[HV.Nemesis].remains > 60);
	local varPoolingForMeta = not talents[HV.Demonic] and cooldown[HV.Metamorphosis].remains < 6 and
		furyDeficit > 30 and (not varWaitingForNemesis or cooldown[HV.Nemesis].remains < 10);
	local varPoolingForBladeDance = varBladeDance and (fury < 75 - (talents[HV.FirstBlood] and 1 or 0) * 20);
	local varWaitingForDarkSlash = talents[HV.DarkSlash] and not varPoolingForBladeDance and
		not varPoolingForMeta and cooldown[HV.DarkSlash].ready;
	local varWaitingForMomentum = talents[HV.MomentumTalent] and not buff[HV.Momentum].up;


	-- Dark slash rotation
	if talents[HV.DarkSlash] and (varWaitingForDarkSlash or debuff[HV.DarkSlash].up) then
		if cooldown[HV.DarkSlash].ready and fury >= 80 and (not varBladeDance or not cooldown[HV.BladeDance].ready) then
			return HV.DarkSlash;
		end

		if fury >= 40 and debuff[HV.DarkSlash].up then
			return chaosStrike;
		end
	end

	local canFelBarrage = talents[HV.FelBarrage] and cooldown[HV.FelBarrage].ready;
	local canFelBlade = talents[HV.Felblade] and cooldown[HV.Felblade].ready;
	local canBladeDance = cooldown[HV.BladeDance].ready and
		fury >= (35 - (talents[HV.FirstBlood] and 20 or 0));

	if talents[HV.Demonic] then
		if canFelBarrage then
			return HV.FelBarrage;
		end

		if canBladeDance and buff[HV.Metamorphosis].up and varBladeDance then
			return bladeDance;
		end

		if canEyeBeam and not self.buffMetamorphosisExtended and
			(buff[HV.Metamorphosis].remains > 4 or not buff[HV.Metamorphosis].up)
		then
			return HV.EyeBeam;
		end

		if canBladeDance and varBladeDance and not cooldown[HV.Metamorphosis].ready and
			(cooldown[HV.EyeBeam].remains > (5 - azerite[HV.RevolvingBlades] * 3)) then
			return bladeDance;
		end

		if talents[HV.ImmolationAura] and cooldown[HV.ImmolationAura].ready then
			return HV.ImmolationAura;
		end

		if canFelBlade and (fury < 40 or (not buff[HV.Metamorphosis].up and furyDeficit >= 40)) then
			return HV.Felblade;
		end

		if fury >= 40 and (talents[HV.BlindFury] or furyDeficit < 30 or buff[HV.Metamorphosis].remains < 5) and
			buff[HV.Metamorphosis].up and
			not varPoolingForBladeDance
		then
			return chaosStrike;
		end

		if fury >= 40 and (talents[HV.BlindFury] or furyDeficit < 30) and
			not buff[HV.Metamorphosis].up and
			not varPoolingForMeta and
			not varPoolingForBladeDance
		then
			return chaosStrike;
		end
	else
		if canFelBarrage and not varWaitingForMomentum and (targets > 1) then
			return HV.FelBarrage;
		end

		if canBladeDance and buff[HV.Metamorphosis].up and varBladeDance then
			return bladeDance;
		end

		if talents[HV.ImmolationAura] and cooldown[HV.ImmolationAura].ready then
			return HV.ImmolationAura;
		end

		if canEyeBeam and targets > 1 and not varWaitingForMomentum then
			return HV.EyeBeam;
		end

		if canBladeDance and not buff[HV.Metamorphosis].up and varBladeDance then
			return bladeDance;
		end

		if canFelBlade and furyDeficit >= 40 then
			return HV.Felblade;
		end

		if canEyeBeam and not talents[HV.BlindFury] and not varWaitingForDarkSlash then
			return HV.EyeBeam;
		end

		if (talents[HV.DemonBlades] or not varWaitingForMomentum or furyDeficit < 30 or buff[HV.Metamorphosis].remains < 5) and
			buff[HV.Metamorphosis].up and
			not varPoolingForBladeDance and
			not varWaitingForDarkSlash
		then
			return chaosStrike;
		end

		if fury >= 40 and (talents[HV.DemonBlades] or not varWaitingForMomentum or furyDeficit < 30) and
			not buff[HV.Metamorphosis].up and
			not varPoolingForMeta and
			not varPoolingForBladeDance and
			not varWaitingForDarkSlash
		then
			return chaosStrike;
		end

		if canEyeBeam and talents[HV.BlindFury] then
			return HV.EyeBeam;
		end
	end

	if talents[HV.DemonBlades] then
		if cooldown[HV.ThrowGlaive].ready then
			return HV.ThrowGlaive;
		else
			return nil;
		end
	end

	return HV.DemonsBite;
end