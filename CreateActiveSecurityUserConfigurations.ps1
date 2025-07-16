    #// Copyright (c) Microsoft Corporation.
    #// Licensed under the MIT license.


    # Setup
    $configPath = '.\CreateActiveSecurityUserConfigurationsConfig.json'

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
        $ruleCollectionName = $configs["ruleCollectionName"]
        Write-Host "Regions: " $RuleCollectionName
        $regions = $configs["regions"]
        Write-Host "Regions: " $Regions
        $deleteExistingNSG = $configs["deleteExistingNSG"]
        $sourceAddressPrefixList = $configs["sourceAddressPrefixList"]
        $destinationAddressPrefixList = $configs["destinationAddressPrefixList"]
        $sourcePortList = $configs["sourcePortList"]
        $destinationPortList = $configs["destinationPortList"]
        $ruleName = $configs["ruleName"]
        $protocol = $configs["protocol"]
        $direction = $configs["direction"]
        $access = $configs["access"]
        $priority = $configs["priority"]
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
    
    New-AzNetworkManagerSecurityUserConfiguration -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -Name $configName
    
    $securityUserConfig = Get-AzNetworkManagerSecurityUserConfiguration -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -Name $configName


    [System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.NetworkManager.PSNetworkManagerSecurityUserGroupItem]]$configGroup  = @() 
    foreach($networkGroupId in $networkGroupIds)
    {
        $groupItem = New-AzNetworkManagerSecurityUserGroupItem -NetworkGroupId $networkGroupId
        $configGroup.Add($groupItem)
    }
    
    New-AzNetworkManagerSecurityUserRuleCollection -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -ConfigName $configName -Name $ruleCollectionName -AppliesToGroup $configGroup

    $ruleCollection = Get-AzNetworkManagerSecurityAdminRuleCollection -ResourceGroupName $RgName -NetworkManagerName $NetworkManagerName -ConfigName $configName -Name $ruleCollectionName

     [System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.NetworkManager.PSNetworkManagerAddressPrefixItem]] $sourceAddressPrefixes  = @()
    foreach($sourceAddress in $sourceAddressPrefixList)
    {
        $sourceAddressPrefix = New-AzNetworkManagerAddressPrefixItem -AddressPrefix $sourceAddress.AddressPrefix -AddressPrefixType $sourceAddress.AddressPrefixType
        $sourceAddressPrefixes.Add($sourceAddressPrefix)
    }
    
    [System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.NetworkManager.PSNetworkManagerAddressPrefixItem]]$destinationAddressPrefixes  = @()
    foreach($destinationAddress in $destinationAddressPrefixList)
    {
        $destinationAddressPrefix = New-AzNetworkManagerAddressPrefixItem -AddressPrefix $destinationAddress.AddressPrefix -AddressPrefixType $destinationAddress.AddressPrefixType
        $destinationAddressPrefixes.Add($destinationAddressPrefix)
    }

    New-AzNetworkManagerSecurityUserRule -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -ConfigName $configName  -RuleCollectionName $ruleCollectionName -Name $ruleName -Protocol $protocol -Direction $direction -SourcePortRange $sourcePortList -DestinationPortRange $destinationPortList -SourceAddressPrefix $sourceAddressPrefixes -DestinationAddressPrefix $destinationAddressPrefixes

    $configIds  = @($securityUserConfig.Id)
    Deploy-AzNetworkManagerCommit -ResourceGroupName $rgname -Name $networkManagerName -TargetLocation $regions -ConfigurationId $configIds -CommitType "SecurityUser" 
