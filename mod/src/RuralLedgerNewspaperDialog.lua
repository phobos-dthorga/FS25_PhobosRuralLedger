PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.NewspaperDialog = PhobosRuralLedger.NewspaperDialog or {}

local NewspaperDialog = PhobosRuralLedger.NewspaperDialog
local NewspaperDialog_mt = Class(NewspaperDialog, MessageDialog)

function NewspaperDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or NewspaperDialog_mt)

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

function NewspaperDialog:onGuiSetupFinished()
    NewspaperDialog:superClass().onGuiSetupFinished(self)

    if self.newspaperList ~= nil then
        if self.newspaperList.setDataSource ~= nil then
            self.newspaperList:setDataSource(self)
        end

        if self.newspaperList.setDelegate ~= nil then
            self.newspaperList:setDelegate(self)
        end
    end
end

function NewspaperDialog:onOpen()
    NewspaperDialog:superClass().onOpen(self)
    self:updateDisplay()

    if FocusManager ~= nil and FocusManager.setFocus ~= nil and self.newspaperList ~= nil then
        FocusManager:setFocus(self.newspaperList)
    end
end

function NewspaperDialog:setEdition(model)
    self.model = model or {}
    self.rows = self.model.rows or {}
    self:updateDisplay()
end

function NewspaperDialog:updateDisplay()
    local model = self.model or {}

    setText(self.newspaperTitle, model.title or i18n("rl_newspaper_dialog_title", "Rural Newspaper"))
    setText(self.newspaperDateline, model.subtitle or "")
    setText(self.newspaperMasthead, model.masthead or i18n("rl_newspaper_masthead", "THE RURAL LEDGER"))
    setText(self.newspaperHeadline, model.headline or "")
    setText(self.newspaperSummary, model.summary or "")
    reloadList(self.newspaperList)
end

function NewspaperDialog:onClickBack()
    if self.close ~= nil then
        self:close()
        return
    end

    local super = NewspaperDialog:superClass()
    if super ~= nil and super.close ~= nil then
        super.close(self)
    end
end

function NewspaperDialog:getNumberOfSections()
    return 1
end

function NewspaperDialog:getNumberOfItemsInSection(list, section)
    if list == self.newspaperList then
        return #self.rows
    end

    return 0
end

function NewspaperDialog:populateCellForItemInSection(list, section, index, cell)
    local row = self.rows[index] or {}

    setText(cellAttribute(cell, "title"), row.title or "")
    setText(cellAttribute(cell, "body"), row.body or "")
end
