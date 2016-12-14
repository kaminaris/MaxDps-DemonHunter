-- Spells
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

-- Talents
local _isDemonic = false;
local _isFelEruption = false;
local _isFirstBlood = false;
local _isFelblade = false;
local _isBloodlet = false;
local _isFelBarrage = false;
local _isDemonBlades = false;

MaxDps.DemonHunter = {};

MaxDps.DemonHunter.CheckTalents = function()
	_isDemonic = MaxDps:TalentEnabled('Demonic');
	_isFelEruption = MaxDps:TalentEnabled('Fel Eruption');
	_isFirstBlood = MaxDps:TalentEnabled('First Blood');
	_isFelblade = MaxDps:TalentEnabled('Felblade');
	_isBloodlet = MaxDps:TalentEnabled('Bloodlet');
	_isFelBarrage = MaxDps:TalentEnabled('Fel Barrage');
	_isDemonBlades = MaxDps:TalentEnabled('Demon Blades');
end

function MaxDps:EnableRotationModule(mode)
	mode = mode or 1;
	MaxDps.Description = "Demon Hunter [Havoc]";
	MaxDps.ModuleOnEnable = MaxDps.DemonHunter.CheckTalents;
	if mode == 1 then
		MaxDps.NextSpell = MaxDps.DemonHunter.Havoc;
	end;
	if mode == 2 then
		MaxDps.NextSpell = MaxDps.DemonHunter.Vengeance;
	end;
end

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

	MaxDps:GlowCooldown(_VengefulRetreat, MaxDps:SpellAvailable(_VengefulRetreat, timeShift) and not momentum);
	MaxDps:GlowCooldown(_ChaosBlades, MaxDps:SpellAvailable(_ChaosBlades, timeShift));
	MaxDps:GlowCooldown(_Metamorphosis, MaxDps:SpellAvailable(_Metamorphosis, timeShift));
	MaxDps:GlowCooldown(_FelRush, MaxDps:SpellCharges(_FelRush, timeShift) and not momentum);

	if _isDemonic and eye and fury >= 48 then
		return _EyeBeam;
	end

	if _isFelEruption and MaxDps:SpellAvailable(_FelEruption, timeShift) and fury >= 20 then
		return _FelEruption;
	end

	if MaxDps:SpellAvailable(_FuryoftheIllidari, timeShift) then
		return _FuryoftheIllidari;
	end

	if _isFirstBlood and MaxDps:SpellAvailable(bladeDance, timeShift) and fury >= 35 then
		return bladeDance;
	end

	if _isFelblade and MaxDps:SpellAvailable(_Felblade, timeShift) and furyMax - fury > 30 then
		return _Felblade;
	end

	if _isBloodlet and tg and not bl then
		return _ThrowGlaive;
	end

	if _isFelBarrage and fbCharges >= 5 then
		return _FelBarrage;
	end

	if meta and furyMax - fury < 30 then
		return _Annihilation;
	end

	if eye and fury >= 48 then
		return _EyeBeam;
	end

	if not meta and furyMax - fury < 30 then
		return _ChaosStrike;
	end

	if _isFelBarrage and fbCharges >= 4 then
		return _FelBarrage;
	end

	if _isDemonBlades then
		if tgCharges > 0 then
			return _ThrowGlaive;
		else
			return nil
		end
	end

	return _DemonsBite;
end

function MaxDps.DemonHunter.Vengeance()
	local timeShift, currentSpell, gcd = MaxDps:EndCast();

	return nil;
end