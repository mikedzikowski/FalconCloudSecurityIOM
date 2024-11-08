targetScope = 'managementGroup'

param eventHubName string
param eventHubRuleId string
param managementGroupName string
param principalId string
param location string

var roleDefinitionIds = [
  '39bc4728-0917-49c7-9d2c-d95423bc2eb4' // Security Reader | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#automation-contributor
  '21090545-7ca7-4776-b22c-e363652d74d2' // Key Vault Reader| https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader
  'de139f84-1756-47ae-9be6-808fbbe84772' // Website Contributor | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
  '7f6c6a51-bcf8-42ba-9220-52d62157d7db' // Azure Kubernetes Service RBAC Reader | https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#virtual-machine-contributor
]

// Policy definition scoped to the management group level
resource policyDefinition 'Microsoft.Authorization/policyDefinitions@2021-06-01' = {
  name: 'CrowdStrike - CSPM Azure Activity to EventHub'
  properties: {
    displayName: 'CrowdStrike - CSPM Azure Activity to EventHub'
    mode: 'All'
    description: 'Deploys the diagnostic settings for Azure Activity to stream subscriptions audit logs to a CrowdStrike EventHub to monitor subscription-level events'
    policyRule: {
      if: {
        field: 'type'
        equals: 'Microsoft.Resources/subscriptions'
      }
      then: {
        effect: '[parameters(\'effect\')]'
        details: {
          type: 'Microsoft.Insights/diagnosticSettings'
          deploymentScope: 'Subscription'
          existenceScope: 'Subscription'
          existenceCondition: {
            allOf: [
              {
                field: 'Microsoft.Insights/diagnosticSettings/eventHubAuthorizationRuleId'
                equals: '[parameters(\'eventHubRuleId\')]'
              }
              {
                field: 'Microsoft.Insights/diagnosticSettings/logs.enabled'
                equals: '[parameters(\'logsEnabled\')]'
              }
            ]
          }
          deployment: {
            location: 'westus'
            properties: {
              mode: 'incremental'
              template: {
                '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json# [schema.management.azure.com]'
                contentVersion: '1.0.0.0 [1.0.0.0]'
                parameters: {
                  eventHubRuleId: {
                    type: 'String'
                  }
                  eventHubName: {
                    type: 'String'
                  }
                }
                variables: {
                  eventHubShortName: '[last(split(parameters(\'eventHubName\'),\'/\'))]'
                }
                resources: [
                  {
                    type: 'Microsoft.Insights/diagnosticSettings'
                    name: 'cs-monitor-activity-to-eventhub'
                    apiVersion: '2021-05-01-preview'
                    properties: {
                      eventHubAuthorizationRuleId: '[parameters(\'eventHubRuleId\')]'
                      eventHubName: '[variables(\'eventHubShortName\')]'
                      metrics: []
                      logs: [
                        {
                          category: 'Administrative'
                          enabled: true
                        }
                        {
                          category: 'Security'
                          enabled: true
                        }
                        {
                          category: 'ServiceHealth'
                          enabled: true
                        }
                        {
                          category: 'ResourceHealth'
                          enabled: true
                        }
                        {
                          category: 'Alert'
                          enabled: true
                        }
                        {
                          category: 'Autoscale'
                          enabled: true
                        }
                        {
                          category: 'Policy'
                          enabled: true
                        }
                        {
                          category: 'Recommendation'
                          enabled: true
                        }
                      ]
                    }
                  }
                ]
                outputs: {}
              }
              parameters: {
                eventHubRuleId: {
                  value: '[parameters(\'eventHubRuleId\')]'
                }
                eventHubName: {
                  value: '[parameters(\'eventHubName\')]'
                }
              }
            }
          }
          roleDefinitionIds: [
            '/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
          ]
        }
      }
    }
    parameters: {
      eventHubRuleId: {
        type: 'String'
        metadata: {
          displayName: 'EventHub Rule ID'
          description: 'The Event Hub authorization rule Id for Azure Diagnostics. The authorization rule needs to be at Event Hub namespace level. e.g. /subscriptions/{subscription Id}/resourceGroups/{resource group}/providers/Microsoft.EventHub/namespaces/{Event Hub namespace}/authorizationrules/{authorization rule}'
          strongType: 'Microsoft.EventHub/Namespaces/AuthorizationRules'
          assignPermissions: true
        }
      }
      eventHubName: {
        type: 'String'
        metadata: {
          displayName: 'EventHub Name'
          description: 'The Event Hub name for Azure Diagnostics.'
          strongType: 'Microsoft.EventHub/Namespaces/EventHubs'
          assignPermissions: true
        }
      }
      effect: {
        type: 'String'
        metadata: {
          displayName: 'Effect'
          description: 'Enable or disable the execution of the policy'
        }
        allowedValues: [
          'DeployIfNotExists'
          'Disabled'
        ]
        defaultValue: 'DeployIfNotExists'
      }
      logsEnabled: {
        type: 'String'
        metadata: {
          displayName: 'Enable logs'
          description: 'Whether to enable logs stream to the Eventhub - True or False'
        }
        allowedValues: [
          'True'
          'False'
        ]
        defaultValue: 'True'
      }
    }
  }
}

// Policy assignment within the management group
module policyAssignmentModule './fcs-assign-diagnostics-settings-policy.bicep' = {
  name: 'policyAssignmentModule'
  scope: managementGroup(managementGroupName)
  params: {
    eventHubRuleId: eventHubRuleId
    eventHubName: eventHubName
    location: location
  }
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleDefinitionId in roleDefinitionIds: {
    name: guid(principalId, roleDefinitionId, managementGroup().id)
    properties: {
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionId)
      principalId: principalId
      principalType: 'ServicePrincipal'
    }
  }
]

output mgPolicyAssignmentId string = policyDefinition.name
output mgRoleAssignmentId string = roleAssignment[0].name
