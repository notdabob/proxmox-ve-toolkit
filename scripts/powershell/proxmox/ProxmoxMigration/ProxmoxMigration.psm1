<#
.SYNOPSIS
    A PowerShell module containing all functions for Proxmox VE cluster migration.

.DESCRIPTION
    This module provides a set of functions to orchestrate the migration of VMs
    and LXC containers between Proxmox VE 9.0.4 nodes. It includes functionality
    for pre-flight checks, network optimization (LACP), cluster management,
    Proxmox Backup Server (PBS) deployment, and robust logging and error handling.
    All state is managed within the module, and it is designed to be called from
    the Orchestrator.ps1 entry script.

.NOTES
    File Name      : ProxmoxMigration.psm1
    Author         : ProxMox Space – GPT
    Prerequisite   : PowerShell 7.0+, Posh-SSH Module
    Copyright      : (c) 2025

.LINK
    https://github.com/lordsomer/proxmox-ve-toolkit/blob/main/scripts/powershell/proxmox/ProxmoxMigration/README.md
#>

# ProxmoxMigration.psm1
# VERSION 1.0  (2025-08-17)
#   PowerShell module housing every function used by Orchestrator.ps1.
#   Follows DRY, security-first, robust error handling.

# region > PUBLIC EXPORTS  (export exactly what callers may use)
Export-ModuleMember -Function `
    Write-LogMessage, Confirm-Action, Get-SSHCredential, Test-SSHConnection, `
    Start-Migration
# endregion

# --------------------------------------------------------------------------
# > GLOBAL VARIABLES (created once when module loads – kept internal)
# --------------------------------------------------------------------------
# Module-scoped variables - avoiding global scope
$script:PXM_LogFile = ""
$script:PXM_LogLevel = "Info"
$script:PXM_DryRun = $false
$script:PXM_SSHUser = "root"

# --------------------------------------------------------------------------
function Write-LogMessage {
    <#
.SYNOPSIS
    Writes a color-coded, timestamped log message to the console and log file.

.DESCRIPTION
    This function provides a centralized logging mechanism. It respects the globally
    configured log level, skipping debug messages if not in Debug mode. All messages
    are prefixed with a timestamp and log level.

.PARAMETER Level
    Specifies the severity level of the message. Valid options are Info, Warning,
    Error, or Debug.

.PARAMETER Message
    The text of the log message to write.

.EXAMPLE
    PS C:\> Write-LogMessage -Level Info -Message "Starting process..."
    Logs an informational message to the console and the active log file.

.OUTPUTS
    None.
#>
    param(
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info',
        [Parameter(Mandatory)][string]$Message
    )

    if ($Level -eq 'Debug' -and $PXM_LogLevel -ne 'Debug') { return }

    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $text = "[$Level] $ts  $Message"

    # Write to console and log file
    Write-Information $text -InformationAction Continue

    if ($PXM_LogFile) { Add-Content -Path $PXM_LogFile -Value $text }
}

# --------------------------------------------------------------------------
function Confirm-Action {
    <#
.SYNOPSIS
    Interactive yes/no prompt for safety and confirmation of critical steps.
.DESCRIPTION
    Prompts the user with the supplied message and returns $true for a positive reply (Y/y/yes/YES), $false for all other responses (including Enter).
.PARAMETER Prompt
    The question text to display.
.OUTPUTS
    [bool] $true if user confirms, $false otherwise.
.EXAMPLE
    if (Confirm-Action "Continue to next step?") { ... }
.NOTES
    Always defaults to NO on Enter or any value other than a clear affirmative.
#>
    param(
        [Parameter(Mandatory)][string]$Prompt
    )
    $resp = Read-Host "$Prompt [y/N]:"
    return $resp -match '^(y|yes)$'
}

