#Funcion encargada de imprimir en la consola mensajes de acuerdo al tipo.
#@Example WriteMsg -Msg "Mensaje informativo por defecto";
#@Example WriteMsg -Type "INFO" -Msg "Mensaje informativo";
#@Example WriteMsg -Type "ERROR" -Msg "Mensaje de error";
#@Example WriteMsg -Type "WARNING" -Msg "Mensaje de advertencia";
#@Example WriteMsg -Type "SUCCESS" -Msg "Mensaje de exito";
function WriteMsg(){
	Param(   
		$Type="INFO",
		$Msg=""
	);   
	if($Type -eq "INFO"){
		Write-Host "[INFO] - $Msg";
	} else {
		if($Type -eq "ERROR"){
			Write-Host -ForegroundColor Red "[ERROR] - $Msg";
		} else {
			Write-Host -ForegroundColor Yellow "[WARNING] - $Msg";
		}
	}
}

#Funcion encargada de disparar excepciones genericas en los script powershell
function DisplayError(){
	Param(
		$Obj
	);
	$ErrorMessage = $Obj.Exception.Message;
	Throw $ErrorMessage;
}

#Funcion encargada de leer un archivo properties y administrar los valores como variables de entorno.
function Get-PropertiesFile(){
	Param(
		$PropertiesFile
	);
    
	$file_content = Get-Content -Path $PropertiesFile;
	$file_content = $file_content -join [Environment]::NewLine;

	return ConvertFrom-StringData($file_content);
}

#Funcion encargada de obtener el valor de una variable x de un archivo properties
#@Example Get-PropValue -file "D:\global.properties"
function PropValue(){
	Param(
		$file,
		$nameVar
	);
	
	$properties = Get-PropertiesFile -PropertiesFile $file;
	return $properties.$nameVar;
	
}

#Funcion encargada de remplazar un String X por su correspondiente variable reservada
function ReplaceReservedVar(){
	Param(
		$Expression,
		$Var,
		$Value
	);
	
	$Replaced = $Expression;
	if($Expression.Contains($Var)){
		$Replaced = $Expression -replace $Var, $Value;
	}
	return $Replaced;
}

#Funcion encargada de obtener el ultimo elemento de una Url
function GetLastElementUrl()
{
    Param($string);
	$string = $string -replace "/", "\";
	if($string.Contains("\")){
		$split = $string.Split("\");
		$string = $split[$($split.length) - 1];
	}
	return $string;
}

#Funcion encargada de obtener los nodos registrations de un xml tipo AssemblyRegistration
function GetRegistrations(){
    Param($XmlFile, [string] $Del = "false", [string] $XmlPath);
    #[xml]$Xml = Get-Content -Path $XmlFile;
	
    $XmlNodes = $XmlFile.AssemblyRegistration.Registrations;
    
    if($Del -eq "true"){
        $CountXml = $XmlNodes.ChildNodes.Count;
        if($CountXml -gt 0){
            $XmlNodes.RemoveAll();
        }
    }
    $XmlFile.Save($XmlPath);
    return $XmlNodes;
}

#Funcion encargada de leer un archivo Xml
function GetXml(){
	Param(
		$Path
	);
	[xml] $XmlFile = Get-Content -Path $Path;
	return $XmlFile;
}