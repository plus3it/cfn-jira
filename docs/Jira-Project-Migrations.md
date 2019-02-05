# Jira Project Migration Guide

As part of a Jira deployment, there may be a need to migrate just select projects and not the entire Jira instance.  This guide will provide a summary of the steps that are required to use the built-in project import feature found within the Jira web management console.  For additional details on the project migration process, please refer to Atlassian's documentation ([Restoring Jira project from backup](https://confluence.atlassian.com/adminjiraserver073/restoring-a-project-from-backup-861253833.html)).

This guide is based on Jira Server version 7.6.1.

## Pre-migration Notes

*  Naming references:
   *  `Source Jira Instance` - Jira instance containing the projects to be imported
   *  `Target Jira Instance` - Jira instance that will be the destination of the import
*  It is required that the source and target Jira instances are at the same version.  If the versions are different, an upgrade must be performed to bring both Jira instances to the same version.
*  Ensure the target Jira instance contains all the necessary plugins that are required by the imported project(s).
*  It is recommended that a test migration be performed initially on a test Jira instance that is a replica of the final target Jira instance.  This will help to ensure most issues are resolved before the final migration is performed.

## Project Migration Outline

*  [Create Full Backup Of Both Jira Instances](#create-full-backup-of-both-jira-instances)
*  [Create Empty Project In Target Jira Instance](#create-empty-project-in-target-jira-instance)
*  [Create Matching Configurations In Target Jira Instance](#create-matching-configurations-in-target-jira-instance)
*  [Create Users/Groups/Roles In Target Jira Instance](#create-usersgroupsroles-in-target-jira-instance)
*  [Initiate Project Import](#initiate-project-import)

## Create Full Backup Of Both Jira Instances

Before initiating the project migration, it is important to create a backup for both source and target Jira instances.  The source backup will be used to import the project(s) and the destination backup will serve as a fallback option if the project import causes the target Jira instance to become unusable  or unrecoverable.

Backup Steps:
*  Log into the web management console using an account with Jira administrator privileges.
*  Click the gear wheel icon at the top right and select `System` under `JIRA ADMINISTRATION`.
*  In the Administration page, select `Backup system` under `IMPORT AND EXPORT`.
*  Type in a name for the backup file and click `Backup`.

For a default Jira installation, the backup file should be in `/var/atlassian/application-data/jira/export`.  Repeat the above steps on the source and target Jira instances.

## Create Empty Project In Target Jira Instance

The Jira import mechanism requires the target Jira instance to have an existing project to serve as a receiver for the imported data.  The project must have the same project `Key` value as the source project being imported.

Steps to create an empty project:
*  Log into the web management console using an account with Jira administrator privileges.
*  Select `Projects` on the top menu and then `Create project`.
*  Select the project format that matches the source project and click `Next`.
*  Select the default Issue Types and Workflow and click `Select`.
*  Enter values for the `Name`, `Key`, select the `Project Lead`, and click `Submit`.  **IMPORTANT: The Key value must match the source project**.

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

Jira's project import mechanism will create local users attached to the imported project if it can not find a matching username on the target Jira instance.  If the desire is to re-link the users to an external directory (i.e. Active Directory) and/or maintain user links to the issues, the users must be pre-created in the target Jira instance before the import and the username must match exactly.

The same applies to groups and roles.  If the desire is to maintain the groups and roles as found on the imported project, these groups and roles need to be pre-created.

## Initiate Jira Project Import

After creating the empty project on the target Jira instance and setting all the necessary configurations to match the source project, the project import can be attempted.

### Project Import Outline

*  [Copy Backup Files From Source To Destination](#copy-backup-files-from-source-to-destination)
*  [Initiate Jira Project Import](#initiate-jira-project-import)
*  [Project Import Notes](#project-import-notes)
*  [Project Import Validation](#project-import-validation)

### Copy Backup Files From Source To Destination

Projects are imported using the full system backup files of a Jira deployment.  To initiate the project import, copy the full backup files of the source Jira instance created previously to the target Jira instance.  Copy the backup database `zip` file and the associated project attachment folder to `/var/atlassian/application-data/jira/import`.  Ensure the user and group ownership is `jira`.  Otherwise, the project import will fail.

### Initiate Jira Project Import

After the requisite files are copied to the appropriate location, the project import can be initiate by the following steps:

*  Log into the web management console using an account with Jira administrator privileges.
*  Click the gear wheel icon at the top right and select `System` under `JIRA ADMINISTRATION`.
*  In the Administration page, select `Project import` under `IMPORT AND EXPORT`.
*  Type in the file name of the backup `zip` file copied over in a previous step and click `Next`.  This will initiate a scan of the backup files and provide a list of available projects to import.
*  Select the desired project to import from the drop-down menu and ensure there are no warnings or issues raised.  Check the option `Overwrite Project Details`. Click `Next` to proceed.
*  Review the validation results and resolve any items that have not passed as indicated by a yellow exclamation point.  Items that passed are indicated by a green check-mark.
*  Once all items are resolved, the import is ready to proceed.  Click `Import` to proceed.

Depending on the size of the project, the import process can be a lengthy process so be patient.  Confirm the import is progressing by checking the status/completion bar.

### Project Import Validation

If the project import is successful, a summary page will appear to summarize the results. Click `OK` to proceed and exit the project import page.  Browse to the project and confirm all project items were imported correctly and matches the source Jira project.  Verify attachments, users, issues, and any other dependencies have been restored.

## Project Import Notes

*  Importing Jira projects should be done when access is minimal or downtime can be scheduled.  The import process can lock the Jira instance.
*  The import may fail before completion and may require reviewing the Jira application log file.  In some cases, errors may be associated with problems in the database and may require manipulation of the database directly.
*  After the import completes, there maybe permissions changes that prevent access to the newly imported project.  In such cases, the project permissions can be updated in the Administrator view of all projects.
