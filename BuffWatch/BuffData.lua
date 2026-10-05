-- Catalog of buffs per class, shown in the "Browse buffs" picker.
-- Each entry uses the rank 1 spell ID for its icon and tooltip. Matching is done
-- by name, so every rank of a buff counts. "alt" lists buffs that also satisfy
-- the entry (the group version of a single-target buff, for example).
-- Names are fallbacks only: the client's own (localized) name is used when the
-- spell ID exists.

local _, ns = ...

ns.BuffCatalog = {
    { key = "DRUID", entries = {
        { id = 1126,  name = "Mark of the Wild", alt = { { id = 21849, name = "Gift of the Wild" } } },
        { id = 467,   name = "Thorns" },
        { id = 16864, name = "Omen of Clarity" },
    }},
    { key = "HUNTER", entries = {
        { id = 13165, name = "Aspect of the Hawk" },
        { id = 13163, name = "Aspect of the Monkey" },
        { id = 5118,  name = "Aspect of the Cheetah" },
        { id = 13159, name = "Aspect of the Pack" },
        { id = 20043, name = "Aspect of the Wild" },
        { id = 19506, name = "Trueshot Aura" },
    }},
    { key = "MAGE", entries = {
        { id = 1459,  name = "Arcane Intellect", alt = { { id = 23028, name = "Arcane Brilliance" } } },
        { id = 168,   name = "Frost Armor" },
        { id = 7302,  name = "Ice Armor" },
        { id = 6117,  name = "Mage Armor" },
        { id = 1008,  name = "Amplify Magic" },
        { id = 604,   name = "Dampen Magic" },
    }},
    { key = "PALADIN", entries = {
        { id = 19740, name = "Blessing of Might",      alt = { { id = 25782, name = "Greater Blessing of Might" } } },
        { id = 19742, name = "Blessing of Wisdom",     alt = { { id = 25894, name = "Greater Blessing of Wisdom" } } },
        { id = 20217, name = "Blessing of Kings",      alt = { { id = 25898, name = "Greater Blessing of Kings" } } },
        { id = 1038,  name = "Blessing of Salvation",  alt = { { id = 25895, name = "Greater Blessing of Salvation" } } },
        { id = 19977, name = "Blessing of Light",      alt = { { id = 25890, name = "Greater Blessing of Light" } } },
        { id = 20911, name = "Blessing of Sanctuary",  alt = { { id = 25899, name = "Greater Blessing of Sanctuary" } } },
        { id = 465,   name = "Devotion Aura" },
        { id = 7294,  name = "Retribution Aura" },
        { id = 19746, name = "Concentration Aura" },
        { id = 25780, name = "Righteous Fury" },
    }},
    { key = "PRIEST", entries = {
        { id = 1243,  name = "Power Word: Fortitude", alt = { { id = 21562, name = "Prayer of Fortitude" } } },
        { id = 14752, name = "Divine Spirit",         alt = { { id = 27681, name = "Prayer of Spirit" } } },
        { id = 976,   name = "Shadow Protection",     alt = { { id = 27683, name = "Prayer of Shadow Protection" } } },
        { id = 588,   name = "Inner Fire" },
        { id = 6346,  name = "Fear Ward" },
    }},
    { key = "SHAMAN", entries = {
        { id = 324,   name = "Lightning Shield" },
        { id = 8076,  name = "Strength of Earth" },
        { id = 8836,  name = "Grace of Air" },
        { id = 5677,  name = "Mana Spring" },
    }},
    { key = "WARLOCK", entries = {
        { id = 687,   name = "Demon Skin" },
        { id = 706,   name = "Demon Armor" },
        { id = 5697,  name = "Unending Breath" },
        { id = 132,   name = "Detect Lesser Invisibility" },
    }},
    { key = "WARRIOR", entries = {
        { id = 6673,  name = "Battle Shout" },
    }},
    { key = "CONSUMABLES", label = "Consumables & world buffs", entries = {
        { id = 17626, name = "Flask of the Titans" },
        { id = 17627, name = "Distilled Wisdom" },
        { id = 17628, name = "Supreme Power" },
        { id = 17538, name = "Elixir of the Mongoose" },
        { id = 11405, name = "Elixir of the Giants" },
        { id = 17539, name = "Greater Arcane Elixir" },
        { id = 22888, name = "Rallying Cry of the Dragonslayer" },
        { id = 15366, name = "Songflower Serenade" },
        { id = 24425, name = "Spirit of Zandalar" },
        { id = 16609, name = "Warchief's Blessing" },
    }},
}

-- Turn a catalog definition into a watch-list entry using the client's spell data
function ns.ResolveCatalogEntry(def)
    local name = C_Spell.GetSpellName(def.id) or def.name
    local icon = C_Spell.GetSpellTexture(def.id)
    local alt
    if def.alt then
        alt = {}
        for _, a in ipairs(def.alt) do
            table.insert(alt, C_Spell.GetSpellName(a.id) or a.name)
        end
    end
    return { name = name, id = def.id, icon = icon, alt = alt }
end

function ns.CategoryLabel(cat)
    if cat.label then return cat.label end
    local name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[cat.key]) or cat.key
    local color = C_ClassColor and C_ClassColor.GetClassColor(cat.key)
    return color and color:WrapTextInColorCode(name) or name
end
