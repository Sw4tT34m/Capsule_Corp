#Leame.
#El objetivo funcional del presente script, contempla el lanzamiento de los scripts de despliegue automático para portales construidos en c#.

$invocation = (Get-Variable MyInvocation).Value
$MainDirectory = Split-Path $invocation.MyCommand.Path
$GlobalFunctions = "$MainDirectory\Config\Global_functions.psm1";
Import-Module $GlobalFunctions;

$date = $(get-date -format 'yyyymmdd_hhmmss');   
$GlobalProperties="$MainDirectory\Config\global.properties";

$PublishProfile = "ProfileGeneral";

$PathLogs = $(PropValue -file $GlobalProperties -nameVar "location.global.logs") + "\Log_$date.log";
if($PathLogs.Contains("MainDirectory")){
	$PathLogs = $PathLogs -replace "MainDirectory", $MainDirectory;
}

Start-Transcript -path $PathLogs;

function AppSettingsAttr(){
	Param(
		[System.Xml.XmlDocument]$XmlFile,
		$KeyVar
	);
	
	$Value = "";
	
	if("$KeyVar" -ne ""){
		$Value = $XmlFile.SelectNodes("//configuration/appSettings/add")| where{$_.key -eq $($KeyVar)};

	}
	
	return $Value;
}

function UpdateWebProject(){

	Param(
		$fileName
	);
	Try{
		$Project = [System.Xml.XmlDocument](Get-Content $fileName);
		
		$csproj = $Project.Project;
		
		$Elm = $Project.CreateElement("ItemGroup",$csproj.NamespaceURI);
		$Elm.RemoveAttribute("xmlns");
		$ItemGroup = $csproj.AppendChild($Elm);

		$Elm = $Project.CreateElement("None",$ItemGroup.NamespaceURI);
		$Elm.SetAttribute("Include","Properties\PublishProfiles\$($PublishProfile).pubxml");
		$Elm.RemoveAttribute("xmlns");
		$ItemGroup.AppendChild($Elm);

		$Project.Save($fileName);
		
		WriteMsg -Msg "El perfil de publicacion general ha sido asignado con exito";
		
	}
	Catch {
		WriteMsg -Type "ERROR" -Msg "UpdateWebProject: Se ha producido un error en tiempo de ejecucion";
		WriteMsg -Type "ERROR" -Msg $_.Exception.Message;
	}
}

#Funcion encargada de realizar la publicación de la solucion como archivo .zip, insumo necesario para el deploy
function PublishProfileToZip(){
	Param(
		$Workspace
	);
	
	$sln = Get-ChildItem -Path $Workspace -Filter *.sln;
	echo "la longitud es: [$($sln.length)]";
	if($($sln.length) -gt 0){
		& MSBuild "$($sln.fullname)" /p:DeployOnBuild=true /p:PublishProfile=$($PublishProfile) /p:RunCodeAnalysis=false;
	} else {
		
		WriteMsg -Type "ERROR" -Msg "No fue posible encontrar la solucion en el workspace, verifique la ruta de la aplicacion.";
		Throw "";
	}
}

function DeployOnIIS(){
	Param(
		$Workspace,
		$Server,
		$User,
		$Password
	);
	
	$MSDeployKey = 'HKLM:\SOFTWARE\Microsoft\IIS Extensions\MSDeploy\3'
    if(!(Test-Path $MSDeployKey)) {
       throw "No se pudo encontrar MSDeploy. Utilice el Web Platform Installer para instalar el 'Web Deployment Tool' y vuelva a lanzar el proceso de despliegue."
    }
    $InstallPath = (Get-ItemProperty $MSDeployKey).InstallPath
    if(!$InstallPath -or !(Test-Path $InstallPath)) {
       throw "No se pudo encontrar MSDeploy. Utilice el Web Platform Installer para instalar el 'Web Deployment Tool' y vuelva a lanzar el proceso de despliegue."
    }

    $msdeploy = Join-Path $InstallPath "msdeploy.exe"
    if(!(Test-Path $MSDeploy)) {
       throw "No se pudo encontrar MSDeploy. Utilice el Web Platform Installer para instalar el 'Web Deployment Tool' y vuelva a lanzar el proceso de despliegue."
    }
	
	$Psw = ConvertTo-SecureString -String $Password -AsPlainText -Force;
	
	$DebugMode = $(PropValue -file $GlobalProperties -nameVar "debug.mode.active");
	$Operations="y";
	if("$DebugMode" -eq "true"){
		$Operations="t";
		WriteMsg -Type "WARNING" -Msg "Se realizara el despliegue en modo de prueba, lo que indica que no necesariamente sera desplegado sobre el IIS";
	}
		
	$files = Get-ChildItem -path $Workspace -filter *.cmd;	
	foreach ($file in $files) {
		if("$Server" -eq "localhost"){
			& "$($file.fullname)" /$Operations /u:$user /p:$Psw /a:Basic;
		} else {
			& "$($file.fullname)" /$Operations /u:$user /p:$Psw /a:Basic /m:https://$Server:8172/MSDeploy.axd;
		}
	}
}

