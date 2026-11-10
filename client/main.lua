local uiOpen = false
local displayZones = {}

local function nui(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function setOpen(state)
    uiOpen = state
    SetNuiFocus(state, state)
    nui(state and 'show' or 'hide', {})
end

local function notify(message, kind)
    lib.notify({ description = message, type = kind or 'inform' })
end

local function openEditor()
    local data = lib.callback.await('pure_pub:server:editorData', false)
    if not data or not data.allowed then
        notify('Du hast keine Berechtigung für die Redaktion.', 'error')
        return
    end
    setOpen(true)
    nui('editor', data)
end

RegisterCommand(Config.Command, openEditor, false)

RegisterNUICallback('close', function(_, cb)
    setOpen(false)
    cb({ ok = true })
end)

RegisterNUICallback('saveDocument', function(data, cb)
    local result = lib.callback.await('pure_pub:server:saveDocument', false, data)
    cb(result or { ok = false, error = 'Keine Antwort vom Server.' })
end)

RegisterNUICallback('publishDocument', function(data, cb)
    local result = lib.callback.await('pure_pub:server:publishDocument', false, data.id)
    cb(result or { ok = false, error = 'Keine Antwort vom Server.' })
end)

RegisterNUICallback('deleteDocument', function(data, cb)
    local result = lib.callback.await('pure_pub:server:deleteDocument', false, data.id)
    cb(result or { ok = false, error = 'Keine Antwort vom Server.' })
end)

RegisterNUICallback('getPosition', function(_, cb)
    local coords = GetEntityCoords(PlayerPedId())
    cb({ x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(PlayerPedId()) })
end)

RegisterNUICallback('saveLocation', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    local result = lib.callback.await('pure_pub:server:saveLocation', false, {
        name = data.name, documentId = data.documentId,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = GetEntityHeading(PlayerPedId())
    })
    cb(result or { ok = false, error = 'Keine Antwort vom Server.' })
end)

RegisterNUICallback('deleteLocation', function(data, cb)
    local result = lib.callback.await('pure_pub:server:deleteLocation', false, data.id)
    cb(result or { ok = false, error = 'Keine Antwort vom Server.' })
end)

RegisterNUICallback('refreshEditor', function(_, cb)
    cb(lib.callback.await('pure_pub:server:editorData', false) or { allowed = false })
end)

local function showDocument(document)
    if not document then return end
    setOpen(true)
    nui('document', document)
end

RegisterNetEvent('pure_pub:client:openDocument', function(document)
    showDocument(document)
end)

local function loadDisplayZones(zones)
    for _, id in pairs(displayZones) do
        exports.ox_target:removeZone(id)
    end
    displayZones = {}
    for _, zone in ipairs(zones or {}) do
        local id = exports.ox_target:addBoxZone({
            name = ('pure_pub_display_%s'):format(zone.id),
            coords = vec3(zone.x, zone.y, zone.z),
            size = vec3(Config.DisplayBox.width, Config.DisplayBox.length, Config.DisplayBox.height),
            rotation = zone.heading or 0,
            debug = Config.Debug,
            drawSprite = false,
            options = {{
                name = ('pure_pub_read_%s'):format(zone.id),
                icon = 'fa-solid fa-book-open',
                label = zone.label,
                onSelect = function()
                    local doc = lib.callback.await('pure_pub:server:readAtLocation', false, zone.id)
                    if doc then showDocument(doc) else notify('Hier ist momentan kein gültiges Dokument ausgehängt.', 'error') end
                end
            }}
        })
        displayZones[#displayZones + 1] = id
    end
end

CreateThread(function()
    while GetResourceState('ox_target') ~= 'started' do Wait(250) end
    exports.ox_target:addModel(Config.NewspaperModels, {{
        name = 'pure_pub_newspaper',
        icon = 'fa-solid fa-newspaper',
        label = ('Zeitung kaufen ($%s)'):format(Config.NewspaperPrice),
        onSelect = function(data)
            local coords = GetEntityCoords(data.entity)
            local result = lib.callback.await('pure_pub:server:buyNewspaper', false, { x = coords.x, y = coords.y, z = coords.z })
            notify(result and result.message or 'Der Kauf ist fehlgeschlagen.', result and result.ok and 'success' or 'error')
        end
    }})
    local zones = lib.callback.await('pure_pub:server:getLocations', false)
    loadDisplayZones(zones)
end)

RegisterNetEvent('pure_pub:client:refreshLocations', function(zones)
    loadDisplayZones(zones)
end)

exports('useNewspaper', function(data, slot)
    exports.ox_inventory:useItem(data, function(usedData)
        if not usedData then return end
        local document = lib.callback.await('pure_pub:server:useNewspaper', false, slot)
        if document then showDocument(document) end
    end)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if uiOpen then SetNuiFocus(false, false) end
        for _, id in pairs(displayZones) do exports.ox_target:removeZone(id) end
    end
end)
