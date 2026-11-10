local ESX = exports.es_extended:getSharedObject()
local resource = GetCurrentResourceName()
local actionTimes = {}

local function rateLimited(src, action, interval)
    local now = GetGameTimer()
    actionTimes[src] = actionTimes[src] or {}
    local last = actionTimes[src][action] or 0
    if now - last < interval then return true end
    actionTimes[src][action] = now
    return false
end

AddEventHandler('playerDropped', function()
    actionTimes[source] = nil
end)

local function log(message)
    if Config.Debug then print(('[%s] %s'):format(resource, message)) end
end

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, result = pcall(json.decode, value)
    return ok and type(result) == 'table' and result or fallback
end

local function identifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    return xPlayer and xPlayer.getIdentifier() or nil
end

local function hasAdmin(src)
    if src == 0 then return true end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local group = xPlayer.getGroup()
    for _, allowed in ipairs(Config.AdminGroups) do
        if group == allowed then return true end
    end
    return false
end

local function canEdit(src, docType)
    if hasAdmin(src) then return true end
    local permission = Config.Permissions[docType]
    if not permission then return false end
    local jobs = permission.jobs or {}
    if next(jobs) == nil then return true end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local job = xPlayer.getJob()
    local minimum = jobs[job.name]
    return minimum ~= nil and (job.grade or 0) >= minimum
end

local function sanitizeDocument(input)
    if type(input) ~= 'table' or not PurePub.ValidType(input.type) then return nil, 'Ungültiger Dokumenttyp.' end
    local title = PurePub.Trim(input.title)
    if title == '' or #title > Config.MaxTitleLength then return nil, 'Bitte einen gültigen Titel eintragen.' end
    local content = type(input.content) == 'table' and input.content or {}
    local cover = PurePub.SafeImageUrl(content.coverUrl)
    if cover == nil then return nil, 'Das Titelbild benötigt einen gültigen HTTPS-Bildlink.' end
    content.coverUrl = cover
    if input.type == 'newspaper' then
        if type(content.articles) ~= 'table' or #content.articles < 1 or #content.articles > Config.MaxArticles then
            return nil, ('Eine Ausgabe braucht 1 bis %s Artikel.'):format(Config.MaxArticles)
        end
        for _, article in ipairs(content.articles) do
            article.title = PurePub.Trim(article.title)
            article.body = PurePub.Trim(article.body)
            article.imageUrl = PurePub.SafeImageUrl(article.imageUrl) or ''
            if article.title == '' or #article.title > 120 or article.body == '' or #article.body > Config.MaxTextLength then
                return nil, 'Jeder Artikel braucht eine Überschrift und einen gültigen Text.'
            end
        end
    elseif input.type == 'menu' then
        if type(content.entries) ~= 'table' or #content.entries < 1 or #content.entries > Config.MaxMenuEntries then
            return nil, ('Die Speisekarte braucht 1 bis %s Einträge.'):format(Config.MaxMenuEntries)
        end
        for _, entry in ipairs(content.entries) do
            entry.name = PurePub.Trim(entry.name)
            entry.category = PurePub.Trim(entry.category)
            entry.description = PurePub.Trim(entry.description or '')
            entry.price = math.max(0, math.floor(tonumber(entry.price) or 0))
            if entry.name == '' or #entry.name > 100 or #entry.description > 500 then return nil, 'Ein Speisekarteneintrag ist ungültig.' end
        end
    elseif input.type == 'wanted' then
        content.subject = PurePub.Trim(content.subject)
        content.description = PurePub.Trim(content.description)
        content.lastSeen = PurePub.Trim(content.lastSeen or '')
        content.reward = math.max(0, math.floor(tonumber(content.reward) or 0))
        content.photoUrl = PurePub.SafeImageUrl(content.photoUrl) or ''
        if content.subject == '' or content.description == '' then return nil, 'Fahndung braucht eine Person und eine Beschreibung.' end
        local days = math.floor(tonumber(content.expiresInDays) or 7)
        content.expiresInDays = math.max(1, math.min(days, 365))
    end
    return { type = input.type, title = title, subtitle = PurePub.Trim(input.subtitle or ''):sub(1, 160), content = content }
