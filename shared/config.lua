Config = {}

Config.Debug = false
Config.Locale = 'de'
Config.Command = 'publikation'
Config.NewspaperItem = 'pure_newspaper'
Config.NewspaperPrice = 25
Config.NewspaperLifetimeHours = 24
Config.MaxTitleLength = 90
Config.MaxTextLength = 7000
Config.MaxArticles = 12
Config.MaxMenuEntries = 60
Config.MaxImageUrlLength = 500
Config.AdminGroups = { 'admin', 'superadmin' }
Config.NewspaperModels = {
    'prop_news_disp_01a', 'prop_news_disp_02a', 'prop_news_disp_02b',
    'prop_news_disp_03a', 'prop_news_disp_04a'
}
-- Jobname => Mindestgrad. Leere Tabelle bedeutet: Dokumenttyp ist für alle zugänglich.
Config.Permissions = {
    newspaper = { jobs = {} },
    menu = { jobs = {} },
    wanted = { jobs = {} },
    locations = { adminOnly = true }
}
Config.DisplayBox = { width = 1.4, length = 1.4, height = 2.0 }
Config.PhotoSchemes = { 'https' }
