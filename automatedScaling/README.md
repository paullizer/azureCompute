# Automated VM Vertical Scaling
Azure Alerts combined with two Azure Automation Runbooks using Webhooks provides a capability to vertically scale Virtual Machines based on CPU thresholds over a given window using a custom VM size table.

There are methods to do each of these tasks on their own. You could use the built-in Alert runbook to Scale Up or Scale Down a VM; however, the system sizes use marketplace sizing which may exceed cost parameters defined by your project (or your wallet).

{MORE INFO COMING}

### Goal

Scale one or more monitored Virtual Machines up or down using a custom list of VM sizes.

## Workflow

### Scale Up

![scale_up_process](https://user-images.githubusercontent.com/34814295/130251189-070dbe2e-de94-48d2-bc70-68ea6d2c0264.png)

### Scale Down

![scale_down_process](https://user-images.githubusercontent.com/34814295/130251240-2c15cabe-514d-4356-abd0-042bbf657fbd.png)

## Requirements

1. Azure Automation Account with Run As
2. Azure Runbook
3. Azure Virtual Machine(s)
4. Azure Alert

### Azure Automation Account

Azure automation account uses the same permission defined for the Power On/Off capabilities ([Enable Azure Automation Start/Stop VMs during off-hours | Microsoft Docs](https://docs.microsoft.com/en-us/azure/automation/automation-solution-vm-management-enable)). The automation account leverages Run As to perform actions on resources within its defined scope. 

### Azure Runbook

This is how actions are performed against Azure resources. When an alert is triggered the alert will initiate an Azure Runbook. The Azure Runbook is an Azure PowerShell script. The Runbook can be executed on its own with the administrator supplying two values: VM Name and Resource Group. When a Runbook is initiated by an Alert, the Alert sends Webhook data in JSON format to the Runbook. The Runbook uses this information to determine which Virtual Machine triggered the alert and uses the $Webhook data to populate the VM Name and Resource Group.

#### Webhook Data

Webhook data comes in JSON format. The following is a sanitized example of the webhook data. You can view a JSON file version here ([azureCompute/example_triggered_alert_output.json at main · paullizer/azureCompute (github.com)](https://github.com/paullizer/azureCompute/blob/main/automatedScaling/example_triggered_alert_output.json)). The webhook data is provided by the alert trigger to the runbook and includes resource_id and name of the Azure resource that triggered the alert. 

The webhook uses the Command Alert Schema in JSON format ([Common alert schema for Azure Monitor alerts - Azure Monitor | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-common-schema)). It is important to make sure to enable using Common Alert Schema when setting up the Alert. This step is explained in the Deployment Section.

![example_webhook_json_data](https://user-images.githubusercontent.com/34814295/130284120-aa028963-f839-4ff9-81c8-76f512777f17.png)

The following figure is a truncated copy of the Runbook showing the $webhook data processing. 

![example_webhook](https://user-images.githubusercontent.com/34814295/130283145-8f4690d2-ef44-4bbf-9443-3195c38685ad.png)

### Azure Virtual Machine

You need at least one Azure VM but the alert can be setup to monitor all virtual machines within a resource group.

### Azure Alert

This is used to monitor VM CPU levels over time and perform an action like initiated a Runbook.

## Deployment



## Execution

#### Scale Levels

Scale levels are defined in the Runbook/PowerShell script. The script should be edited to provide the sizing defined by

![example_scale_levels](https://user-images.githubusercontent.com/34814295/130280847-d585e3ce-ab0b-4b57-b198-d0c3d5bd40a5.png)



### Resources

The following resources were consulted during the development of this capability

- https://www.petri.com/automatically-resize-azure-vm 
- https://www.apress.com/gp/blog/all-blog-posts/scale-up-azure-vms/15823864
- https://blog.ctglobalservices.com/azure/jgs/azure-automation-using-webhooks-part-1-input-data/
- https://docs.microsoft.com/en-us/azure/automation/automation-solution-vm-management-enable 
- https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-common-schema
- https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-common-schema-definitions 
- https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups-logic-app 
- https://docs.microsoft.com/en-us/azure/virtual-machines/windows/resize-vm#use-powershell-to-resize-a-vm-not-in-an-availability-set
- https://devblogs.microsoft.com/scripting/find-the-index-number-of-a-value-in-a-powershell-array/
  https://docs.microsoft.com/en-in/azure/automation/automation-webhooks