end

local function documentRow(row)
    if not row then return nil end
    return {
        id = row.id, type = row.type, title = row.title, subtitle = row.subtitle,
        content = decode(row.content, {}), status = row.status,
        publishedAt = row.published_at, expiresAt = row.expires_at,
        author = row.author_name or 'Redaktion'
    }
end

local function getLocations()
    local rows = MySQL.query.await('SELECT id, label, document_id, x, y, z, heading FROM pure_publishing_locations ORDER BY label') or {}
    local result = {}
    for _, row in ipairs(rows) do
        result[#result + 1] = { id = row.id, label = row.label, documentId = row.document_id, x = row.x, y = row.y, z = row.z, heading = row.heading }
    end
    return result
end

local function refreshLocations()
    TriggerClientEvent('pure_pub:client:refreshLocations', -1, getLocations())
end

lib.callback.register('pure_pub:server:editorData', function(src)
    local types = {}
    for docType in pairs(PurePub.Types) do if canEdit(src, docType) then types[docType] = true end end
    local locationsAllowed = hasAdmin(src)
    if not next(types) and not locationsAllowed then return { allowed = false } end
    local rows = MySQL.query.await('SELECT * FROM pure_publishing_documents ORDER BY updated_at DESC LIMIT 100') or {}
    local docs = {}
    for _, row in ipairs(rows) do if canEdit(src, row.type) then docs[#docs + 1] = documentRow(row) end end
    return { allowed = true, types = types, documents = docs, locations = locationsAllowed and getLocations() or {}, canManageLocations = locationsAllowed }
end)

lib.callback.register('pure_pub:server:saveDocument', function(src, input)
    if rateLimited(src, 'saveDocument', 700) then return { ok = false, error = 'Bitte kurz warten.' } end
    if type(input) ~= 'table' then return { ok = false, error = 'Ungültige Eingabe.' } end
    local clean, err = sanitizeDocument(input)
    if not clean then return { ok = false, error = err } end
    if not canEdit(src, clean.type) then return { ok = false, error = 'Du darfst diesen Dokumenttyp nicht bearbeiten.' } end
    local authorId = identifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    local authorName = xPlayer and xPlayer.getName() or 'Redaktion'
    local id = type(input.id) == 'string' and input.id or nil
    local row = id and MySQL.single.await('SELECT id, type, owner_identifier FROM pure_publishing_documents WHERE id = ?', { id }) or nil
    if row then
        if row.type ~= clean.type or (row.owner_identifier ~= authorId and not hasAdmin(src)) then return { ok = false, error = 'Dieses Dokument gehört einer anderen Redaktion.' } end
        MySQL.update.await('UPDATE pure_publishing_documents SET title = ?, subtitle = ?, content = ?, status = \'draft\', updated_at = NOW() WHERE id = ?', {
            clean.title, clean.subtitle, json.encode(clean.content), id
        })
    else
        id = ('doc_%s_%s'):format(os.time(), math.random(100000, 999999))
        MySQL.insert.await('INSERT INTO pure_publishing_documents (id, type, title, subtitle, content, status, owner_identifier, author_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?, \'draft\', ?, ?, NOW(), NOW())', {
            id, clean.type, clean.title, clean.subtitle, json.encode(clean.content), authorId or 'console', authorName
        })
    end
    return { ok = true, id = id, message = 'Entwurf gespeichert.' }
end)

lib.callback.register('pure_pub:server:publishDocument', function(src, id)
    if rateLimited(src, 'publishDocument', 1000) then return { ok = false, error = 'Bitte kurz warten.' } end
    if type(id) ~= 'string' then return { ok = false, error = 'Ungültige Dokument-ID.' } end
    local row = MySQL.single.await('SELECT * FROM pure_publishing_documents WHERE id = ?', { id })
    if not row or not canEdit(src, row.type) then return { ok = false, error = 'Dokument nicht gefunden oder keine Berechtigung.' } end
    if row.owner_identifier ~= identifier(src) and not hasAdmin(src) then return { ok = false, error = 'Nur der Ersteller oder ein Administrator kann veröffentlichen.' } end
    local content = decode(row.content, {})
    local expiresAt = nil
    if row.type == 'wanted' then expiresAt = os.time() + (math.floor(tonumber(content.expiresInDays) or 7) * 86400) end
    MySQL.update.await('UPDATE pure_publishing_documents SET status = \'published\', published_at = NOW(), expires_at = ?, updated_at = NOW() WHERE id = ?', {
        expiresAt and os.date('%Y-%m-%d %H:%M:%S', expiresAt) or nil, id
    })
    if row.type == 'newspaper' then
        local editionId = ('edition_%s_%s'):format(os.time(), math.random(100000, 999999))
        local snapshot = { type = row.type, title = row.title, subtitle = row.subtitle, content = content, author = row.author_name or 'Redaktion', publishedAt = os.date('%Y-%m-%d %H:%M:%S') }
        MySQL.insert.await('INSERT INTO pure_publishing_editions (id, document_id, snapshot, published_at) VALUES (?, ?, ?, NOW())', {
            editionId, id, json.encode(snapshot)
        })
    end
    refreshLocations()
    return { ok = true, message = 'Dokument veröffentlicht.' }
end)

lib.callback.register('pure_pub:server:deleteDocument', function(src, id)
    if rateLimited(src, 'deleteDocument', 1000) then return { ok = false, error = 'Bitte kurz warten.' } end
    if type(id) ~= 'string' then return { ok = false, error = 'Ungültige Dokument-ID.' } end
    local row = MySQL.single.await('SELECT id, type, owner_identifier FROM pure_publishing_documents WHERE id = ?', { id })
    if not row or not canEdit(src, row.type) then return { ok = false, error = 'Dokument nicht gefunden oder keine Berechtigung.' } end
    if row.owner_identifier ~= identifier(src) and not hasAdmin(src) then return { ok = false, error = 'Nur der Ersteller oder ein Administrator kann löschen.' } end
    MySQL.update.await('UPDATE pure_publishing_documents SET status = \'archived\', updated_at = NOW() WHERE id = ?', { id })
    refreshLocations()
    return { ok = true, message = 'Dokument archiviert.' }
end)

lib.callback.register('pure_pub:server:saveLocation', function(src, input)
    if rateLimited(src, 'saveLocation', 1000) then return { ok = false, error = 'Bitte kurz warten.' } end
    if not hasAdmin(src) then return { ok = false, error = 'Nur Administratoren dürfen Anzeigeorte verwalten.' } end
    if type(input) ~= 'table' or type(input.name) ~= 'string' or #PurePub.Trim(input.name) < 2 or #input.name > 80 or type(input.documentId) ~= 'string' then
        return { ok = false, error = 'Name und Dokument sind erforderlich.' }
    end
    local doc = MySQL.single.await('SELECT id, status FROM pure_publishing_documents WHERE id = ?', { input.documentId })
    if not doc then return { ok = false, error = 'Dokument nicht gefunden.' } end
    local c = input.coords or {}
    if type(c.x) ~= 'number' or type(c.y) ~= 'number' or type(c.z) ~= 'number' then return { ok = false, error = 'Position ungültig.' } end
    local id = ('loc_%s_%s'):format(os.time(), math.random(100000, 999999))
    MySQL.insert.await('INSERT INTO pure_publishing_locations (id, label, document_id, x, y, z, heading, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())', {
        id, PurePub.Trim(input.name), input.documentId, c.x, c.y, c.z, tonumber(input.heading) or 0
    })
    refreshLocations()
    return { ok = true, message = 'Anzeigeort gespeichert.' }
end)

lib.callback.register('pure_pub:server:deleteLocation', function(src, id)
    if not hasAdmin(src) then return { ok = false, error = 'Nur Administratoren dürfen Anzeigeorte verwalten.' } end
    MySQL.update.await('DELETE FROM pure_publishing_locations WHERE id = ?', { id })
    refreshLocations()
    return { ok = true, message = 'Anzeigeort entfernt.' }
end)

lib.callback.register('pure_pub:server:getLocations', function() return getLocations() end)

lib.callback.register('pure_pub:server:readAtLocation', function(_, id)
    local location = MySQL.single.await('SELECT document_id FROM pure_publishing_locations WHERE id = ?', { id })
    if not location then return nil end
    local row = MySQL.single.await([[SELECT * FROM pure_publishing_documents
        WHERE id = ? AND status = 'published' AND (expires_at IS NULL OR expires_at > NOW())]], { location.document_id })
    return documentRow(row)
end)

lib.callback.register('pure_pub:server:buyNewspaper', function(src, coords)
    if rateLimited(src, 'buyNewspaper', 1500) then return { ok = false, message = 'Bitte kurz warten.' } end
    if type(coords) ~= 'table' or type(coords.x) ~= 'number' then return { ok = false, message = 'Automat nicht erreichbar.' } end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return { ok = false, message = 'Spieler nicht gefunden.' } end
    local p = GetEntityCoords(ped)
    if #(p - vector3(coords.x, coords.y, coords.z)) > 4.0 then return { ok = false, message = 'Du bist zu weit vom Automaten entfernt.' } end
    local edition = MySQL.single.await('SELECT id, snapshot FROM pure_publishing_editions ORDER BY published_at DESC LIMIT 1')
    if not edition then return { ok = false, message = 'Es ist noch keine Zeitungsausgabe verfügbar.' } end
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.getMoney() < Config.NewspaperPrice then return { ok = false, message = 'Du hast nicht genug Bargeld.' } end
    local expiresAt = os.time() + (Config.NewspaperLifetimeHours * 3600)
    local metadata = { editionId = edition.id, expiresAt = expiresAt, label = 'Zeitung', description = 'Läuft nach 24 Stunden ab.' }
    if not exports.ox_inventory:CanCarryItem(src, Config.NewspaperItem, 1, metadata) then return { ok = false, message = 'Dein Inventar ist voll.' } end
    xPlayer.removeMoney(Config.NewspaperPrice)
    local success = exports.ox_inventory:AddItem(src, Config.NewspaperItem, 1, metadata)
    if not success then xPlayer.addMoney(Config.NewspaperPrice); return { ok = false, message = 'Die Zeitung konnte nicht ausgegeben werden.' } end
    return { ok = true, message = 'Zeitung gekauft.' }
end)

lib.callback.register('pure_pub:server:useNewspaper', function(src, slotId)
    if rateLimited(src, 'useNewspaper', 800) then return nil end
    local slot = exports.ox_inventory:GetSlot(src, tonumber(slotId))
    if not slot or slot.name ~= Config.NewspaperItem then return nil end
    local metadata = slot.metadata or {}
    local expiresAt = tonumber(metadata.expiresAt)
    if not expiresAt or expiresAt <= os.time() then
        exports.ox_inventory:RemoveItem(src, Config.NewspaperItem, 1, nil, slot.slot)
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Diese Zeitung ist abgelaufen.' })
        return nil
    end
    local edition = MySQL.single.await('SELECT snapshot FROM pure_publishing_editions WHERE id = ?', { metadata.editionId })
    return edition and decode(edition.snapshot, nil) or nil
end)

MySQL.ready(function()
    local zones = getLocations()
    TriggerClientEvent('pure_pub:client:refreshLocations', -1, zones)
    log(('Gestartet; %s Anzeigeorte geladen.'):format(#zones))
end)
