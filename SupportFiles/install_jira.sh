#!/bin/bash
# shellcheck disable=SC2015
#
# Script to install Jira Datacenter and dependencies
#
#################################################################
# shellcheck disable=SC2086
PROGNAME="$(basename ${0})"
FWPORTS=(
         80
         443
         8005
         8080
        )
HSHAREPATH="${JIRADC_SHARE_PATH:-UNDEF}"
HSHARETYPE="${JIRADC_SHARE_TYPE:-UNDEF}"
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
RPMDEPLST=(
           postgresql
           postgresql-jdbc
          )


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

##
## Open firewall ports
function FwStuff {
   # Temp-disable SELinux (need when used in cloud-init context)
   setenforce 0 || \
      err_exit "Failed to temp-disable SELinux"
   echo "Temp-disabled SELinux"

   if [[ $(systemctl --quiet is-active firewalld)$? -eq 0 ]]
   then
      local FWCMD='firewall-cmd'
   else
      local FWCMD='firewall-offline-cmd'
      ${FWCMD} --enabled
   fi

   for PORT in "${FWPORTS[@]}"
   do
      printf "Add firewall exception for port %s... " "${PORT}"
      ${FWCMD} --permanent --add-port="${PORT}"/tcp || \
         err_exit "Failed to add port ${PORT} to firewalld"
   done

   # Restart firewalld with new rules loaded
   printf "Reloading firewalld rules... "
   ${FWCMD} --reload || \
      err_exit "Failed to reload firewalld rules"

   # Restart SELinux
   setenforce 1 || \
      err_exit "Failed to reactivate SELinux"
   echo "Re-enabled SELinux"
}

##
## Install any missing RPMs
function InstMissingRPM {
   local INSTRPMS=()

   # Check if we're missing any RPMs
   for RPM in "${RPMDEPLST[@]}"
   do
      printf "Cheking for presence of %s... " "${RPM}"
      if [[ $(rpm --quiet -q "$RPM")$? -eq 0 ]]
      then
         echo "Already installed."
      else
         echo "Selecting for install"
         INSTRPMS+=(${RPM})
      fi
   done

   # Install any missing RPMs
    if [[ ${#INSTRPMS[@]} -ne 0 ]]
   then
      echo "Will attempt to install the following RPMS: ${INSTRPMS[*]}"
      yum install -y "${INSTRPMS[@]}" || \
         err_exit "Install of RPM-dependencies experienced failures"
   else
      echo "No RPM-dependencies to satisfy"
   fi
}

##
## Enable NFS-client pieces
function NfsClientStart {
   local NFSCLIENTSVCS=(
            rpcbind
            nfs-server
            nfs-lock
            nfs-idmap
         )

    # Enable and start services
    for SVC in "${NFSCLIENTSVCS[@]}"
    do
       printf "Enabling %s... " "${SVC}"
       systemctl enable "${SVC}" && echo "Success!" || \
          err_exit "Failed to enable ${SVC}"
       printf "Starting %s... " "${SVC}"
       systemctl start "${SVC}" && echo "Success!" || \
          err_exit "Failed to start ${SVC}"
    done
}


####
## Main
####

# Modify some behaviors depending on Jira-home's share-type
case "${HSHARETYPE}" in
   UNDEF)
      ;;
   nfs)
      RPMDEPLST+=(
            nfs-utils
            nfs4-acl-tools
         )
      (
       printf "%s\t%s\tnfs4\t" "${HSHAREPATH}" "${JIRADCHOME}" ;
       printf "rw,relatime,vers=4.1,rsize=1048576,wsize=1048576," ;
       printf "namlen=255,hard,proto=tcp,timeo=600,retrans=2\t0 0\n"
      ) >> /etc/fstab || err_exit "Failed to add NFS volume to fstab"
      ;;
   glusterfs)
      RPMDEPLST+=(
            glusterfs
            glusterfs-fuse
            attr
         )
      (
       printf "%s\t%s\tglusterfs\t" "${HSHAREPATH}" "${JIRADCHOME}" ;
       printf "defaults\t0 0\n"
      ) >> /etc/fstab || err_exit "Failed to add NFS volume to fstab"
      ;;
esac

# Call setup functions
FwStuff
InstMissingRPM

# Start NFS Client services as necessary
if [[ $(rpm --quiet -q nfs-utils)$? -eq 0 ]]
then
   NfsClientStart
fi

# Mount persistent Jira home directory
if [[ -d ${JIRADCHOME} ]]
then
   echo "${JIRADCHOME} already exists: skipping create"
else
   printf "Attempting to create %s... " "${JIRADCHOME}"
   mkdir "${JIRADCHOME}" && echo "Success!" || \
      err_exit "Failed to create Jira var-dir"
fi

# Mount Jira home-dir if needed
if [[ $(mountpoint -q "${JIRADCHOME}")$? -ne 0 ]]
then
   printf "Attempting to mount %s... " "${JIRADCHOME}"
   mount "${JIRADCHOME}" && echo "Success!" || 
      err_exit "Failed to mount Jira var-dir"
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
service jira stop 
# shellcheck disable=SC1004
sed -i '/Connector port="8080"/a \
                   proxyName="'${PROXYFQDN}'" proxyPort="443" scheme="https"' /opt/atlassian/jira/conf/server.xml || err_exit "Failed to add proxy-def to server.xml"
service jira start || err_exit "Failed to start Jira service"
