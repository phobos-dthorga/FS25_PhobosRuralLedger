PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.I18n = PhobosRuralLedger.I18n or {}

local I18n = PhobosRuralLedger.I18n

local function formatText(text, ...)
    if select("#", ...) == 0 then
        return tostring(text or "")
    end

    local ok, formatted = pcall(string.format, tostring(text or ""), ...)
    if ok then
        return formatted
    end

    return tostring(text or "")
end

function I18n.get(key, fallback, ...)
    if PhobosFS25 ~= nil and PhobosFS25.I18n ~= nil and PhobosFS25.I18n.get ~= nil then
        return PhobosFS25.I18n.get("FS25_PhobosRuralLedger", key, fallback, ...)
    end

    local value = fallback or key

    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, translated = pcall(function()
            return g_i18n:getText(key)
        end)

        if ok and translated ~= nil and translated ~= "" and translated ~= key then
            value = translated
        end
    end

    return formatText(value, ...)
end
