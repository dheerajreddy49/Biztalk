
directory 'c:\Setup\SQL' do
  recursive true
  action :create
end

remote_file 'c:\setup\sql\en_sql_server_2014_developer_edition_with_service_pack_2_x64_dvd_8967821.iso' do
  source node['BIZTALK']['SQL_ISOUrl']
  action :create_if_missing
end
log "#{cookbook_name}::SQL Iso downloaded from Artifactory to c:\\setup\\sql successfully"

template 'c:\setup\sql\Configuration.ini' do
  source 'SQLToolsConfig.erb'
  action :create_if_missing
end
log "#{cookbook_name}::SQL Conifguration.ini  C:\\setup\\sql\\Configuration.ini successfully"

log "#{cookbook_name}::Starting BizTalk Core Component Setup..."

powershell_script 'Install BizTalk Core Components' do
  code <<-EOH
        $btsIsoFile = "#{node['BIZTALK']['BTS_ISOFile']}"
        $btsCabFile = "#{node['BIZTALK']['BTS_DependencyCab']}"
        $btsFeaturesFile = "#{node['BIZTALK']['BTS_ServerFeaturesFile']}"
        $btsErrorLog = "#{node['BIZTALK']['BTS_LogFile']}"
        $btsMountResult = (Mount-DiskImage $btsIsoFile -PassThru)
    $btsDriveLetter = ($btsMountResult | Get-Volume).Driveletter
    $btsDrive = $btsDriveLetter + ":"
    cd $btsDrive
    cd "\\BizTalk Server\\Platform\\sso64\\platform\\VCRedist\\x64"
   start-Process -filePath ".\\vcredist.exe" -argumentList "/q" -wait

    cd "\\BizTalk Server\\Platform\\sso64\\platform\\vcredist\\x86"
   start-Process -filePath ".\\vcredist.exe" -argumentList "/q" -wait

    cd "\\BizTalk Server\\Platform\\SSO64"
    start-process -filePath ".\\setup.exe" -argumentList "/quiet /ADDLOCAL ALL /L c:\\setup\\bts\\SSOLog.txt" -wait

    cd "\\BizTalk Server"
    $btsArgs = "/s '" + $btsFeaturesFile + "' /L '" + $btsErrorLog + "' /CABPATH '" + $btsCabFile + "'"
    start-Process -filePath ".\\setup.exe" -argumentList "/s c:\\setup\\bts\\biztalkserverfeatures.xml /L c:\\setup\\bts\\install.log /CABPATH c:\\setup\\bts\\BTSRedistW2k12EN64.cab"  -wait

    write-host "Installing Adapter packages"
    cd "\\BizTalk Server\\ASDK_x64"
    Start-Process -FilePath ".\\AdapterFramework64.msi" -ArgumentList "/quiet" -Wait

    cd "\\BizTalk Server\\ASDK_x86"
    Start-Process -FilePath ".\\AdapterFramework.msi" -ArgumentList "/quiet" -Wait

    cd "\\BizTalk Server\\AdapterPack_x64"
    Start-Process -FilePath ".\\AdaptersSetup64.msi" -ArgumentList "/quiet" -Wait

    cd "\\BizTalk Server\\AdapterPack_x86"
    Start-Process -FilePath ".\\AdaptersSetup.msi" -ArgumentList "/quiet" -Wait

    write-host "Installing ESB Toolkit 2.3"
    cd "\\BizTalk Server\\ESBT_x64"
    start-Process -filePath "c:\\windows\\sysWow64\\msiexec.exe" -argumentList "/qn /le ""C:\\setup\\bts\\esbLog.log"" /i ""Biztalk ESB Toolkit 2.3.msi"" "  -wait

    dismount-diskimage $btsIsoFile
    EOH
  guard_interpreter :powershell_script
  not_if '( (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\BizTalk Server\3.0").ProductVersion -eq "3.11.158.0") '
  #  not_if '(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\BizTalk Server\3.0")'
end

log "#{cookbook_name}::Installed BizTalk CoreComponents Successfully"
