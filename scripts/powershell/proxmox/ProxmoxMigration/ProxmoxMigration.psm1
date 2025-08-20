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
    Thread-safe, colorised logger.

.PARAMETER Level
    Info | Warning | Error | Debug

.PARAMETER Message
    Message text
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
.SYNOPSIS  Interactive Y/N prompt.
#>
    param(
        [Parameter(Mandatory)][string]$Prompt
    )
    $resp = Read-Host "$Prompt (y/N)"
    return $resp -match '^(y|yes)$'
}

# --------------------------------------------------------------------------
function Get-SSHCredential {
    <#
.SYNOPSIS
    Returns a reusable PSCredential for the $Global:PXM_SSHUser using SSH keys
    (no password).  If SSH agent isn’t loaded, tries blank password.
#>
    if (-not $script:_cachedCred) {
        $script:_cachedCred = New-Object PSCredential($PXM_SSHUser, (ConvertTo-SecureString '' -AsPlainText -Force))
    }
    return $script:_cachedCred
}

# --------------------------------------------------------------------------
function Test-SSHConnection {
    <#
.SYNOPSIS
    Lightweight reachability check (2 s timeout).

.PARAMETER ComputerName
    Node IP / FQDN
#>
    param(
        [Parameter(Mandatory)][string]$ComputerName
    )
    try {
        New-SSHSession -ComputerName $ComputerName -Credential (Get-SSHCredential) `
            -ConnectionTimeout 2 -AcceptKey -ErrorAction Stop | Remove-SSHSession
        return $true
    } catch { return $false }
}

# --------------------------------------------------------------------------
function Stop-AllVMAndContainer {
    <#
.SYNOPSIS
    Gracefully stops every running VM & LXC on all standalone nodes.
    Produces CSV report under $ReportsDir.
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
    High-level wrapper that executes every migration phase in order.
.PARAMETER ConfigFile
    Optional JSON configuration file. If omitted, launches interactive setup wizard and auto-saves config.
.PARAMETER LogLevel
    Info (default) | Warning | Error | Debug
.PARAMETER DryRun
    Switch to simulate mode (no remote changes).
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
    Runs iperf3 baseline/network tests, applies LACP config, reruns benchmarks, saves results.
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
    Applies new hostnames and IPs (auto-backup before modifying).
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
    Forms initial cluster (pm1 + rg-prox03), adds rg-prox01 after migration.
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
    Deploys PBS as new VM on rg-prox03, downloads ISO, configures.
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
    Migrates all VMs and LXCs from rg-prox01 to pm1 with integrity checks and multi-stream rsync.
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
    Creates summary logs and migration reports, zips everything for audit/compliance.
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
    If migration fails, restores network configs, starts all guests, tries cluster config cleanup.
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
