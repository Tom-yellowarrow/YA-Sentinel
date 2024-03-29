param(
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [Parameter(Mandatory = $true)][string]$Workspace,
    [Parameter(Mandatory = $true)][string[]]$Connectors
)

$context = Get-AzContext

if (!$context) {
    Connect-AzAccount
    $context = Get-AzContext
}

$SubscriptionId = $context.Subscription.Id

Write-Host "Connected to Azure with subscription: " + $context.Subscription

$baseUri = "/subscriptions/${SubscriptionId}/resourceGroups/${ResourceGroup}/providers/Microsoft.OperationalInsights/workspaces/${Workspace}"
$templatesUri = "$baseUri/providers/Microsoft.SecurityInsights/alertRuleTemplates?api-version=2023-02-01-preview"
$alertUri = "$baseUri/providers/Microsoft.SecurityInsights/alertRules/"

try {
    $alertRulesTemplates = ((Invoke-AzRestMethod -Path $templatesUri -Method GET).Content | ConvertFrom-Json).value
}
catch {
    Write-Verbose $_
    Write-Error "Unable to get alert rules with error code: $($_.Exception.Message)" -ErrorAction Stop
}

$return = @()

if ($Connectors) {
    $scheduledTemplates = $alertRulesTemplates | Where-Object { $_.kind -eq "Scheduled" }

    foreach ($item in $scheduledTemplates) {
        $matchingConnector = $item.properties.requiredDataConnectors | Where-Object { $_.connectorId -in $Connectors }
        
        if ($matchingConnector) {
            $guid = New-Guid
            $alertUriGuid = $alertUri + $guid + '?api-version=2023-02-01-preview'

            $properties = @{
                displayName              = $item.properties.displayName
                enabled                  = $true
                suppressionDuration      = "PT5H"
                suppressionEnabled       = $false
                alertRuleTemplateName    = $item.name
                description              = $item.properties.description
                query                    = $item.properties.query
                queryFrequency           = $item.properties.queryFrequency
                queryPeriod              = $item.properties.queryPeriod
                severity                 = $item.properties.severity
                entityMappings           = $item.properties.entityMappings
                sentinelEntitiesMappings = $item.properties.sentinelEntitiesMappings
                tactics                  = $item.properties.tactics
                techniques               = $item.properties.techniques
                triggerOperator          = $item.properties.triggerOperator
                triggerThreshold         = $item.properties.triggerThreshold
            }
            
            $alertBody = @{
                kind       = $item.kind
                properties = $properties
            }

            try {
                Invoke-AzRestMethod -Path $alertUriGuid -Method PUT -Payload ($alertBody | ConvertTo-Json -Depth 99)
            }
            catch {
                Write-Verbose $_
                Write-Error "Unable to create alert rule with error code: $($_.Exception.Message)" -ErrorAction Stop
            }
        }
    }
}

return $return
