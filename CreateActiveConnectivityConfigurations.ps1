    #// Copyright (c) Microsoft Corporation.
    #// Licensed under the MIT license.


    # Setup
    $configPath = '.\CreateActiveConnectivityConfigurationsConfig.json'

    try
    {
        $configs = Get-Content -Path $configPath | ConvertFrom-Json  -AsHashtable -ErrorAction SilentlyContinue
        $subId = $configs["subsid"]
        Write-Host "Subscription Id: " $subId
        $rgName = $configs["resourceGroupName"]
        Write-Host "ResourceGroup Id: " $rgName
        $networkManagerName = $configs["networkManagerName"]
        Write-Host "NetworkManager Name: " $networkManagerName
        $configName = $configs["configName"]
        Write-Host "Configuration Name: " $configName
        $networkGroupIds = $configs["networkGroupIds"]
        Write-Host "networkGroupIds: " $networkGroupIds
        $hubIds = $configs["hubIds"]
        Write-Host "HubIds: " $hubIds
        $connectivityTopology = $configs["connectivityTopology"]
        Write-Host "ConnectivityTopology: " $connectivityTopology
        $deleteExistingPeering = $configs["deleteExistingPeering"]     
        Write-Host "DeleteExistingPeering: " $deleteExistingPeering
        $isGlobal = $configs["isGlobal"]
        Write-Host "IsGlobal: " $isGlobal
        $connectivityCapability = $configs["connectivityCapability"]
        Write-Host "ConnectivityCapability: " $ConnectivityCapability
        $regions = $configs["regions"]
        Write-Host "Regions: " $regions
        
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
    
    $hubList = [System.Collections.ArrayList]::new()
    foreach($hubId in $hubIds)
    {
        $resourceId = $hubId["ResourceId"]
        $ResourceType = $hubId["ResourceType"]
        $hub = New-AzNetworkManagerHub -ResourceId $resourceId -ResourceType $ResourceType
        $hubList.Add($hub)
    }  
    
    $connectivityGroup = [System.Collections.ArrayList]::new()
    foreach($networkGroupId in $networkGroupIds)
    {
        $connectivityGroupItem = New-AzNetworkManagerConnectivityGroupItem -NetworkGroupId $networkGroupId
        $connectivityGroup.Add($connectivityGroupItem)
    }
    
    if($deleteExistingPeering -eq "True" || $deleteExistingPeering -eq "true")
    {
       Write-Host "deleteExistingPeering is enabled"
       if($isGlobal -eq "True" || $isGlobal -eq "true")
        {
           Write-Host "IsGlobal is enabled"
           New-AzNetworkManagerConnectivityConfiguration -ResourceGroupName $rgname -Name $configName -NetworkManagerName $networkManagerName -ConnectivityTopology $connectivityTopology -Hub $hublist -AppliesToGroup $connectivityGroup -DeleteExistingPeering -IsGlobal -ConnectivityCapability $connectivityCapability
        }
        else
        {
            Write-Host "IsGlobal is disabled"
            New-AzNetworkManagerConnectivityConfiguration -ResourceGroupName $rgname -Name $configName -NetworkManagerName $networkManagerName -ConnectivityTopology $connectivityTopology -Hub $hublist -AppliesToGroup $connectivityGroup -DeleteExistingPeering -ConnectivityCapability $connectivityCapability
        }
    }
    else
    {
       Write-Host "deleteExistingPeering is not enabled"
       if($isGlobal -eq "True" || $isGlobal -eq "true")
        {
           Write-Host "IsGlobal is enabled"
           New-AzNetworkManagerConnectivityConfiguration -ResourceGroupName $rgname -Name $configName -NetworkManagerName $networkManagerName -ConnectivityTopology $connectivityTopology -Hub $hublist -AppliesToGroup $connectivityGroup -IsGlobal -ConnectivityCapability $connectivityCapability
        }
        else
        {
            Write-Host "IsGlobal is disabled"
            New-AzNetworkManagerConnectivityConfiguration -ResourceGroupName $rgname -Name $configName -NetworkManagerName $networkManagerName -ConnectivityTopology $connectivityTopology -Hub $hublist -AppliesToGroup $connectivityGroup -ConnectivityCapability $connectivityCapability
        }
       
    }

    $newConnConfig = Get-AzNetworkManagerConnectivityConfiguration -ResourceGroupName $rgname -NetworkManagerName $networkManagerName -Name $configName 
    $configids  = @($newConnConfig.Id)
    Deploy-AzNetworkManagerCommit -ResourceGroupName $rgname -Name $networkManagerName -TargetLocation $regions -ConfigurationId $configids -CommitType "Connectivity"
   