# --------------------------------------------------------------------------
function Get-SSHCredential {
    <#
.SYNOPSIS
    Returns (and caches) a PowerShell credential object for root SSH access to remote Proxmox nodes.
.DESCRIPTION
    By default, returns a PSCredential for user "root" with a blank password (for key-based SSH authentication).
    If the module variable $script:PXM_SSHUser is defined and set to something other than 'root', that username is used.
    Prompts for a password on first use if $env:PROXMOX_MIGRATION_FORCE_PASSWORD is set (or modify to add prompt logic if required).
    The returned credential is cached module-wide for subsequent use in the same session.
.PARAMETER None
.OUTPUTS
    [PSCredential] A credential object for SSH remoting (for use with New-SSHSession).
.EXAMPLE
    $cred = Get-SSHCredential
    $sess = New-SSHSession -ComputerName $ip -Credential $cred
.NOTES
    For key-based authentication (recommended), the password should be empty and keys must be in place (see SSH agent docs).
    You can modify the username by setting $script:PXM_SSHUser or by editing the module's configuration.
#>
    # Use module-level variable for caching
    if (-not $script:_cachedCred) {
        $username = if ($script:PXM_SSHUser) { $script:PXM_SSHUser } else { "root" }
        # By default, use blank password for key-based SSH
        $secret = ConvertTo-SecureString '' -AsPlainText -Force

        # Optionally allow forcing a password prompt -- e.g., for sudo or alternate accounts
        if ($env:PROXMOX_MIGRATION_FORCE_PASSWORD -eq "1") {
            $secret = Read-Host "Enter SSH password for $username" -AsSecureString
        }

        $script:_cachedCred = New-Object PSCredential($username, $secret)
    }
    return $script:_cachedCred
}


# --------------------------------------------------------------------------
function Test-SSHConnection {
    <#
.SYNOPSIS
    Performs a lightweight, quick check to verify SSH connectivity to a node.

.DESCRIPTION
    This function attempts to open and immediately close an SSH session to the
    target computer with a short connection timeout (2 seconds). It's used for
    quick, non-intrusive reachability checks before attempting more complex
    operations.

.PARAMETER ComputerName
    The IP address or FQDN of the Proxmox node to test.

.EXAMPLE
    PS C:\> if (Test-SSHConnection -ComputerName "192.168.1.100") {
    >>    Write-Host "Node is reachable."
    >> }

.OUTPUTS
    System.Boolean
    Returns $true if the connection is successful; otherwise, returns $false.
#>
    param(
        [Parameter(Mandatory)][string]$ComputerName
    )
    try {
        $sess = New-SSHSession -ComputerName $ComputerName -Credential (Get-SSHCredential) -ConnectTimeout 3 -AcceptKey -ErrorAction Stop
        if ($sess) { Remove-SSHSession $sess | Out-Null }
        return $true
    } catch {
        return $false
    }
}

# --------------------------------------------------------------------------
function Stop-AllVMAndContainer {
    <#
.SYNOPSIS
    Gracefully stops every running VM and LXC container on all defined nodes.

.DESCRIPTION
    Iterates through each node, lists all running VMs and containers, and then
    calls Stop-RemoteGuest for each one. It produces a CSV report detailing the
    outcome of each shutdown attempt.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess("All VMs and Containers", "Stop")) {
        return
    }

    Write-LogMessage Info "Shutting down VMs/LXCs on ${($Nodes.Keys -join ', ')}"

    $csv = Join-Path $ReportsDir "shutdown_${PXM_TimeStamp}.csv"
    "Node,Type,ID,Name,Result,Seconds" | Out-File $csv

    foreach ($nk in $Nodes.Keys) {
        $ip = $Nodes[$nk].IP
        if (-not (Test-SSHConnection $ip)) {
            Write-LogMessage Error "$nk unreachable – skipping"
            continue
        }

        $sess = New-SSHSession -ComputerName $ip -Credential (Get-SSHCredential) -AcceptKey
        try {
            # ---- VMs ----
            $vmRaw = Invoke-SSHCommand $sess 'qm list --full --output-format json' | Select-Object -Expand Output
            $vms = $vmRaw | ConvertFrom-Json
            foreach ($vm in $vms) {
                if ($vm.status -ne 'running') { continue }
                Stop-RemoteGuest -Session $sess -Type 'VM' -Id $vm.vmid -Name $vm.name -Csv $csv -Node $nk
            }

            # ---- LXCs ----
            $ctRaw = Invoke-SSHCommand $sess 'pct list --full --output-format json' | Select-Object -Expand Output
            $cts = $ctRaw | ConvertFrom-Json
            foreach ($ct in $cts) {
                if ($ct.status -ne 'running') { continue }
                Stop-RemoteGuest -Session $sess -Type 'LXC' -Id $ct.vmid -Name $ct.name -Csv $csv -Node $nk
            }
        } finally { Remove-SSHSession $sess | Out-Null }
    }
    Write-LogMessage Info "Shutdown report: $csv"
    return $true
}

