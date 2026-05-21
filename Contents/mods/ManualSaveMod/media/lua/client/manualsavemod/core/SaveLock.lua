-- Core/SaveLock.lua
-- Gestisce il lock globale durante un salvataggio in corso.
-- Impedisce salvataggi multipli, delete, load e altre operazioni concorrenti.
---@diagnostic disable: undefined-global

ManualSave          = ManualSave or {}
ManualSave.SaveLock = ManualSave.SaveLock or {}

local _locked    = false
local _listeners = {}

--- Ritorna true se un salvataggio e' in corso.
---@return boolean
function ManualSave.SaveLock.isLocked()
    return _locked
end

--- Attiva il lock e notifica i listener.
function ManualSave.SaveLock.lock()
    if _locked then return end
    _locked = true
    for _, fn in ipairs(_listeners) do pcall(fn, true) end
end

--- Disattiva il lock e notifica i listener.
function ManualSave.SaveLock.unlock()
    if not _locked then return end
    _locked = false
    for _, fn in ipairs(_listeners) do pcall(fn, false) end
end

--- Registra una funzione chiamata con (true) al lock e (false) all'unlock.
---@param fn fun(locked:boolean)
function ManualSave.SaveLock.addListener(fn)
    table.insert(_listeners, fn)
end

--- Rimuove un listener precedentemente registrato.
---@param fn fun(locked:boolean)
function ManualSave.SaveLock.removeListener(fn)
    for i, f in ipairs(_listeners) do
        if f == fn then table.remove(_listeners, i); return end
    end
end

print("[ManualSaveMod] Core/SaveLock.lua loaded.")
