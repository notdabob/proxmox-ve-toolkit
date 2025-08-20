#Requires -Version 7.0
#Requires -Modules Posh-SSH

<#
.SYNOPSIS
    Proxmox VE 9.0.4 cluster migration & automation orchestrator (entry script).

.DESCRIPTION
    Coordinates every migration phase by loading ProxmoxMigration.psm1 and
    invoking Start-Migration. All heavy lifting lives in the module. This script
    serves as the main entry point for the entire migration process.

.PARAMETER ConfigFile
    The path to an optional JSON configuration file that was exported from a
    previous run. If not provided, the script will launch an interactive wizard.

.PARAMETER LogLevel
    Specifies the logging verbosity. Valid options are: Info (default), Warning,
    Error, or Debug.

.PARAMETER DryRun
    A switch parameter that, if present, simulates the migration actions without
    making any actual changes on the Proxmox nodes.

.EXAMPLE
    PS C:\> ./Orchestrator.ps1
    Starts the migration process in interactive mode, prompting the user for
    all necessary configuration details.

.EXAMPLE
    PS C:\> ./Orchestrator.ps1 -ConfigFile .\config\node_config.json -LogLevel Debug -DryRun
    Runs the migration using a pre-existing configuration file with debug logging
    enabled and in dry-run mode (no changes will be made).

.OUTPUTS
    None. This script does not return any objects to the pipeline.

.NOTES
    File Name      : Orchestrator.ps1
    Author         : ProxMox Space – GPT
    Prerequisite   : PowerShell 7.0+, Posh-SSH module.
    Copyright      : (c) 2025

.LINK
    https://github.com/lordsomer/proxmox-ve-toolkit/blob/main/scripts/powershell/proxmox/ProxmoxMigration/README.md
#>

[CmdletBinding()]

param(
    [string]$ConfigFile,
    [ValidateSet('Info', 'Warning', 'Error', 'Debug')] [string]$LogLevel = 'Info',
    [switch]$DryRun
)

#---------------------------------------------------------------------
# 1.  CONSTANTS & PATHS
#---------------------------------------------------------------------
$Script:Root = Split-Path -Parent $PSCommandPath
$Script:LogDir = Join-Path $Root 'logs'
$Script:ConfigDir = Join-Path $Root 'config'
$Script:ReportsDir = Join-Path $Root 'reports'
$Script:TimeStamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
$Script:MainLog = Join-Path $LogDir "orchestrator_$TimeStamp.log"

# 2.  PREPARE FOLDERS
$null = New-Item $LogDir, $ConfigDir, $ReportsDir -ItemType Directory -Force

# 3.  IMPORT MODULE (forces recompilation if you tweak functions)
Import-Module (Join-Path $Root 'ProxmoxMigration.psm1') -Force

# 4.  KICK OFF
Start-Migration -ConfigFile $ConfigFile -LogLevel $LogLevel -DryRun:$DryRun