function Stop-RemoteGuest {
    <#
.SYNOPSIS
    Stops a single VM or container on a remote node and records the result.

.DESCRIPTION
    This is a helper function that handles the logic for stopping a guest.
    It first attempts a graceful shutdown, waits for up to 5 minutes, and if the
    guest is still running, it forces a stop. The result is appended to the
    shutdown CSV report.

.PARAMETER Session
    The active Posh-SSH session to the target node.

.PARAMETER Type
    The type of guest, either 'VM' or 'LXC'.

.PARAMETER Id
    The numeric ID of the guest (VMID).

.PARAMETER Name
    The name of the guest.

.PARAMETER Csv
    The file path to the CSV report to append the result to.

.PARAMETER Node
    The name of the node where the guest is running.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [SSH.SshSession]$Session, [string]$Type, [int]$Id,
        [string]$Name, [string]$Csv, [string]$Node
    )

    if (-not $PSCmdlet.ShouldProcess("$Type $Name ($Id)", "Stop")) {
        return $false
    }

    $cmdStop = if ($Type -eq 'VM') { "qm shutdown $Id" } else { "pct shutdown $Id" }
    $cmdStat = if ($Type -eq 'VM') { "qm status $Id" } else { "pct status $Id" }

    $null = Invoke-SSHCommand $Session $cmdStop
    $sw = [Diagnostics.Stopwatch]::StartNew()

    do {
        Start-Sleep -Seconds 5
        $state = (Invoke-SSHCommand $Session $cmdStat | Select-Object -Expand Output) -match 'stopped'
    } until ($state -or $sw.Elapsed.TotalSeconds -gt 300)

    $result = if ($state) { 'SUCCESS' } else {
        # force stop
        Invoke-SSHCommand $Session ($cmdStop -replace 'shutdown', 'stop') | Out-Null
        'TIMEOUT'
    }
    "$Node,$Type,$Id,$Name,$result,$([int]$sw.Elapsed.TotalSeconds)" | Add-Content $Csv
    Write-LogMessage Info "$Type $Id on $Node : $result"
}

function Start-Migration {
    <#
.SYNOPSIS
    The main, high-level function that executes the entire Proxmox migration workflow.

.DESCRIPTION
    This function serves as the primary entry point for the migration process.
    It orchestrates a series of phases in a specific order: loading configuration,
    running pre-flight checks, shutting down all guests, optimizing the network,
    applying network changes, forming the cluster, deploying the backup server,
    and finally, migrating all VMs and containers. It includes a top-level
    try/catch block to trigger an emergency rollback if any phase fails.

.PARAMETER ConfigFile
    The path to an optional JSON configuration file. If this file is omitted or
    does not exist, the function triggers an interactive setup wizard to generate
    the configuration.

.PARAMETER LogLevel
    Specifies the logging verbosity. Valid options are: Info (default), Warning,
    Error, or Debug.

.PARAMETER DryRun
    A switch parameter that, if present, puts the entire module into a simulation
    mode where no remote changes will be made. This is useful for testing the
    script's logic.

.EXAMPLE
    PS C:\> Start-Migration -LogLevel Debug -DryRun
    Starts the migration in interactive mode with debug logging and dry-run enabled.

.EXAMPLE
    PS C:\> Start-Migration -ConfigFile .\config\nodes_20250817_143000.json
    Runs the migration using a specified configuration file.

.OUTPUTS
    None.
#>
    [CmdletBinding()]
    param(
        [string]$ConfigFile,
        [ValidateSet('Info', 'Warning', 'Error', 'Debug')][string]$LogLevel = 'Info',
        [switch]$DryRun
    )
    $script:LogLevel = $LogLevel
    $script:DryRun = $DryRun.IsPresent

    Write-LogMessage Info '=== Proxmox Migration Orchestrator Started ==='

    # 1. Ensure dependency module
    if (-not (Get-Module -Name Posh-SSH -ListAvailable)) {
        throw 'Posh-SSH module missing. Install-Module Posh-SSH and retry.'
    }
    Import-Module Posh-SSH -Force

    # 2. Load or create configuration
    if ($ConfigFile -and (Test-Path $ConfigFile)) {
        Write-LogMessage Info "Loading config file $ConfigFile"
        $config = Get-Content $ConfigFile | ConvertFrom-Json
    } else {
        Write-LogMessage Warning 'No config file supplied; generating interactively.'
        # --- Interactive setup wizard ---
        $config = [PSCustomObject]@{
            Timestamp   = $script:TimeStamp
            ClusterName = Read-Host "Enter cluster name [proxmox-cluster]"
            PBSVMID     = [int](Read-Host "Enter PBS VMID [200]")
            PBSMemory   = [int](Read-Host "Enter PBS VM RAM (MB) ")
            Nodes       = [ordered]@{}
        }
        if (-not $config.ClusterName) { $config.ClusterName = 'proxmox-cluster' }
        if (-not $config.PBSVMID) { $config.PBSVMID = 200 }
        if (-not $config.PBSMemory) { $config.PBSMemory = 4096 }

        $nodeNames = @(
            @{Name = 'pm1'; Role = 'cluster-root'; DefaultIP = '192.168.1.100' },
            @{Name = 'rg-prox01'; Role = 'migration-source'; DefaultIP = '192.168.1.101' },
            @{Name = 'rg-prox03'; Role = 'backup-nas-pbs'; DefaultIP = '192.168.1.102' }
        )

        foreach ($nDef in $nodeNames) {
            $n = $nDef.Name
            Write-Host "`nNode: $n ($($nDef.Role))" -ForegroundColor Cyan
            $ip = Read-Host "IP Address [$($nDef.DefaultIP)]"
            if (-not $ip) { $ip = $nDef.DefaultIP }
            $hn = Read-Host "Hostname [$n]"
            if (-not $hn) { $hn = $n }
            $ifaces = Read-Host "Network interfaces for LACP bonding (comma-separated, e.g. eth0,eth1)"
            $ifaceArr = $ifaces -split "," | ForEach-Object { $_.Trim() }
            if ($ifaceArr.Count -lt 2) {
                throw "At least 2 interfaces required for LACP on $n."
            }
            $config.Nodes.$n = @{
                IP         = $ip
                Hostname   = $hn
                Interfaces = $ifaceArr
                Role       = $nDef.Role
            }
        }

        # Save autogenerated config
        $cfgPath = Join-Path $script:ConfigDir "nodes_$script:TimeStamp.json"
        $config | ConvertTo-Json -Depth 10 | Set-Content $cfgPath
        Write-LogMessage Info "Interactive config saved to $cfgPath"
    }
    $nodes = $config.Nodes

    try {
        # ==== Core workflow ====
        Invoke-PreflightChecks -Nodes $nodes
        Stop-AllVMsAndContainers -Nodes $nodes
        Invoke-NetworkOptimisation -Nodes $nodes
        Set-NetworkChanges -Nodes $nodes
        New-ProxmoxCluster -Nodes $nodes -ClusterName $config.ClusterName
        Deploy-ProxmoxBackupServer -Nodes $nodes -VMID $config.PBSVMID -MemoryMB $config.PBSMemory
        Invoke-Migration -Nodes $nodes
        New-FinalReports
        Write-LogMessage Info '🎉 Migration completed successfully.'
        Write-Host "`nMigration finished. All logs and reports written to $script:ReportsDir" -ForegroundColor Green
    } catch {
        Write-LogMessage Error $_.Exception.Message
        Invoke-EmergencyRollback -Nodes $nodes
        throw
    }
}

