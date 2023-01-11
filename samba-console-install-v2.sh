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

set -euo pipefail
shopt -s inherit_errexit nullglob
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
MG=$(echo "\033[35m")
RD=$(echo "\033[01;31m")
BGN=$(echo "\033[4;92m")
GN=$(echo "\033[1;92m")
DGN=$(echo "\033[32m")
CL=$(echo "\033[m")
BFR="\\r\\033[K"
HOLD="-"
CM="${GN}✓${CL}"
CROSS="${RD}✗${CL}"

function header_info {
    echo -e "${RD}
   _____                 __             ____           __        ____
  / ___/____ _____ ___  / /_  ____ _   /  _/___  _____/ /_____ _/ / /
  \__ \/ __ '/ __ '__ \/ __ \/ __ '/   / // __ \/ ___/ __/ __ '/ / /
 ___/ / /_/ / / / / / / /_/ / /_/ /  _/ // / / (__  ) /_/ /_/ / / /
/____/\__,_/_/ /_/ /_/_.___/\__,_/  /___/_/ /_/____/\__/\__,_/_/_/ v4

${CL}"
}

clear
header_info

while true; do
    read -p "Start the Samba Install Script (y/n)? " yn
    case $yn in
    [Yy]*) break ;;
    [Nn]*) exit ;;
    *) echo "Please answer yes or no." ;;
    esac
done

echo

function msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${YW}${msg}...\n"
}

function msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CM} ${GN}${msg}${CL}\n"
}

#-------------------------------------------------
# Get hostname to netbios
#-------------------------------------------------
NETBIOS=$(echo $(hostname) | tr '[:upper:]' '[:lower:]')

#-------------------------------------------------
# Set DNS forwarder
#-------------------------------------------------
DNS=$(ip route show | grep default | awk {'print $3'})

#-------------------------------------------------
# Get IP address
#-------------------------------------------------
IP=$(hostname -I)

#-------------------------------------------------
# Change the Default Shell
#-------------------------------------------------
#<< EOF
# ----------------------------------------------------------------------------
# /bin/sh is a symlink to /bin/dash, however we need /bin/bash, not /bin/dash.
# ----------------------------------------------------------------------------
#EOF
#
#echo "dash dash/sh boolean false" | debconf-set-selections
#DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash 2> /dev/null

#-------------------------------------------------
# Set public DNS - it's temporary
#-------------------------------------------------
cat << EOF > /etc/resolv.conf
nameserver	9.9.9.9
nameserver	8.8.8.8
EOF

#-------------------------------------------------
# Actualizamos el sistema
#-------------------------------------------------
msg_info "Update & Full Upgrade System"
apt update &>/dev/null
apt -y dist-upgrade &>/dev/null
msg_ok "Completed Successfully!"

#-------------------------------------------------
# Instalamos samba y todas sus dependencias
#-------------------------------------------------
msg_info "Installing Samba & dependencies"
DEBIAN_FRONTEND=noninteractive apt -y install \
    samba smbclient krb5-user winbind libpam-winbind \
    libnss-winbind xattr sudo acl bc &>/dev/null
#-------------------------------------------------
# Tweaks to samba services
#-------------------------------------------------
systemctl stop samba-ad-dc.service smbd.service nmbd.service winbind.service &>/dev/null
systemctl disable samba-ad-dc.service smbd.service nmbd.service winbind.service &>/dev/null
msg_ok "Completed Successfully!"
sleep 2s

clear
header_info
echo -e "${BL}
 #####################################################
 ###    APROVISIONAMIENTO DEL DIRECTORIO ACTIVO    ###
 ###       DEBE PROPORCIONAR DATOS CORRECTOS       ###
 #####################################################
${CL}"
#-------------------------------------------------
# ADD A NEW FOREST
#-------------------------------------------------
echo -e "${GN}
 --------------------------------------------------------
 AGREGAR NUEVO BOSQUE -- ESPECIFIQUE SU NOMBRE DE DOMINIO
 --------------------------------------------------------
${CL}"

printf '%s%s%s%s' "$(tput setaf 3)" "$(tput blink)" " Nombre de Dominio Raiz: " "$(tput sgr0)"
read REALM

REALM=$(echo ${REALM} | tr '[:upper:]' '[:lower:]')

#-------------------------------------------------
# THE NETBIOS DOMAIN NAME
#-------------------------------------------------
echo -e "${GN}
 ---------------------------------------------------------
 DOMINIO NETBIOS -- TAMBIEN CONOCIDO COMO GRUPO DE TRABAJO
 ---------------------------------------------------------
${GN}"