function DeployPortalCSharp()
{
	Param(
		#Workspace Corresponde con la ubicación actual de la solución.
		$Workspace,
		$Environment="Desarrollo",
		$Server="localhost"
	);   
	
	if( $( $Workspace.length) -gt 0  ) {
	
		$User = $(PropValue -file $GlobalProperties -nameVar "server.usr");
		$Password = $(PropValue -file $GlobalProperties -nameVar "server.password");
		
		if( ("$User" -eq "") -or ("$Password" -eq "")){
			Throw "Usuario o contraseña invalidos para efectuar el proceso de despliegue. Por favor verifiquelos";
		}
		
		$SlnName = GetLastElementUrl -string $Workspace;
		WriteMsg -Msg "Iniciando el proceso de despliegue para el portal C#[$SlnName]";
		
		$XmlPath = "$MainDirectory\Resources\ProfileGeneral.pubxml";
        
        $XmlFile = GetXml -Path $XmlPath;
		$XmlNodes = $XmlFile.Project; 
        $CountXml = $XmlNodes.ChildNodes.Count; 
		for($i=0; $i -lt $CountXml; $i++){
			
			if($($CountXml) -eq 1){
				$CurrentNode = $XmlNodes.PropertyGroup;
			} else {
				Throw "Existe mas de una configuracion.";
			}
			$CurrentNode.WebPublishMethod="Package";
			
			$ProfileDirs = Get-ChildItem $workspace -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "PublishProfiles"};
			
			foreach ($file in $ProfileDirs) {
				
				$Current = $file.Fullname;
				$WorkspaceConfig = $Current + "\..\..";
				$WebConfig = $WorkspaceConfig + "\Web.config";
				$XmlConfig = GetXml -Path $WebConfig;				
				#$IISApp = $XmlConfig.SelectNodes("//configuration/appSettings/add")| where{$_.key -eq 'IISApp'};
				$IISApp = AppSettingsAttr -XmlFile $XmlConfig -KeyVar 'IISApp';

				#$webConfigTest = $XmlConfig.SelectNodes("//configuration/appSettings/add")| where{$_.key -eq 'webConfigTest'};
				$webConfigTest = AppSettingsAttr -XmlFile $XmlConfig -Key "webConfigTest";
				#$webConfigRelease = $XmlConfig.SelectNodes("//configuration/appSettings/add")| where{$_.key -eq 'webConfigRelease'};
				$webConfigRelease = AppSettingsAttr -XmlFile $XmlConfig -Key "webConfigRelease";
				if($($($IISApp.value).length) -ge 0 ){
				
					if("$Environment" -eq "Pruebas"){
						#$webConfigSelected = $XmlConfig.SelectNodes("//configuration/appSettings/add")| where{$_.key -eq 'webConfigTest'};
						$webConfigSelected = AppSettingsAttr -XmlFile $XmlConfig -Key "webConfigTest";
					} else {
						if("$Environment" -eq "Produccion"){
							#$webConfigSelected = $XmlConfig.SelectNodes("//configuration/appSettings/add")| where{$_.key -eq 'webConfigRelease'};
							$webConfigSelected = AppSettingsAttr -XmlFile $XmlConfig -Key "webConfigRelease";
						} else {
							#Ambiente corresponde con Desarrollo
							
							if("$webConfigSelected" -ne ""){
								#$webConfigSelected = $XmlConfig.SelectNodes("//configuration/appSettings/add")| where{$_.key -eq 'webConfigDev'};
								$webConfigSelected = AppSettingsAttr -XmlFile $XmlConfig -Key "webConfigDev";
							} else {
								Throw "No se ha encontrado el parametro 'webConfigDev' que especifique el WebConfig personalizado para el ambiente.";
							}
						}
					}
					WriteMsg -Msg "Se instalara la aplicacion '$($IISApp.value)' con base al Web.config personalizado '$($webConfigSelected.value)'";
					
					$CurrentNode.LastUsedBuildConfiguration="$($webConfigSelected.value)";
					$CurrentNode.LastUsedPlatform="Any CPU";			
					$CurrentNode.LaunchSiteAfterPublish="True";
					$CurrentNode.ExcludeApp_Data="False";
					$WebDeployDir = New-Item -Force -ItemType directory -Path "$Workspace\WebDeploy";
					$CurrentNode.DesktopBuildPackageLocation="$($WebDeployDir.fullname)";
					$CurrentNode.PackageAsSingleFile="True";
					$CurrentNode.DeployIisAppPath="Default Web Site/$($IISApp.value)";
					$XmlFile.Save("$($Current)\$($PublishProfile).pubxml");
					
					$FileProject = Get-ChildItem -Path $WorkspaceConfig -Filter *.csproj;
					WriteMsg -Msg "Inclusion de perfil para generacion de paquete, sobre el proyecto [$($FileProject.fullname)]";

					UpdateWebProject -fileName $($FileProject.fullname);


				} else {
					WriteMsg -Type "ERROR" -Msg "La variable IISApp no fue configurada en el archivo $($WorkspaceConfig)\Web.config del proyecto web.";
					Throw "";
				}
								
			}
					
					
			PublishProfileToZip -Workspace $Workspace;

			DeployOnIIS -Workspace $($WebDeployDir.fullname) -Server $Server -User $User -Password $Password;
			
		}
		
		WriteMsg -Msg "El proceso de despliegue ha finalizado";
        
	} else {
		WriteMsg -Type "ERROR" -Msg "Se esperaba la ruta de la solucion para proceder con el despliegue";
		Throw "";
	}
	
}

DeployPortalCSharp -Workspace $args[0] -Environment $args[1] -Url $args[2];

#Se detiene el registro de logs en archivo
stop-transcript;