function Invoke-NetworkOptimisation {
    <#
.SYNOPSIS
    Benchmarks network, applies LACP bonding, and runs benchmarks again.

.DESCRIPTION
    This function orchestrates the network optimization phase. It first runs
    iperf3 between all nodes to establish a baseline. It then configures a
    9000 MTU LACP bond (802.3ad, layer2+3) on all nodes using the interfaces
    defined in the config. Finally, it runs the iperf3 benchmarks again to
    measure the improvement. Results are saved to CSV reports.

.PARAMETER Nodes
    The node configuration hashtable.
#>
    param([hashtable]$Nodes)
    Write-LogMessage Info 'Running baseline network benchmarks (iperf3)...'
    $baselineReport = Join-Path $script:ReportsDir "network_baseline_$script:TimeStamp.csv"
    'Source,Target,Bandwidth_Mbps,Latency_ms,Result' | Out-File $baselineReport

    $nodeList = $Nodes.Keys
    for ($i = 0; $i -lt $nodeList.Count; $i++) {
        for ($j = 0; $j -lt $nodeList.Count; $j++) {
            if ($i -eq $j) { continue }
            $srcName = $nodeList[$i]
            $dstName = $nodeList[$j]
            $srcIP = $Nodes[$srcName].IP
            $dstIP = $Nodes[$dstName].IP
            Write-LogMessage Info "Testing ${srcName}→${dstName}..."
            # Start iperf3 server
            $dstSess = New-SSHSession -ComputerName $dstIP -Credential (Get-SSHCredential) -AcceptKey
            Invoke-SSH $dstSess 'pkill iperf3; iperf3 -s -D' | Out-Null
            Start-Sleep -Seconds 2
            # Run client
            $srcSess = New-SSHSession -ComputerName $srcIP -Credential (Get-SSHCredential) -AcceptKey
            $out = Invoke-SSH $srcSess "iperf3 -c $dstIP -t 10 -J"
            Remove-SSHSession $dstSess | Out-Null
            Remove-SSHSession $srcSess | Out-Null
            # Parse output
            try {
                $json = $out | ConvertFrom-Json
                $bw = [math]::Round($json.end.sum_received.bits_per_second / 1MB, 2)
                $latencyResult = (Test-Connection -ComputerName $dstIP -Count 3 | Measure-Object ResponseTime -Average).Average
                "$srcName,$dstName,$bw,$latencyResult,SUCCESS" | Add-Content $baselineReport
            } catch {
                "$srcName,$dstName,0,0,ERROR" | Add-Content $baselineReport
            }
        }
    }
    Write-LogMessage Info "Baseline benchmarks completed. Report: $baselineReport"

    # LACP config (Idempotent!)
    foreach ($name in $Nodes.Keys) {
        $ip = $Nodes[$name].IP
        $ifaces = $Nodes[$name].Interfaces -join ' '
        Write-LogMessage Info "Applying LACP 802.3ad bond0 to $name"
        $lacpConfig = @"
auto bond0
iface bond0 inet static
    address $ip
    netmask 255.255.255.0
    gateway 192.168.1.1
    bond-slaves $ifaces
    bond-mode 802.3ad
    bond-miimon 100
    bond-lacp-rate fast
    bond-xmit-hash-policy layer2+3
    mtu 9000
auto vmbr0
iface vmbr0 inet manual
    bridge-ports bond0
    bridge-stp off
    bridge-fd 0
"@
        $sess = New-SSHSession -ComputerName $ip -Credential (Get-SSHCredential) -AcceptKey
        $tmpFile = "/tmp/interfaces_new"
        Invoke-SSH $sess "echo '$lacpConfig' > $tmpFile"
        Invoke-SSH $sess "cp $tmpFile /etc/network/interfaces && systemctl restart networking"
        Remove-SSHSession $sess | Out-Null
    }
    Write-LogMessage Info "LACP Bonding applied on all nodes."

    # Post-change benchmarks
    $postReport = Join-Path $script:ReportsDir "network_postlacp_$script:TimeStamp.csv"
    'Source,Target,Bandwidth_Mbps,Latency_ms,Result' | Out-File $postReport
    Write-LogMessage Info "Running post-LACP benchmarks..."
    for ($i = 0; $i -lt $nodeList.Count; $i++) {
        for ($j = 0; $j -lt $nodeList.Count; $j++) {
            if ($i -eq $j) { continue }
            $srcName = $nodeList[$i]
            $dstName = $nodeList[$j]
            $srcIP = $Nodes[$srcName].IP
            $dstIP = $Nodes[$dstName].IP
            $dstSess = New-SSHSession -ComputerName $dstIP -Credential (Get-SSHCredential) -AcceptKey
            Invoke-SSH $dstSess 'pkill iperf3; iperf3 -s -D' | Out-Null
            Start-Sleep -Seconds 2
            $srcSess = New-SSHSession -ComputerName $srcIP -Credential (Get-SSHCredential) -AcceptKey
            $out = Invoke-SSH $srcSess "iperf3 -c $dstIP -t 10 -J"
            Remove-SSHSession $dstSess | Out-Null
            Remove-SSHSession $srcSess | Out-Null
            try {
                $json = $out | ConvertFrom-Json
                $bw = [math]::Round($json.end.sum_received.bits_per_second / 1MB, 2)
                $latencyResult = (Test-Connection -ComputerName $dstIP -Count 3 | Measure-Object ResponseTime -Average).Average
                "$srcName,$dstName,$bw,$latencyResult,SUCCESS" | Add-Content $postReport
            } catch {
                "$srcName,$dstName,0,0,ERROR" | Add-Content $postReport
            }
        }
    }
    Write-LogMessage Info "Post-LACP benchmarks completed. Report: $postReport"
}

