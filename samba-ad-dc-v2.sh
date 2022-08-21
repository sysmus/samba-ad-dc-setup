#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------
# Autor: Oficinas CAYRO -- sysmus@hotmail.com
# Fecha: Agosto 2019
# ---------------------------------------------------------------------------------------
# DESCRIPCIÓN:
# Samba es un software gratuito de código abierto que proporciona una interoperabilidad
# estándar entre el sistema operativo Windows y los sistemas operativos GNU/Linux&Unix.
#
# Samba puede funcionar como servidor de archivos e impresión independiente para clientes
# de Windows y Linux a través del conjunto de protocolos SMB/CIFS o puede actuar como un
# controlador de dominio Active Directory o unirse a un reino como miembro de dominio.
#
# El nivel de bosque y dominio en modo AD DC más alto que Samba puede emular
# a la fecha es: Windows Server 2008 R2.
#
# Este escript le guiará en la configuración de un controlador de dominio de
# Active Directory basando en Samba4. (Debian Based Systems)
# ---------------------------------------------------------------------------------------

set -e

# IMPORTs
. lib/ansicolors.sh
. lib/functions.sh

# Get hostname to netbios
NETBIOS=$(echo $(hostname) | tr '[:upper:]' '[:lower:]')

# Set DNS forwarder
DNS=$(ip route show | grep default | awk {'print $3'})

# Get IP address
IP=$(hostname -I)

###############
# WHIPTAIL BASE
TITLE="SAMBA AD DC INSTALLER by <sysmus@hotmail.com>"
BACKTITLE="::: SAMBA COMO CONTROLADOR DE DOMINIO"

whiptail_message "lib/welcome.md" 22 100

# If you cannot understand this, read Bash_Shell_Scripting#if_statements again.
if (whiptail \
    --backtitle "$BACKTITLE" \
    --title "$TITLE" \
    --yesno "Desea continuar con esta instalación?" \
    7 70); then
    echo ""
else
    exit 0
fi

# Change the Default Shell
#<< EOF
# ----------------------------------------------------------------------------
# /bin/sh is a symlink to /bin/dash, however we need /bin/bash, not /bin/dash.
# ----------------------------------------------------------------------------
#EOF

#echo "dash dash/sh boolean false" | debconf-set-selections
#DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash &>/dev/null
#unset DEBIAN_FRONTEND

# Set public DNS - it's temporary
cat << EOF > /etc/resolv.conf
nameserver	9.9.9.9
nameserver	8.8.8.8
EOF

# UPDATE SYSTEM & SAMBA INSTALL
debconf-apt-progress -- apt update
debconf-apt-progress -- apt -y dist-upgrade
debconf-apt-progress -- apt -y install \
    sudo \
    samba \
    smbclient \
    libpam-winbind \
    libnss-winbind \
    krb5-user \
    winbind \
    xattr \
    acl

# Tweaks to samba services
systemctl stop samba-ad-dc.service smbd.service nmbd.service winbind.service &> /dev/null
systemctl disable samba-ad-dc.service smbd.service nmbd.service winbind.service &> /dev/null

# Capturamos variables provenientes de krb5-config
REALM=$(cat /etc/krb5.conf | egrep default_realm | cut -d ' ' -f3)
DOMAIN=$(echo $REALM | cut -d '.' -f1)

REALM=$(echo ${REALM} | tr '[:upper:]' '[:lower:]')
DOMAIN=$(echo ${DOMAIN} | tr '[:upper:]' '[:lower:]')

# Now we'll copy the krb5.conf kerberos
cp /etc/krb5.conf{,.orig}
# Now we'll copy the smb.conf samba
cp /etc/samba/smb.conf{,.orig}
# Now we'll copy the nsswitch
cp /etc/nsswitch.conf{,.orig}

cat << EOF > /etc/samba/smb.conf
# Global parameters
[global]
    dns forwarder = ${DNS}
    interfaces = 127.0.0.1 ${IP}
    netbios name = ${NETBIOS^^}
    realm = ${REALM^^}
    server role = active directory domain controller
    server string = Samba4 AD DC Server
    workgroup = ${DOMAIN^^}
    idmap_ldb:use rfc2307 = yes
    allow dns updates = nonsecure
    ldap server require strong auth = no

    winbind use default domain = true
    winbind offline logon = false
    winbind nss info = rfc2307
    password server = *
;   winbind separator = +
    winbind enum users = yes
    winbind enum groups = yes
    winbind uid = 10000-20000
    winbind gid = 10000-20000
    template homedir = /tmp
    template shell = /bin/false

#### Debugging/Accounting ####

# This tells Samba to use a separate log file for each machine
# that connects
    log file = /var/log/samba/log.%m

# Cap the size of the individual log files (in KiB).
    max log size = 1000
    log level = 2

#======================= Share Definitions =======================

[netlogon]
	path = /var/lib/samba/sysvol/${REALM,,}/scripts
	read only = No

[sysvol]
	path = /var/lib/samba/sysvol
	read only = No

[home]
	path = /home/sysvol
	read only = No
EOF

cat << EOF > /etc/krb5.conf
[libdefaults]
	default_realm = ${REALM^^}
	dns_lookup_realm = false
	dns_lookup_kdc = true

