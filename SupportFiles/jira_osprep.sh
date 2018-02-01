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
JIRAPORTS=(
      8005
      8080
   )
JIRASVCS=(
      http
      https
      jira
      nfs
      rpc-bind
      mountd
   )
HSHAREPATH="${JIRADC_SHARE_PATH:-UNDEF}"
HSHARETYPE="${JIRADC_SHARE_TYPE:-UNDEF}"
JIRADCHOME="/var/atlassian"
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

#
# Ensure persistent data storage is valid
function ValidShare {
   SHARESRVR="${HSHAREPATH/\:*/}"
   SHAREPATH=${HSHAREPATH/${SHARESRVR}\:\//}

   echo "Attempting to validate share-path"
   printf "\t- Attempting to mount %s... " "${SHARESRVR}"
   if [[ ${HSHARETYPE} = glusterfs ]]
   then
      mount -t "${HSHARETYPE}" "${SHARESRVR}":/"${SHAREPATH}" /mnt && echo "Success" ||
        err_exit "Failed to mount ${SHARESRVR}"
   elif [[ ${HSHARETYPE} = nfs ]]
   then
      mount -t "${HSHARETYPE}" "${SHARESRVR}":/ /mnt && echo "Success" ||
        err_exit "Failed to mount ${SHARESRVR}"
      printf "\t- Looking for %s in %s... " "${SHAREPATH}" "${SHARESRVR}"
      if [[ -d /mnt/${SHAREPATH} ]]
      then
         echo "Success"
      else
         echo "Not found."
         printf "Attempting to create %s in %s... " "${SHAREPATH}" "${SHARESRVR}"
         mkdir /mnt/"${SHAREPATH}" && echo "Success" ||
           err_exit "Failed to create ${SHAREPATH} in ${SHARESRVR}"
      fi
   fi

   printf "Cleaning up... "
   umount /mnt && echo "Success" || echo "Failed"
}


##
## Open firewall ports
function FwStuff {
   local SELMODE
     SELMODE=$(getenforce)

   # Relax SEL as necessary
   if [[ ${SELMODE} = Enforcing ]]
   then
      printf "Temporarily relaxing SELinux mode... "
      setenforce 0 && echo "Done" || \
        err_exit 'Failed to relax SELinux mode'
   fi

   # Update firewalld config
   printf "Creating firewalld service for Jira... "
   firewall-cmd --permanent --new-service=jira || \
     err_exit 'Failed to initialize jira firewalld service'

   printf "Setting short description for Jira firewalld service... "
   firewall-cmd --permanent --service=jira \
     --set-short="Jira Service Ports" || \
     err_exit 'Failed to add short service description'

   printf "Setting long description for Jira firewalld service... "
   firewall-cmd --permanent --service=jira \
     --set-description="Firewalld options supporting Jira deployments" || \
     err_exit 'Failed to add long service description'

   for SVCPORT in "${JIRAPORTS[@]}"
   do
      printf "Adding port %s to Jira's firewalld service-definition... " \
        "${SVCPORT}"
      firewall-cmd --permanent --service=jira --add-port="${SVCPORT}"/tcp || \
        err_exit "Failed to add firewalld exception for ${SVCPORT}/tcp"
   done

   if [[ $(systemctl is-active firewalld) == active ]]
   then
      systemctl restart firewalld
   fi
   
   for SVCNAME in "${JIRASVCS[@]}"
   do
      printf "Adding %s service to firewalld... " "${SVCNAME}"
      firewall-cmd --permanent --add-service ${SVCNAME} || \
        err_exit "Failed adding ${SVCNAME} service to firewalld"
   done

   if [[ $(systemctl is-active firewalld) == active ]]
   then
      systemctl restart firewalld
   fi
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

# Ensure that share-service has the exported-path
ValidShare

# Mount Jira home-dir if needed
if [[ $(mountpoint -q "${JIRADCHOME}")$? -ne 0 ]]
then
   printf "Attempting to mount %s... " "${JIRADCHOME}"
   mount "${JIRADCHOME}" && echo "Success!" || 
      err_exit "Failed to mount Jira var-dir"
fi
