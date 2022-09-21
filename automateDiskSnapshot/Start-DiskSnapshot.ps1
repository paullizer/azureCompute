<#  
.SYNOPSIS  
    A runbook using Managed Identity to check if "backup.txt" file exists and if so take snapshot of one or more disks of the VM.
.DESCRIPTION  
    A runbook using Managed Identity to check if "backup.txt" file exists and if so take snapshot of one or more disks of the VM.

        v1.0 - Update
.NOTES  
    File Name       :   Start-DiskSnapshot.ps1  
    Author          :   Paul Lizer, paullizer@microsoft.com
    Prerequisite    :   PowerShell V5, Azure PowerShell 5.6.0 or greater
    Version         :   1.0 (2022 09 21)     
.LINK  
    https://github.com/paullizer/azureCompute 

.EXAMPLE  
    Triggered by Scheduled Runbook.

        Start-DiskSnapshot.ps1        
#>

<#***************************************************
                       Process
-----------------------------------------------------
    
https://github.com/paullizer/azureCompute/tree/main/automatedDiskSnapshot

Requirements
    Automation Account
    Automation Account Management Identity
    ResourceId of Disk that will have a snapshot taken
    Automation Account Management Identity assigned Contributor Role of the VM
    Automation Account Management Identity assigned Contributor Role of the Resource Group of the VM
    Automation Account Management Identity assigned Contributor Role of the Disk

***************************************************#>
    

<#***************************************************
                       Terminology
-----------------------------------------------------
N\A
***************************************************#>


<#***************************************************
                       Variables
-----------------------------------------------------
***************************************************#>

param (
    [Parameter(Mandatory=$true, HelpMessage="Enter Region/Location of VM.")]
    [string]$location,
    [Parameter(Mandatory=$true, HelpMessage="Enter a singular VM name.")]
    [string]$vmName,
    [Parameter(Mandatory=$true, HelpMessage="Enter a singular Resource Group.")]
    [string]$vmResourceGroupName,
    [Parameter(Mandatory=$true, HelpMessage="Enter a singular Subscription name of VM.")]
    [string]$subscriptionName,
    [Parameter(Mandatory=$true, HelpMessage="Enter a singular LUN Resource ID).")]
    [string]$lunResourceId,
    [Parameter(Mandatory=$true, HelpMessage="Path of the file whose existance triggers a snapshot of the disk/LUN.")]
    [string]$filePath
)


$lunName = $lunResourceId.split("/")[$lunResourceId.split("/").count-1]
$snapShotName = $VmName + $lunName + (Get-Date -UFormat "%m%d%Y%s")

$runCommandName = "RunShellScript"
$runCommandScriptString = "test -e $filePath && echo exists || echo not"

try
{
    Write-Output "Logging in to Azure using automation account's managed identity"
    Connect-AzAccount -Identity | Out-Null
}
catch {
    Write-Output $_.Exception
    throw $_.Exception
}

try
{
    Write-Output "Setting subscription context to $subscriptionName"
	Set-AzContext -Subscription $subscriptionName | Out-Null
}
catch {
    Write-Output $_.Exception
    throw $_.Exception
}

try
{   
    Write-Output "Checking if file $filePath exists on $vmName"
    $vmResourceGroupNames = "RG-IDENTITY-EAST-PROD"
    $vmNames = "SysLogForwarder"
	$test = Invoke-AzVMRunCommand -ResourceGroupName $vmResourceGroupNames -Name $vmNames -CommandId $runCommandName -ScriptString  $runCommandScriptString
    $output = $test.Value.Message -split '\r?\n'
}
catch {
    Write-Output $_.Exception
    throw $_.Exception
}

if ($output[2] -eq "exists"){
    Write-Output "File $filePath exists, backing Up VM."
    $snapshotconfig = New-AzSnapshotConfig -CreateOption copy -Location $location -SourceUri  $lunResourceId
    try
    {
        $snapShotStatus = New-AzSnapshot -ResourceGroupName $vmResourceGroupName -SnapshotName $snapShotName -Snapshot $snapshotconfig
        if ($snapShotStatus.ProvisioningState -eq "Succeeded"){
            Write-Output "Snapshot Successfully Completed. Search Snapshots in Azure Portal to view."
        } else {
            Write-Output "Snapshot failed."
            Write-Output $snapShotStatus 
            throw "Snapshot failed. This may be a permission issue. Validate Automation Account managed identity is assigned contributor role on disk and the source resource group."
        }

    }
    catch {
        Write-Output $_.Exception
        throw $_.Exception
    }
} else {
    Write-Output "File $filePath not found, VM disk not ready for snapshot."
}