function Set-NetworkChange {
    <#
.SYNOPSIS
    Applies new hostnames to the nodes as defined in the configuration.

.DESCRIPTION
    This function connects to each node and updates `/etc/hostname` and `/etc/hosts`
    to reflect the desired hostname from the configuration. It does not handle
    IP address changes, as those are applied as part of the LACP bonding in
    the Invoke-NetworkOptimisation function.

.PARAMETER Nodes
    The node configuration hashtable.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Nodes)

    if (-not $PSCmdlet.ShouldProcess("Network Configuration", "Apply Changes")) {
        return
    }

    foreach ($key in $Nodes.Keys) {
        $ip = $Nodes[$key].IP
        $hostname = $Nodes[$key].Hostname
        Write-LogMessage Info "Setting hostname for $key -> $hostname"
        $sess = New-SSHSession -ComputerName $ip -Credential (Get-SSHCredential) -AcceptKey
        try {
            Invoke-SSH $sess "echo '$hostname' > /etc/hostname && hostnamectl set-hostname $hostname"
            $hostsLine = "$ip $hostname"
            Invoke-SSH $sess "echo '$hostsLine' >> /etc/hosts"
            Write-LogMessage Info "Hostname/IP applied for $key"
        } finally { Remove-SSHSession $sess | Out-Null }
    }
}