printf '%s%s%s%s' "$(tput setaf 3)" "$(tput blink)" " Nombre del Grupo de Trabajo: " "$(tput sgr0)"
read DOMAIN

DOMAIN=$(echo ${DOMAIN} | tr '[:upper:]' '[:lower:]')

#-------------------------------------------------
# ADMINISTRATOR PASSWORD
#-------------------------------------------------
echo -e "${GN}
 --------------------------------------------------------------
 La cuenta administrador de samba por defecto es: Administrator
 Ingrese una contraseña compleja con mas de 7 caracteres.
 Por favor utilice letras, números y simbolos.
 ---------------------------------------------
${GN}"

printf '%s%s%s%s' "$(tput setaf 3)" "$(tput blink)" " Contraseña de Administrador: " "$(tput sgr0)"

unset PASSWORD
unset CHARCOUNT

stty -echo

CHARCOUNT=0
while IFS= read -p "${PROMPT:-}" -r -s -n 1 CHAR
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

echo; echo

#-------------------------------------------------
# Now we'll copy the krb5.conf
#-------------------------------------------------
if [ -f /etc/krb5.conf ]; then
    cp /etc/krb5.conf{,.orig}
fi
#-------------------------------------------------
# Now we'll copy the smb.conf
#-------------------------------------------------
if [ -f /etc/samba/smb.conf ]; then
    cp /etc/samba/smb.conf{,.orig}
fi
#-------------------------------------------------
# Now we'll copy the nsswitch.conf
#-------------------------------------------------
if [ -f /etc/nsswitch.conf ]
then
    cp /etc/nsswitch.conf{,.orig}
fi

cat << EOF > /etc/samba/smb.conf
# Global parameters
[global]
    dns forwarder = ${DNS}
    interfaces = 127.0.0.1 ${IP}
    netbios name = ${NETBIOS^^}
    realm = ${REALM^^}
    server role = active directory domain controller
    server string = Samba AD DC Server
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

#-------------------------------------------------
# Converting to primary DNS
#-------------------------------------------------
cat << EOF > /etc/resolv.conf
nameserver 127.0.0.1
search ${REALM,,}
domain ${REALM,,}
nameserver ${DNS}
options timeout:1
EOF

#-------------------------------------------------
# Next, we need to adjust the Debian default settings for the samba services.
#-------------------------------------------------
adjustSamba=(
    "systemctl stop smbd nmbd winbind systemd-resolved"
    "systemctl disable smbd nmbd winbind systemd-resolved"
    "systemctl mask smbd nmbd winbind"
    "systemctl unmask samba-ad-dc"
    "systemctl enable samba-ad-dc"
)

msg_info "Active Directory Provisioning"

samba-tool domain provision \
    --use-rfc2307 \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --realm="${REALM^^}" \
    --domain="${DOMAIN^^}" \
    --adminpass="${ADMINPASS}" &>/dev/null

for ((i=0;i<=5;++i))
do
    eval "${adjustSamba[$i]:-}" &>/dev/null
done

msg_ok "Completed Successfully!"

#-------------------------------------------------
# And finally, we'll start the Samba AD DC service:
#-------------------------------------------------
systemctl start samba-ad-dc
samba-tool domain level show

echo -e "${YW}"; read -p " Press [Enter] key to continue..."; echo -e "${CL}"

#-------------------------------------------------
# Look up the DC's AD DNS record:
#-------------------------------------------------
echo -e "${BL} Look up the DC's AD DNS record\n ${CL}"
host -t A ${REALM,,}
host -t A ${NETBIOS,,}.${REALM,,}
host -t SRV _ldap._tcp.${REALM,,}
host -t SRV _kerberos._tcp.${REALM,,}
host -t SRV _kerberos._udp.${REALM,,}

echo -e "${YW}"; read -p " Press [Enter] key to continue..."; echo -e "${CL}"

echo ${ADMINPASS} | kinit Administrator
klist

samba-tool user setexpiry Administrator --noexpiry

#-------------------------------------------------
# List all shares provided by the DC:
#-------------------------------------------------
smbclient -L localhost -U%

#-------------------------------------------------
# To verify authentication, connect to the netlogon share:
#-------------------------------------------------
smbclient //localhost/netlogon -UAdministrator%"${ADMINPASS}" -c 'ls'

cp -a /var/lib/samba/sysvol /home
setfacl -m g:users:rwx /home/sysvol
setfacl -m g:users:rwx /var/lib/samba/sysvol/"${REALM,,}"/scripts

echo -e "${MG} \n Congratulations! everything has been installed.\n"
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
echo -e "${CL}"
