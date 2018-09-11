#!/bin/bash
# shellcheck disable=SC2015
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
PLUGINS2TMP="$SCRIPTHOME/plugins2"
PLUGINS2DIR="${DBCFGDIR}/plugins"
INSTLPLUGINS2DIR="${DBCFGDIR}/plugins/installed-plugins"

# Array of URLs to download plugins (Type 1 or 2)
PLUGINS1JARURL=(
                 # "<http or https link to Type 1 jar file>"
               )
PLUGINS2JARURL=(
                 # "<http or https link to Type 2 jar or obr file>"
               )

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

############
##  Main  ##
############

# Check for Unzip and install Unzip if needed
rpm -q unzip && echo "Unzip already installed" || \
  yum install unzip -y && echo "Unzip installed successfully" || \
    err_exit "Failed to install unzip"

#########################################
##                                     ##
##    Plugins Type 1 Installation      ##
##                                     ##
#########################################

if [[ ${#PLUGINS1JARURL[@]} -ne 0 ]]
then
  # Check if JIRA Plugins 1 folder exists, create if necessary
  if [[ -d ${PLUGINS1DIR} ]]
  then
    echo "${PLUGINS1DIR} exists - skipping create"
  else
    printf "Creating %s... " "${PLUGINS1DIR}"
    install -d -o jira -g jira -m 0755 "$PLUGINS1DIR" && echo "Success!" ||
      err_exit "Failed to create ${PLUGINS1DIR}"
  fi

  # Pull down plugins
  for URL in "${PLUGINS1JARURL[@]}"
  do
    printf "Pulling down %s... " "${URL}"
    install -b -m 000644 -o jira -g jira \
      <( curl -fskL "${URL}" ) "${PLUGINS1DIR}/$( echo ${URL##*\/} | sed 's/\?.*$//' )" \
      && echo "Success!" || \
      err_exit "Failed to download Add-On binary-installer ${URL}"
  done
else
  printf "Plugins 1 array empty. No plugins added!"
fi

#########################################
##                                     ##
##    Plugins Type 2 Installation      ##
##                                     ##
#########################################

if [[ ${#PLUGINS2JARURL[@]} -ne 0 ]]
then
  # Check if JIRA Plugins 2 folder exists, create if necessary
  if [[ -d ${INSTLPLUGINS2DIR} ]]
  then
    echo "${INSTLPLUGINS2DIR} exists - skipping create"
  else
    printf "Creating %s... " "${INSTLPLUGINS2DIR}"
    install -d -o jira -g jira -m 0750 "$INSTLPLUGINS2DIR" && echo "Success!" || \
      err_exit "Failed to create ${INSTLPLUGINS2DIR}"
  fi

  # Pull down plugins
  printf "Creating temporary plugins folder %s... " "${PLUGINS2TMP}"
  install -d "${PLUGINS2TMP}"  && echo "Success!" || \
    err_exit "Failed to create ${PLUGINS2TMP}"

  for URL in "${PLUGINS2JARURL[@]}"
  do
    FILENAME=$(echo ${URL##*\/} | sed 's/\?.*$//')
    PLUGINEXT=$(echo ${URL##*\/} | sed 's/\?.*$//' | sed 's/.*\.//')
    printf "Pulling down %s... " "${FILENAME}"
    install -b -m 000640 -o jira -g jira \
      <( curl -fskL "${URL}" ) "${PLUGINS2TMP}/${FILENAME}" && echo "Success!" || \
      err_exit "Failed to download Add-On binary-installer ${URL}"
    if [[ "${PLUGINEXT}" == "jar" ]]
    then
      printf "Plugin file %s is a JAR file. Unzip not required." "${FILENAME}"
    else
      if [[ "${PLUGINEXT}" == "obr" ]]
      then
        printf "Extracting OBR file %s... " "${FILENAME}"
        unzip -o ${PLUGINS2TMP}/${FILENAME} -d ${PLUGINS2TMP}/${FILENAME%.*} && echo "Success!" || \
          err_exit "Failed to extract OBR file ${PLUGINS2TMP}/${FILENAME##*/}"
      else
        printf "Incompatible plugin. %s not downloaded" "${URL##*/}"
      fi
    fi
  done

  # Move all plugin JAR files to plugins folder
  printf "Moving all JAR files to %s directory" "${INSTLPLUGINS2DIR}"
  find ${PLUGINS2TMP} -name '*.jar' -type f -print0 | \
    xargs -0 -n1 -I {} -t mv {} ${INSTLPLUGINS2DIR} && echo "Success!" || \
    err_exit "Failed to find and move JAR files to Plugins 2 directory"

  # Set file permissions and ownership for Plugin directory
  chown -R jira:jira "${PLUGINS2DIR}" && echo "Success!"|| \
    err_exit "Failed to set owner:group ownership in ${PLUGINS2DIR}"
else
  printf "Plugins 2 array empty. No plugins added!"
fi

printf 'Restarting Jira systemd service... '
systemctl --quiet restart jira && echo "Success." || \
  err_exit "Failed to restart Jira systemd service"