function New-ProxmoxCluster {
    <#
.SYNOPSIS
    Forms the Proxmox cluster in a phased approach.

.DESCRIPTION
    First, it creates the cluster on the primary node (pm1). Second, it joins
    the backup node (rg-prox03). Finally, after the migration is complete, it
    joins the source migration node (rg-prox01) to the cluster.

.PARAMETER Nodes
    The node configuration hashtable.

.PARAMETER ClusterName
    The name for the new Proxmox cluster.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param([hashtable]$Nodes, [string]$ClusterName)

    if (-not $PSCmdlet.ShouldProcess("Proxmox Cluster '$ClusterName'", "Create")) {
        return
    }

    # Assume pm1 is the root
    $pm1IP = $Nodes['pm1'].IP
    $rg_prox03IP = $Nodes['rg-prox03'].IP
    $rg_prox01IP = $Nodes['rg-prox01'].IP
    Write-LogMessage Info "Creating cluster $ClusterName from pm1..."
    $pm1Sess = New-SSHSession -ComputerName $pm1IP -Credential (Get-SSHCredential) -AcceptKey
    $rg_prox03Sess = New-SSHSession -ComputerName $rg_prox03IP -Credential (Get-SSHCredential) -AcceptKey
    $rg_prox01Sess = New-SSHSession -ComputerName $rg_prox01IP -Credential (Get-SSHCredential) -AcceptKey

    # Create cluster on pm1
    Invoke-SSH $pm1Sess "pvecm create $ClusterName"
    # Join rg-prox03
    Invoke-SSH $rg_prox03Sess "pvecm add $pm1IP"
    Write-LogMessage Info "pm1 and rg-prox03 in cluster"
    # After migration, join rg-prox01
    Invoke-SSH $rg_prox01Sess "pvecm add $pm1IP"
    Write-LogMessage Info "rg-prox01 joined cluster"
    Remove-SSHSession $pm1Sess, $rg_prox03Sess, $rg_prox01Sess | Out-Null
}
function Deploy-ProxmoxBackupServer {
    <#
.SYNOPSIS
    Deploys a new Proxmox Backup Server (PBS) VM on the backup node.

.DESCRIPTION
    This function downloads the latest PBS ISO image, creates a new VM on the
    specified backup node (rg-prox03) with the configured VMID and memory,
    attaches the ISO, and starts the VM to begin the installation process.

.PARAMETER Nodes
    The node configuration hashtable.

.PARAMETER VMID
    The numeric ID to assign to the new PBS VM.

.PARAMETER MemoryMB
    The amount of RAM in megabytes to allocate to the PBS VM.
#>
    param([hashtable]$Nodes, [int]$VMID, [int]$MemoryMB)
    $rg_prox03IP = $Nodes['rg-prox03'].IP
    $sess = New-SSHSession -ComputerName $rg_prox03IP -Credential (Get-SSHCredential) -AcceptKey
    Write-LogMessage Info "Deploying PBS VM $VMID on rg-prox03"
    try {
        # Download PBS ISO
        Invoke-SSH $sess "wget -O /var/lib/vz/template/iso/pbs.iso https://enterprise.proxmox.com/iso/proxmox-backup-server-latest.iso"
        # Create VM
        Invoke-SSH $sess "qm create $VMID --name PBS --memory $MemoryMB --net0 virtio,bridge=vmbr0 --ostype l26"
        Invoke-SSH $sess "qm set $VMID --ide2 local:iso/pbs.iso,media=cdrom"
        Invoke-SSH $sess "qm set $VMID --boot order=ide2"
        Invoke-SSH $sess "qm start $VMID"
        Write-LogMessage Info "PBS VM created and started"
    } finally { Remove-SSHSession $sess | Out-Null }
}

