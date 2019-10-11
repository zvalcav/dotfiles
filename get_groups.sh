#!/bin/bash
#mysql-backup
# script get_groups.sh slouzi k synchronizaci pripojnych bodu z NMS do Adminusu. Jedna se o kritickou vec,
# takze je potreba ho mit znacne pod kontrolou
set -o pipefail

VERSION_MAJOR=1
VERSION_MINOR=0
VERSION_PATCH=0
VERSION="$VERSION_MAJOR.$VERSION_MINOR.$VERSION_PATCH"

#LIST
#_PROMENNE
#_EXITY
#_LOGOVANI
#_PODMINKY
#_KONFIGURACE
#_MYSQL_BACKUP_CRON
#_ZALOHA

# pri predani parametru -x provede zapnuti debug logu
if [ "$1" = "-x" ]
then
	set -x
fi

# vypsani verze
if [ "$1" = "-V" -o "$1" = "--version" ]
then
	echo "$VERSION"
	exit 0
fi

#_PROMENNE
scriptName="get_groups.sh"
todayDateTime="$(date +%F_%H-%M)"

#konfigurace pro soubor s heslem
mysqlDefaultsFile="/home/shaperd/.my.cnf"
postgresqlDefaultsFile="/home/shaperd/.pgpass"

#cesta ke scriptu
scriptDir="/usr/local/bash-scripts"
verbose=0
deBug=0

if [ "$1" = "-h" -o "$1" = "--help" ]
then
	echo -e "\n
script slouzi pro pravidelnou synchronizaci pripojnych bodu z NMS do Adminusu
pri behu scriptu se nesmi provadet export pro shapery, protoze se mazou veskere pripojne body
script se vola standardne cronem v 6:00 a 20:00 - tyto casy se vynechavaji pro exportni scripty
podporovane parametry:
-x                  Debug vystup scriptu
-V | --version      vypis verze scriptu
-c                  vynuceny zapis konfiguracniho souboru - bude prepsan a zazalohovan stavajici
-h | --help         vypis napovedy"
	exit 0
fi

#_LOGOVANI

#nacteni definice funkci Log,LogError,RvLog,MailSend z knihovny
. "$scriptDir"/funkce	

Log "script ($scriptName) - zacatek"
echo "$$" > "$startFile"
Log "($startFile) set to ($$)"

#funkce pro zapis souboru pro pristup do mysql
write_mysqlDefaultsFile()
{
	{
		echo "[mysql]"
		echo "user=MYSQL_USER"
		echo "password='MYSQL_PASSWORD'"
		echo "default-character-set=utf8mb4"
	} > "$mysqlDefaultsFile"
	chmod 600 "$mysqlDefaultsFile"
}

#funkce pro zapis souboru pro pristup do postgresql
write_postgresqlDefaultsFile()
{
	{
		echo "# hostname:port:database:username:password"
		echo "#*:5432:nms:shaperd:heslo - priklad konfigurace"
		echo "HOST:5432:DATABASE:USER:PASSWORD"
	} > "$postgresqlDefaultsFile"
	chmod 600 "$postgresqlDefaultsFile"
}

