#!/bin/bash
#zabbix-update.sh
#provadi kontrolu verze zabbixu proti serveru
#20141031 - predelano na nacitani knihoven a ucesano

#_LIST _PROMENNE _EXITY _KONFIGURACE _PODMINKY _KONTROLY _FUNKCE _ZALOHA

#_PROMENNE
scriptName="zabbix-update.sh"	
yuminstall="-y --enablerepo=zabbix* install"	#yum parametry
server="monitoring.comarr.cz"	#server se zabixem
localhost="127.0.0.1"
updateDone="0"		#slouzi pro kontrolu poctu prubehu
pupdateDone="0"


if [ "$(echo $PWD | grep -c pracovni)" = "0" ] && [ "$(echo $0 | grep -c pracovni)" = "0" ]	#v pripade, ze je script spousten ze slozky pracovni, nastavi se mu jine cesty, nez pri spusteni pres cron
then
	md5Dir="/var/btsync/md5sum"	#slozka, kde jsou nahrane md5sumy jednotlivych scriptu
	libDir="/var/btsync/lib"	#slozka kde jsou definovany spolecne funkce
	scriptDir="/var/btsync/scripty/${scriptName%.sh}" #cesta ke scriptu
else
	[ "$cronTime" = "1" ] && exit 99	#pokud zustala nastavena cesta do pracovniho adresare a script je spusteny pres cron
	md5Dir="/var/btsync/pracovni/md5sum"	#slozka, kde jsou nahrane md5sumy jednotlivych scriptu
	libDir="/var/btsync/pracovni/lib"	#slozka kde jsou definovany spolecne funkce
	scriptDir="/var/btsync/pracovni/${scriptName%.sh}" #cesta ke scriptu
	verbose="1"
fi


export md5Dir	#nastavi promenne jako globalni
export libDir


#_EXITY
#exit 1		#pokud byl zadan parametr -h
#exit 2		#pokud nesouhlasi md5sum
#exit 3		#pri zapsani noveho md5sum souboru
#exit 4		#nepodarilo se nainstalovat zabbix-get
#exit 5		#na serveru neni repozitar zabbixu
#exit 6		#na serveru neni zabbix agent
#exit 7		#nepodarilo se zapnout agenta, nebo proxy
#exit 8		#nenacetla se nektera z verzi zabbixu
#exit 9		#proxy se nezapnula po updatu
#exit 10	#agent se nezapnul po updatu


. $libDir/promenne
rv="$?"
if [ "$rv" != "0" ]
then
	echo "ERROR - promenne skoncily s hodnotou ($rv)"
	exit "$rv"
fi


. $libDir/logovani 	#nacteni definice funkci Log,LogError,RvCheck,MailSend z knihovny


#_PODMINKY
Log "kontrola parametru, md5sum atd"
. $libDir/casecheck "$1"	#nacteni kontrolniho case
rv="$?"
if [ "$rv" != "0" ]
then
	echo "CaseCheck skoncil s hodnotou ($rv)"
	exit "$rv"
fi


#_KONFIGURACE
#zapise konfiguracni soubor, ze ktereho bude nasledne nacitat hodnoty
if [ -f "$configFile" ]
then
	. "$configFile"
	Log "nacten konfiguracni soubor $configFile"
else
	echo "#!/bin/bash" > $configFile
	echo "#recipient=\"\"	#odkomentuj a zapis email pro posilani erroru" >> $configFile
	echo "#disabled=\"1\"	#odkomentuj pro zruseni spousteni scriptu" >> $configFile
	Log "zapsan konfiguracni soubor pro server $HOSTNAME"
	. "$configFile"
fi


#nastavenim disabled na 1 se vypne spousteni scriptu, uprav $configFile, mail se neposila
if [ "$disabled" = "1" ]
then
	Log "script byl disablovan v konfiguracnim souboru $configFile"
	exit 0
fi

#pokud neni repozitar zabbixu, tak konci s chybou a posila mail
if [ ! -e /etc/yum.repos.d/zabbix.repo ]
then
	LogError "na serveru neni repozitar zabbixu"
	MailSend
	exit 5
fi


##FUNKCE