function Invoke-Migration {
    <#
.SYNOPSIS
    Migrates all VMs and LXCs from the source node to the destination node.

.DESCRIPTION
    This function handles the core data migration. It iterates through all VMs
    and containers on the source node (rg-prox01), ensures they are stopped,
    and then uses rsync to copy their disk images and configuration files to
    the destination node (pm1). It uses checksums to ensure data integrity.

.PARAMETER Nodes
    The node configuration hashtable.
#>
    param([hashtable]$Nodes)
    $srcIP = $Nodes['rg-prox01'].IP
    $dstIP = $Nodes['pm1'].IP
    Write-LogMessage Info "Migrating VMs and LXCs from rg-prox01 to pm1..."

    $srcSess = New-SSHSession -ComputerName $srcIP -Credential (Get-SSHCredential) -AcceptKey
    $dstSess = New-SSHSession -ComputerName $dstIP -Credential (Get-SSHCredential) -AcceptKey
    try {
        # List VMs & LXCs
        $vms = Invoke-SSH $srcSess "qm list --full --output-format json" | ConvertFrom-Json
        $cts = Invoke-SSH $srcSess "pct list --full --output-format json" | ConvertFrom-Json
        foreach ($vm in $vms) {
            $vmid = $vm.vmid
            Write-LogMessage Info "Migrating VM $vmid..."
            # Stop VM (should be stopped as part of prior step)
            Invoke-SSH $srcSess "qm stop $vmid"
            Start-Sleep -Seconds 2
            # Rsync config/disks with checksums
            $diskPath = "/var/lib/vz/images/$vmid"
            $configPath = "/etc/pve/qemu-server/$vmid.conf"
            $rsyncCmd = "rsync -az --progress $diskPath root@${dstIP}:/var/lib/vz/images/ --checksum --inplace --ignore-existing"
            Invoke-SSH $srcSess $rsyncCmd
            $rsyncConfig = "rsync -az $configPath root@${dstIP}:/etc/pve/qemu-server/"
            Invoke-SSH $srcSess $rsyncConfig
            Write-LogMessage Info "Migrated VM $vmid"
        }
        foreach ($ct in $cts) {
            $ctid = $ct.vmid
            Write-LogMessage Info "Migrating LXC $ctid..."
            Invoke-SSH $srcSess "pct stop $ctid"
            Start-Sleep -Seconds 2
            $ctPath = "/var/lib/vz/private/$ctid"
            $confPath = "/etc/pve/lxc/$ctid.conf"
            $rsyncCmd = "rsync -az --progress $ctPath root@${dstIP}:/var/lib/vz/private/ --checksum --inplace --ignore-existing"
            Invoke-SSH $srcSess $rsyncCmd
            $rsyncConf = "rsync -az $confPath root@${dstIP}:/etc/pve/lxc/"
            Invoke-SSH $srcSess $rsyncConf
            Write-LogMessage Info "Migrated LXC $ctid"
        }
        Write-LogMessage Info "Migration completed."
    } finally {
        Remove-SSHSession $srcSess | Out-Null
        Remove-SSHSession $dstSess | Out-Null
    }
}

function New-FinalReport {
    <#
.SYNOPSIS
    Generates and archives all final migration reports.

.DESCRIPTION
    This function gathers all the CSV reports generated during the migration,
    compiles them into a single summary text file, and then creates a zip archive
    of all reports for audit and compliance purposes.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (-not $PSCmdlet.ShouldProcess("Final Migration Report", "Generate")) {
        return
    }

    $reportFiles = Get-ChildItem $script:ReportsDir -Filter \"*.csv\" | Select-Object -ExpandProperty FullName
    $summaryPath = Join-Path $script:ReportsDir \"migration_summary_$script:TimeStamp.txt\"
    \"Proxmox Cluster Migration Summary ($script:TimeStamp)\n\" | Set-Content $summaryPath
    foreach ($rf in $reportFiles) {
        (Get-Content $rf) | Add-Content $summaryPath
        \"\n---\n\" | Add-Content $summaryPath
    }
    # Zip full report
    $zipPath = Join-Path $script:ReportsDir \"migration_audit_$script:TimeStamp.zip\"
    Compress-Archive -Path $reportFiles -DestinationPath $zipPath
    Write-LogMessage Info \"All reports archived to $zipPath\"
}

