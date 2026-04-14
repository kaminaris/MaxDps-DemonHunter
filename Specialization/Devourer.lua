local _, addonTable = ...
local DemonHunter = addonTable.DemonHunter
local MaxDps = _G.MaxDps
if not MaxDps then return end

local GetItemCooldown = C_Item.GetItemCooldown

local Devourer  = {}

function DemonHunter:Devourer()
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization()
    local specName = specIndex and select(2, GetSpecializationInfo(specIndex))

    if class and specName and MaxDps.classCooldowns[class] and MaxDps.classCooldowns[class][specName] then
        for _, spellID in pairs(MaxDps.classCooldowns[class][specName].defensive) do
            --print("Defensive:", spellName, spellID)
            if MaxDps:CheckSpellUsable(spellID) then
                MaxDps:GlowDefensiveHPMidnight(spellID, true)
            end
        end
    end
    if class and specName
        and MaxDps.classInterrupts[class]
        and MaxDps.classInterrupts[class][specName]
    then
        for _, spellID in pairs(MaxDps.classInterrupts[class][specName]) do
            --print("Defensive:", spellName, spellID)
            if MaxDps:CheckSpellUsable(spellID) then
                MaxDps:GlowInteruptMidnight(spellID)
            end
        end
    end
    if class and specName and MaxDps.classCooldowns[class] and MaxDps.classCooldowns[class][specName] then
        for _, spellID in pairs(MaxDps.classCooldowns[class][specName].offensive) do
            --print("Offensive:", C_Spell.GetSpellInfo(spellID).name, spellID)
            if MaxDps.FrameData.ACSpells and MaxDps.FrameData.ACSpells[1217605] then -- Metamorphosis
                MaxDps.FrameData.ACSpells[1217605] = nil
            end
            --if MaxDps.FrameData.ACSpells and MaxDps.FrameData.ACSpells[1221150] then -- Collapsing Star
            --    MaxDps.FrameData.ACSpells[1221150] = nil
            --end
            if not MaxDps.FrameData.ACSpells or not MaxDps.FrameData.ACSpells[spellID] then
                --if MaxDps:CheckSpellUsable(spellID) then
                --    --print("Offensive:", C_Spell.GetSpellInfo(spellID).name, spellID)
                --    MaxDps:GlowCooldownMidnight(spellID, true)
                --end
                --if MaxDps:CheckSpellUsable(spellID) and MaxDps.Spells[1221150] then
                --    --print("Offensive:", C_Spell.GetSpellInfo(spellID).name, spellID)
                --    MaxDps:GlowCooldownMidnight(spellID, false)
                --elseif MaxDps:CheckSpellUsable(spellID) and not MaxDps.Spells[1221150] then
                --    --print("Offensive:", C_Spell.GetSpellInfo(spellID).name, spellID)
                --    MaxDps:GlowCooldownMidnight(spellID, true)
                --end
                MaxDps:GlowCooldownMidnight(spellID, MaxDps:CheckSpellUsable(spellID))

            --else
            --    if MaxDps and MaxDps.Spells and MaxDps.Spells[spellID] and not InCombatLockdown() then
            --        for i=1,#MaxDps.Spells[spellID] do
            --            C_ActionBar.UnregisterActionUIButton(MaxDps.Spells[spellID][i])
            --        end
            --    end
            --    if MaxDps and MaxDps.FrameData and MaxDps.FrameData.ACSpells and MaxDps.FrameData.ACSpells[spellID] then
            --        MaxDps.FrameData.ACSpells[spellID] = nil
            --    end
            end
        end
    end
end
