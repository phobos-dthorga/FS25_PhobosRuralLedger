PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.HistoryDialog = PhobosRuralLedger.HistoryDialog or {}

local HistoryDialog = PhobosRuralLedger.HistoryDialog
local HistoryDialog_mt = Class(HistoryDialog, MessageDialog)

function HistoryDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or HistoryDialog_mt)

    self.model = nil
    self.rows = {}

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

function HistoryDialog:onGuiSetupFinished()
    HistoryDialog:superClass().onGuiSetupFinished(self)

    if self.historyList ~= nil then
        if self.historyList.setDataSource ~= nil then
            self.historyList:setDataSource(self)
        end

        if self.historyList.setDelegate ~= nil then
            self.historyList:setDelegate(self)
        end
    end
end

function HistoryDialog:onOpen()
    HistoryDialog:superClass().onOpen(self)
    self:updateDisplay()

    if FocusManager ~= nil and FocusManager.setFocus ~= nil and self.historyList ~= nil then
        FocusManager:setFocus(self.historyList)
    end
end

function HistoryDialog:setHistory(model)
    self.model = model or {}
    self.rows = self.model.rows or {}
    self:updateDisplay()
end

function HistoryDialog:updateDisplay()
    local model = self.model or {}

    setText(self.historyTitle, model.title or i18n("rl_history_dialog_title", "Property History"))
    setText(self.historySubtitle, model.subtitle or "")
    reloadList(self.historyList)
end

function HistoryDialog:onClickBack()
    if self.close ~= nil then
        self:close()
        return
    end

    local super = HistoryDialog:superClass()
    if super ~= nil and super.close ~= nil then
        super.close(self)
    end
end

function HistoryDialog:getNumberOfSections()
    return 1
end

function HistoryDialog:getNumberOfItemsInSection(list, section)
    if list == self.historyList then
        return #self.rows
    end

    return 0
end

function HistoryDialog:populateCellForItemInSection(list, section, index, cell)
    local line = cellAttribute(cell, "line")
    setText(line, self.rows[index] or "")
end
