#Requires -Version 7.0
#Requires -Modules Posh-SSH

<#
.SYNOPSIS
    Proxmox VE 9.0.4 cluster migration & automation orchestrator (entry script).

.DESCRIPTION
    Coordinates every migration phase by loading ProxmoxMigration.psm1 and
    invoking Start-Migration.  All heavy lifting lives in the module.

.PARAMETER ConfigFile
    Optional JSON config exported from a previous run.

.PARAMETER LogLevel
    Info (default), Warning, Error, Debug.

.PARAMETER DryRun
    Switch – simulate actions, make NO changes on Proxmox nodes.

.EXAMPLE
    ./Orchestrator.ps1
    # interactive wizard

.EXAMPLE
    ./Orchestrator.ps1 -ConfigFile .\config\node_config.json -LogLevel Debug
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
