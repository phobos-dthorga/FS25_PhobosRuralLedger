PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.JobDetailDialog = PhobosRuralLedger.JobDetailDialog or {}

local JobDetailDialog = PhobosRuralLedger.JobDetailDialog
local JobDetailDialog_mt = Class(JobDetailDialog, MessageDialog)

function JobDetailDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or JobDetailDialog_mt)

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

function JobDetailDialog:onGuiSetupFinished()
    JobDetailDialog:superClass().onGuiSetupFinished(self)

    if self.jobDetailList ~= nil then
        if self.jobDetailList.setDataSource ~= nil then
            self.jobDetailList:setDataSource(self)
        end

        if self.jobDetailList.setDelegate ~= nil then
            self.jobDetailList:setDelegate(self)
        end
    end
end

function JobDetailDialog:onOpen()
    JobDetailDialog:superClass().onOpen(self)
    self:updateDisplay()

    if FocusManager ~= nil and FocusManager.setFocus ~= nil and self.jobDetailList ~= nil then
        FocusManager:setFocus(self.jobDetailList)
    end
end

function JobDetailDialog:setJobDetail(model)
    self.model = model or {}
    self.rows = self.model.rows or {}
    self:updateDisplay()
end

function JobDetailDialog:updateDisplay()
    local model = self.model or {}

    setText(self.jobDetailTitle, model.title or i18n("rl_job_detail_dialog_title", "Job Detail"))
    setText(self.jobDetailSubtitle, model.subtitle or "")
    reloadList(self.jobDetailList)
end

function JobDetailDialog:onClickBack()
    if self.close ~= nil then
        self:close()
        return
    end

    local super = JobDetailDialog:superClass()
    if super ~= nil and super.close ~= nil then
        super.close(self)
    end
end

function JobDetailDialog:getNumberOfSections()
    return 1
end

function JobDetailDialog:getNumberOfItemsInSection(list, section)
    if list == self.jobDetailList then
        return #self.rows
    end

    return 0
end

function JobDetailDialog:populateCellForItemInSection(list, section, index, cell)
    local line = cellAttribute(cell, "line")
    setText(line, self.rows[index] or "")
end
