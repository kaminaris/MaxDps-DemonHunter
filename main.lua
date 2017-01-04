-- Havoc
local _DemonsBite = 162243;
local _DemonBlades = 203555;
local _ChaosStrike = 162794;
local _VengefulRetreat = 198793;
local _Prepared = 203551;
local _Momentum = 206476;
local _FelRush = 195072;
local _FelMastery = 192939;
local _EyeBeam = 198013;
local _Demonic = 213410;
local _FelEruption = 211881;
local _FuryoftheIllidari = 201467;
local _BladeDance = 188499;
local _DeathSweep = 210152;
local _FirstBlood = 206416;
local _Felblade = 213241;
local _ThrowGlaive = 204157;
local _Bloodlet = 206473;
local _FelBarrage = 211053;
local _Annihilation = 201427;
local _AnguishoftheDeceiver = 201473;
local _Metamorphosis = 191427;
local _ChaosBlades = 211048;
local _ChaosCleave = 206475;
local _DemonicAppetite = 206478;
local _Nemesis = 206491;
local _Blur = 198589;
local _DemonSpeed = 201469;
local _UnleashedDemons = 201460;
local _ConsumeMagic = 183752;

-- Vengeance
local _SoulCarver = 207407;
local _FelDevastation = 212084;
local _SoulCleave = 228477;
local _ImmolationAura = 178740;
local _Shear = 203783;
local _SigilOfFlame = 204596;
local _InfernalStrike = 189110;
local _FieryBrand = 204021;
local _DemonSpikes = 203720;
local _MetamorphosisV = 187827;
local _EmpowerWards = 218256;

-- Talents
local _isDemonic = false;
local _isFelEruption = false;
local _isFirstBlood = false;
local _isFelblade = false;
local _isBloodlet = false;
local _isFelBarrage = false;
local _isDemonBlades = false;
local _isFelDevastation = false;

MaxDps.DemonHunter = {};

MaxDps.DemonHunter.CheckTalents = function()
	MaxDps:CheckTalents();
	_isDemonic = MaxDps:HasTalent(_Demonic);
	_isFelEruption = MaxDps:HasTalent(_FelEruption);
	_isFirstBlood = MaxDps:HasTalent(_FirstBlood);
	_isFelblade = MaxDps:HasTalent(_Felblade);
	_isBloodlet = MaxDps:HasTalent(_Bloodlet);
	_isFelBarrage = MaxDps:HasTalent(_FelBarrage);
	_isDemonBlades = MaxDps:HasTalent(_DemonBlades);
	_isFelDevastation = MaxDps:HasTalent(_FelDevastation);
end

function MaxDps:EnableRotationModule(mode)
	mode = mode or 1;
	MaxDps.Description = "Demon Hunter [Havoc, Vengeance]";
	MaxDps.ModuleOnEnable = MaxDps.DemonHunter.CheckTalents;
	if mode == 1 then
		MaxDps.NextSpell = MaxDps.DemonHunter.Havoc;
	end;
	if mode == 2 then
		MaxDps.NextSpell = MaxDps.DemonHunter.Vengeance;
	end;
end