#_KONFIGURACE
# zapise konfiguracni soubor, ze ktereho bude nasledne nacitat hodnoty
write()
{
	if [ -f "$configFile" ]
	then
		cp -a "$configFile" "${configFile}.back"
		RvLog "provedena zaloha konfigurace do (${configFile}.back)"
	fi

	# vychozi podoba konfiguracniho souboru
	{
		echo "# vypne/zapne (1/0) provadeni scriptu"
		echo "# pro samotne spousteni scriptu je potreba vytvorit radek v cronu uzivatele shaperd"
		echo "# je nutno dodrzet nize stanovene casy a na tyto chvile vynechat volani exportniho scriptu"
		echo "# DOCHAZI K MAZANI VESKERYCH PRIPOJNYCH BODU. PRI NEDODRZENI HROZI POTIZE"
		echo "#0 6 * * * /home/shaperd/get_groups.sh"
		echo "#0 20 * * * /home/shaperd/get_groups.sh"
		echo "disabled=1"
		echo ""
		echo "# definuje adresy pro posilani notifikacnich mailu - oddelene mezerami"
		echo "mailNotification=\"vaclav.serejch@tlapnet.cz vaclav.zindulka@tlapnet.cz davfia@atlas.cz\""
		echo ""
		echo "# nastavuje, do jake mysql databaze a pod jakym userem bude script sahat"
		echo "# heslo se nastavuje v ($mysqlDefaultsFile)"
		echo "mysqlUser=\"MYSQL_USER\""
		echo "mysqlDatabase=\"MYSQL_DATABASE\""
		echo ""
		echo "# nastavuje, do jake postgresql databaze a pod jakym userem bude script sahat"
		echo "# heslo se nastavuje v ($postgresqlDefaultsFile)"
		echo "psqlUser=\"POSTGRESQL_USER\""
		echo "psqlDatabase=\"POSTGRESQL_DATABASE\""
	} > "$configFile"

	LogErrorVerbose "zapsan konfiguracni soubor ($configFile) pro server ($HOSTNAME) - nutno upravit"

	# pri zapisu konfiguracniho souboru zapise i vychozi soubory pro pristup
	write_mysqlDefaultsFile
	LogErrorVerbose "zapsan novy konfiguracni soubor ($mysqlDefaultsFile) pro server ($HOSTNAME) - nutno upravit"

	write_postgresqlDefaultsFile
	LogErrorVerbose "zapsan novy konfiguracni soubor ($postgresqlDefaultsFile) pro server ($HOSTNAME) - nutno upravit"
}

#pokud neni konfiguracni soubor, nebo byl predan parametr -c
if [ ! -f "$configFile" ] || [ "$1" = "-c" ]
then
	write
	MailSend
	exit 12
fi

# kontrola existence config souboru
if [ -f "$configFile" ]
then
	. "$configFile"
	Log "nacten konfiguracni soubor ($configFile)"
else
	LogErrorVerbose "Nebyl nalezen konfiguracni soubor ($configFile)"
	exit 13
fi

#nastavenim disabled na 1 se vypne spousteni scriptu, uprav $configFile, mail se neposila
if [ "$disabled" -eq 1 ]
then
	LogErrorVerbose "script ($scriptName) byl disablovan v konfiguracnim souboru ($configFile)"
	MailSend
	exit 14
fi

#kontrola, zda mysqlPassword neobsahuje vychozi heslo
if [ -f "$mysqlDefaultsFile" -a $(grep -c "MYSQL_PASSWORD" "$mysqlDefaultsFile") -ne 0 ]
then
	LogErrorVerbose "POZOR, neni nastaveno heslo pro mysql-backup v [$mysqlDefaultsFile]"
	MailSend
	exit 15
fi

#kontrola, zda mysqlPassword neobsahuje vychozi heslo
if [ -f "$postgresqlDefaultsFile" -a $(grep -c "DATABASE:USER:PASSWORD" "$postgresqlDefaultsFile") -ne 0 ]
then
	LogErrorVerbose "POZOR, neni nastaveno heslo pro pristup do postgresql v [$postgresqlDefaultsFile]"
	MailSend
	exit 16
fi

# kontrola nacteni promennych z konfiguracniho souboru
if [ -z "$psqlUser" -o -z "$psqlDatabase" -o -z "$mysqlUser" -o -z "$mysqlDatabase" -o -z "$mailNotification" ]
then
	LogErrorVerbose "POZOR, neni nastavena nektera z promennych v konfiguracnim souboru [$configFile]"
	MailSend
	exit 17
fi

# kontrola vychozich hodnot konfiguracniho souboru
if [ $(grep -c "POSTGRESQL_DATABASE\|POSTGRESQL_USER\|MYSQL_DATABASE\|MYSQL_USER" "$configFile") -ne 0 ]
then
	LogErrorVerbose "POZOR, neni nastavena nektera z promennych v konfiguracnim souboru [$configFile]"
	MailSend
	exit 18
fi

# vytvoreni tabulky pro nahrani ip adres vsech klientu - POSTGRESQL - CREATE TABLE
if ! psql -U"$psqlUser" "$psqlDatabase"\
	-c "CREATE TABLE IF NOT EXISTS adminus_ips_get (ip varchar(40));" &> /dev/null
then
	LogErrorVerbose "Problem pri tvorbe tabulky adminus_ips_get v postgresql databazi: ($psqlDatabase) pod uzivatelem: ($psqlUser)"
	exit 1
fi

