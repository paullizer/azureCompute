# Automated VM Vertical Scaling
Azure Alerts combined with two Azure Automation Runbooks using Webhooks provides a capability to vertically scale Virtual Machines based on CPU thresholds over a given window using a custom VM size table.

There are methods to do each of these tasks on their own. You could use the built-in Alert runbook to Scale Up or Scale Down a VM; however, the system sizes use marketplace sizing which may exceed cost parameters defined by your project (or your wallet).

{MORE INFO COMING}

### Goal

Scale one or more monitored Virtual Machines up or down using a custom list of VM sizes.

### Workflow

#### Scale Up

![scale_up_process](https://user-images.githubusercontent.com/34814295/130251189-070dbe2e-de94-48d2-bc70-68ea6d2c0264.png)

#### Scale Down

![scale_down_process](https://user-images.githubusercontent.com/34814295/130251240-2c15cabe-514d-4356-abd0-042bbf657fbd.png)

### Requirements

1. Azure Automation Account with Run As
2. Azure Runbook
3. Azure Virtual Machine(s)
4. Azure Alert

### Resources

The following resources were consulted during the development of this capability.

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
