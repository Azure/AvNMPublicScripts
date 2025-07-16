    #// Copyright (c) Microsoft Corporation.
    #// Licensed under the MIT license.


    # Setup
    $configPath = '.\CreateActiveSecurityAdminConfigurationsConfig.json'

    try
    {
        $Configs = Get-Content -Path $configPath | ConvertFrom-Json  -AsHashtable -ErrorAction SilentlyContinue
        $SubId = $configs["subsid"]
        Write-Host "Subscription Id: " $SubId
        $RgName = $configs["resourceGroupName"]
        Write-Host "ResourceGroup Id: " $RgName
        $NetworkManagerName = $configs["networkManagerName"]
        Write-Host "NetworkManager Name: " $NetworkManagerName
        $ConfigName = $configs["configName"]
        Write-Host "Configuration Name: " $ConfigName
        $NetworkGroupIds = $configs["networkGroupIds"]
        Write-Host "networkGroupIds: " $NetworkGroupIds
        $RuleCollectionName = $configs["ruleCollectionName"]
        Write-Host "Regions: " $RuleCollectionName
        $ApplyOnNetworkIntentPolicyBasedServices = $configs["applyOnNetworkIntentPolicyBasedServices"]
        $Regions = $configs["regions"]
        Write-Host "Regions: " $Regions
        $DeleteExistingNSG = $configs["deleteExistingNSG"]
        $SourceAddressPrefixList = $configs["sourceAddressPrefixList"]
        $DestinationAddressPrefixList = $configs["destinationAddressPrefixList"]
        $SourcePortList = $configs["sourcePortList"]
        $DestinationPortList = $configs["destinationPortList"]
        $RuleName = $configs["ruleName"]
        $Protocol = $configs["protocol"]
        $Direction = $configs["direction"]
        $Access = $configs["access"]
        $Priority = $configs["priority"]
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
    
    if($DeleteExistingNSG -eq "True" || $DeleteExistingNSG -eq "true")
    {
       Write-Host "DeleteExistingNSG is enabled"
       New-AzNetworkManagerSecurityAdminConfiguration -ResourceGroupName $RgName -NetworkManagerName $NetworkManagerName -Name $ConfigName -DeleteExistingNSG -ApplyOnNetworkIntentPolicyBasedService $ApplyOnNetworkIntentPolicyBasedServices
    }
    else
    {
       Write-Host "DeleteExistingNSG is not enabled"
       New-AzNetworkManagerSecurityAdminConfiguration -ResourceGroupName $RgName -NetworkManagerName $NetworkManagerName -Name $ConfigName -ApplyOnNetworkIntentPolicyBasedService $ApplyOnNetworkIntentPolicyBasedServices
    }
    
    $securityConfig = Get-AzNetworkManagerSecurityAdminConfiguration -ResourceGroupName $RgName -NetworkManagerName $NetworkManagerName -Name $ConfigName


    [System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.NetworkManager.PSNetworkManagerSecurityGroupItem]]$configGroup  = @() 
    foreach($networkGroupId in $networkGroupIds)
    {
        $groupItem = New-AzNetworkManagerSecurityGroupItem -NetworkGroupId $networkGroupId
        $configGroup.Add($groupItem)
    }
    
    New-AzNetworkManagerSecurityAdminRuleCollection -ResourceGroupName $RgName -NetworkManagerName $NetworkManagerName -ConfigName $ConfigName -Name $RuleCollectionName -AppliesToGroup $configGroup 

    $ruleCollection = Get-AzNetworkManagerSecurityAdminRuleCollection -ResourceGroupName $RgName -NetworkManagerName $NetworkManagerName -ConfigName $ConfigName -Name $RuleCollectionName

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
    

    New-AzNetworkManagerSecurityAdminRule -ResourceGroupName $RgName -NetworkManagerName $NetworkManagerName -ConfigName $ConfigName  -RuleCollectionName $RuleCollectionName -Name $RuleName -Protocol $Protocol -Direction $Direction -Access $Access -Priority $Priority -SourcePortRange $SourcePortList -DestinationPortRange $DestinationPortList -SourceAddressPrefix $sourceAddressPrefixes -DestinationAddressPrefix $destinationAddressPrefixes 

    $adminRule = Get-AzNetworkManagerSecurityAdminRule -ResourceGroupName $RgName -NetworkManagerName $NetworkManagerName -SecurityAdminConfigurationName $ConfigName -RuleCollectionName $RuleCollectionName -Name $RuleName

    $configids  = @($securityConfig.Id)
    Deploy-AzNetworkManagerCommit -ResourceGroupName $rgname -Name $networkManagerName -TargetLocation $Regions -ConfigurationId $configids -CommitType "SecurityAdmin" 

   