# vymazani tabulky pred jejim plnenim - POSTGRESQL - DELETE FROM TABLE
if ! psql -U"$psqlUser" "$psqlDatabase" -c "DELETE FROM adminus_ips_get;" > /dev/null
then
	LogErrorVerbose "Problem pri mazani obashu tabulky adminus_ips_get v postgresql databazi: ($psqlDatabase) pod uzivatelem: ($psqlUser)"
	exit 2
fi

# select z databaze adminusu, kdy se vypisou veskere adresy klientu
# postgresql si je nacte do tabulky adminus_ips_get
if ! mysql -u"$mysqlUser" --defaults-file="$mysqlDefaultsFile" "$mysqlDatabase" --batch\
#	-e "SELECT ip FROM adminus_ip_address;"\
#	| grep -v "ip" | psql -U"$psqlUser" "$psqlDatabase" -c "COPY adminus_ips_get FROM stdin;" > /dev/null
	-e "SELECT IFNULL(ip, m_adminustlapnetshaping_subnet) AS ip FROM adminus_ip_address;"\
	| grep -v "ip" | psql -U"$psqlUser" "$psqlDatabase" -c "COPY adminus_ips_get FROM stdin;" > /dev/null
then
	LogErrorVerbose "Problem pri selectu z tabulky adminus_ip_address v mysql databazi: ($mysqlDatabase) nebo jejim vkladani do tabulky adminus_ips_get v postgresql databazi: ($psqlDatabase) pod uzivatelem: ($psqlUser)"
	exit 3
fi

# vymazani tabulky pripojnych bodu pred plnenim
if ! mysql -u"$mysqlUser" --defaults-file="$mysqlDefaultsFile" "$mysqlDatabase"\
	-e "SET FOREIGN_KEY_CHECKS=0;DELETE FROM adminustlapnetshaping_shape_group;" > /dev/null
then
	LogErrorVerbose "Problem pri vypinani kontroly cizich klicu, nebo mazani obsahu tabulky adminustlapnetshaping_shape_group v mysql databazi: ($mysqlDatabase) pod uzivatelem: ($mysqlUser)"
	exit 5
fi


if ! mysql -u"$mysqlUser" --defaults-file="$mysqlDefaultsFile" "$mysqlDatabase"\
	-e "SET FOREIGN_KEY_CHECKS=0;TRUNCATE adminus_ip_address_range;" > /dev/null
then
	LogErrorVerbose "Problem pri vypinani kontroly cizich klicu, nebo mazani obsahu tabulky adminus_ip_address_range v mysql databazi: ($mysqlDatabase) pod uzivatelem: ($mysqlUser)"
	exit 6
fi

# select z psql s porovnanim a nahrazenim hodnot -A bez formatovani, -F, - oddelovac ,
# sed nahrazuje zacatky a konce radku prislusnou zavorkou a veskere hodntoy obali '',
# za ukoncovaci zavorku tez doplni carku a tr to spoji do jedne lajny, na zaver se na zacatek prida insert into
# a na konci se nahradi , za ; - pak se to cele skrz pipe posle do mysql
if ! psql -U"$psqlUser" "$psqlDatabase" -A -F, -c "
SELECT
   i.nms_device_interface_id AS groupId,
   CONCAT(UNACCENT(e.name), ' / ', UNACCENT(d.identificator), ' / ', UNACCENT(c.identificator), ' / ', UNACCENT(b.name)) AS groupName,
   g.ssid AS groupSSID
FROM nms_ip_address AS i
JOIN adminus_ips_get AS t
ON (select inet(t.ip) << inet(i.ipv4)) = true OR
   (select inet(i.ipv4) <<= cidr(t.ip)) = true
	
JOIN nms_device_interface AS b
ON i.nms_device_interface_id = b.id
	
JOIN nms_device AS c
ON b.nms_device_id = c.id
	
JOIN nms_pop AS d
ON c.nms_pop_id = d.id
	
JOIN nms_pop_area AS e
ON d.nms_pop_area_id = e.id

LEFT JOIN nms_port_has_interface AS f
ON b.id = f.nms_device_interface_id

LEFT JOIN nms_antenna AS g
ON f.nms_port_id = g.nms_port_id

