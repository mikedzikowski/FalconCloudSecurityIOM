targetScope = 'managementGroup'

param eventHubRuleId string
param eventHubName string
param location string

// Existing policy definition based on name
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' existing = {
  name: 'CrowdStrike - CSPM Azure Activity to EventHub'
}

// Policy assignment within the management group
resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: 'AA Logs to FCS EventHub'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: 'CrowdStrike - CSPM Azure Activity to EventHub'
    enforcementMode: 'Default'
    policyDefinitionId: policyDefinition.id
    parameters: {
      eventHubRuleId: {
        value: eventHubRuleId
      }
      eventHubName: {
        value: eventHubName
      }
    }
  }
}

// Role assignment for the system assigned managed identity
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid('RoleAssignment', policyDefinition.id, 'ContributorRole')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor role
    principalId: policyAssignment.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Remediation task for the policy assignment
resource remediateTask 'Microsoft.PolicyInsights/remediations@2021-10-01' = {
  name: guid('Remediate', policyDefinition.id, managementGroup().id)
  properties: {
    failureThreshold: {
      percentage: 1
    }
    resourceCount: 500
    policyAssignmentId: policyAssignment.id
    policyDefinitionReferenceId: policyDefinition.id
    parallelDeployments: 10
    resourceDiscoveryMode: 'ReEvaluateNonCompliant'
  }
  dependsOn: [
    roleAssignment
  ]
}
