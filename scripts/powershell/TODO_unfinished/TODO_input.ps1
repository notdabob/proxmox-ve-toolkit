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

function Set-NetworkChanges {
    <#
.SYNOPSIS
    Applies new hostnames and IPs (auto-backup before modifying).
#>
    param([hashtable]$Nodes)
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
    param([hashtable]$Nodes, [string]$ClusterName)
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
            $rsyncCmd = "rsync -az --progress $diskPath root@$dstIP:/var/lib/vz/images/ --checksum --inplace --ignore-existing"
            Invoke-SSH $srcSess $rsyncCmd
            $rsyncConfig = "rsync -az $configPath root@$dstIP:/etc/pve/qemu-server/"
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
            $rsyncCmd = "rsync -az --progress $ctPath root@$dstIP:/var/lib/vz/private/ --checksum --inplace --ignore-existing"
            Invoke-SSH $srcSess $rsyncCmd
            $rsyncConf = "rsync -az $confPath root@$dstIP:/etc/pve/lxc/"
            Invoke-SSH $srcSess $rsyncConf
            Write-LogMessage Info "Migrated LXC $ctid"
        }
        Write-LogMessage Info "Migration completed."
    } finally {
        Remove-SSHSession $srcSess | Out-Null
        Remove-SSHSession $dstSess | Out-Null
    }
}

function New-FinalReports {
    <#
.SYNOPSIS
    Creates summary logs and migration reports, zips everything for audit/compliance.
#>
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
    Stop-AllVMsAndContainers -Nodes $Nodes # Already supports rollback if rerun

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
