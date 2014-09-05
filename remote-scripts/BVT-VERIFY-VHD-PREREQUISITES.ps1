﻿<#-------------Create Deployment Start------------------#>
Import-Module .\TestLibs\RDFELibs.psm1 -Force
$result = ""
$testResult = ""
$resultArr = @()
$isDeployed = DeployVMS -setupType $currentTestData.setupType -Distro $Distro -xmlConfig $xmlConfig
#$isDeployed = "ICA-BVTDeployment-Ubuntu1410-7-3-10-21-27"
if ($isDeployed)
{

	try
	{
		$testServiceData = Get-AzureService -ServiceName $isDeployed

#Get VMs deployed in the service..
		$testVMsinService = $testServiceData | Get-AzureVM

		$hs1vm1 = $testVMsinService
		$hs1vm1Endpoints = $hs1vm1 | Get-AzureEndpoint
		$hs1vm1sshport = GetPort -Endpoints $hs1vm1Endpoints -usage ssh
		$hs1VIP = $hs1vm1Endpoints[0].Vip
		$hs1ServiceUrl = $hs1vm1.DNSName
		$hs1ServiceUrl = $hs1ServiceUrl.Replace("http://","")
		$hs1ServiceUrl = $hs1ServiceUrl.Replace("/","")
        $detectedDistro = DetectLinuxDistro -VIP $hs1VIP -SSHport $hs1vm1sshport -testVMUser $user -testVMPassword $password
        if ($detectedDistro -imatch "UBUNTU")
            {
                $matchstrings = @("_TEST_SUDOERS_VERIFICATION_SUCCESS","_TEST_GRUB_VERIFICATION_SUCCESS", "_TEST_KVP_INSTALLED", "_TEST_REPOSITORIES_AVAILABLE")
            }
        elseif ($detectedDistro -imatch "SUSE")
            {
                $matchstrings = @("_TEST_SUDOERS_VERIFICATION_SUCCESS","_TEST_GRUB_VERIFICATION_SUCCESS", "_TEST_REPOSITORIES_AVAILABLE")
            }
        elseif ($detectedDistro -imatch "CENTOS")
            {
                $matchstrings = @("_TEST_NETWORK_MANAGER_NOT_INSTALLED","_TEST_NETWORK_FILE_SUCCESS", "_TEST_IFCFG_ETH0_FILE_SUCCESS", "_TEST_UDEV_RULES_SUCCESS", "_TEST_REPOSITORIES_AVAILABLE", "_TEST_YUM_CONF_ERROR", "_TEST_GRUB_VERIFICATION_SUCCESS")
            }
        elseif ($detectedDistro -imatch "ORACLELINUX")
            {
                $matchstrings = @("_TEST_NETWORK_MANAGER_NOT_INSTALLED","_TEST_NETWORK_FILE_SUCCESS", "_TEST_IFCFG_ETH0_FILE_SUCCESS", "_TEST_UDEV_RULES_SUCCESS", "_TEST_REPOSITORIES_AVAILABLE", "_TEST_YUM_CONF_ERROR", "_TEST_GRUB_VERIFICATION_SUCCESS")
            }
        elseif ($detectedDistro -imatch "REDHAT")
            {
                $matchstrings = @("_TEST_SUDOERS_VERIFICATION_SUCCESS","_TEST_GRUB_VERIFICATION_SUCCESS", "_TEST_KVP_INSTALLED", "_TEST_REPOSITORIES_AVAILABLE")
            }
        elseif ($detectedDistro -imatch "SLES")
            {
                $matchstrings = @("_TEST_SUDOERS_VERIFICATION_SUCCESS","_TEST_GRUB_VERIFICATION_SUCCESS", "_TEST_DHCLIENT_SET_HOSTNAME_IS_NO_SUCCESS", "_TEST_REPOSITORIES_AVAILABLE")
            }
      
		RemoteCopy -uploadTo $hs1VIP -port $hs1vm1sshport -files $currentTestData.files -username $user -password $password -upload
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "chmod +x *.py" -runAsSudo


		LogMsg "Executing : $($currentTestData.testScript)"
		$consoleOut = RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "python $($currentTestData.testScript) -d $detectedDistro" -runAsSudo
		RunLinuxCmd -username $user -password $password -ip $hs1VIP -port $hs1vm1sshport -command "mv Runtime.log $($currentTestData.testScript).log" -runAsSudo
		RemoteCopy -download -downloadFrom $hs1VIP -files "/home/$user/$($currentTestData.testScript).log" -downloadTo $LogDir -port $hs1vm1sshport -username $user -password $password
        $errorCount = 0
        foreach ($testString in $matchstrings)
            {
                if( $consoleOut -imatch $testString)
                {
                    LogMsg "$detectedDistro$testString"
                }
                else
                {
                    LogErr "Expected String : $detectedDistro$testString not present. Please check logs."
                    $errorCount += 1
                }
            }  
        if($errorCount -eq 0)
            {
                $testResult = "PASS"
            }
        else
            {
                $testResult = "FAIL"
            }
        LogMsg "Test Status : Completed"
        Logmsg "Test Resullt : $testResult"
	}
	catch
	{
		$ErrorMessage =  $_.Exception.Message
		LogMsg "EXCEPTION : $ErrorMessage"   
	}
	Finally
	{
		$metaData = ""
		if (!$testResult)
		{
			$testResult = "Aborted"
		}
		$resultArr += $testResult
#$resultSummary +=  CreateResultSummary -testResult $testResult -metaData $metaData -checkValues "PASS,FAIL,ABORTED" -testName $currentTestData.testName# if you want to publish all result then give here all test status possibilites. if you want just failed results, then give here just "FAIL". You can use any combination of PASS FAIL ABORTED and corresponding test results will be published!
	}   
}

else
{
	$testResult = "Aborted"
	$resultArr += $testResult
}

$result = GetFinalResultHeader -resultarr $resultArr

#Clean up the setup
DoTestCleanUp -result $result -testName $currentTestData.testName -deployedServices $isDeployed

#Return the result and summery to the test suite script..
return $result