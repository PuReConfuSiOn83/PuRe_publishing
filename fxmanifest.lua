fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'PuRe_publishing'
author 'PuReConfuSiOn'
description 'Ingame-Publikationssystem für Zeitungen, Speisekarten und Fahndungen'
version '0.1.1'

ui_page 'web/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/utils.lua'
}

client_scripts { 'client/main.lua' }
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files { 'web/index.html', 'web/style.css', 'web/app.js' }

dependencies { 'es_extended', 'ox_lib', 'oxmysql', 'ox_inventory', 'ox_target' }
