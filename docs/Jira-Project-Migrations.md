# Jira Project Migration Guide

During the lifecycle of a Jira deployment, migration of individual projects &mdash; but not the entirety of a Jira domain &mdash; may be requested.  This guide will provide a summary of steps required when using the Jira web management console's built-in project-import.  For additional details on the project migration process, please refer to Atlassian's documentation ([Restoring Jira project from backup](https://confluence.atlassian.com/adminjiraserver073/restoring-a-project-from-backup-861253833.html)).

This guide is based on Jira Server version 7.6.1.

## Pre-migration Notes

*  Naming references:
   *  `Source Jira Instance` - Jira instance containing the project(s) to be imported
   *  `Target Jira Instance` - Jira instance that will be the destination of the import
*  It is required that the source and target Jira instances are at the same version.  If the versions are different, an upgrade must be performed to bring both Jira instances to the same version.
*  An assessment needs to be performed on the project(s) to determine the additional resources that maybe required on the target Jira instance.  The instance-type may need to be increased to handle the import process as well as the increased load from additional users and data.
 to handle the import process and additional load that can come from more users and data.  The instance-types for the host and database may need to be increased.  
*  Ensure the target Jira instance contains all plugins currently used within the to-be-imported project(s).
*  The importance of a pre-migration rehearsal cannot be understated. Use a clone of the eventual target to practice against. Practice will help to ensure  both strong familiarity with the migration processes and to help uncover and mitigate the vast majority of issues that may exist in a pending migration without placing the actual migration-target at risk.
*  The project migration will require the operator to have filesystem access to the Jira instance.

## Project Migration Outline

1.  [Create Full Backup Of Both Jira Instances](#create-full-backup-of-both-jira-instances)
1.  [Create Empty Project In Target Jira Instance](#create-empty-project-in-target-jira-instance)
1.  [Create Matching Configurations In Target Jira Instance](#create-matching-configurations-in-target-jira-instance)
1.  [Create Users/Groups/Roles In Target Jira Instance](#create-usersgroupsroles-in-target-jira-instance)
1.  [Initiate Project Import](#initiate-project-import)

## Create Full Backup Of Both Jira Instances

Before initiating the project migration, it is important to create a backup for both source and target Jira instances.  The source backup will be used to import the project(s) and the destination backup will serve as a fallback option if the project import causes the target Jira instance to become "deranged" (inconsistent), unusable  or unrecoverable.

Backup Steps:
1.  Log into the web management console using an account with Jira administrator privileges.
1.  Click the gear wheel icon at the top right and select `System` under `JIRA ADMINISTRATION`.
1.  In the Administration page, select `Backup system` under `IMPORT AND EXPORT`.
1.  Type in a name for the backup file and click `Backup`.

For a default Jira installation, the backup file should be in `/var/atlassian/application-data/jira/export`.  Repeat the above steps on the source and target Jira instances.

## Create Empty Project In Target Jira Instance

The Jira import mechanism requires the target Jira instance to have an existing project to serve as a receiver for the imported data.  The project must have the same project `Key` value as the source project being imported.

Steps to create an empty project:
1.  Log into the web management console using an account with Jira administrator privileges.
1.  Select `Projects` on the top menu and then `Create project`.
1.  Select the project format that matches the source project and click `Next`.
1.  Select the default Issue Types and Workflow and click `Select`.
1.  Enter values for the `Name`, `Key`, select the `Project Lead`, and click `Submit`.  **IMPORTANT: The Key value must match the source project**.

Verify the empty project was created by selecting `Projects` on the top menu and select `View All Projects`.  Search for the Name or Key that matches the newly created project.

## Create Matching Configurations In Target Jira Instance

After creating the empty project on the target Jira instance to receive the import, it needs to be configured to match the source project in order for the Jira import mechanism to complete properly.  It must use the same issue types, workflows, screens, fields, priorities, and any other custom configurations.  To view and compare the configurations, click on the gear icon in the top right and select `Issues` under `JIRA ADMINISTRATION`.  This will open the page where all project issue configurations can be modified.  Perform this procedure on both the source and target Jira instances and compare the settings for the empty target project and the source project.

Below is a list of items to review and modify to match between the source and target projects:

*  **ISSUE TYPES** - `Issue types`, `Issue type schemes`, `Sub-tasks`
*  **WORKFLOWS** - `Workflows`, `Workflow schemes`
(Note: A copy of the source project `Workflow` can be exported from the source project and then imported to the new target project. It is not necessary to re-create it from scratch.)
*  **SCREENS** - `Screens`, `Screen schemes`, `Issue type screen schemes`
*  **FIELDS** - `Custom fields`, `Field configurations`, `Field configuration schemes`
*  **PRIORITIES, ISSUE FEATURES, ISSUE ATTRIBUTES** - Jira projects tend to use the defaults for these configurations but a quick review should be performed to confirm if any custom settings were created.

## Create Users/Groups/Roles In Target Jira Instance

Jira's project import mechanism will create local users attached to the imported project if it can not find a matching user name on the target Jira instance.  If the desire is to not create new users, maintain user names of the target Jira instance, and  maintain user name links to the issues on the source Jira instance, the user names on the source Jira instance must be changed to match exactly that of the target Jira instance.

The same applies to groups and roles.  If the desire is to maintain the groups and roles as found on the imported project, these groups and roles need to be pre-created.

## Initiate Jira Project Import

After creating the empty project on the target Jira instance and setting all the necessary configurations to match the source project, the project import can be attempted.

### Project Import Outline

1.  [Copy Backup Files From Source To Destination](#copy-backup-files-from-source-to-destination)
1.  [Initiate Jira Project Import](#initiate-jira-project-import)
1.  [Project Import Notes](#project-import-notes)
1.  [Project Import Validation](#project-import-validation)

### Copy Backup Files From Source To Destination

Projects are imported using the full system backup files of a Jira deployment.  To initiate the project import, copy the full backup files of the source Jira instance created previously to the target Jira instance.  Copy the backup database `zip` file and the associated project attachment folder to `/var/atlassian/application-data/jira/import`.  Ensure the user and group ownership is `jira`.  Otherwise, the project import will fail.

### Initiate Jira Project Import

After the requisite files are copied to the appropriate location, the project import can be initiate by the following steps:

1.  Log into the web management console using an account with Jira administrator privileges.
1.  Click the gear wheel icon at the top right and select `System` under `JIRA ADMINISTRATION`.
1.  In the Administration page, select `Project import` under `IMPORT AND EXPORT`.
1.  Type in the file name of the backup `zip` file copied over in a previous step and click `Next`.  This will initiate a scan of the backup files and provide a list of available projects to import.
1.  Select the desired project to import from the drop-down menu and ensure there are no warnings or issues raised.  Check the option `Overwrite Project Details`. Click `Next` to proceed.
1.  Review the validation results and resolve any items that have not passed as indicated by a yellow exclamation point.  Items that passed are indicated by a green check-mark.
1.  Once all items are resolved, the import is ready to proceed.  Click `Import` to proceed.

Depending on the size of the project, the import process can be a lengthy process so be patient.  Confirm the import is progressing by checking the status/completion bar.

### Project Import Validation

If the project import is successful, a summary page will appear to summarize the results. Click `OK` to proceed and exit the project import page.  Browse to the project and confirm all project items were imported correctly and matches the source Jira project.  Verify attachments, users, issues, and any other dependencies have been restored.

## Project Import Notes

*  Importing Jira projects should be done when access is minimal or downtime can be scheduled.  The import process can lock the Jira instance.
*  The import may fail before completion and may require reviewing the Jira application log file.  In some cases, errors may be associated with problems in the database and may require manipulation of the database directly.
*  After the import completes, there maybe permissions changes that prevent access to the newly imported project.  In such cases, the project permissions can be updated in the Administrator view of all projects.
