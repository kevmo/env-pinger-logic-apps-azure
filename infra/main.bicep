param environment string
param location string = 'eastus'

var logicAppName = 'logic-envpinger-${environment}'
var resourceGroupName = 'rg-envpinger-${environment}'

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: {
    environment: environment
    project: 'envpinger'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            method: 'GET'
            schema: {}
          }
        }
      }
      actions: {
        Response: {
          type: 'Response'
          kind: 'Http'
          inputs: {
            statusCode: 200
            headers: {
              'Content-Type': 'application/json'
            }
            body: {
              message: 'Hi from ${environment}'
              resource_group: resourceGroupName
              timestamp: '@{utcNow()}'
            }
          }
        }
      }
      outputs: {}
    }
  }
}

output triggerUrl string = listCallbackUrl('${logicApp.id}/triggers/manual', '2019-05-01').value
