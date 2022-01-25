#!/bin/bash

VERSION=1.6

LOG_FILE=/var/log/ncr_app_installer.log

# NCR App Variables
HOME_TAR="home.tar.gz"
INSTALL_NCR_APP_SCRIPT="/home/NCRServices/fds/testwrapper"
STO_ENV_FILE="/home/reg/gd90/7052_env.bat"
LAN_ENV_FILE="/home/reg/lan_env.bat"

# Mastercard Service Variables
MASTERCARD_SERVICE_INSTALLER_SCRIPT="/home/reg/CajaLinux/DEPLOY_GATEWAY/HGATEWAY.sh"
MASTERCARD_SERVICE_SCRIPT="/etc/init.d/HGATEWAY"

# Paperless Service Variables
PAPERLESS_SERVICE_INSTALLER_SCRIPT="/home/Paperless/ppljpos"
PAPERLESS_SERVICE_SCRIPT="/etc/init.d/ppljpos"

function set_host_alias()
{
local HOST_IP=$1
shift
local HOST_ALIAS=$*

    # Add ${HOST_ALIAS} and ${HOST_IP} when they do not exist
    grep ${HOST_IP} /etc/hosts >/dev/null 2>&1 || \
        grep "${HOST_ALIAS}" /etc/hosts >/dev/null 2>&1 || {
        echo "${HOST_IP} ${HOST_ALIAS}" >> /etc/hosts
    }

    # Update ${HOST_ALIAS} when it exists
    grep "${HOST_ALIAS}" /etc/hosts >/dev/null 2>&1 && \
        grep ${HOST_IP} /etc/hosts >/dev/null 2>&1 || {
        sed -r -i.old "s/.*${HOST_ALIAS}/${HOST_IP} ${HOST_ALIAS}/g" /etc/hosts
    }

    # Update ${HOST_ALIAS} when it changes
    grep ${HOST_IP} /etc/hosts >/dev/null 2>&1 && \
        grep "${HOST_ALIAS}" /etc/hosts >/dev/null 2>&1 || {
        sed -r -i.old "s/.*REG[0-9]{3}/${HOST_IP} ${HOST_ALIAS}/g" /etc/hosts
    }
}

function check_if_app_is_installed()
{
    [ -d /home/reg/gd90 ] && return 0
    return 1
}

function check_if_ncr_services_are_installed()
{
# Remember, we have a / and /home partitions and the app's installer
# installs files in both of them.
# If the image is reinstalled, everything on the / partition is lost,
# but not on /home.

    [ -e /etc/init.d/FDS ] && return 0
    return 1
}

function check_if_mastercard_services_are_installed()
{
    [ ! -e ${MASTERCARD_SERVICE_INSTALLER_SCRIPT} ] && return 0
    [ -e ${MASTERCARD_SERVICE_SCRIPT} ] && return 0
    return 1
}

function install_mastercard_services()
{
    ${MASTERCARD_SERVICE_INSTALLER_SCRIPT} install
}

function start_mastercard_services()
{
    ${MASTERCARD_SERVICE_SCRIPT} status || ${MASTERCARD_SERVICE_SCRIPT} start
}

function download_ncr_app()
{
    busybox tftp -g -b 32768 -r "NCR/${HOME_TAR}" -l /tmp/${HOME_TAR} SRV999
}

function install_ncr_services()
{
    ${INSTALL_NCR_APP_SCRIPT} install
}

function start_ncr_services()
{
    /etc/init.d/FDS status || /etc/init.d/FDS start
}