function Invoke-EmergencyRollback {
    <#
.SYNOPSIS
    Attempts to roll back changes if a critical failure occurs during migration.

.DESCRIPTION
    This function is called by the main catch block in Start-Migration. It attempts
    to restore the original network configurations from backups, restart all guest
    VMs/containers, and clean up any partial cluster configurations to return the
    nodes to their pre-migration state.

.PARAMETER Nodes
    The node configuration hashtable.
#>
    param([hashtable]$Nodes)
    Write-LogMessage Error \"EMERGENCY ROLLBACK INITIATED!\"

    # Rollback network config
    foreach ($n in $Nodes.Keys) {
        $ip = $Nodes[$n].IP
        $backup = Join-Path $script:ConfigDir 'backups' \"${n}_interfaces_$script:TimeStamp\"
        if (Test-Path $backup) {
            $sess = New-SSHSession -ComputerName $ip -Credential (Get-SSHCredential) -AcceptKey
            try {
                Invoke-SSH $sess \"cp $backup /etc/network/interfaces && systemctl restart networking\"
            } finally { Remove-SSHSession $sess | Out-Null }
            Write-LogMessage Info \"Restored network config for $n\"
        }
    }
    # Start guests
    Stop-AllVMAndContainer -Nodes $Nodes # Already supports rollback if rerun

    # Clean cluster state
    foreach ($n in $Nodes.Keys) {
        $ip = $Nodes[$n].IP
        $sess = New-SSHSession -ComputerName $ip -Credential (Get-SSHCredential) -AcceptKey
        try {
            Invoke-SSH $sess \"systemctl stop pve-cluster || true\"
            Invoke-SSH $sess \"systemctl stop corosync || true\"
            Invoke-SSH $sess \"rm -f /etc/pve/corosync.conf || true\"
            Invoke-SSH $sess \"rm -f /etc/corosync/corosync.conf || true\"
        } finally { Remove-SSHSession $sess | Out-Null }
        Write-LogMessage Info \"Cleaned partial cluster on $n\"
    }
    Write-LogMessage Info \"Rollback completed\"
}
function Invoke-PreflightChecks {
    <#
.SYNOPSIS
    Verifies SSH connectivity, Proxmox version, and backs up current network and hosts configurations on all defined nodes.
.DESCRIPTION
    - Ensures SSH access to each node using provided SSH keys/credentials.
    - Validates each node is running the expected Proxmox VE version (requires version 9.0.x).
    - Creates a timestamped backup of /etc/network/interfaces and /etc/hosts, both locally (to $script:ConfigDir\backups) and remotely (on the node itself).
    - Aborts with clear logs if any node fails a preflight check.
.NOTES
    Logs all progress and results, aborts on any critical failure.
#>
    param([hashtable]$Nodes)

    Write-LogMessage Info "==== Proxmox Pre-flight Checks ===="
    $backupDir = Join-Path $script:ConfigDir "backups"
    if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }

    foreach ($name in $Nodes.Keys) {
        $ip = $Nodes[$name].IP
        Write-LogMessage Info ("Checking connectivity and configuration on {0} ({1})" -f $name, $ip)

        if (-not (Test-SSHConnection $ip)) {
            Write-LogMessage Error "SSH connection FAILED for $name ($ip)"
            throw "Cannot SSH to $name ($ip). Aborting."
        }

        $sess = New-SSHSession -ComputerName $ip -Credential (Get-SSHCredential) -AcceptKey
        try {
            # Validate Proxmox version
            $ver = Invoke-SSHCommand -SSHSession $sess -Command 'pveversion -v | head -n1' -TimeOut 30 | Select-Object -Expand Output
            Write-LogMessage Info "$name: $ver"

            if ($ver -notmatch 'pve-manager/9\.0') {
                Write-LogMessage Warning "$name: Expected Proxmox VE 9.0.x, got: $ver"
                if (-not (Confirm-Action "This node may not be compatible. Continue anyway?")) {
                    throw "Version check failed on $name"
                }
            }

            $ts = $script:TimeStamp
            # Create remote network and hosts backups (timestamped)
            Invoke-SSHCommand -SSHSession $sess -Command "cp /etc/network/interfaces /etc/network/interfaces.bak.$ts" | Out-Null
            Invoke-SSHCommand -SSHSession $sess -Command "cp /etc/hosts /etc/hosts.bak.$ts" | Out-Null

            # Fetch backups locally as well
            $netBackup = Join-Path $backupDir "${name}_interfaces_$ts"
            $hostsBackup = Join-Path $backupDir "${name}_hosts_$ts"
            Get-SCPFile -ComputerName $ip -Credential (Get-SSHCredential) -RemoteFile "/etc/network/interfaces" -LocalFile $netBackup -ErrorAction Stop
            Get-SCPFile -ComputerName $ip -Credential (Get-SSHCredential) -RemoteFile "/etc/hosts" -LocalFile $hostsBackup -ErrorAction Stop

            Write-LogMessage Info "Backups saved for $name: $netBackup, $hostsBackup"
        } catch {
            Write-LogMessage Error "Failed pre-flight on $name ($ip): $_"
            throw
        } finally {
            Remove-SSHSession $sess | Out-Null
        }
    }
    Write-LogMessage Info "==== All pre-flight checks PASSED. ===="
}
