<#  
.SYNOPSIS  
    A runbook using Managed Identity to delete snapshots older than the specified number of days from a specific resource group.
.DESCRIPTION  
    A runbook using Managed Identity to delete snapshots older than the specified number of days from a specific resource group.

        v1.0 - Update
.NOTES  
    File Name       :   Remove-ExpiredAzSnapshots.ps1  
    Author          :   Paul Lizer, paullizer@microsoft.com
    Prerequisite    :   PowerShell V5, Azure PowerShell 5.6.0 or greater
    Version         :   1.0 (2022 09 26)     
.LINK  
    https://github.com/paullizer/azureCompute 

.EXAMPLE  
    Triggered by Scheduled Runbook.

        Remove-ExpiredAzSnapshots.ps1        
#>

<#***************************************************
                       Process
-----------------------------------------------------
    
https://github.com/paullizer/azureCompute/tree/main/automatedDiskSnapshot

Requirements
    Automation Account
    Automation Account Managed Identity
    Automation Account Managed Identity assigned Contributor Role of the Resource Group where snapshots are stored

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
    [Parameter(Mandatory=$true, HelpMessage="Enter a singular Resource Group.")]
    [string]$vmResourceGroupName,
    [Parameter(Mandatory=$true, HelpMessage="Enter a singular Subscription name of VM.")]
    [string]$subscriptionName,
    [Parameter(Mandatory=$true, HelpMessage="Enter number of days in which a disk snapshot expires. e.g. 3 = older than 3 days and disk snapshot is removed.")]
    [int]$snapShotAge
)


try {
    Write-Output "Logging in to Azure using automation account's managed identity"
    Connect-AzAccount -Identity | Out-Null
}
catch {
    Write-Output $_.Exception
    throw $_.Exception
}

try {
    Write-Output "Setting subscription context to $subscriptionName"
	Set-AzContext -Subscription $subscriptionName | Out-Null
}
catch {
    Write-Output $_.Exception
    throw $_.Exception
}


try {   
    Write-Output "Checking if file $filePath exists on $vmName"
	$listOfSnapshots = Get-AzSnapshot -ResourceGroupName $vmResourceGroupName
    Write-Output $test
}
catch {
    Write-Output $_.Exception
    throw $_.Exception
}

foreach ($snapshot in $listOfSnapshots){

    Write-Output ("Snapshot exists, " + $snapshot.Name + " checking if it is older than $snapShotAge days.")

    if ($snapshot.TimeCreated -lt ((Get-Date).AddDays(-$snapShotAge))){
        try {
            Write-Output ("`tSnapshot older than $snapShotAge days. Deleting snapshot.")
            $snapShotStatus = Remove-AzSnapshot -ResourceGroupName $snapshot.ResourceGroupName -SnapshotName $snapshot.Name -Force
            if ($snapShotStatus.Status -eq "Succeeded"){
                Write-Output "`t`tSnapshot Successfully Deleted."
            } else {
                Write-Output "`t`tSnapshot delete failed."
                #Write-Output $snapShotStatus 
                throw "Snapshot delete failed. This may be a permission issue. Validate Automation Account managed identity is assigned contributor role on disk and the source resource group."
            }
        }
        catch {
            Write-Output $_.Exception
            throw $_.Exception
        }
    }
}
