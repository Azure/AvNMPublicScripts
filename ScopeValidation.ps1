    #// Copyright (c) Microsoft Corporation.
    #// Licensed under the MIT license.

    # Setup
    $configPath = '.\ScopeValidation.json'

    try
    {
        $Configs = Get-Content -Path $configPath | ConvertFrom-Json  -AsHashtable -ErrorAction SilentlyContinue
        $subId = $configs["subsid"]
        Write-Host "Subscription Id: " $SubId
        $rgname = $configs["resourceGroupName"]
        Write-Host "ResourceGroup Id: " $rgname
        $networkManagerName = $configs["networkManagerName"]
        Write-Host "NetworkManager Name: " $NetworkManagerName
        $subscriptions = $configs["subscriptions"]
        $managementGroups = $configs["managementGroups"]
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
    $currentSubs = $networkManager.NetworkManagerScopes.Subscriptions
    $currentMgmts = $networkManager.NetworkManagerScopes.ManagementGroups

    $removedSubs = $currentSubs | Where-Object { $subscriptions -notcontains $_ }
    Write-Host "Removed Subscriptions: " $removedSubs
    
    $removedMgmts = $currentMgmts | Where-Object { $managementGroups -notcontains $_ }
    Write-Host "Removed ManagementGroups: "  $removedMgmts
    
    $addedSubs = $subscriptions | Where-Object { $currentSubs -notcontains $_ }
    Write-Host "Added Subscriptions: " $addedSubs
    
    $addedMgmts = $managementGroups | Where-Object { $currentMgmts -notcontains $_ }
    Write-Host "Added ManagementGroups: "  $addedMgmts
    
    if($removedSubs.Count -eq 0 -and $removedMgmts.Count -eq 0)
    {
        Write-Host "No Scope Removed, Stop" -ForegroundColor Green
        return
    }
    
    $networkManagerId = $networkManager.Id
    $validationQuery =  "networkresources " +
                    "| where type in~ ('microsoft.network/effectivesecurityadminrules', 'microsoft.network/effectiveconnectivityconfigurations', "+ 
                    "'microsoft.network/virtualnetworks/subnets/effectivesecurityuserrules', 'microsoft.network/virtualnetworks/subnets/effectiveroutingrules') " +
                    "| where properties contains '"+$networkManagerId+"' " +
                    "| summarize dcount(id)";
    
    if($addedSubs.Count -eq 0 -and $addedMgmts.Count -eq 0)
    {  
        if($removedSubs.Count -ne 0)
        {
            $subList = New-Object System.Collections.Generic.List[System.String]
            foreach ($sub in $removedSubs) {
                $sub = $sub.Replace("/subscriptions/", "")
                $subList.Add($sub)
            }
            $result = Search-AzGraph -Query $validationQuery -Subscription $subList
        
            if($result.dcount_id -ne 0)
            {
               Write-Host "Removed Scope Contains Deployed Resources, Please Clean Up Before Removing Scope" -ForegroundColor Red
               return
            }
        }

        if($removedMgmts.Count -ne 0)
        {
            $mgmtList = New-Object System.Collections.Generic.List[System.String]
            foreach ($mgmt in $removedMgmts) {
                $mgmt = $mgmt.Replace("/providers/Microsoft.Management/managementGroups/", "")
                $mgmtList.Add($mgmt)
            }
            $result = Search-AzGraph -Query $validationQuery -ManagementGroup $mgmtList
            
            if($result.dcount_id -ne 0)
            {
               Write-Host "Removed Scope Contains Deployed Resources, Please Clean Up Before Removing Scope" -ForegroundColor Red
               return
            }
       }
    }
    else{       
        $mgmtFliter = ""
        $subFliter = ""
        if($addedSubs.Count -ne 0)
        {
            $subStr = $addedSubs -join '", "'
            $subFliter = '| where id !in~ ("'+$subStr+'") '
        }
        
        if($addedMgmts.Count -ne 0)
        {
            $mgmtList = New-Object System.Collections.Generic.List[System.String]
            foreach ($mgmt in $addedMgmts) {
                $mgmt = $mgmt.Replace("/providers/Microsoft.Management/managementGroups/", "")
                $mgmtList.Add($mgmt)
            }
            $mgmtStr = $mgmtList -join '", "'
            $mgmtFliter = '| extend excludedManagementGroupList = set_intersect(list, pack_array("'+$mgmtStr+'")) | where  array_length(excludedManagementGroupList) == 0 '
        }
        $query ='resourcecontainers ' +
                 '| where type =~ "microsoft.resources/subscriptions" ' +
                 '| extend props = parse_json(properties) ' +
                 '| extend managementGroupAncestorsChains = props["managementGroupAncestorsChain"] ' +
                 '| mv-expand managementGroupAncestorsChains ' +
                 '| extend mgName = managementGroupAncestorsChains.["name"] ' +
                 '| summarize  list = make_list(mgName) by id' +
                 $mgmtFliter +
                 $subFliter  +
                 '| distinct id'

        $subList = New-Object System.Collections.Generic.List[System.String]
        foreach ($sub in $removedSubs) {
            $sub = $sub.Replace("/subscriptions/", "")
            $subList.Add($sub)
        }

        $resultList = New-Object System.Collections.Generic.List[System.String]
        
        if($subList.Count -ne 0)
        {
            $sublistFromSub = Search-AzGraph -Query $query -Subscription $subList
            foreach ($sub in $sublistFromSub) {
                $id = $sub.id.Replace("/subscriptions/", "")
                $resultList.Add($id)
            }
        }
        
        $mgmtList = New-Object System.Collections.Generic.List[System.String]
        foreach ($mgmt in $removedMgmts) {
            $mgmt = $mgmt.Replace("/providers/Microsoft.Management/managementGroups/", "")
            $mgmtList.Add($mgmt)
        }
        
        if($mgmtList.Count -ne 0)
        {
            $sublistFromMgmt = Search-AzGraph -Query $query -ManagementGroup $mgmtList
            foreach ($sub in $sublistFromMgmt) {
                $id = $sub.id.Replace("/subscriptions/", "")
                $resultList.Add($id)
            }
        }
        
        if($resultList.Count -ne 0)
        {
            $result = Search-AzGraph -Query $validationQuery -Subscription $resultList            
            if($result.dcount_id -ne 0)
            {
               Write-Host "Removed Scope Contains Deployed Resources, Please Clean Up Before Removing Scope" -ForegroundColor Red
               return
            }
        }
    }
    
    Write-Host "Removed Scopes Do Not Contain Deployed Resources, Safe To Remove" -ForegroundColor Green
    