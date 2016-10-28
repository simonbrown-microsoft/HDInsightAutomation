$subscriptionName = (Get-AzureSubscription | where {$_.IsCurrent -eq "True"}).SubscriptionName
$clusterName = "TestCluster"
$location = "<MicrosoftDataCenter>"
$clusterNodes = <ClusterSizeInNodes>

$storageAccountName_Default = "<DefaultFileSystemStorageAccountName>"
$containerName_Default = "<DefaultFileSystemContainerName>"

$storageAccountName_Add1 = "<AdditionalStorageAccountName>"

$hiveSQLDatabaseServerName = "<SQLDatabaseServerNameForHiveMetastore>"
$hiveSQLDatabaseName = "<SQLDatabaseDatabaseNameForHiveMetastore>"
$oozieSQLDatabaseServerName = "<SQLDatabaseServerNameForOozieMetastore>"
$oozieSQLDatabaseName = "<SQLDatabaseDatabaseNameForOozieMetastore>"

# Get the virtual network ID and subnet name
$vnetID = "<AzureVirtualNetworkID>"
$subNetName = "<AzureVirtualNetworkSubNetName>"

# Get the Storage account keys
Select-AzureSubscription $subscriptionName
$storageAccountKey_Default = Get-AzureStorageKey $storageAccountName_Default | %{ $_.Primary }
$storageAccountKey_Add1 = Get-AzureStorageKey $storageAccountName_Add1 | %{ $_.Primary }

$oozieCreds = Get-Credential -Message "Oozie metastore"
$hiveCreds = Get-Credential -Message "Hive metastore"

# Create a Blob storage container
$dest1Context = New-AzureStorageContext -StorageAccountName $storageAccountName_Default -StorageAccountKey $storageAccountKey_Default  
New-AzureStorageContainer -Name $containerName_Default -Context $dest1Context

# Create a new HDInsight cluster
$config = New-AzureHDInsightClusterConfig -ClusterSizeInNodes $clusterNodes |
    Set-AzureHDInsightDefaultStorage -StorageAccountName "$storageAccountName_Default.blob.core.windows.net" -StorageAccountKey $storageAccountKey_Default -StorageContainerName $containerName_Default |
    Add-AzureHDInsightStorage -StorageAccountName "$storageAccountName_Add1.blob.core.windows.net" -StorageAccountKey $storageAccountKey_Add1 |
    Add-AzureHDInsightMetastore -SqlAzureServerName "$hiveSQLDatabaseServerName.database.windows.net" -DatabaseName $hiveSQLDatabaseName -Credential $hiveCreds -MetastoreType HiveMetastore |
    Add-AzureHDInsightMetastore -SqlAzureServerName "$oozieSQLDatabaseServerName.database.windows.net" -DatabaseName $oozieSQLDatabaseName -Credential $oozieCreds -MetastoreType OozieMetastore |
        New-AzureHDInsightCluster -Name $clusterName -Location $location -VirtualNetworkId $vnetID -SubnetName $subNetName