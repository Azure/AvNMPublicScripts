    #// Copyright (c) Microsoft Corporation.
    #// Licensed under the MIT license.

    # Setup
    $configPath = '.\GetNetworkManagerScope.json'

    try
    {
        $Configs = Get-Content -Path $configPath | ConvertFrom-Json  -AsHashtable -ErrorAction SilentlyContinue
        $subId = $configs["subsid"]
        Write-Host "Subscription Id: " $subId
        $rgname = $configs["resourceGroupName"]
        Write-Host "ResourceGroup Id: " $rgname
        $networkManagerName = $configs["networkManagerName"]
        Write-Host "NetworkManager Name: " $NetworkManagerName
        $outputPath = $configs["outputPath"]
        Write-Host "OutputPath: " $outputPath
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
    
    $networkManager = Get-AzNetworkManager -ResourceGroupName $rgname -Name $networkManagerName    
    
    $scope = $networkManager.NetworkManagerScopes | Select-Object * -ExcludeProperty "CrossTenantScopes", "ManagementGroupsText", "SubscriptionsText", "CrossTenantScopesText" 
    $scope | ConvertTo-Json | Out-File -FilePath $outputPath
    
    Write-Host "Get Scope Completed In " $outputPath  -ForegroundColor Green
    
    