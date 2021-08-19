# Azure Compute
Processes to manage Azure Compute services.



## Automated Scaling

Azure Alerts combined with two Azure Automation Runbooks using Webhooks provides a capability to scale Virtual Machines based on CPU thresholds over a given window using a custom VM size table .

There are methods to do each of these tasks on their own. You could use the built-in Alert runbook to Scale Up or Scale Down a VM; however, the system sizes use marketplace sizing which may exceed cost parameters defined by your project (or your wallet).

### Goal

Scale one or more monitored Virtual Machines up or down using a custom list of VM sizes.

### Requirements

1. Azure Automation Account with Run As
2. Azure Runbook
3. Azure Virtual Machine(s)
4. Azure Alert

### Execution

See detailed process in the ReadMe for the solution

##### URL

https://github.com/paullizer/azureCompute/tree/main/automatedScaling



[INSERT FIGURE]
