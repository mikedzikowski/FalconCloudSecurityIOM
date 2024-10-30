param policyAssignmentId string

resource exemption 'Microsoft.Authorization/policyExemptions@2022-07-01-preview' = {
  name: 'exempt-cspm-resource-group'
  properties: {
    assignmentScopeValidation: 'Default'
    description: 'Exempts the resource group to prevent issues with deploying FCS CSPM.'
    displayName: 'IOM and IOA Resource Group Exemption'
    exemptionCategory: 'Mitigated'
    expiresOn: null
    metadata: null
    policyAssignmentId: policyAssignmentId
    policyDefinitionReferenceIds: []
    resourceSelectors: []
  }
}
