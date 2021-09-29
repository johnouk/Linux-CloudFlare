#!/bin/bash
##########################################################################################################################
# Script to block incoming connection to port 80, 443 from all host and allow only from cloudflare IP (both ipv4 and ipv6)
# Created By        : iFast.uk
##########################################################################################################################
## ----------------------------------
# Define variables
# ----------------------------------
RED='\033[0;41;30m'
GREEN='\033[0;42;30m'
STD='\033[0;0;39m'
YES=[Yy]*
NO=[Nn]*
ALL=[Aa]*
TEMP=/tmp
CURRENT_PATH=`pwd`
TEMPFILE3=`mktemp -p ${TEMP}`
TEMPFILE4=`mktemp -p ${TEMP}`
#Cloudflare ip last updated on December 2020
CLOUDFLARE_IPV4_ARR=("173.245.48.0/20" "103.21.244.0/22" "103.22.200.0/22" "103.31.4.0/22" "141.101.64.0/18" "108.162.192.0/18" "190.93.240.0/20" "188.114.96.0/20" "197.234.240.0/22" "198.41.128.0/17" "162.158.0.0/15" "104.16.0.0/12" "172.64.0.0/13" "131.0.72.0/22")
CLOUDFLARE_IPV6_ARR=("2400:cb00::/32" "2606:4700::/32" "2803:f800::/32" "2405:b500::/32" "2405:8100::/32" "2a06:98c0::/29" "2c0f:f248::/32")
PORT_TO_BLOCK=("80" "443")
DEFAULT_INTERFACE=eth0 #Check Default Interface
IPV4_ENABLE=1
IPV6_ENABLE=1

# ----------------------------------
# Check for needed tools
# ----------------------------------
#Check for iptables
OUTPUT=`command -v iptables`
if [ ! ${OUTPUT} ]
then
	echo -e "${RED}Error: iptables program needed but not exist, please install it.${STD}"
	exit 1	
fi
#Check if ipv6 enabled on this system
if  [ -f /proc/net/if_inet6 ]
then
	#IPv6 enabled, check for ip6tables if exist
	OUTPUT=`command -v ip6tables`
	if [ ! ${OUTPUT} ]
	then
		echo -e "${RED}Warning: ip6tables program not available. If you would like to block ipv6, please install it.${STD}"
		IPV6_ENABLE=0
		pause
	fi
fi
# ------------------------------------
# Check if user have root privilege 
# ------------------------------------
if [ ! -w /etc/passwd ]
then
    echo -e "${RED}Error: Please su to root first.${STD}"
    exit 1
fi
# ----------------------------------
# User defined function
# ----------------------------------
pause(){
#pause and wait for enter
  read -p "Press [Enter] key to continue..." 
}
# ------------------------------------
# Check if interface exist
# ------------------------------------
INTERFACE=${DEFAULT_INTERFACE}
while true
do
	ip link show | grep ^[1-9] | grep -q ${INTERFACE}
	RETURN=$?
	#0 = exist, 1 = not exist
	if [ ${RETURN} -eq 1 ]
	then
		echo -e "${RED}Error: Interface ${INTERFACE} not found${STD} "
	        read -p "Please input interface to block: " INTERFACE
 		case "${INTERFACE}"
       	          in
                    '')
        	 	echo -e "${RED}Error: Interface can not be blank${STD} "
			INTERFACE=${DEFAULT_INTERFACE}
                       	;;
       	             *)
             	        ;;
               	esac
	else
		break
	fi
done
echo -e "${GREEN}Using interface ${INTERFACE}${STD}"
#Generate iptables for ipv4 script block all incoming interface to port as listed
if [ ${IPV4_ENABLE} -eq 1 ]
then
	for i in "${PORT_TO_BLOCK[@]}"
	do
		for j in "${CLOUDFLARE_IPV4_ARR[@]}"
		do
			echo "iptables -A INPUT -i ${INTERFACE} -s ${j} -p tcp --destination-port $i -j ACCEPT" >> ${TEMPFILE3}
		done
	done
	for i in "${PORT_TO_BLOCK[@]}"
	do
		echo "iptables -A INPUT -i ${INTERFACE} -p tcp --destination-port $i -j DROP" >> ${TEMPFILE3}
	done
	#cat ${TEMPFILE3}
fi
#Run iptables for ipv4 script
bash ${TEMPFILE3}
#Generate iptables for ipv6 script block all incoming interface to port as listed
if [ ${IPV6_ENABLE} -eq 1 ]
then
	for i in "${PORT_TO_BLOCK[@]}"
	do
		for j in "${CLOUDFLARE_IPV6_ARR[@]}"
		do
			echo "ip6tables -A INPUT -i ${INTERFACE} -s ${j} -p tcp --destination-port $i -j ACCEPT" >> ${TEMPFILE4}
		done
	done
	for i in "${PORT_TO_BLOCK[@]}"
	do
		echo "ip6tables -A INPUT -i ${INTERFACE} -p tcp --destination-port $i -j DROP" >> ${TEMPFILE4}
	done
	#cat ${TEMPFILE4}
fi
#Run iptables for ipv4 script
bash ${TEMPFILE4}
rm -f ${TEMPFILE3} ${TEMPFILE4}
echo -e "${GREEN}Done.${STD}"
