    #// Copyright (c) Microsoft Corporation.
    #// Licensed under the MIT license.


    # Setup
    $configPath = '.\CreateActiveRoutingConfigurationsConfig.json'

    try
    {
        $Configs = Get-Content -Path $configPath | ConvertFrom-Json  -AsHashtable -ErrorAction SilentlyContinue
        $subId = $configs["subsid"]
        Write-Host "Subscription Id: " $SubId
        $rgname = $configs["resourceGroupName"]
        Write-Host "ResourceGroup Id: " $rgname
        $networkManagerName = $configs["networkManagerName"]
        Write-Host "NetworkManager Name: " $NetworkManagerName
        $configName = $configs["configName"]
        Write-Host "Configuration Name: " $ConfigName
        $networkGroupIds = $configs["networkGroupIds"]
        Write-Host "networkGroupIds: " $NetworkGroupIds
        $ruleCollections = $configs["ruleCollections"]
        $rules = $configs["rules"]
        $regions = $configs["regions"]
        Write-Host "Regions: " $Regions
    }        
    catch
    {
        Write-Host "Config file is in incorrect json format, please format it correctly" -ForegroundColor Red
        return
    }

    if ($null -eq $configs)
    {
        Write-Host "Config file is in incorrect json format, please format it correctly" -ForegroundColor Red
        return
    }
    
    Connect-AzAccount -Subscription $subId
        
    # Create a Routing Configuration
    New-AzNetworkManagerRoutingConfiguration -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -Name $configName
    
    $routingConfig = Get-AzNetworkManagerRoutingConfiguration -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -Name $configName

    foreach($rc in $ruleCollections)
    {
        # Create a Routing Rule Collection
        [System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.NetworkManager.PSNetworkManagerRoutingGroupItem]]$configGroup  = @() 
        foreach($networkGroupId in $rc.networkGroupIds)
        {
            $groupItem = New-AzNetworkManagerRoutingGroupItem -NetworkGroupId $networkGroupId
            $configGroup.Add($groupItem)
        }


        New-AzNetworkManagerRoutingRuleCollection -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -ConfigName $configName -Name $rc.ruleCollectionName -AppliesTo $configGroup -DisableBgpRoutePropagation $rc.disableBgpRoutePropagation
    }

    foreach($rule in $rules)
    {
        # Create Routing Rule
        $destination = New-AzNetworkManagerRoutingRuleDestination -DestinationAddress $rule.destinationAddress -Type $rule.type
        $nextHop = New-AzNetworkManagerRoutingRuleNextHop -NextHopType $rule.nextHopType -NextHopAddress $rule.nextHopAddress

        New-AzNetworkManagerRoutingRule -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -ConfigName $configName -RuleCollectionName $rule.ruleCollectionsName -ResourceName $rule.ruleName -Destination $destination -NextHop $nextHop
    }

    $configIds  = @($routingConfig.Id)
    Deploy-AzNetworkManagerCommit -ResourceGroupName $rgname -Name $networkManagerName -TargetLocation $regions -ConfigurationId $configIds -CommitType "Routing" 
