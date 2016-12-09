#input parameters
param (
    [string]$token = $(throw "-token is required. This is the master label for the Cluster, and all resources."), 
    [string]$username = $(throw "-username is required."),
    [string]$password = $( Read-Host -asSecureString "Input password" ),
    [string]$sshusername = $(throw "-username is required."),
    [string]$sshpassword = $( Read-Host -asSecureString "Input sshpassword" ),
    [string]$location = "Australia Southeast"   ,
    [int]$clusterNodes = 1           # The number of nodes in the HDInsight cluster


)

Write-Progress -Activity "Creating Credentials" -PercentComplete 10
#create credentials from parameter username/password combinations
[securestring] $securepassword = convertto-securestring -String $password -AsPlainText -Force
[securestring] $securesshpassword = convertto-securestring -String $sshpassword -AsPlainText -Force

$credentials = new-object -typename System.Management.Automation.PSCredential `
                ($username, (convertto-securestring -String $password -AsPlainText -Force))

$sshCredentials = new-object -typename System.Management.Automation.PSCredential `
         -argumentlist $sshusername, $securesshpassword


Write-Progress -Activity "Setting Up Variables" -PercentComplete 20
#variable setup
$resourceGroupName = $token + "rg"      # Provide a Resource Group name
$vnetName = $token + "vnet"             #provide virtual network name
$subnetName = $token + "hdisubnet"      # Provide a virtual network subnet name
$clusterName = $token
$defaultStorageAccountName = $token + "store"   # Provide a Storage account name
$defaultStorageContainerName = $token + "container"

$sqlservername = $token + "dbserver"
$sqldatabasename = $token + "db"

# Select the subscription to use if you have multiple subscriptions
#$subscriptionID = "<SubscriptionName>"        # Provide your Subscription Name
#Select-AzureRmSubscription -SubscriptionId $subscriptionID

# Create an Azure Resource Group
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

Write-Progress -Activity "Creating Storage Account" -PercentComplete 30
# Create an Azure Storage account and container used as the default storage
New-AzureRmStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -StorageAccountName $defaultStorageAccountName `
    -Location $location `
    -Type Standard_LRS
$defaultStorageAccountKey = (Get-AzureRmStorageAccountKey -Name $defaultStorageAccountName -ResourceGroupName $resourceGroupName)[0].Value
$destContext = New-AzureStorageContext -StorageAccountName $defaultStorageAccountName -StorageAccountKey $defaultStorageAccountKey
New-AzureStorageContainer -Name $defaultStorageContainerName -Context $destContext

# Create an HDInsight cluster


# The location of the HDInsight cluster must be in the same data center as the Storage account.
$location = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $defaultStorageAccountName | %{$_.Location}

######################################################
#create network
# https://azure.microsoft.com/en-us/documentation/articles/hdinsight-extend-hadoop-virtual-network/
######################################################

Write-Progress -Activity "Creating Virtual Network" -PercentComplete 40
New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName `
    -AddressPrefix 192.168.0.0/16 -Location $location   



# Get the Virtual Network object
$vnet = Get-AzureRmVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $resourceGroupName

Add-AzureRmVirtualNetworkSubnetConfig -Name $subnetName `
    -VirtualNetwork $vnet -AddressPrefix 192.168.1.0/24

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet



 
# Get the region the Virtual network is in.
$location = $vnet.Location
# Get the subnet object
$subnet = $vnet.Subnets | Where-Object Name -eq $subnetName
$subnetID = $subnet[0].id

Write-Host $subnet -ForegroundColor Green
Write-Host $subnetID -ForegroundColor Green  
#$subnet




