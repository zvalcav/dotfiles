# scripty pro zalohovani
- scripty umoznuji hlidani pomoci zabbixove sablony
- `git clone git@git.tlapnet.dev:tools/bash-scripts.git /usr/local/bash-scripty`
- staci stahnout script initialize, ktery provede git clone do `/usr/local/bash-scripty` - cestu zachovavat
- pokud udelas git clone rucne, pridej na konec parametr s cestou `/usr/local/bash-scripty`
- spust script `initialize`
- nasledne staci pustit script, ktery chces pouzivat `./script-name`
  - zapise se konfiguracni soubor do `/usr/local/etc/` - nutno upravit a povolit spousteni
  - zapise se cron soubor do `/etc/cron.d/`
- na server, kam scripty nasadis, aplikuj sablonu `Tlapnet Active Scripty` - budou se hlidat