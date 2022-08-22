#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------
# Autor: Oficinas CAYRO -- sysmus@hotmail.com
# Fecha: Diciembre 2015
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

. lib/ansicolors.sh

# Get hostname to netbios
NETBIOS=$(echo $(hostname) | tr '[:upper:]' '[:lower:]')

# Set DNS forwarder
DNS=$(ip route show | grep default | awk {'print $3'})

# Get IP address
IP=$(hostname -I)

clear

echo -e "${Yellow}"
cat << EOF
 #############################################################
 ###                                                       ###
 ### INSTALACION AUTOMATIZADA DE UN CONTROLADOR DE DOMINIO ###
 ###           ACTIVE DIRECTORY BASADO EN SAMBA4           ###
 ###                                                       ###
 #############################################################
EOF

# Change the Default Shell
#<< EOF
# ----------------------------------------------------------------------------
# /bin/sh is a symlink to /bin/dash, however we need /bin/bash, not /bin/dash.
# ----------------------------------------------------------------------------
#EOF
#
#echo "dash dash/sh boolean false" | debconf-set-selections
#DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash 2> /dev/null

# Set public DNS - it's temporary
cat << EOF > /etc/resolv.conf
nameserver	9.9.9.9
nameserver	8.8.8.8
EOF

# Actualizamos el sistema
echo -e "${Cyan} \n Actualizamos el sistema\n ${ColorOff}"
apt update && apt -y dist-upgrade

# Instalamos samba y todas sus dependencias
echo -e "${Cyan} \n Instalamos samba y todas sus dependencias\n ${ColorOff}"
DEBIAN_FRONTEND=noninteractive apt -y install \
    samba smbclient krb5-user winbind libpam-winbind libnss-winbind xattr sudo acl bc

# Tweaks to samba services
systemctl stop samba-ad-dc.service smbd.service nmbd.service winbind.service &>/dev/null
systemctl disable samba-ad-dc.service smbd.service nmbd.service winbind.service &>/dev/null

clear
echo -e "${Yellow}"
cat << EOF
 #############################################################
 ###                                                       ###
 ###    APROVISIONAMIENTO DE DIRECTORIO ACTIVO DE SAMBA    ###
 ###           DEBE PROPORCIONAR DATOS CORRECTOS           ###
 ###                                                       ###
 #############################################################
EOF

# ADD A NEW FOREST
echo -e "${Green}"
cat << EOF
 --------------------------------------------------------

 AGREGAR NUEVO BOSQUE -- ESPECIFIQUE SU NOMBRE DE DOMINIO

 --------------------------------------------------------
EOF
echo
printf '%s%s%s%s' "$(tput setaf 3)" "$(tput blink)" " Nombre de dominio raíz: " "$(tput sgr0)"
read REALM

REALM=$(echo ${REALM} | tr '[:upper:]' '[:lower:]')

# THE NETBIOS DOMAIN NAME
echo -e "${Green}"
cat << EOF
 ------------------------------------------------------------

 EL DOMINIO NETBIOS -- TAMBIEN CONOCIDO COMO GRUPO DE TRABAJO

 ------------------------------------------------------------
EOF
echo
printf '%s%s%s%s' "$(tput setaf 3)" "$(tput blink)" " Nombre del grupo de trabajo: " "$(tput sgr0)"
read DOMAIN

DOMAIN=$(echo ${DOMAIN} | tr '[:upper:]' '[:lower:]')

# ADMINISTRATOR PASSWORD
echo -e "${Green}"
cat << EOF
 -----------------------------------------------------------------------------

 CONTRASEÑA DE ADMINISTRADOR -- DEBE CUMPLIR CON LOS REQUISITOS DE COMPLEJIDAD

 -----------------------------------------------------------------------------
EOF
echo
printf '%s%s%s%s' "$(tput setaf 3)" "$(tput blink)" " Contraseña de administrador: " "$(tput sgr0)"

unset PASSWORD
unset CHARCOUNT

stty -echo

CHARCOUNT=0
while IFS= read -p "$PROMPT" -r -s -n 1 CHAR
do
    # Enter - accept password
    if [[ $CHAR == $'\0' ]] ; then
        break
    fi
    # Backspace
    if [[ $CHAR == $'\177' ]] ; then
        if [ $CHARCOUNT -gt 0 ] ; then
            CHARCOUNT=$((CHARCOUNT-1))
            PROMPT=$'\b \b'
            PASSWORD="${PASSWORD%?}"
        else
            PROMPT=''
        fi
    else
        CHARCOUNT=$((CHARCOUNT+1))
        PROMPT='*'
        PASSWORD+="$CHAR"
    fi
done

stty echo

ADMINPASS=$PASSWORD

echo;echo

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
    eval "${adjustSamba[$i]}" &>/dev/null
done

samba-tool domain provision \
    --use-rfc2307 \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --realm="${REALM^^}" \
    --domain="${DOMAIN^^}" \
    --adminpass="${ADMINPASS}"

echo

# And finally, we'll start the Samba AD DC service:
systemctl start samba-ad-dc

samba-tool domain level show

echo -e $BWhite; read -p ' Press [Enter] key to continue...'; echo -e $ColorOff

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

