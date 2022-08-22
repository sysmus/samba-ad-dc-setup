### SAMBA COMO CONTROLADOR DE DOMINIO ###

Inicialmente samba está creado para realizar comunicación entre sistemas de red NFS y SMB y garantizar la compartición de ficheros por usuarios. Pero tiene la posibilidad de generar un Domain Controller al uso mediante configuraciones por defecto.

Para ello se necesitaran de los siguientes paquetes:

samba -------->: Permite compartición y acceso a recursos a través de la red por usuario.
krb5-user ---->: Permite autenticar usuarios dentro de un servicio de red.
krb5-config -->: Configuración de Kerberos protocolo de autenticación de redes de ordenador.
winbind ------>: Permite resolver información de usuarios y grupos de entornos NT Windows.
libnss-winbind>: Permite unir el sistema de resolución de nombres con autenticación.
dns ---------->: IMPORTANTE: Al utilizar samba como controlador de dominio, se debe utilizar
                 este servidor como servidor de nombres primario.
