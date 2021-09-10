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

Webhook data comes in JSON format. The following is a sanitized example of the webhook data. You can view a JSON file version here ([azureCompute/example_webhook.json at main · paullizer/azureCompute (github.com)](https://github.com/paullizer/azureCompute/blob/main/automatedScaling/example_webhook.json)). The webhook data is provided by the alert trigger to the runbook and includes resource_id and name of the Azure resource that triggered the alert. 

The webhook uses the Command Alert Schema in JSON format ([Common alert schema for Azure Monitor alerts - Azure Monitor | Microsoft Docs](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-common-schema)). It is important to make sure to enable using Common Alert Schema when setting up the Alert. This step is explained in the Deployment Section.

![example_webhook_json_data](https://user-images.githubusercontent.com/34814295/130284120-aa028963-f839-4ff9-81c8-76f512777f17.png)

The Webhook's RequestBody node contains an additional JSON formatted dataset. This dataset contains the valued variables like Resource IDs and Names that triggered the alert. The following figure is a formatted copy of the RequestBody in the previous figure. You can also view the code version here ([azureCompute/example_webhook_requestBody.json at main · paullizer/azureCompute (github.com)](https://github.com/paullizer/azureCompute/blob/main/automatedScaling/example_webhook_requestBody.json)). The code version can be used to select additional values that may be important if you were to modify the Runbooks or to create your own Runbooks. 

![example_webhook_requestBody_json_data](https://user-images.githubusercontent.com/34814295/130356034-ba135a10-36ad-49d1-8d6d-4ccc4fa1c539.png)

The following figure is a truncated copy of the Runbook showing the $webhook data processing. You can view this code within the context of the Runbook by viewing either the Scale Up or Scale Down Runbooks, you can view the Scale Up VM Runbook here ([azureCompute/Start-AzVMScaleUp.ps1 at main · paullizer/azureCompute (github.com)](https://github.com/paullizer/azureCompute/blob/main/automatedScaling/Start-AzVMScaleUp.ps1)).

![example_webhook](https://user-images.githubusercontent.com/34814295/130283145-8f4690d2-ef44-4bbf-9443-3195c38685ad.png)

#### Scale Levels

Scale levels are defined in the Runbook/PowerShell script. Script editors can modify the code to update the default set of scale levels. 

![example_scale_levels](https://user-images.githubusercontent.com/34814295/130280847-d585e3ce-ab0b-4b57-b198-d0c3d5bd40a5.png)

#### VM Size Parameter

There is another option to provide a set of VM sizes at run-time of the Runbook or script. ![example_vmsize_variable](https://user-images.githubusercontent.com/34814295/130367903-4885eaff-ff85-45a4-ab3a-b7f8f3401334.png)

When setting up the Runbook, the administrator can provide a comma separated list of VM Sizes which will override the default values in the Runbook/script.

1. Select Parameter field.
2. Enter a comma separated list of VM Sizes.
3. Select OK.

![provide_vmsize_parameter](https://user-images.githubusercontent.com/34814295/130368153-5beb6de8-b010-4e36-8cea-81958d084ff6.png)

### Azure Virtual Machine

You need at least one Azure VM but the alert can be setup to monitor all virtual machines within a resource group.

### Azure Alert

This is used to monitor VM CPU levels over time and perform an action like initiated a Runbook.

## Deployment

1. Deploy Automation Account with Start/Stop ([Enable Azure Automation Start/Stop VMs during off-hours | Microsoft Docs](https://docs.microsoft.com/en-us/azure/automation/automation-solution-vm-management-enable))
   1. This task sets up the Automation Account with the appropriate permissions
2. Create a new Runbook in your Automation Account ([Manage runbooks in Azure Automation | Microsoft Docs](https://docs.microsoft.com/en-us/azure/automation/manage-runbooks#:~:text=1 Sign in to the Azure portal. 2,to create the runbook and open the editor.))
   1. You will create 2 (two) Runbooks: One for Start-AzVMScaleUp and another for Start-AzVMScaleDown
      2. ![example_automation_account_runbooks](https://user-images.githubusercontent.com/34814295/130367471-79e995c2-a1f3-4cb5-9220-742e6241881c.png)
   2. (1) Paste the code for each Scale process into their respective Runbooks, (2) Save, and then (3) Publish the Runbook
      4. ![example_publish_runbook](https://user-images.githubusercontent.com/34814295/130367664-7ea7a671-3fc9-4c36-bd3e-02f79bafcf71.png)
3. Create CPU Threshold Alert
   1. Go to the Alerts management pane; one way is to (1) search for alerts and (2) select from the drop down menu.
      1. ![example_alert_portal_search](https://user-images.githubusercontent.com/34814295/132868181-2877253b-8f64-4d47-98f6-a198e1be8da1.png)
   2. You will create two rules, one to scale up and one to scale down the virtual machines. 
   3. Create a new alert by Select **+ New alert rule** 
   4. Select the scope, this will be the resource group(s) holding the virtual machines to monitor.
      1. (1) select **Select resource**, (2) verify the correct subscription is pre-selected, (3) update **Filter by resource type** to *Virtual machines*, (4) type in the name of the Resource Group, (5) select the Resource Group, (6) select **Done**![example_alert_scope-select_resource](https://user-images.githubusercontent.com/34814295/132871054-8ab06220-9326-4026-b9af-f81e013555c4.png)
   5. Select the condition to evaluate and trigger a VM to scale.
      1. (1) select **Add condition**, (2) enter *cpu* in the search input, (3) select **Percentage CPU** ![example_alert_condition-add_condition](https://user-images.githubusercontent.com/34814295/132871235-f9f8250a-aa30-46c8-b9e7-f206d372717e.png)
      2. When creating the scale up alert, you will select *Greater Than* as the **Operator** and a **Threshold value** of *50-90*. The **Threshold value** is the average percentage of CPU usage you want the Virtual Machine to exceed over 15 minutes. This example uses a **Threshold value** of *70*.
         1. (1) select *Greater than* as the **Operator**, (2) enter *70* as the **Threshold value**, (3) select *15 minutes* as the **Aggregation granularity (Period)**, (4) select *Every 1 minute* as the **Frequency of evaluation**.![example_alert_condition-configure_signal_logic-scale_up](https://user-images.githubusercontent.com/34814295/132872280-a6a6100c-7d44-40c6-87c1-bdc451221d94.png)
      3. When creating the scale down alert, you will select *Less Than* as the **Operator** and a **Threshold value** of *10-50*. The **Threshold value** is the average percentage of CPU usage you want the Virtual Machine to exceed over 15 minutes. This example uses a **Threshold value** of *15*.
         1. (1) select *Less than* as the **Operator**, (2) enter *15* as the **Threshold value**, (3) select *15 minutes* as the **Aggregation granularity (Period)**, (4) select *Every 1 minute* as the **Frequency of evaluation**.![example_alert_condition-configure_signal_logic-scale_down](https://user-images.githubusercontent.com/34814295/132873683-099e524e-8a3a-413b-a74d-6ff305d50c3d.png)
   6. Select the action to be performed when a condition threshold is triggered
      1. Select **Add action groups**
      2. Select **+ Create action groups**
      3. Edit the Basics tab
         1. Select the Resource group holding your Virtual machines
         2. Enter a name for the Action group; this example uses the following Action group name based on which Alert is being created
            1. Scale_Up_VM 
            2. Scale_Down_VM 
         3. Enter a display name for the Action group; this example uses the following Display name based on which Alert is being created
            1. Scale_Up_VM 
            2. Scale_Down_VM
      4. Edit the Notifications tab
         1. 

## Execution





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