WHERE (i.nms_device_interface_id IN (2629, 3547, 6182) AND g.ssid IS NOT NULL)
OR (i.nms_device_interface_id NOT IN (2629, 3547, 6182))
GROUP BY groupId, groupName, groupSSID
ORDER BY groupId;" | grep -v "groupid,groupname,groupssid\|rows"\
	| sed -e "s/,/','/g" -e "s/^/('/g" -e "s/$/'),/g" | tr '\n' ' '\
	| sed -e "s/^/INSERT INTO adminustlapnetshaping_shape_group (id, name, identificator) VALUES/g"\
	-e "s/, $/;/g" | tee get_group.dump\
	| mysql -u"$mysqlUser" --defaults-file="$mysqlDefaultsFile" "$mysqlDatabase" > /dev/null
then
	LogErrorVerbose "Problem pri nacitani pripojnych bodu z postgresql databaze: ($psqlDatabase), nebo jejich uprave, nebo pri vkladani do mysql databaze: ($mysqlDatabase) do tabulky: adminustlapnetshaping_shape_group pod uzivatelem: ($mysqlUser)"
	exit 7
fi

# zapise do souboru vypnuti cizich klicu, aby se to provedlo v jedne sessione
echo "SET FOREIGN_KEY_CHECKS=0;" > get_range.dump

# naplneni tabulky subnetu z NMS
if ! psql -U"$psqlUser" "$psqlDatabase" -A -F, -c "
SELECT
   i.nms_device_interface_id AS groupId,
   network(INET(i.ipv4)) AS range,
   inet(host(inet(i.ipv4))) - '0.0.0.0'::inet as intstart,
   inet(broadcast(inet(i.ipv4))) - '0.0.0.0'::inet as intend
FROM nms_ip_address AS i
JOIN adminus_ips_get AS t
ON (select inet(t.ip) << inet(i.ipv4)) = true OR
   (select inet(i.ipv4) <<= cidr(t.ip)) = true
GROUP BY groupId, range, intstart, intend
ORDER BY groupId;" | grep\
	-v "groupid,range,intstart,intend\|rows" | sed -e "s/,/','/g" -e "s/^/('/g" -e "s/$/'),/g" | tr '\n' ' '\
	| sed -e 's/^/INSERT INTO adminus_ip_address_range (shape_group_id, `range`, intstart, intend) VALUES/g'\
	-e "s/, $/;/g" >> get_range.dump
then
	LogErrorVerbose "Problem pri nacitani subnetu pripojnych bodu z postgresql databaze: ($psqlDatabase), nebo jejich uprave, nebo pri priprave na vkladani do mysql databaze: ($mysqlDatabase) do tabulky: adminus_ip_address_range"
	exit 8
fi

if ! mysql -u"$mysqlUser" --defaults-file="$mysqlDefaultsFile" "$mysqlDatabase" < get_range.dump > /dev/null
then
	LogErrorVerbose "Problem pri vkladani pripravenych subnetu pripojnych bodu do mysql databaze: ($mysqlDatabase) do tabulky: adminus_ip_address_range pod uzivatelem: ($mysqlUser)"
	exit 9
fi

# oprava autoincrementu
if ! echo "ALTER TABLE adminustlapnetshaping_shape_group AUTO_INCREMENT = $(mysql -u"$mysqlUser" --defaults-file="$mysqlDefaultsFile" "$mysqlDatabase" --silent -e "SELECT MAX(id) + 1 FROM adminustlapnetshaping_shape_group;" | grep -v "MAX")" | mysql -u"$mysqlUser" --defaults-file="$mysqlDefaultsFile" "$mysqlDatabase"
then
	LogErrorVerbose "Problem pri korekci autoincrementu tabulky adminustlapnetshaping_shape_group v mysql databazi: ($mysqlDatabase) pod uzivatelem: ($mysqlUser)"
	exit 10
fi

# naparovani pripojnych bodu na smlouvy
if ! mysql -u"$mysqlUser" --defaults-file="$mysqlDefaultsFile" "$mysqlDatabase" -e "
UPDATE adminus_contract d
INNER JOIN (
	SELECT  a.shape_group_id,
			b.ip,
			b.contract_id
		FROM adminus_ip_address_range AS a,
			 adminus_ip_address AS b
		WHERE INET_ATON(b.ip) BETWEEN a.intstart AND a.intend
			OR b.ip = a.range) c
ON d.id = c.contract_id
SET m_adminustlapnetshaping_shape_group_id = c.shape_group_id;" > /dev/null
then
	exit 11
fi

Log "Script $scriptName uspesne dokoncen"

exit 0
