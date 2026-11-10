-- In ox_inventory/data/items.lua ergänzen:
['pure_newspaper'] = {
    label = 'Zeitung',
    weight = 150,
    stack = false,
    degrade = 1440,
    decay = true,
    close = true,
    consume = 0,
    description = 'Eine aktuelle Zeitungsausgabe.',
    client = {
        export = 'PuRe_publishing.useNewspaper'
    }
},