-- Demon Hunter Havoc reworked by Ryzux
function MaxDps.DemonHunter.Havoc()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	local fury = UnitPower('player', SPELL_POWER_FURY);
	local furyMax = UnitPowerMax('player', SPELL_POWER_FURY);

	local meta = MaxDps:Aura(_Metamorphosis, timeShift);

	local bladeDance = _BladeDance;
	if meta then
		bladeDance = _DeathSweep;
	end

	local chaosStrike = _ChaosStrike;
	if meta then
		chaosStrike = _Annihilation;
	end

	local momentum = MaxDps:Aura(_Momentum, timeShift);

	local bl = MaxDps:TargetAura(_Bloodlet, timeShift + 2);

	local eye = MaxDps:SpellAvailable(_EyeBeam, timeShift);
	local tg, tgCharges = MaxDps:SpellCharges(_ThrowGlaive, timeShift);
	local fb, fbCharges = MaxDps:SpellCharges(_FelBarrage, timeShift);

	MaxDps:GlowCooldown(_FelRush, MaxDps:SpellCharges(_FelRush, timeShift) and not momentum and fury >= 40);
	MaxDps:GlowCooldown(_VengefulRetreat, MaxDps:SpellAvailable(_VengefulRetreat, timeShift) and not momentum);
	MaxDps:GlowCooldown(_Metamorphosis, MaxDps:SpellAvailable(_Metamorphosis, timeShift));
	MaxDps:GlowCooldown(_ChaosBlades, MaxDps:SpellAvailable(_ChaosBlades, timeShift));

	-- #3. Fury of the Illidari on CD
	if MaxDps:SpellAvailable(_FuryoftheIllidari, timeShift) then
		return _FuryoftheIllidari;
	end

	-- #4. Fel Barrage with 5 Charges and Momentum
	if _isFelBarrage and fbCharges >= 5 and momentum then
		return _FelBarrage;
	end

	-- #5. Demonic
	if _isDemonic and eye and fury >= 48 then
		return _EyeBeam;
	end

	-- #6. First Blood
	if _isFirstBlood and MaxDps:SpellAvailable(bladeDance, timeShift) and fury >= 35 then
		return bladeDance;
	end

	-- #7. Fel Eruption
	if _isFelEruption and MaxDps:SpellAvailable(_FelEruption, timeShift) and fury >= 20 then
		return _FelEruption;
	end

	-- #8. Felblade
	if _isFelblade and MaxDps:SpellAvailable(_Felblade, timeShift) and furyMax - fury > 30 then
		return _Felblade;
	end

	-- #9. Bloodlet on Momentum
	if _isBloodlet and tg and momentum and not bl then
		return _ThrowGlaive;
	end

	-- #10. Eye Beam
	if eye and fury >= 48 then
		return _EyeBeam;
	end

	-- #11. Annihilation on Metamorphosis
	if meta and furyMax - fury < 30 then
		return chaosStrike;
	end

	-- #11. Chaos Strike on Momentum
	if momentum and fury >= 40 then
		return chaosStrike;
	end

	-- #11. Chaos Strike if Fury cap
	if not momentum and fury >= 90 then
		return chaosStrike;
	end

	-- #12. Fel Barrage with 4 Charges and Momentum
	if _isFelBarrage and fbCharges >= 4 and momentum then
		return _FelBarrage;
	end

	if _isDemonBlades then
		if tgCharges > 0 then
			return _ThrowGlaive;
		else
			return nil;
		end
	end

	return _DemonsBite;
end

-- Demon Hunter Vengeance by Ryzux
function MaxDps.DemonHunter.Vengeance()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	local pain = UnitPower('player', SPELL_POWER_PAIN);
	local painMax = UnitPowerMax('player', SPELL_POWER_PAIN);

	local meta = MaxDps:Aura(_MetamorphosisV, timeShift);

	MaxDps:GlowCooldown(_MetamorphosisV, MaxDps:SpellAvailable(_MetamorphosisV, timeShift));
	MaxDps:GlowCooldown(_InfernalStrike, MaxDps:SpellAvailable(_InfernalStrike, timeShift));

	-- Rotation

	-- #1. Soul Carver on cooldown
	if MaxDps:SpellAvailable(_SoulCarver, timeShift) then
		return _SoulCarver;
	end

	-- #2. Fel Devastation on cooldown
	if _isFelDevastation and MaxDps:SpellAvailable(_FelDevastation, timeShift) and pain >= 30 then
		return _FelDevastation;
	end

	-- #3. Soul Cleave above 80 pain
	if pain > 80 then
		return _SoulCleave;
	end

	-- #4. Immolation Aura on cooldown
	if MaxDps:SpellAvailable(_ImmolationAura, timeShift) then
		return _ImmolationAura;
	end

	-- #5. Felblade on cooldown
	if _isFelblade and MaxDps:SpellAvailable(_Felblade, timeShift) then
		return _Felblade;
	end

	-- #6. Sigil of Flame on cooldown
	if MaxDps:SpellAvailable(_SigilOfFlame, timeShift) then
		return _SigilOfFlame;
	end

	-- #7. Shear as a filler
	return _Shear;
end