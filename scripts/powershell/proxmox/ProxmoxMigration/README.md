# Proxmox VE Cluster Migration & Automation Project

## Objective

Create comprehensive automation scripts for Proxmox VE 9.0.4 cluster formation, VM/LXC migration, and network optimization.

## Hardware Environment

- **3x Dell servers**: R710, R610, R520 (legacy EOL hardware)
- **Current names**: pm1 (12TB), rg-prox01 (4TB), rg-prox03 (16TB)
- **Network**: Multiple gigabit ethernet ports per server (2-4 ports), same LAN
- **SSH**: Key authentication already configured between all nodes

## Current Situation

- All 3 servers run independent Proxmox VE 9.0.4 instances
- Incorrectly identified rg-prox01 as cluster root and migrated VMs there
- Need pm1 as actual cluster root (correct choice in hindsight)
- rg-prox01 has current/updated VM copies, pm1 has outdated versions
- rg-prox03 will be backup/NAS node + run Proxmox Backup Server

## Requirements

### Script Architecture

- **Separation of concerns**: Multiple focused scripts vs monolithic
- **Dual language support**: Both Bash (.sh) and PowerShell (.ps1/.psm1) versions
- **Comprehensive inline documentation**: Self-documenting code with detailed headers
- **DRY principles**: No hardcoded values, reusable components
- **Security-first approach**: Input validation, error handling, rollback capabilities

### Core Functionality

1. **Pre-migration safety**: Shutdown ALL VMs/LXCs across all nodes before migration
2. **Network optimization**:
   - Configure LACP bonding (802.3ad) or fallback modes
   - Benchmark network performance before/after changes
   - Present results with rerun/reconfigure/revert options
3. **Cluster formation**: pm1 + rg-prox03 first, then add rg-prox01 after migration
4. **PBS deployment**: Autonomous download, VM creation, installation on rg-prox03
5. **Migration logic**:
   - Both VMs and LXC containers
   - Checksum + modification date comparison
   - Archive older/duplicate files to rg-prox03 (never delete)
   - Multi-stream transfers for performance
6. **Interactive configuration**: Prompt for new hostnames, IP addresses, network interfaces

### Deliverables Requested

- **Main orchestrator script**: Single entry point that coordinates everything
- **Modular components**: Network bonding, benchmarking, PBS setup, migration
- **Common library**: Shared functions for logging, validation, CSV reporting
- **Both Bash and PowerShell implementations**
- **Comprehensive documentation**: Usage, requirements, safety features in headers

### Execution Flow

1. Collect user inputs (hostnames, IPs, network interfaces)
2. Shutdown all VMs/LXCs on all nodes
3. Baseline network benchmarks
4. Configure LACP bonding on all nodes
5. Post-change benchmarks with user decision menu
6. Apply hostname/IP changes
7. Create initial cluster (pm1 + rg-prox03)
8. Deploy PBS as VM on rg-prox03
9. Migrate VMs/LXCs from rg-prox01 to pm1
10. Join rg-prox01 to cluster
11. Generate comprehensive reports

### Technical Specifications

- **File transfers**: Optimized rsync with multiple streams
- **Validation**: MD5 checksums for data integrity
- **Logging**: Timestamped logs and CSV reports
- **Backup strategy**: Archive to rg-prox03, never delete data
- **Network testing**: iperf3 full-mesh benchmarks
- **Error handling**: Graceful failures with rollback options

### Output Requirements

- Timestamped execution logs
- CSV migration reports for audit
- Network benchmark results and analysis
- Configuration backups before changes
- User prompts for all critical decisions
  Run from pm1 as root, fully autonomous with interactive prompts, no hardcoded values.

# 1 Place all three files in the same folder on pm1

# 2 Install Posh-SSH once:

Install-Module Posh-SSH -Scope CurrentUser

# 3 Run:

cd .\Proxmox-Migration
./Orchestrator.ps1
