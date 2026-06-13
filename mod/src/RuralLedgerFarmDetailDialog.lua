PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.FarmDetailDialog = PhobosRuralLedger.FarmDetailDialog or {}

local FarmDetailDialog = PhobosRuralLedger.FarmDetailDialog
local FarmDetailDialog_mt = Class(FarmDetailDialog, MessageDialog)

function FarmDetailDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or FarmDetailDialog_mt)

    self.detail = nil
    self.detailRows = {}

    return self
end

local function i18n(key, fallback, ...)
    if PhobosRuralLedger.I18n ~= nil and PhobosRuralLedger.I18n.get ~= nil then
        return PhobosRuralLedger.I18n.get(key, fallback, ...)
    end

    if select("#", ...) > 0 then
        local ok, value = pcall(string.format, fallback or key, ...)
        if ok then
            return value
        end
    end

    return fallback or key
end

local function setText(element, value)
    if element ~= nil and element.setText ~= nil then
        element:setText(tostring(value or ""))
    end
end

local function reloadList(list)
    if list ~= nil and list.reloadData ~= nil then
        list:reloadData()
    end
end

local function cellAttribute(cell, name)
    if cell ~= nil and cell.getAttribute ~= nil then
        return cell:getAttribute(name)
    end

    return nil
end

function FarmDetailDialog:onGuiSetupFinished()
    FarmDetailDialog:superClass().onGuiSetupFinished(self)

    if self.detailList ~= nil then
        if self.detailList.setDataSource ~= nil then
            self.detailList:setDataSource(self)
        end

        if self.detailList.setDelegate ~= nil then
            self.detailList:setDelegate(self)
        end
    end
end

function FarmDetailDialog:onOpen()
    FarmDetailDialog:superClass().onOpen(self)
    self:updateDisplay()

    if FocusManager ~= nil and FocusManager.setFocus ~= nil and self.detailList ~= nil then
        FocusManager:setFocus(self.detailList)
    end
end

function FarmDetailDialog:setFarmDetail(detail)
    self.detail = detail or {}
    self.detailRows = self.detail.lines or {}
    self:updateDisplay()
end

function FarmDetailDialog:updateDisplay()
    local detail = self.detail or {}
    local status = detail.status or {}
    local explanation = detail.explanation or {}

    setText(self.detailTitle, detail.displayName or i18n("rl_detail_no_farm_title", "No farm selected"))
    setText(self.detailSubtitle, detail.profileLabel or "")
    setText(self.detailHeadline, status.headline or "")
    setText(self.detailCause, i18n(
        "rl_detail_primary_pressure",
        "Primary pressure: %s",
        tostring(explanation.mainCause or i18n("rl_stress_unknown", "Unknown"))
    ))
    setText(self.detailMeaning, explanation.playerMeaning or "")
    reloadList(self.detailList)
end

function FarmDetailDialog:onClickBack()
    if self.close ~= nil then
        self:close()
        return
    end

    local super = FarmDetailDialog:superClass()
    if super ~= nil and super.close ~= nil then
        super.close(self)
    end
end

function FarmDetailDialog:getNumberOfSections()
    return 1
end

function FarmDetailDialog:getNumberOfItemsInSection(list, section)
    if list == self.detailList then
        return #self.detailRows
    end

    return 0
end

function FarmDetailDialog:populateCellForItemInSection(list, section, index, cell)
    local text = self.detailRows[index] or ""
    local line = cellAttribute(cell, "line")

    setText(line, text)
end