function install_ncr_app()
{
    # App installation fails if FDS file exists, delete it
    rm -f /etc/init.d/FDS
    rm -rf /home/*

    mv /tmp/${HOME_TAR} /home
    cd /home
    tar -zxvf ${HOME_TAR}
    rm -f ${HOME_TAR}
}

function get_reg_number()
{
# Example: REG001
    echo $(hostname -s) | awk '{ print substr($1, 1 + length($1) - 3) }'
}

function get_store_number()
{
# Example: hplmprcrv0523.promart.hpsa.pe
    echo $DNSDOMAIN | cut -d. -f1 | \
        awk --posix '{
            regexp = "[0-9]{4}"
            where = match($1, regexp)
            print substr($1, where)
        }'
}

function setup_ncr_app()
{
local REG_NUM=$(get_reg_number)
local STO_NUM=$(get_store_number)

    sed -r -i.old "s/(REG=)[0-9]{3}/\1${REG_NUM}/g" ${STO_ENV_FILE}
    sed -r -i.old "s/(STO=)[0-9]{4}/\1${STO_NUM}/g" ${STO_ENV_FILE}

    sed -r -i.old "s/(REG=)[0-9]{3}/\1${REG_NUM}/g" ${LAN_ENV_FILE}
}

function check_if_paperless_services_are_installed()
{
    [ -e ${PAPERLESS_SERVICE_SCRIPT} ] && return 0
    return 1
}

function install_paperless_services()
{
    if [ -e ${PAPERLESS_SERVICE_INSTALLER_SCRIPT} ] ;
    then
        cp ${PAPERLESS_SERVICE_INSTALLER_SCRIPT} ${PAPERLESS_SERVICE_SCRIPT}
        chmod 755 ${PAPERLESS_SERVICE_SCRIPT}
        insserv $(basename ${PAPERLESS_SERVICE_SCRIPT})
        return 0
    fi
    return 1
}

function start_paperless_services()
{
    [ -e ${PAPERLESS_SERVICE_SCRIPT} ] && ${PAPERLESS_SERVICE_SCRIPT} start
}

function check_reg_user_logged_in()
{
    who | grep reg >/dev/null 2>&1
    return $?
}

function find_out_interface_name()
{
local INTERFACES=$(hwinfo --netcard | grep "Device File:" | cut -d: -f2)

    for iface in $INTERFACES;
    do
        if [ -f /etc/sysconfig/network/ifcfg-${iface} ] ;
        then
            DHCPCD_LEASE_FILE="/var/lib/dhcpcd/dhcpcd-${iface}.info"
            break
        fi
    done
}

function wait_for_network_to_be_setup()
{
local MYIP=$1
local CHECK=0

    while ! ip addr show | grep -w $MYIP >/dev/null;
    do
        sleep 2
        if [ $CHECK -eq 45 ] ;
        then
            ifconfig -a
            break
        fi
        CHECK=$((CHECK + 1))
    done
}

function wait_for_hostname_to_be_setup()
{
local CHECK=0

    while ! hostname -s >/dev/null;
    do
        sleep 2
        if [ $CHECK -eq 30 ] ;
        then
            hostname -s
            break
        fi
        CHECK=$((CHECK + 1))
    done
}

function wait_for_dhcpcd_lease_file
{
local MYLEASEFILE=$1
local CHECK=0

    while true;
    do
        [ -f $MYLEASEFILE ]
        [ $? -eq 0 ] && sleep 1 && return 0

        [ $CHECK -eq 15 ] && return 1

        echo -n "Waiting for lease file ${MYLEASEFILE}..."
        CHECK=$((CHECK + 1))
        sleep 2
    done
}

#
# Log everything to a file
#
exec 1>> ${LOG_FILE} 2>&1

set -x

echo "== BEGIN NCR APP INSTALLATION $(date) =="

find_out_interface_name
wait_for_dhcpcd_lease_file $DHCPCD_LEASE_FILE

if [ -f  $DHCPCD_LEASE_FILE ] ;
then
    . $DHCPCD_LEASE_FILE

    wait_for_network_to_be_setup $IPADDR

    wait_for_hostname_to_be_setup

    # Set ARS server alias
    set_host_alias $DHCPSID SRV999

    # Only set hostname if starting with REG
    echo $(hostname -s) | grep REG >/dev/null 2>&1 && {
        set_host_alias $IPADDR $(hostname -s) $(hostname -s) BUS999
        echo $(hostname -s)".site" > /etc/HOSTNAME
    }

    if ! check_reg_user_logged_in ;
    then
        check_if_app_is_installed || {
            download_ncr_app && install_ncr_app && setup_ncr_app
        }
        check_if_ncr_services_are_installed || {
            install_ncr_services && start_ncr_services
        }
        check_if_mastercard_services_are_installed || {
            install_mastercard_services && start_mastercard_services
        }
        check_if_paperless_services_are_installed || {
            install_paperless_services && start_paperless_services
        }
    fi
    RET=$?
fi

echo "==  END NCR APP INSTALLATION $(date) =="

exit ${RET}
