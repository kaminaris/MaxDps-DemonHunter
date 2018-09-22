if not MaxDps then
	return ;
end

local DemonHunter = MaxDps:NewModule('DemonHunter');

-- Havoc
local _DemonsBite = 162243;
local _DemonBlades = 203555;
local _ChaosStrike = 162794;
local _VengefulRetreat = 198793;
local _Momentum = 208628;
local _MomentumTalent = 206476;
local _FelRush = 195072;
local _FelBarrage = 258925;
local _DarkSlash = 258860;
local _EyeBeam = 198013;
local _Nemesis = 206491;
local _Metamorphosis = 191427;
local _MetamorphosisAura = 162264;
local _BladeDance = 188499;
local _DeathSweep = 210152;
local _ImmolationAura = 258920;
local _Felblade = 232893;
local _Annihilation = 201427;
local _ThrowGlaive = 185123;
local _FirstBlood = 206416;
local _Demonic = 213410;
local _BlindFury = 203550;
local _FelMastery = 192939;
local _TrailOfRuin = 258881;

-- Vengeance

function DemonHunter:Enable()
	MaxDps:Print(MaxDps.Colors.Info .. 'Demon Hunter [Havoc]');

	if MaxDps.Spec == 1 then
		MaxDps.NextSpell = DemonHunter.Havoc;
	elseif MaxDps.Spec == 2 then
		MaxDps.NextSpell = DemonHunter.Vengeance;
	end

	return true;
end