#Check 
#zkontroluje nainstalovane balicky, pokud je zavolana bez argumentu, zkontroluje vse, s argumentem jen dany balicek
#pouziti Check, Check "agentpackage"
Check() {
	case $1 in
		agentpackage)
			agentPackage=$(yum list installed | grep -c zabbix-agent)
			Log "Check - $1 ($?)"
			;;
		agentrunning)
			tmp=$(service zabbix-agent status)
			agentRunning=$?
			Log "Check - $1 ($?)"
			;;
		proxypackage)
			proxyPackage=$(yum list installed | grep -c zabbix-proxy)
			Log "Check - $1 ($?)"
			;;
		proxyrunning)
			tmp=$(service zabbix-proxy status)
			proxyRunning=$?
			Log "Check - $1 ($?)"
			;;
		getpackage)
			getPackage=$(yum list installed | grep -c zabbix-get)
			Log "Check - $1 ($?)"
			;;
		*)
			agentPackage=$(yum list installed | grep -c zabbix-agent)
			proxyPackage=$(yum list installed | grep -c zabbix-proxy)
			getPackage=$(yum list installed | grep -c zabbix-get)


			#pokud neni nainstalovan zabbix agent tak zahlasi error mailem a do logu a skonci s priznakem 2
			if [ "$agentPackage" = "0" ]
			then
				LogError "ERROR - na serveru neni nainstalovan balicek zabbix-agent"
				MailSend
				exit 6
			fi
			Log "Check - vsechny promenne"
		;;
	esac
}

#YumPackage
#vola se s nazvem balicku (YumPackage "zabbix-get")
YumPackage() {
	case $1 in
	zabbix*)
		yum clean all >> $logFile
		sleep 1
		yum $yuminstall $1 >> $logFile
		RvCheck "yum install $1"
		Log "nainstalovan balicek $1"
		;;
	*)
		LogError "ERROR - zadan spatny argument ve funkci YumPackage - $1"
		;;
	esac
}

#AgentRunning
#zkontroluje, zda je spusten agent
AgentRunning() {
	Check "agentrunning"
	if [ "$agentRunning" != 0 ]
	then
		LogError "VAROVANI - $HOSTNAME Agent nebezi, zapinam"
		#zapne agenta
		service zabbix-agent start >> $logFile
		RvCheck "agent start"
		sleep 1
		#pomoci funkce Check zkontroluje aktualni stav agenta
		Check "agentrunning"
		
		if [ "$agentRunning" = 0 ]
		then
			Log "INFORMACE - $HOSTNAME agent byl spusten"
		else
			LogError "agent nebyl spusten"
			MailSend
			exit 7
		fi

	fi
}

#ProxyRunning
#zkontroluje, zda je spustena proxy
ProxyRunning() {
	Check "proxyrunning"
	if [ "$proxyRunning" != 0 ]
	then
		LogError "VAROVANI - proxy nebezi, zapinam"
		#zapne proxy
		service zabbix-proxy start >> $logFile
		RvCheck "proxy start"
		sleep 1
		#pomoci funkce zkontroluje aktualni stav proxy
		Check "proxyrunning"
	
		if [ "$proxyRunning" = 0 ]
		then
			Log "INFORMACE - $HOSTNAME proxy byla spustena"
		else
			LogError "proxy nebyla spustena"
			MailSend
			exit 7
		fi
	fi
}

#GetPackage
#zkontroluje, zda je nainstaovany balicek zabbix-get, pokud ne, zkusi ho nainstalovat
GetPackage() {
	if [ "$getPackage" = 0 ]
	then
		#zabbix-get neni nainstalovan, pokusi se ho nainstalovat
		LogError "VAROVANI - na serveru $HOSTNAME neni nainstalovan balicek zabbix-get - zkusim ho nainstalovat"
		#zavola funkci YumPackage s parametrem zabbix-get pro instalaci balicku
		YumPackage "zabbix-get"
		#zkontroluje balicek, zda se nainstaloval
		Check "getpackage"
		if [ "$getPackage" != 0 ]
		then
		#podarilo se nainstalovat balicek, spusti se funkce GetPackage pro novou kontrolu
			Log "INFORMACE - $HOSTNAME byl nainstalovan balicek zabbix-get"
			GetPackage
		else

			#nepodarilo se nainstalovat balicek zabbix-get, koncim s priznakem 4
			LogError "nebyl nainstalovan balicek zabbix-get"
			exit 4
		fi
	fi
}