# Create a new Network Security Group.
# And add exemptions for the HDInsight health and management services.
$nsg = New-AzureRmNetworkSecurityGroup `
    -Name "hdisecure" `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    | Add-AzureRmNetworkSecurityRuleConfig `
        -name "hdirule1" `
        -Description "HDI health and management address 168.61.49.99" `
        -Protocol "*" `
        -SourcePortRange "*" `
        -DestinationPortRange "443" `
        -SourceAddressPrefix "168.61.49.99" `
        -DestinationAddressPrefix "VirtualNetwork" `
        -Access Allow `
        -Priority 300 `
        -Direction Inbound `
    | Add-AzureRmNetworkSecurityRuleConfig `
        -Name "hdirule2" `
        -Description "HDI health and management 23.99.5.239" `
        -Protocol "*" `
        -SourcePortRange "*" `
        -DestinationPortRange "443" `
        -SourceAddressPrefix "23.99.5.239" `
        -DestinationAddressPrefix "VirtualNetwork" `
        -Access Allow `
        -Priority 301 `
        -Direction Inbound `
    | Add-AzureRmNetworkSecurityRuleConfig `
        -Name "hdirule3" `
        -Description "HDI health and management 168.61.48.131" `
        -Protocol "*" `
        -SourcePortRange "*" `
        -DestinationPortRange "443" `
        -SourceAddressPrefix "168.61.48.131" `
        -DestinationAddressPrefix "VirtualNetwork" `
        -Access Allow `
        -Priority 302 `
        -Direction Inbound `
    | Add-AzureRmNetworkSecurityRuleConfig `
        -Name "hdirule4" `
        -Description "HDI health and management 138.91.141.162" `
        -Protocol "*" `
        -SourcePortRange "*" `
        -DestinationPortRange "443" `
        -SourceAddressPrefix "138.91.141.162" `
        -DestinationAddressPrefix "VirtualNetwork" `
        -Access Allow `
        -Priority 303 `
        -Direction Inbound
# Set the changes to the security group
Set-AzureRmNetworkSecurityGroup -NetworkSecurityGroup $nsg
# Apply the NSG to the subnet
Set-AzureRmVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnet `
    -Name $subnetName `
    -AddressPrefix $subnet.AddressPrefix `
    -NetworkSecurityGroup $nsg

Set-AzureRmVirtualNetwork -VirtualNetwork $vnet

<#
Hive:
Export HIVE_AUX_JARS_PATH=$HIVE_AUX_JARS_PATH:/usr/hdp/current/custom/HadoopCryptoCompressor-0.0.6-SNAPSHOT.jar
SET hive.exec.compress.output=true;
SET hive.exec.compress.intermediate=true;
#>

$hiveConfigValues = @{ "hive.exec.compress.output"="true"
                       "hive.exec.compress.intermediate"="true" }

<#
HDFS:
SET io.compression.codecs;
classpath
#>

$HDFSConfigValues = @{"io.compression.codecs"="org.apache.hadoop.io.compress.GzipCodec,org.apache.hadoop.io.compress.DefaultCodec,org.apache.hadoop.io.compress.SnappyCodec,org.apache.hadoop.io.compress.CryptoCodec" }

<# 
Yarn:
yarn.application.classpath   /usr/hdp/current/custom/*
#>

<#
Mapreduce:
Classpath
SET mapreduce.output.fileoutputformat.compress=true;
SET mapreduce.output.fileoutputformat.compress.codec=org.apache.hadoop.io.compress.CryptoCodec;
#>
$MapRedConfigValues = @{"mapreduce.output.fileoutputformat.compress"="true"
    "mapreduce.output.fileoutputformat.compress.codec"="org.apache.hadoop.io.compress.CryptoCodec"}

 
<#
 
Spark:
export SPARK_DIST_CLASSPATH=$SPARK_DIST_CLASSPATH:/usr/hdp/current/custom/HadoopCryptoCompressor-0.0.6-SNAPSHOT.jar
export SPARK_DIST_CLASSPATH=$SPARK_DIST_CLASSPATH:/usr/hdp/current/custom/*
 
 #>

$config = New-AzureRmHDInsightClusterConfig `
    | Set-AzureRmHDInsightDefaultStorage `
        -StorageAccountName "$defaultStorageAccountName.blob.core.windows.net" `
        -StorageAccountKey $defaultStorageAccountKey `
    | Add-AzureRmHDInsightConfigValues `
        -HiveSite $hiveConfigValues -MapReduce $MapRedConfigValues -Hdfs $HdfsConfigValues

       

New-AzureRmHDInsightCluster -ClusterName $clusterName `
    -ResourceGroupName $resourceGroupName `
    -HttpCredential $credentials `
    -Location $location `
    -DefaultStorageAccountName "$defaultStorageAccountName.blob.core.windows.net" `
    -DefaultStorageAccountKey $defaultStorageAccountKey `
    -DefaultStorageContainer $defaultStorageContainerName  `
    -ClusterSizeInNodes $clusterNodes `
    -ClusterType Hadoop `
    -OSType Linux `
    -Version "3.4" `
    -SshCredential $sshCredentials `
    -config $config `
    -VirtualNetworkId $vnet.Id `
    -SubnetName $subnetID

#Get-AzureRmVirtualNetwork -ResourceGroupName $resourceGroupName -Name $vnetName

#########################
# create SQL database
#########################
#$sqladmin = Get-Credential
#$sqlserver = New-AzureRmSqlServer -ResourceGroupName $resourceGroupName -ServerName $sqlservername -Location $location -SqlAdministratorCredentials $sqladmin
#$sqldatabase = New-AzureRmSqlDatabase -DatabaseName $sqldatabasename -ServerName $sqlservername -ResourceGroupName $resourceGroupName