[realms]
    ${REALM^^} = {
        kdc = ${NETBIOS^^}.${REALM^^}
        master_kdc = ${NETBIOS^^}.${REALM^^}
        admin_server = ${NETBIOS^^}.${REALM^^}
        default_domain = ${REALM,,}
    }

[domain_realm]
    .${REALM,,} = ${REALM^^}
    ${REALM,,} = ${REALM^^}
EOF

cat << EOF > /etc/nsswitch.conf
passwd:         files winbind ldap
group:          files winbind ldap
shadow:         files winbind ldap
gshadow:        files

hosts:          files dns wins
networks:       files dns

protocols:      db files
services:       db files
ethers:         db files
rpc:            db files

netgroup:       nis
EOF

# Converting to primary DNS
cat << EOF > /etc/resolv.conf
nameserver 127.0.0.1
search ${REALM,,}
domain ${REALM,,}
nameserver ${DNS}
options timeout:1
EOF

# Next, we need to adjust the Debian default settings for the samba services.
adjustSamba=(
    "systemctl stop smbd nmbd winbind"
    "systemctl disable smbd nmbd winbind"
    "systemctl mask smbd nmbd winbind"
    "systemctl unmask samba-ad-dc"
    "systemctl enable samba-ad-dc"
)

for ((i=0;i<=5;++i))
do
    eval "${adjustSamba[$i]}" &> /dev/null
done

unset INPUT
whiptail_password "\nIntroducimos la contraseña del administrador del dominio :::IMPORTANTE::: Se recomienda usar una contraseña con la siguiente estructura:\nNo inferior a 8 caracteres, contener al menos un carácter en mayúscula, uno en minúsculas y un numero."
ADMINPASS=$INPUT

whiptail_message 'lib/provision.md' 14 100

samba-tool domain provision \
    --use-rfc2307 \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --realm="${REALM^^}" \
    --domain="${DOMAIN^^}" \
    --adminpass="${ADMINPASS}" &> /tmp/$0.log &

i=0
while [ $i -ne 1 ]
do
    i=$(cat /tmp/$0.log | egrep 'DOMAIN SID' | wc -l)
{
    for ((i=0; i<=100; i+=1))
    do
        sleep .05
        echo $i
    done
} | whiptail \
    --backtitle "$BACKTITLE" \
    --title "$TITLE" \
    --gauge "\nProvisioning a Samba Active Directory, Wait please.." 8 78 0
done

# And finally, we'll start the Samba AD DC service:
systemctl start samba-ad-dc

echo -e "\nSAMBA 4 AC DC ESTA COMPLETAMENTE OPERATIVO\n" > /tmp/$0.log
samba-tool domain level show >> /tmp/$0.log

whiptail_message /tmp/$0.log 14 80

whiptail_message lib/success.md 12 70

echo -e "$BCyan"
cat << EOF
        ---oOO-- (_) ----oOO---
 ╔═══════════════════════════════════╗
 ║ REALIZAMOS COMPROBACIONES FINALES ║
 ╚═══════════════════════════════════╝
 # # # # # # # # # # # # # # # # # # #

EOF

# Look up the DC's AD DNS record:
echo -e "${Cyan} Look up the DC's AD DNS record\n ${ColorOff}"
host -t A ${REALM,,}
host -t A ${NETBIOS,,}.${REALM,,}
host -t SRV _ldap._tcp.${REALM,,}
host -t SRV _kerberos._tcp.${REALM,,}
host -t SRV _kerberos._udp.${REALM,,}

echo -e $BWhite; read -p ' Press [Enter] key to continue...'; echo -e $ColorOff

echo ${ADMINPASS} | kinit Administrator
klist

samba-tool user setexpiry Administrator --noexpiry

# List all shares provided by the DC:
smbclient -L localhost -U%

# To verify authentication, connect to the netlogon share:
smbclient //localhost/netlogon -UAdministrator%"${ADMINPASS}" -c 'ls'

cp -a /var/lib/samba/sysvol /home
setfacl -m g:users:rwx /home/sysvol
setfacl -m g:users:rwx /var/lib/samba/sysvol/${REALM,,}/scripts

echo -e "$Purple \n Congratulations! everything has been installed.\n"
#---
echo "                                                                 _____      ";
echo "                                                                /    /      ";
echo "                     __  __   ___   /|                         /    /       ";
echo "                    |  |/  \`.'   \`. ||                        /    /        ";
echo "                    |   .-.  .-.   '||                       /    /         ";
echo "               __   |  |  |  |  |  |||  __        __        /    /  __      ";
echo "       _    .:--.'. |  |  |  |  |  |||/'__ '.  .:--.'.     /    /  |  |     ";
echo "     .' |  / |   \ ||  |  |  |  |  ||:/\`  '. '/ |   \ |   /    '   |  |     ";
echo "    .   | /\`\" __ | ||  |  |  |  |  |||     | |\`\" __ | |  /    '----|  |---. ";
echo "  .'.'| |// .'.''| ||__|  |__|  |__|||\    / ' .'.''| | /          |  |   | ";
echo ".'.'.-'  / / /   | |_               |/\'..' / / /   | |_'----------|  |---' ";
echo ".'   \_.'  \ \._,\ '/               '  \`'-'\`  \ \._,\ '/           |  |     ";
echo "            \`--'  \`\"                           \`--'  \`\"           /____\    ";
#---
echo
echo " Powered by GNU/Linux Debian Rules :) Enjoy It's!"
echo -e "$ColorOff"