#Version
#zkontroluje lokalni a serverovou verzi
Version() {
	#zkontroluje, zda agent bezi	
	AgentRunning
	#zkontroluje, zda je nainstalovany zabbix_get	
	GetPackage
	#nacte verze zabbixu
	localVersion=$(zabbix_get -s $localhost -k agent.version)
	serverVersion=$(wget http://$server/version.txt -q -O -)
	Log "version - server: $serverVersion local: $localVersion"
	#pokud se nenacte lokalni verze, je potreba upravit config agenta a doplnit localhost, skonci s priznakem 8"
	if [ "$localVersion" = "" ]
	then
		LogError "nenacetla se verze agenta (8)"
		exit 8
	fi
	if [ "$serverVersion" = "" ]
	then
		LogError "nenacetla se verze ze serveru, server pravdepodobne nebezi (8)"
		exit 8
	fi
	#porovna verze zabbixu
	if [ "$localVersion" != "$serverVersion" -a "$updateDone" = "0" ]
	then
		#verze se neshoduje s verzi na serveru, provede se update agenta		
		Log "zabbix version mismatch, updating"
		YumPackage "zabbix-agent"
		service zabbix-agent restart >> $logFile
		RvCheck "agent restart"
		AgentRunning
		if [ "$agentRunning" = 0 ]
		then
			Log "INFORMACE - $HOSTNAME zabbix agent byl updatovan"
			updateDone=1
		else
			#agent se updatoval, ale nespustil, nutna kontrola logu a konfig souboru, konci s priznakem 5
			LogError "agent se nespustil po updatu (10)"
			exit 10
		fi
	else
		Log "zabbix version is matching server version"
	fi
}

#ProxyVersion
#zkontroluje, zda je nainstalovana proxy
ProxyVersion() {
	if [ "$proxyPackage" != 0 ]
	then
		ProxyRunning
		serverVersion=$(wget http://$server/version.txt -q -O -)
		proxyVersion=$(yum info zabbix-agent | grep Version | sed -e 's/^[^0-9]*//g')
		if [ "$proxyVersion" = "" ]
		then
			LogError "nenacetla se verze proxy (8)"
			exit 8
		fi
		#pokud se nenacte serverova verze, tak nejde internet, nebo je jiny problem v komunikaci, rekord je 7500 mailu za 4 dny :P
		if [ "$serverVersion" = "" ]
		then
			LogError "nenacetla se verze ze serveru, server pravdepodobne nebezi (8)"
			MailSend
			exit 8
		fi
		#zkontroluje navzajem verze proxy
		if [ "$serverVersion" != "$proxyVersion" -a "$pupdateDone" = "0" ]
		then
			Log "zabbix proxy version mismatch, updating"
			YumPackage "zabbix-proxy"
			service zabbix-proxy restart >> $logFile
			ProxyRunning
			if [ "$proxyRunning" = 0 ]
			then
				Log "INFORMACE - $HOSTNAME zabbix proxy byla updatovana"
				pupdateDone="1"
			else
				LogError "proxy se nespustila po updatu (9)"
				MailSend
				exit 9
			fi
		else
			Log "zabbix proxy version is matching server version"
		fi
	else
		Log "proxy neni nainstalovana"
	fi
}


#RepoUpdate
#zkontroluje zda je nainstalovany nektery z balicku ve slozce update
RepoUpdate()
{
	updateDir="$scriptDir/update"	#promenna s cestou do updateDir
	centosVersion="$(uname -r | cut -d "." -f 4)"	#cutem vytahne z uname -r verzi el5/el6
	Log "nactena promenna centosVersion ($centosVersion)"
	updateRepo=$(ls "$updateDir/zabbix-release*$centosVersion*")	#slouzi pro nacteni nazvu souboru s repozitarem
	Log "nactena promenna updateRepo ($updateRepo)"
	if [ -f "$updateRepo" ]
	then
		if [ $(yum list installed | grep -c "$(basename ${updateRepo%.noarch.rpm})") = "0" ]	#zkontroluje, zda uz je nainstalovany nejnovejsi repozitar
		then
			yum -y localinstall $updateRepo
			RvLog "RepoUpdate - instalace repozitare $updateRepo"
		else
			Log "RepoUpdate - repozitar zabbixu je aktualni"
		fi
	else
		LogError "RepoUpdate - ve slozce $updateDir neni zadny balicek s repozitarem zabbixu"
	fi
}

##TELO SKRIPTU

#zacatek
Log "Spoustim kontrolu verze zabbixu"

#spusteni aktualizace repozitare
RepoUpdate

#spusteni funkce Check pro nacteni vsech promennych
Check

#spusteni funkce ProxyVersion pro update proxy
ProxyVersion

#spusteni funkce Version pro porovnani verze
Version

#konec
Log "OK - Kontrola verze zabbixu dokoncena"
MailSend


unset md5Dir	#zrusi globalni promenne
unset libDir


exit 0
