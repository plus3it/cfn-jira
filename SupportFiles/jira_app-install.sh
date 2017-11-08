#!/bin/bash
# shellcheck disable=SC2015
#
# Script to install Jira Datacenter and dependencies
#
#################################################################
# shellcheck disable=SC2086
PROGNAME="$(basename ${0})"
# Ensure we'v got our CFn envs (in case invoking via other than CFn)
while read -r ENV
do
  # shellcheck disable=SC2163
  export "${ENV}"
done < /etc/cfn/Jira.envs
JIRADCURL=${JIRADC_SOFTWARE_URL:-UNDEF}
JIRADCHOME="/var/atlassian"
DBCFGDIR="${JIRADCHOME}/application-data/jira"
DBCFGFILE="${DBCFGDIR}/dbconfig.xml"
JIRAINSTBIN="/root/atlassian-jira-software-x64.bin"
PGSQLHOST="${JIRADC_PGSQL_HOST:-UNDEF}"
PGSQLTABL="${JIRADC_PGSQL_INST:-UNDEF}"
PGSQLMANAGR="${JIRADC_PGSQL_MANAGER:-UNDEF}"
PGSQLPASSWD="${JIRADC_PGSQL_PASSWORD:-UNDEF}"
PROXYFQDN="${JIRADC_FQDN:-UNDEF}"
RESPFILE="/root/response.vars"
SERVERXML="/opt/atlassian/jira/conf/server.xml"


##
## Set up an error logging and exit-state
function err_exit {
   local ERRSTR="${1}"
   local SCRIPTEXIT=${2:-1}

   # Our output channels
   echo "${ERRSTR}" > /dev/stderr
   logger -t "${PROGNAME}" -p kern.crit "${ERRSTR}"

   # Need our exit to be an integer
   if [[ ${SCRIPTEXIT} =~ ^[0-9]+$ ]]
   then
      exit "${SCRIPTEXIT}"
   else
      exit 1
   fi
}

####
## Main
####

# Dial-back SEL if necessary
SELMODE="$(/sbin/getenforce)"
if [[ ${SELMODE} == Enforcing ]]
then
   setenforce 0
fi

# Create the automated-response file used for
# unattended install of Jira Datacenter Software
cat > ${RESPFILE} << EOF
#install4j response file for JIRA Software 7.3.6
launch.application\$Boolean=false
rmiPort\$Long=8005
app.jiraHome=${JIRADCHOME}/application-data/jira
app.install.service\$Boolean=true
existingInstallationDir=/opt/JIRA Software
sys.confirmedUpdateInstallationString=false
sys.languageId=en
sys.installationDir=/opt/atlassian/jira
executeLauncherAction\$Boolean=true
httpPort\$Long=8080
portChoice=default
EOF

# Make sure the config-dir exists
if [[ -d ${DBCFGDIR} ]]
then
   echo "${DBCFGDIR} exists - skipping create"
else
   printf "Creating %s... " "${DBCFGDIR}"
   install -d -m 0700 "${DBCFGDIR}" && echo "Success!" ||
      err_exit "Failed to create ${DBCFGDIR}"
fi

# Create dbconfig.xml
if [[ -f ${DBCFGFILE} ]]
then
   echo "Found dbconfig.xml file at ${DBCFGFILE}."
else
   install -b -m 0600 /dev/null ${DBCFGFILE}

   cat > ${DBCFGFILE} << EOF
<?xml version="1.0" encoding="UTF-8"?>

<jira-database-config>
  <name>defaultDS</name>
  <delegator-name>default</delegator-name>
  <database-type>postgres72</database-type>
  <schema-name>public</schema-name>
  <jdbc-datasource>
    <url>jdbc:postgresql://${PGSQLHOST}:5432/${PGSQLTABL}</url>
    <driver-class>org.postgresql.Driver</driver-class>
    <username>${PGSQLMANAGR}</username>
    <password>${PGSQLPASSWD}</password>
    <pool-min-size>20</pool-min-size>
    <pool-max-size>20</pool-max-size>
    <pool-max-wait>30000</pool-max-wait>
    <validation-query>select 1</validation-query>
    <min-evictable-idle-time-millis>60000</min-evictable-idle-time-millis>
    <time-between-eviction-runs-millis>300000</time-between-eviction-runs-millis>
    <pool-max-idle>20</pool-max-idle>
    <pool-remove-abandoned>true</pool-remove-abandoned>
    <pool-remove-abandoned-timeout>300</pool-remove-abandoned-timeout>
    <pool-test-on-borrow>false</pool-test-on-borrow>
    <pool-test-while-idle>true</pool-test-while-idle>
  </jdbc-datasource>
</jira-database-config>
EOF

   # shellcheck disable=SC2181
   # Verify that creation worked
   if [[ $? -eq 0 ]]
   then
      echo "Created ${DBCFGFILE}."
   else
      err_exit "Failed to create ${DBCFGFILE}."
   fi
fi

# Pull down the Jira software
printf "Pulling down %s... " "${JIRADCURL}"
curl -skL "${JIRADCURL}" > "${JIRAINSTBIN}" && echo "Success!" || \
   err_exit "Failed to download Jira binary-installer"
chmod 755 "${JIRAINSTBIN}" || \
   err_exit "Failed to set exec-mode on Jira binary-installer"

# Install Jira Software
echo "Running Jira unattended install... "
"${JIRAINSTBIN}" -q -varfile /root/response.vars && \
   echo "Jira installed." || \
   err_exit "Unattended install experienced errors"

# Massage Jira's listener
service jira stop || echo "Jira did not need to be stopped..."

printf "Waiting for creation of %s " "${SERVERXML}"
while [[ ! -e ${SERVERXML} ]]
do
   printf "."
done

echo " Go!"

echo "Adding 'proxyName' parm to Jira config..."
# shellcheck disable=SC1004
sed -i '/Connector port="8080"/a \
                   proxyName="'${PROXYFQDN}'" proxyPort="443" scheme="https"' "${SERVERXML}" \
  || err_exit "Failed to add proxy-def to server.xml"

# Start Jira (via systemd)
systemctl daemon-reload

if [[ $(systemctl is-enabled jira) == disabled ]]
then
   printf 'Enabling Jira systemd service... '
   systemctl --quiet enable jira && echo "Success." || \
     err_exit "Failed to enable Jira systemd service"
fi

if [[ $(systemctl is-active jira) == inactive ]]
then
   printf 'Starting Jira systemd service... '
   systemctl --quiet restart jira && echo "Success." || \
     err_exit "Failed to start Jira systemd service"
fi

# Return SEL-mode to pre-script state
setenforce "${SELMODE}"
