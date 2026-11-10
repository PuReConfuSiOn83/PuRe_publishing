# PuRe_publishing v0.1.1

Ingame-Publikationssystem für FiveM mit ESX Legacy, ox_lib, oxmysql, ox_inventory und ox_target.

## Umfang
- Zeitungsartikel mit Bildlinks, unveränderlichen Ausgabe-Snapshots und eigener Zeitungs-Lesegestaltung
- Zeitungskopf mit Ausgabedatum, Titelgeschichte, Titelbild und weiteren Meldungen
- Zeitungskauf an konfigurierten Zeitungsautomaten-Props
- Jedes Exemplar ist ab Kauf 24 Stunden lesbar; danach wird es beim Benutzungsversuch entfernt
- Speisekarten und Fahndungen mit Ablaufdatum
- Ingame-Editor mit Entwürfen, Live-Vorschau im Zeitungsstil, Veröffentlichung und Archivierung
- Anzeigeorte als ox_target-Boxzonen, im Spiel durch Administratoren platzierbar
- Job-/Rangberechtigungen pro Dokumenttyp

## Installation
1. `sql/install.sql` in die Datenbank importieren.
2. `install/ox_inventory_item.lua` in `ox_inventory/data/items.lua` übernehmen.
3. Ressource nach `ox_lib`, `es_extended`, `oxmysql`, `ox_inventory` und `ox_target` starten.
4. `ensure PuRe_publishing` in die server.cfg eintragen.
5. Mit `/publikation` die Redaktion öffnen.
6. Für Menü/Fahndung: Entwurf anlegen und veröffentlichen. Danach mit Administratorrechten unter **Anzeigeorte** die aktuelle Position als Boxzone verknüpfen.

## Konfiguration
`shared/config.lua` enthält Preis, Itemname, Automaten-Props, Dokumentlimits und Rechte.
Leere Joblisten bedeuten, dass der jeweilige Dokumenttyp allen Spielern offensteht.
Beispiel: `newspaper = { jobs = { weazel = 0 } }` bindet die Zeitung an den Job `weazel` ab Grad 0.

## Bildmaterial
Bilder werden als HTTPS-URL in der UI hinterlegt. Für produktiven Betrieb empfiehlt sich ein stabiler direkter Bildlink.

## Hinweise
- Autorenname: PuReConfuSiOn
- Das NUI bleibt unsichtbar, bis es geöffnet wird; es nutzt keinen Vollbild-Schwarzfilter und kein backdrop-filter.
- Dokument- und Rechteprüfungen laufen serverseitig. Clientseitige UI-Eingaben gelten nicht als Berechtigungsnachweis.
