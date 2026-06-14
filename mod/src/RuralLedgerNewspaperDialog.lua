PhobosRuralLedger = PhobosRuralLedger or {}
PhobosRuralLedger.NewspaperDialog = PhobosRuralLedger.NewspaperDialog or {}

local NewspaperDialog = PhobosRuralLedger.NewspaperDialog
local NewspaperDialog_mt = Class(NewspaperDialog, MessageDialog)

function NewspaperDialog.new(target, customMt)
    local self = MessageDialog.new(target, customMt or NewspaperDialog_mt)

    self.model = nil
    self.rows = {}
    self.openSource = "unknown"
    self.closeCleanupDone = false

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

local function updateNewspaperDiagnostics(source, cleanupStatus)
    if PhobosRuralLedger == nil then
        return
    end

    local state = PhobosRuralLedger.getState ~= nil and PhobosRuralLedger.getState() or PhobosRuralLedger.state
    if state == nil then
        return
    end

    state.newspaper = state.newspaper or {}
    local newspaper = state.newspaper
    newspaper.diagnostics = newspaper.diagnostics or {}

    if source ~= nil then
        newspaper.diagnostics.lastDialogOpenSource = tostring(source)
    end

    if cleanupStatus ~= nil then
        newspaper.diagnostics.lastDialogCloseCleanup = tostring(cleanupStatus)
    end
end

local function logInfoOnce(key, message, ...)
    if PhobosRuralLedger == nil or PhobosRuralLedger.logInfo == nil then
        return
    end

    PhobosRuralLedger._newspaperDialogLogState = PhobosRuralLedger._newspaperDialogLogState or {}
    key = tostring(key or message or "newspaper-dialog")

    if PhobosRuralLedger._newspaperDialogLogState[key] == true then
        return
    end

    PhobosRuralLedger._newspaperDialogLogState[key] = true
    PhobosRuralLedger.logInfo(message, ...)
end

local function clearFocus(element)
    if FocusManager == nil then
        return
    end

    if FocusManager.setFocus ~= nil then
        FocusManager:setFocus(nil)
    elseif FocusManager.removeFocus ~= nil and element ~= nil then
        FocusManager:removeFocus(element)
    end
end

local function restoreGameplayPointer()
    local restored = false

    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        g_inputBinding:setShowMouseCursor(false)
        restored = true
    end

    if showPointer ~= nil then
        showPointer(false)
        restored = true
    end

    return restored
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
    self.closeCleanupDone = false
    NewspaperDialog:superClass().onOpen(self)
    self:updateDisplay()

    if FocusManager ~= nil and FocusManager.setFocus ~= nil and self.newspaperList ~= nil then
        FocusManager:setFocus(self.newspaperList)
    end

    updateNewspaperDiagnostics(self.openSource, nil)

    if self.openSource == "autoDelivery" then
        logInfoOnce(
            "newspaper-dialog-auto-open",
            "Rural Ledger newspaper dialog opened from auto delivery."
        )
    end
end

function NewspaperDialog:setOpenContext(source)
    self.openSource = tostring(source or "unknown")
    updateNewspaperDiagnostics(self.openSource, nil)

    if self.openSource == "autoDelivery" then
        logInfoOnce(
            "newspaper-dialog-auto-open",
            "Rural Ledger newspaper dialog opened from auto delivery."
        )
    end
end

function NewspaperDialog:setEdition(model, options)
    if options ~= nil and options.source ~= nil then
        self:setOpenContext(options.source)
    end

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
        self:performCloseCleanup("button")
        return
    end

    local super = NewspaperDialog:superClass()
    if super ~= nil and super.close ~= nil then
        super.close(self)
        self:performCloseCleanup("button")
    end
end

function NewspaperDialog:onClose()
    local super = NewspaperDialog:superClass()
    if super ~= nil and super.onClose ~= nil then
        super.onClose(self)
    end

    self:performCloseCleanup("onClose")
end

function NewspaperDialog:performCloseCleanup(reason)
    if self.closeCleanupDone == true then
        return false
    end

    self.closeCleanupDone = true

    if self.openSource == "autoDelivery" then
        clearFocus(self.newspaperList)
        local restored = restoreGameplayPointer()
        local status = restored and "autoDeliveryRestored" or "autoDeliveryNoRuntimeApi"
        updateNewspaperDiagnostics(self.openSource, status)
        logInfoOnce(
            "newspaper-dialog-auto-cleanup",
            "Rural Ledger newspaper dialog restored gameplay input after auto delivery close (%s).",
            tostring(reason or "unknown")
        )
        return true
    end

    updateNewspaperDiagnostics(self.openSource, "screenArchiveNoGameplayCleanup")
    return false
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
