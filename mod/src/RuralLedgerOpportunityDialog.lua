PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.OpportunityDialog = PhobosRuralLedger.OpportunityDialog or {}

local OpportunityDialog = PhobosRuralLedger.OpportunityDialog
local OpportunityDialog_mt = Class(OpportunityDialog, MessageDialog)

function OpportunityDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or OpportunityDialog_mt)

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

function OpportunityDialog:onGuiSetupFinished()
    OpportunityDialog:superClass().onGuiSetupFinished(self)

    if self.opportunityList ~= nil then
        if self.opportunityList.setDataSource ~= nil then
            self.opportunityList:setDataSource(self)
        end

        if self.opportunityList.setDelegate ~= nil then
            self.opportunityList:setDelegate(self)
        end
    end
end

function OpportunityDialog:onOpen()
    OpportunityDialog:superClass().onOpen(self)
    self:updateDisplay()

    if FocusManager ~= nil and FocusManager.setFocus ~= nil and self.opportunityList ~= nil then
        FocusManager:setFocus(self.opportunityList)
    end
end

function OpportunityDialog:setOpportunities(model)
    self.model = model or {}
    self.rows = self.model.rows or {}
    self:updateDisplay()
end

function OpportunityDialog:updateDisplay()
    local model = self.model or {}

    setText(self.opportunityTitle, model.title or i18n("rl_opportunity_dialog_title", "Public Opportunities"))
    setText(self.opportunitySubtitle, model.subtitle or "")
    reloadList(self.opportunityList)
end

function OpportunityDialog:onClickBack()
    if self.close ~= nil then
        self:close()
        return
    end

    local super = OpportunityDialog:superClass()
    if super ~= nil and super.close ~= nil then
        super.close(self)
    end
end

function OpportunityDialog:getNumberOfSections()
    return 1
end

function OpportunityDialog:getNumberOfItemsInSection(list, section)
    if list == self.opportunityList then
        return #self.rows
    end

    return 0
end

function OpportunityDialog:populateCellForItemInSection(list, section, index, cell)
    local line = cellAttribute(cell, "line")
    setText(line, self.rows[index] or "")
end
