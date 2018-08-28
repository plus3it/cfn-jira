#!/bin/bash
#
# Script to download and install JIRA Plugins from other sources
#
#################################################################
# shellcheck disable=SC2086
PROGNAME="$(basename ${0})"
SCRIPTHOME="${HOME:-/root}"

JIRADCHOME="/var/atlassian"
JIRAINSTDIR="/opt/atlassian/jira"
DBCFGDIR="${JIRADCHOME}/application-data/jira"
PLUGINS1DIR="${JIRAINSTDIR}/atlassian-jira/WEB-INF/lib"
PLUGINS2DIR="${DBCFGDIR}/plugins"
INSTLPLUGINS2DIR="${DBCFGDIR}/plugins/installed-plugins"

# Array of URLs to download plugins (Type 1 or 2)
PLUGINS1JARURL=(
                 # <http or https link to jar file>
               )
PLUGINS2JARURL=(
                 # <http or https link to jar or obr file>
               )

# Install Unzip if needed
unzip -v && echo "Unzip already installed" || \
  yum install unzip -y

# Misc error-handler
function err_exit {
   local ERRSTR="${1}"
   local SCRIPTEXIT=${2:-1}

   # Our output channels
   # echo "${ERRSTR}" > /dev/stderr
   logger -t "${PROGNAME}" -p kern.crit "${ERRSTR}"

   # Need our exit to be an integer
   if [[ ${SCRIPTEXIT} =~ ^[0-9]+$ ]]
   then
      exit "${SCRIPTEXIT}"
   else
      exit 1
   fi
}

# Make git run quietly...
quiet_git() {
   if [[ $( git "$@" < /dev/null > /dev/null 2>&1 )$? -eq 0 ]]
   then
      echo "Git-fetch successful"
   else
      err_exit "Git-fetch failed"
   fi
}

# Create git staging-area as needed
if [[ -d ${SCRIPTHOME}/git ]]
then
   echo "Git stagining-area already exists"
else
   printf "Creating central location for Git-hosted resources... "
   # shellcheck disable=SC2015
   install -d -m 000700 ${SCRIPTHOME}/git && echo "Success" || \
     err_exit "Failed creating git staging-area."
fi

#########################################
##                                     ##
##    Plugins Type 1 Installation      ##
##                                     ##
#########################################

# Check if JIRA Plugins 1 folder exists, create if necessary
if [[ -d ${PLUGINS1DIR} ]]
then
  echo "${PLUGINS1DIR} exists - skipping create"
else
  printf "Creating %s... " "${PLUGINS1DIR}"
  install -d -o root -g root -m 0755 "$PLUGINS1DIR" && echo "Success!" ||
    err_exit "Failed to create ${PLUGINS1DIR}"
fi

if [[ ${#PLUGINS1JARURL[@]} -ne 0 ]]
then
  # Pull down plugins
  for URL in "${PLUGINS1JARURL[@]}"
  do
    printf "Pulling down %s... " "${URL}"
    curl -skL "${URL}" > "${PLUGINS1DIR}/${URL##*/}" && echo "Success!" || \
      err_exit "Failed to download Add-On binary-installer ${URL}"
    chmod 644 "${PLUGINS1DIR}/${URL##*/}" || \
      err_exit "Failed to set exec-mode on JAR installer ${URL##*/}"
  done
  # Set file permissions and ownership for Plugin directory
  chown -R jira:jira "${PLUGINS1DIR}" && echo "Success!"|| \
    err_exit "Failed to set owner:group ownership in ${PLUGINS1DIR}"
else
  printf "Plugins 1 array empty. No plugins added!"
fi

#########################################
##                                     ##
##    Plugins Type 2 Installation      ##
##                                     ##
#########################################

# Check if JIRA Plugins 2 folder exists, create if necessary
if [[ -d ${INSTLPLUGINS2DIR} ]]
then
  echo "${INSTLPLUGINS2DIR} exists - skipping create"
else
  printf "Creating %s... " "${INSTLPLUGINS2DIR}"
  install -d -o jira -g jira -m 0750 "$INSTLPLUGINS2DIR" && echo "Success!" ||
    err_exit "Failed to create ${INSTLPLUGINS2DIR}"
fi

if [[ ${#PLUGINS2JARURL[@]} -ne 0 ]]
then
  # Pull down plugins
  for URL in "${PLUGINS2JARURL[@]}"
  do
    printf "Pulling down %s... " "${URL}"
    if [[ "${URL##*.}" == "jar" ]]
    then
      curl -skL "${URL}" > "${INSTLPLUGINS2DIR}/${URL##*/}" && echo "Success!" || \
        err_exit "Failed to download Add-On binary-installer ${URL}"
      chmod 640 "${INSTLPLUGINS2DIR}/${URL##*/}" || \
        err_exit "Failed to set exec-mode on JAR installer ${URL##*/}"
    else
      if [[ "${URL##*.}" == "obr" ]]
      then
        curl -skL "${URL}" > "${SCRIPTHOME}/${URL##*/}" && echo "Success!" || \
          err_exit "Failed to download Add-On binary-installer ${URL}"
        printf "Extracting JAR files from file %s... " "${URL##*/}"
        FILENAME=${URL##*/}
        unzip -o ${SCRIPTHOME}/${URL##*/} -d ${SCRIPTHOME}/${FILENAME%.*} && echo "Success!" || \
          err_exit "Failed to extract OBR file ${SCRIPTHOME}/${URL##*/}"
        chmod -R 640 "${SCRIPTHOME}/${FILENAME%.*}" && echo "Success!"|| \
          err_exit "Failed to set exec-mode on extracted folder ${SCRIPTHOME}/${FILENAME%.*}"
        find ${SCRIPTHOME}/${FILENAME%.*} -name '*.jar' -type f | xargs -I {} mv {} ${INSTLPLUGINS2DIR} && echo "Success!" || \
          err_exit "Failed to find and move JAR files to Plugins 2 directory"
      else
        printf "Incompatible plugin. %s not downloaded" "${URL##*/}"
      fi
    fi
  done
  # Set file permissions and ownership for Plugin directory
  chown -R jira:jira "${PLUGINS2DIR}" && echo "Success!"|| \
    err_exit "Failed to set owner:group ownership in ${PLUGINS2DIR}"
else
  printf "Plugins 2 array empty. No plugins added!"
fi

printf 'Restarting Jira systemd service... '
systemctl --quiet restart jira && echo "Success." || \
  err_exit "Failed to restart Jira systemd service"