function DemonHunter:Havoc(timeShift, currentSpell, gcd, talents)
	local fury = UnitPower('player', Enum.PowerType.Fury);
	local furyMax = UnitPowerMax('player', Enum.PowerType.Fury);
	local furyDeficit = furyMax - fury;

	local chaosStrike = MaxDps:FindSpell(_Annihilation) and _Annihilation or _ChaosStrike;
	local bladeDance = MaxDps:FindSpell(_DeathSweep) and _DeathSweep or _BladeDance;

	-- Auras
	local cooldownNemesisReady, cooldownNemesisRemains = MaxDps:SpellAvailable(_Nemesis, timeShift);
	local cooldownMetamorphosisReady, cooldownMetamorphosisRemains = MaxDps:SpellAvailable(_Metamorphosis, timeShift);
	local cooldownDarkSlashReady, cooldownDarkSlashRemains = MaxDps:SpellAvailable(_DarkSlash, timeShift);
	local cooldownBladeDanceReady, cooldownBladeDanceRemains = MaxDps:SpellAvailable(_BladeDance, timeShift);
	local cooldownEyeBeamReady, cooldownEyeBeamRemains = MaxDps:SpellAvailable(_EyeBeam, timeShift);
	local canEyeBeam = cooldownEyeBeamReady and fury >= 30;


	local buffMomentumUp, buffMomentumStack, buffMomentumRemains = MaxDps:Aura(_Momentum, timeShift);
	local buffMetamorphosisUp, buffMetamorphosisStack, buffMetamorphosisRemains = MaxDps:Aura(_MetamorphosisAura, timeShift);
	local buffPreparedUp, buffPreparedStack, buffPreparedRemains = MaxDps:Aura(_Prepared, timeShift);
	local debuffDarkSlashUp, debuffDarkSlashStack, debuffDarkSlashRemains = MaxDps:TargetAura(_DarkSlash, timeShift);

	if talents[_Demonic] then
		-- it was extended at some point
		if self.prevMetamorphosisRemains and buffMetamorphosisRemains > self.prevMetamorphosisRemains then
			self.buffMetamorphosisExtended = true;
		end

		-- once it goes down, flag down
		if not buffMetamorphosisUp then
			self.buffMetamorphosisExtended = false;
			self.prevMetamorphosisRemains = nil;
		else
			self.prevMetamorphosisRemains = buffMetamorphosisRemains;
		end
	end

	-- Cooldowns
	if talents[_MomentumTalent] then
		MaxDps:GlowCooldown(_FelRush, not buffMomentumUp and MaxDps:SpellAvailable(_FelRush, timeShift));
		MaxDps:GlowCooldown(_VengefulRetreat, not buffMomentumUp and MaxDps:SpellAvailable(_VengefulRetreat, timeShift));
	end

	local nemesis, nemesisCd;
	if talents[_Nemesis] then
		MaxDps:GlowCooldown(_Nemesis, cooldownNemesisReady);
	end

	MaxDps:GlowCooldown(_Metamorphosis, MaxDps:SpellAvailable(_Metamorphosis, timeShift));

	local targets = MaxDps:TargetsInRange(_ChaosStrike);

	local varBladeDance = talents[_FirstBlood] or targets >= (3 - (talents[_TrailOfRuin] and 1 or 0));
	local varWaitingForNemesis = not (not talents[_Nemesis] or cooldownNemesisReady or cooldownNemesisRemains > 60);
	local varPoolingForMeta = not talents[_Demonic] and cooldownMetamorphosisRemains < 6 and
		furyDeficit > 30 and (not varWaitingForNemesis or cooldownNemesisRemains < 10);
	local varPoolingForBladeDance = varBladeDance and (fury < 75 - (talents[_FirstBlood] and 1 or 0) * 20);
	local varWaitingForDarkSlash = talents[_DarkSlash] and not varPoolingForBladeDance and
		not varPoolingForMeta and cooldownDarkSlashReady;
	local varWaitingForMomentum = talents[_MomentumTalent] and not buffMomentumUp;


	-- Dark slash rotation
	if talents[_DarkSlash] and (varWaitingForDarkSlash or debuffDarkSlashUp) then
		if cooldownDarkSlashReady and fury >= 80 and (not varBladeDance or not cooldownBladeDanceReady) then
			return _DarkSlash;
		end

		if fury >= 40 and debuffDarkSlashUp then
			return chaosStrike;
		end
	end

	local canFelBarrage = talents[_FelBarrage] and MaxDps:SpellAvailable(_FelBarrage, timeShift);
	local canFelBlade = talents[_Felblade] and MaxDps:SpellAvailable(_Felblade, timeShift);
	local canBladeDance = MaxDps:SpellAvailable(_BladeDance, timeShift) and
		fury >= (35 - (talents[_FirstBlood] and 20 or 0));

	if talents[_Demonic] then
		if canFelBarrage then
			return _FelBarrage;
		end

		if canBladeDance and buffMetamorphosisUp and varBladeDance then
			return bladeDance;
		end

		if canEyeBeam and not self.buffMetamorphosisExtended and
			(buffMetamorphosisRemains > 4 or not buffMetamorphosisUp)
		then
			return _EyeBeam;
		end

		if canBladeDance and varBladeDance and not cooldownMetamorphosisReady and
			(cooldownEyeBeamRemains > 5) then -- (5 - azerite.revolving_blades.rank * 3)
			return bladeDance;
		end

		if talents[_ImmolationAura] and MaxDps:SpellAvailable(_ImmolationAura, timeShift) then
			return _ImmolationAura;
		end

		if canFelBlade and (fury < 40 or (not buffMetamorphosisUp and furyDeficit >= 40)) then
			return _Felblade;
		end

		if fury >= 40 and (talents[_BlindFury] or furyDeficit < 30 or buffMetamorphosisRemains < 5) and
			buffMetamorphosisUp and
			not varPoolingForBladeDance
		then
			return chaosStrike;
		end

		if fury >= 40 and (talents[_BlindFury] or furyDeficit < 30) and
			not buffMetamorphosisUp and
			not varPoolingForMeta and
			not varPoolingForBladeDance
		then
			return chaosStrike;
		end
	else
		if canFelBarrage and not varWaitingForMomentum and (targets > 1) then
			return _FelBarrage;
		end

		if canBladeDance and buffMetamorphosisUp and varBladeDance then
			return bladeDance;
		end

		if talents[_ImmolationAura] and MaxDps:SpellAvailable(_ImmolationAura, timeShift) then
			return _ImmolationAura;
		end

		if canEyeBeam and targets > 1 and not varWaitingForMomentum then
			return _EyeBeam;
		end

		if canBladeDance and not buffMetamorphosisUp and varBladeDance then
			return bladeDance;
		end

		if canFelBlade and furyDeficit >= 40 then
			return _Felblade;
		end

		if canEyeBeam and not talents[_BlindFury] and not varWaitingForDarkSlash then
			return _EyeBeam;
		end

		if (talents[_DemonBlades] or not varWaitingForMomentum or furyDeficit < 30 or buffMetamorphosisRemains < 5) and
			buffMetamorphosisUp and
			not varPoolingForBladeDance and
			not varWaitingForDarkSlash
		then
			return chaosStrike;
		end

		if fury >= 40 and (talents[_DemonBlades] or not varWaitingForMomentum or furyDeficit < 30) and
			not buffMetamorphosisUp and
			not varPoolingForMeta and
			not varPoolingForBladeDance and
			not varWaitingForDarkSlash
		then
			return chaosStrike;
		end

		if canEyeBeam and talents[_BlindFury] then
			return _EyeBeam;
		end
	end

	if talents[_DemonBlades] then
		if MaxDps:SpellAvailable(_ThrowGlaive, timeShift) then
			return _ThrowGlaive;
		else
			return nil;
		end
	end

	return _DemonsBite;
end

function DemonHunter:Vengeance(timeShift, currentSpell, gcd, talents)
	local pain = UnitPower('player', Enum.PowerType.Pain);

	return nil;
end