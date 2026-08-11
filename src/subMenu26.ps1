function psSubMenu26 {
    # DetecciÃ³n y fallback de Active Directory usando ADSI (LDAP nativo sin RSAT)
    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        Write-Host "[INFO] Modulo ActiveDirectory (RSAT) no detectado. Cargando emulacion LDAP nativa..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500

        # Declarar funciones de compatibilidad
        function Get-ADUser {
            param(
                [Parameter(Position = 0, Mandatory = $true)]
                [string]$Identity,
                [Parameter(Position = 1)]
                [string[]]$Properties
            )
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                
                # FunciÃ³n para traducir fechas de LargeInteger
                filter Get-ADDate {
                    if ($null -eq $_ -or $_.Value -eq 0 -or $_.Value -eq 9223372036854775807) { return $null }
                    try {
                        if ($_ -is [System.Int64] -or $_ -is [System.Int32]) {
                            return [DateTime]::FromFileTime($_)
                        }
                        # Intento de invocacion de LargeInteger compatible con PowerShell 2.0 (sin -shl)
                        $high = $_.GetType().InvokeMember("HighPart", [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null)
                        $low = $_.GetType().InvokeMember("LowPart", [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null)
                        $intVal = ([int64]$high * 4294967296) + [uint32]$low
                        return [DateTime]::FromFileTime($intVal)
                    }
                    catch {}
                    return $null
                }

                $prop = @{}
                $prop["Name"] = [string]$entry.Properties["name"].Value
                $prop["DisplayName"] = [string]$entry.Properties["displayName"].Value
                $prop["SamAccountName"] = [string]$entry.Properties["samAccountName"].Value
                $prop["Title"] = [string]$entry.Properties["title"].Value
                $prop["Office"] = [string]$entry.Properties["physicalDeliveryOfficeName"].Value
                $prop["Department"] = [string]$entry.Properties["department"].Value
                $prop["Description"] = [string]$entry.Properties["description"].Value
                $prop["OfficePhone"] = [string]$entry.Properties["telephoneNumber"].Value
                $prop["PostalCode"] = [string]$entry.Properties["postalCode"].Value
                $prop["GivenName"] = [string]$entry.Properties["givenName"].Value
                $prop["Surname"] = [string]$entry.Properties["sn"].Value
                $prop["UserPrincipalName"] = [string]$entry.Properties["userPrincipalName"].Value
                $prop["ObjectClass"] = [string]$entry.SchemaClassName
                if ($entry.Guid) {
                    $prop["ObjectGUID"] = [Guid]$entry.Guid
                }
                else {
                    $prop["ObjectGUID"] = $null
                }

                if ($entry.Properties["objectSid"].Value) { 
                    $prop["SID"] = (New-Object System.Security.Principal.SecurityIdentifier($entry.Properties["objectSid"].Value, 0)).Value 
                }
                else {
                    $prop["SID"] = $null
                }

                $uac = $entry.Properties["userAccountControl"].Value
                if ($uac) {
                    $prop["Enabled"] = -not ($uac -band 2)
                    $prop["PasswordExpired"] = [bool]($uac -band 0x800000)
                    $prop["PasswordNeverExpires"] = [bool]($uac -band 0x10000)
                }
                else {
                    $prop["Enabled"] = $true
                    $prop["PasswordExpired"] = $false
                    $prop["PasswordNeverExpires"] = $false
                }

                $prop["PasswordLastSet"] = $entry.Properties["pwdLastSet"].Value | Get-ADDate
                $prop["AccountExpirationDate"] = $entry.Properties["accountExpires"].Value | Get-ADDate
                
                $lastLogonVal = $entry.Properties["lastLogonTimestamp"].Value
                if ($null -eq $lastLogonVal) { $lastLogonVal = $entry.Properties["lastLogon"].Value }
                $prop["LastLogonDate"] = $lastLogonVal | Get-ADDate

                $managerDN = $entry.Properties["manager"].Value
                if ($managerDN) {
                    $prop["Manager"] = ($managerDN -split ',')[0].Replace('CN=', '')
                }
                else {
                    $prop["Manager"] = $null
                }

                $groups = @()
                foreach ($g in $entry.Properties["memberOf"]) {
                    $groups += $g
                }
                $prop["MemberOf"] = $groups

                return New-Object PSObject -Property $prop
            }
            return $null
        }

        function Set-ADAccountPassword {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Identity,
                [Parameter(Mandatory = $true)]
                [System.Security.SecureString]$NewPassword,
                [switch]$Reset
            )
            
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                $entry.Invoke("SetPassword", $PlainPassword)
                $entry.CommitChanges()
            }
            else {
                throw "No se pudo encontrar al usuario '$Identity' en el dominio."
            }
        }

        function Set-ADUser {
            param(
                [Parameter(Mandatory = $true)]
                [string]$Identity,
                [bool]$ChangePasswordAtLogon
            )
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                if ($ChangePasswordAtLogon) {
                    $entry.Properties["pwdLastSet"].Value = 0
                }
                else {
                    $entry.Properties["pwdLastSet"].Value = -1
                }
                $entry.CommitChanges()
            }
            else {
                throw "No se pudo encontrar al usuario '$Identity' en el dominio."
            }
        }
    }

    # ==============================================================================
    #   FUNCIONES AUXILIARES DE CONEXION Y ANALISIS REMOTO (OPTIMIZACION Y LIMPIEZA)
    # ==============================================================================

    function Parse-RemoteTarget {
        param([string]$Target)
        $Target = $Target.Trim()
        if ($Target -match '^\d{1,3}$') {
            return "192.168.176.$Target"
        }
        elseif ($Target -match '^\d{1,3}\.\d{1,3}$') {
            return "192.168.$Target"
        }
        return $Target
    }

    function Get-RemoteConnectionContext {
        $defTarget = ""
        if ($global:RemoteTargetIP) {
            $defTarget = $global:RemoteTargetIP
        }
        
        Write-Host "`n--- Conexion Remota ---" -ForegroundColor Yellow
        $prompt = "Ingrese IP completa, Hostname o los 2 ultimos octetos"
        if ($defTarget) {
            $prompt += " [$defTarget]"
        }
        $inputTarget = Read-Host $prompt
        
        if ($inputTarget.Trim() -eq "") {
            if ($defTarget) {
                $target = $defTarget
            }
            else {
                Write-Host "[ERROR] Debe especificar un destino." -ForegroundColor Red
                return $null
            }
        }
        else {
            $target = Parse-RemoteTarget $inputTarget
        }
        
        $cred = $null
        if ($global:RemoteTargetIP -eq $target -and $global:RemoteTargetCred -ne $null) {
            $usarExistente = Read-Host "Â¿Usar las credenciales guardadas para $target? (S/N) [S]"
            if ($usarExistente -eq "" -or $usarExistente.ToUpper() -eq "S") {
                $cred = $global:RemoteTargetCred
            }
        }
        
        if ($null -eq $cred) {
            Write-Host "`nSeleccione el tipo de autenticacion para ${target}:" -ForegroundColor Yellow
            Write-Host "1. Credenciales de la sesion actual (SSO/Dominio Local)"
            Write-Host "2. Credenciales de Usuario de Dominio (ej: DOMINIO\Usuario)"
            Write-Host "3. Credenciales de Usuario Local (ej: .\Administrador)"
            $tipoCred = Read-Host "Seleccione opcion [1]"
            
            if ($tipoCred -eq "2" -or $tipoCred -eq "3") {
                $promptUser = if ($tipoCred -eq "2") { "Usuario de Dominio" } else { "Usuario Local" }
                Write-Host "Ingrese las credenciales para ${promptUser}:" -ForegroundColor Yellow
                $cred = Get-Credential
            }
        }
        
        Write-Host "Verificando conexion con $target (Ping)..." -ForegroundColor Yellow
        $ping = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue
        if (-not $ping) {
            Write-Host "[ERROR] El equipo $target no responde a Ping. Verifique si esta encendido." -ForegroundColor Red
            $confirmar = Read-Host "Â¿Desea intentar la conexion de todas formas? (S/N) [N]"
            if ($confirmar.ToUpper() -ne "S") {
                return $null
            }
        }
        
        $global:RemoteTargetIP = $target
        $global:RemoteTargetCred = $cred
        
        return New-Object PSObject -Property @{
            ComputerName = $target
            Credential   = $cred
        }
    }

    function Mount-RemoteCShare {
        param(
            [string]$ComputerName,
            $Credential
        )
        $driveName = "RemoteC_Clean"
        if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
        }
        
        $rootPath = "\\$ComputerName\C$"
        Write-Host "Conectando al recurso administrativo $rootPath..." -ForegroundColor Yellow
        
        try {
            if ($null -ne $Credential) {
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Credential $Credential -Scope Global -ErrorAction Stop | Out-Null
            }
            else {
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Scope Global -ErrorAction Stop | Out-Null
            }
            Write-Host "Conectado exitosamente al recurso compartido C$." -ForegroundColor Green
            return $driveName
        }
        catch {
            Write-Host "[ERROR] No se pudo mapear la unidad C$ remota." -ForegroundColor Red
            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }

    function Dismount-RemoteCShare {
        param([string]$driveName)
        if ($driveName -and (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
            Write-Host "Unidad remota C$ desmontada." -ForegroundColor Gray
        }
    }

    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 26. ===)) AD: COMANDOS AD ====="
            Write-Host "  1. GESTION DE USUARIO DE DOMINIO | ACTIVE DIRECTORY |"
            Write-Host "    1.1 Mostrar Datos de Usuario de Dominio con C.I, Cargo, Lugar."
            Write-Host "    1.2 Mostrar ultima conexion de Usuario"
            Write-Host "    1.3 Mostrar Datos de Usuario de Dominio, fecha cambio clave." -ForegroundColor Green
            Write-Host "    1.4. Cambiar Clave de Usuario de Dominio." -ForegroundColor Red
            Write-Host "    1.5 Reporte detallado de Usuario de Dominio."
            Write-Host ""
            Write-Host "  2. GESTION DE USUARIO REMOTO RECURSOS COMPARTIDOS"
            Write-Host "    2.1 Mostrar usuario PC Remota." -ForegroundColor Cyan
            Write-Host "    2.2 Mostrar usuarios activos y no activos del Dominio - PC Remota." -ForegroundColor Cyan
            Write-Host "    2.5 Mostrar Carpetas Compartidas en PC Remota."
            Write-Host ""
            Write-Host "  3. GESTION DE USUARIO | USUARIO LOCAL |"
            Write-Host "    3.1 Cambiar contrasenia de USUARIO LOCAL en PC REMOTO" -ForegroundColor Cyan            
            Write-Host ""
            Write-Host "  4. OPTIMIZACION Y LIMPIEZA DE SISTEMA REMOTO:" -ForegroundColor Green
            Write-Host "    4.1. Eliminar Archivos TEMPORALES CARPETAS Remoto" -ForegroundColor DarkCyan
            Write-Host "    4.2. Eliminar Archivos Temporales ProgramData Remoto" -ForegroundColor DarkCyan
            Write-Host "    4.3. Liberar RAM Remoto" -ForegroundColor DarkCyan
            Write-Host "    4.4. Liberar Procesador Remoto" -ForegroundColor DarkCyan
            Write-Host "    4.5. Vaciar Papelera de Reciclaje Remoto" -ForegroundColor DarkCyan
            Write-Host "    4.6. Eliminacion avanzada de temporales (Todos los usuarios) Remoto" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  30. REFRESH." -ForegroundColor Red
            Write-Host "  31. REFRESH DESDE GITHUB (ONLINE)." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "==============================="
            
            $op26 = Read-Host "Seleccione la tarea a realizar"

            switch ($op26) {
                "1.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    Write-Host "OfficePhone : Carnet de Identidad de persona" -ForegroundColor Cyan
                    Write-Host ""
                    # 1. Solicitar el nombre de usuario
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    # 2. Definir las propiedades extendidas que queremos extraer
                    $propiedades = @(
                        "Description",    # DescripciÃ³n
                        "Title",          # Cargo / Puesto
                        "Office",         # Oficina (PhysicalDeliveryOfficeName)
                        "Department",     # Ãrea / Departamento
                        "Manager",        # Dependencia (Jefe Directo)
                        "OfficePhone",    # TelÃ©fono
                        "PostalCode",     # CÃ³digo Postal
                        "SID"             # Identificador de Seguridad
                    )

                    try {
                        # Ejecutar la consulta y forzar el formato de lista detallada
                        Get-ADUser -Identity $dato -Properties $propiedades | Format-List `
                            DistinguishedName, 
                        Enabled, 
                        GivenName, 
                        Name, 
                        ObjectClass, 
                        ObjectGUID, 
                        @{Label = "Cargo"; Expression = { $_.Title } },
                        @{Label = "Descripcion"; Expression = { $_.Description } },
                        @{Label = "Oficina"; Expression = { $_.Office } },
                        @{Label = "Area"; Expression = { $_.Department } },
                        @{Label = "Dependencia (Manager)"; Expression = { $_.Manager } },
                        OfficePhone, 
                        PostalCode, 
                        SamAccountName, 
                        SID, 
                        Surname, 
                        UserPrincipalName
                    }
                    catch {
                        Write-Host "Error: No se encontro al usuario '$dato' o no hay conexion con el AD." -ForegroundColor Red
                    }

                }
                "1.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar el nombre de usuario
                    $usuario = Read-Host "Introduzca el usuario de dominio"

                    try {
                        # 2. Obtener datos bÃ¡sicos y Ãºltima conexiÃ³n del AD
                        $adUser = Get-ADUser -Identity $usuario -Properties LastLogonDate, Description, Title

                        if ($adUser) {
                            Write-Host "--- INFORMACION DE CONEXION ---" -ForegroundColor Cyan
                            Write-Host "Usuario:        $($adUser.Name)"
                            Write-Host "Ultimo Logueo:  $($adUser.LastLogonDate)"
                            Write-Host "Estado:         $(if($adUser.Enabled){'Activo'}else{'Deshabilitado'})"
                            
                            # 3. Intentar obtener los equipos desde los Logs de Seguridad (Event ID 4624)
                            # Nota: Esto requiere privilegios de admin y que los logs no se hayan sobrescrito
                            Write-Host "Buscando rastros en logs de seguridad (esto puede tardar)..." -ForegroundColor Yellow
                            
                            $hoy = Get-Date
                            $eventos = Get-WinEvent -FilterHashtable @{
                                LogName   = 'Security'; 
                                ID        = 4624; 
                                StartTime = $hoy.AddDays(-7) # Ãšltimos 7 dÃ­as
                            } -ErrorAction SilentlyContinue | Where-Object {
                                $_.Properties[5].Value -eq $usuario
                            }

                            if ($eventos) {
                                Write-Host "Equipos detectados recientemente:" -ForegroundColor Green
                                $eventos | ForEach-Object {
                                    $computadora = $_.Properties[18].Value
                                    if ($computadora -and $computadora -ne "-") {
                                        $fecha = $_.TimeCreated
                                        Write-Host "- [$fecha] en el equipo: $computadora"
                                    }
                                } | Select-Object -Unique
                            }
                            else {
                                Write-Host "No se encontraron registros recientes en los logs locales de este equipo." -ForegroundColor Gray
                            }
                        }
                    }
                    catch {
                        Write-Host "Error: No se pudo encontrar al usuario o acceder a los logs." -ForegroundColor Red
                    }


                }

                "1.3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar usuario
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    # 2. Definir propiedades a consultar
                    $props = @(
                        "PasswordExpired", "PasswordLastSet", "PasswordNeverExpires", 
                        "AccountExpirationDate", "MemberOf", "Description", 
                        "Office", "OfficePhone", "DisplayName"
                    )

                    try {
                        $user = Get-ADUser -Identity $dato -Properties $props

                        # 3. Determinar lÃ³gica de expiraciÃ³n de cuenta
                        $estadoExp = if ($null -eq $user.AccountExpirationDate) { "Sin fecha de expiracion" } 
                        else { "Expira el: $($user.AccountExpirationDate)" }

                        # 4. Mostrar Resumen Corto pero Completo
                        Write-Host "--- RESUMEN DE USUARIO: $($user.DisplayName) ---" -ForegroundColor Cyan
                        
                        $user | Select-Object `
                        @{Label = "Nombre Completo"; Expression = { $_.DisplayName } },
                        @{Label = "Estado Cuenta"; Expression = { if ($_.Enabled) { "Activo" }else { "Deshabilitado" } } },
                        @{Label = "Oficina"; Expression = { $_.Office } },
                        @{Label = "Descripcion"; Expression = { $_.Description } },
                        @{Label = "Ultimo Cambio Pass"; Expression = { $_.PasswordLastSet } },
                        @{Label = "Pass Expirada"; Expression = { $_.PasswordExpired } },
                        @{Label = "Pass Nunca Expira"; Expression = { $_.PasswordNeverExpires } },
                        @{Label = "Expiracion de Usuario"; Expression = { $estadoExp } } | 
                        Format-List

                        # Apartado de Grupos (Resumen corto)
                        Write-Host "Membresia de Grupos:" -ForegroundColor Yellow
                        $user.MemberOf | ForEach-Object { Write-Host " - $(($_ -split ',')[0].Replace('CN=',''))" }

                    }
                    catch {
                        Write-Host "Error: No se pudo encontrar al usuario '$dato'." -ForegroundColor Red
                    }


                }

                "1.4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar el nombre de usuario (Equivalente a SET /P)
                    $usuarioAD = Read-Host "Introduzca el usuario de dominio"

                    # 2. Solicitar la contraseÃ±a de forma segura (Asteriscos)
                    # Usamos un bloque try/catch para manejar errores de permisos o de usuario no encontrado
                    try {
                        Write-Host "Preparando cambio de contrasenia para: $usuarioAD" -ForegroundColor Cyan
                        
                        # Captura la contraseÃ±a de forma segura (AsSecureString oculta la entrada)
                        $NuevaContrasenia = Read-Host "Introduzca la nueva contrasenia para $usuarioAD" -AsSecureString

                        # 3. Aplicar el cambio (Equivalente a Reset de Administrador)
                        Set-ADAccountPassword -Identity $usuarioAD -NewPassword $NuevaContrasenia -Reset
                        
                        # 4. Forzar que el usuario cambie la contraseÃ±a en el prÃ³ximo inicio de sesiÃ³n (Opcional pero recomendado)
                        Set-ADUser -Identity $usuarioAD -ChangePasswordAtLogon $false

                        Write-Host "EXITO: La contrasenia se ha actualizado correctamente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ERROR: No se pudo cambiar la contrasenia." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor White
                    }

                    

                }            

                "1.5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Entrada de datos
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    try {
                        # 2. ObtenciÃ³n de datos extendidos
                        # Agregamos: Enabled (Estado), Office (Oficina) y Description (DescripciÃ³n)
                        $user = Get-ADUser -Identity $dato -Properties LastLogonDate, MemberOf, AccountExpirationDate, Title, Department, PasswordLastSet, Enabled, Office, Description

                        if ($user) {
                            Write-Host "`n====================================================" -ForegroundColor Cyan
                            Write-Host "   REPORTE DETALLADO DE SEGURIDAD: $($user.Name)"
                            Write-Host "====================================================" -ForegroundColor Cyan

                            # --- NUEVO APARTADO: DATOS DE FILIACIÃ“N ---
                            Write-Host "[*] DATOS GENERALES:" -ForegroundColor Yellow
                            $estado = if ($user.Enabled) { "ACTIVO" } else { "DESHABILITADO" }
                            Write-Host "    Estado Usuario: $estado"
                            Write-Host "    Oficina:        $($user.Office)"
                            Write-Host "    Descripcion:    $($user.Description)"
                            Write-Host "    Cargo:          $($user.Title)"
                            Write-Host "    Area/Depto:     $($user.Department)"

                            # --- APARTADO: ULTIMO CAMBIO DE CONTRASEÃ‘A ---
                            Write-Host "`n[*] FECHA ULTIMO CAMBIO DE CONTRASENIA:" -ForegroundColor Yellow
                            if ($user.PasswordLastSet) { 
                                Write-Host "    $($user.PasswordLastSet)" 
                            }
                            else { 
                                Write-Host "    El usuario nunca ha cambiado su contrasenia." 
                            }
                            
                            # --- APARTADO: CONEXIÃ“N Y ESTADO ---
                            Write-Host "`n[*] ULTIMA CONEXION ESTABLECIDA:" -ForegroundColor Yellow
                            if ($user.LastLogonDate) { 
                                Write-Host "    $($user.LastLogonDate)" 
                            }
                            else { 
                                Write-Host "    Nunca ha iniciado sesiÃ³n o el dato no se ha replicado." 
                            }

                            # --- APARTADO: EXPIRACIÃ“N DE CUENTA ---
                            Write-Host "`n[*] ESTADO DE LA CUENTA Y EXPIRACION:" -ForegroundColor Yellow
                            if ($null -eq $user.AccountExpirationDate) {
                                Write-Host "    La cuenta no tiene fecha de expiracion (Nunca expira)."
                            }
                            else {
                                $fechaExp = $user.AccountExpirationDate
                                Write-Host "    FECHA DE EXPIRACION: $fechaExp"
                                if ($fechaExp -lt (Get-Date)) {
                                    Write-Host "    AVISO: La cuenta ya ha expirado." -ForegroundColor Red
                                }
                            }

                            # --- APARTADO: MEMBRESÃA DE GRUPOS ---
                            Write-Host "`n[*] GRUPOS A LOS QUE PERTENECE:" -ForegroundColor Yellow
                            if ($user.MemberOf) {
                                foreach ($grupoDN in $user.MemberOf) {
                                    $nombreGrupo = ($grupoDN -split ",")[0].Replace("CN=", "")
                                    Write-Host "    - $nombreGrupo"
                                }
                            }
                            else {
                                Write-Host "    El usuario no pertenece a grupos adicionales."
                            }

                            # --- APARTADO: RASTREO DE EQUIPOS ---
                            Write-Host "`n[*] RASTREO DE EQUIPOS RECIENTES (LOGS LOCALES):" -ForegroundColor Yellow
                            $eventos = Get-WinEvent -FilterHashtable @{LogName = 'Security'; ID = 4624 } -MaxEvents 100 -ErrorAction SilentlyContinue | 
                            Where-Object { $_.Properties[5].Value -eq $dato }
                            
                            if ($eventos) {
                                $eventos | ForEach-Object {
                                    $pc = $_.Properties[18].Value
                                    if ($pc -and $pc -ne "-") { 
                                        Write-Host "    - Detectado en: $pc ($($_.TimeCreated))" 
                                    }
                                } | Select-Object -Unique
                            }
                            else {
                                Write-Host "    No se hallaron registros en este equipo."
                            }
                            Write-Host "====================================================" -ForegroundColor Cyan
                        }
                    }
                    catch {
                        Write-Host "`nError: No se pudo obtener informacion del usuario '$dato'." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)"
                    }

                    Write-Host "`n====================================================" -ForegroundColor Cyan

                }

                "2.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. DefiniciÃ³n del segmento de red base
                    $baseIP = "192.168.176."

                    # 2. Captura del Ãºltimo OCTETO con validaciÃ³n simple
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    if ($hostID -match '^\d{1,3}$') {
                        $fullIP = $baseIP + $hostID
                        Write-Host "`n--- Consultando Host: $fullIP ---" -ForegroundColor Cyan
                        
                        try {
                            # 3. EjecuciÃ³n optimizada de quser (query user)
                            # Redirigimos el error 2 al flujo de Ã©xito para procesar el texto de "No hay usuarios"
                            $resultado = quser /server:$fullIP 2>&1

                            # 4. Procesamiento de la respuesta
                            if ($resultado -like "*No hay ningÃºn usuario*" -or $resultado -like "*No user exists*") {
                                Write-Host "Estado: Equipo encendido, pero sin sesiones activas." -ForegroundColor Cyan
                            }
                            elseif ($resultado -like "*Error*") {
                                Write-Host "Error: No se pudo establecer conexion RPC con $fullIP." -ForegroundColor Red
                                Write-Host "Verifique que el equipo estÃ© en lÃ­nea y el Firewall permita RPC." -ForegroundColor Gray
                            }
                            else {
                                # Limpiamos lÃ­neas vacÃ­as y mostramos la tabla de quser
                                $resultado | Where-Object { $_.Trim() -ne "" }
                            }
                        }
                        catch {
                            Write-Host "Error inesperado al ejecutar el comando." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Entrada invalida. Debe ingresar solo numeros (0-255)." -ForegroundColor Red
                    }

                    # Pausa para ver los resultados antes de cerrar la consola
                    # Write-Host "`nPresione cualquier tecla para finalizar esta consulta..."
                    # $null = [Console]::ReadKey()
                    
                }

                "2.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    Write-Host "--- Auditoria de Usuarios: Equipo Remoto ---" -ForegroundColor Cyan

                    # 1. Solicitud de entrada con validacion basica
                    $octeto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX)"

                    if ($octeto -notmatch '^\d{1,3}$') {
                        Write-Host "[ERROR] El octeto ingresado no es valido." -ForegroundColor Red
                        break
                    }

                    $ip = "192.168.176.$octeto"
                    Write-Host "Conectando a $ip..." -ForegroundColor Yellow

                    # 2. Bloque de ejecucion con manejo de errores
                    try {
                        # Consultar usuario actual
                        $pc = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ip -ErrorAction Stop
                        $usuarioActual = $pc.UserName

                        # Consultar perfiles historicos (Excluye cuentas especiales del sistema)
                        $perfiles = Get-WmiObject -Class Win32_UserProfile -ComputerName $ip -Filter "Special=False" -ErrorAction Stop

                        # 3. Presentacion de resultados
                        Write-Host "`n--- Resultado de la Auditoria ---" -ForegroundColor Green
                        
                        # Mostrar usuario activo
                        Write-Host "Usuario Activo Actualmente:" -ForegroundColor White
                        if ($null -eq $usuarioActual) {
                            Write-Host "  No hay ningun usuario con sesion iniciada." -ForegroundColor Gray
                        }
                        else {
                            Write-Host "  $usuarioActual" -ForegroundColor Cyan
                        }

                        # Mostrar historial de perfiles (Solo nombres)
                        Write-Host "`nUsuarios que han iniciado sesion anteriormente:" -ForegroundColor White
                        $listaUsuarios = foreach ($perfil in $perfiles) {
                            $nombreUsuario = $perfil.LocalPath.Split('\')[-1]
                            
                            New-Object PSObject -Property @{
                                Usuario = $nombreUsuario
                            } | Select-Object Usuario
                        }

                        if ($null -eq $listaUsuarios) {
                            Write-Host "  No se encontraron perfiles de usuario adicionales." -ForegroundColor Gray
                        }
                        else {
                            $listaUsuarios | Sort-Object Usuario | Format-Table -AutoSize
                        }

                    }
                    catch {
                        Write-Host "`n[ERROR] No se pudo conectar al equipo $ip." -ForegroundColor Red
                        Write-Host "Razon: $_" -ForegroundColor Red
                        Write-Host "Asegurese de tener permisos de administrador en la maquina remota." -ForegroundColor Yellow
                    }
                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan

                }


                "2.5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. ConfiguraciÃ³n del segmento
                    $segmento = "192.168.176."
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    # Validar que la entrada sea numÃ©rica
                    if ($hostID -match '^\d{1,3}$') {
                        $targetIP = $segmento + $hostID
                        Write-Host "`n--- Buscando recursos compartidos en: $targetIP ---" -ForegroundColor Yellow

                        try {
                            # 2. Uso de Get-WmiObject para mÃ¡xima compatibilidad (Win7 en adelante)
                            # Filtramos Type=0 para mostrar solo carpetas compartidas por el usuario
                            # (Type 2147483648 son recursos administrativos ocultos)
                            $shares = Get-WmiObject -Class Win32_Share -ComputerName $targetIP -ErrorAction Stop | 
                            Where-Object { $_.Type -eq 0 }

                            if ($shares) {
                                Write-Host "Recursos encontrados:" -ForegroundColor Green
                                $shares | Select-Object @{Name = "Carpeta"; Expression = { $_.Name } }, 
                                @{Name = "Ruta Local"; Expression = { $_.Path } }, 
                                @{Name = "Descripcion"; Expression = { $_.Description } } | 
                                Format-Table -AutoSize
                            }
                            else {
                                Write-Host "No se encontraron carpetas compartidas (pÃºblicas) en este equipo." -ForegroundColor Cyan
                            }
                        }
                        catch {
                            Write-Host "ERROR: No se pudo conectar a $targetIP." -ForegroundColor Red
                            Write-Host "Causas posibles: Equipo apagado, IP incorrecta o Firewall bloqueando WMI/RPC." -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "Entrada invalida. Ingrese solo nÃºmeros." -ForegroundColor Red
                    }

                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan

                }

                "3.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # ==============================================================================
                    #   HERRAMIENTA REMOTA DE GESTIÃ“N DE USUARIOS LOCALES (GMSANTACRUZ)
                    #   Compatibilidad: Windows 7 hasta Windows 11
                    # ==============================================================================

                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "     GESTOR DE USUARIOS LOCALES REMOTOS           " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan

                    do {
                        # 1. ConstrucciÃ³n de la DirecciÃ³n IP
                        Write-Host "--- Estructura de Red ---\n" -ForegroundColor White
                        $ultimoOcteto = Read-Host "Ingrese el ULTIMO octeto para el segmento 192.168.176.xxx"
                        
                        # ValidaciÃ³n bÃ¡sica de entrada numÃ©rica
                        if ($ultimoOcteto -notmatch '^\d+$' -or [int]$ultimoOcteto -lt 1 -or [int]$ultimoOcteto -gt 254) {
                            Write-Host "[ERROR] El octeto ingresado no es valido." -ForegroundColor Red
                            break
                        }
                        
                        $ipRemota = "192.168.176.$ultimoOcteto"
                        Write-Host "Conectando a: $ipRemota..." -ForegroundColor Yellow

                        # 2. Manejo opcional de credenciales de Dominio
                        $opcionCred = Read-Host "Â¿Desea usar credenciales de un usuario de Dominio? (SI/NO)"
                        $usarCredenciales = $false
                        $credenciales = $null

                        if ($opcionCred.ToUpper() -eq "SI") {
                            Write-Host "Solicitando credenciales de Administrador de Dominio..." -ForegroundColor Yellow
                            $credenciales = Get-Credential
                            $usarCredenciales = $true
                        }

                        # 3. Listar cuentas locales mediante ADSI (WinNT)
                        Write-Host "`nObteniendo listado de cuentas locales de la PC remota..." -ForegroundColor Yellow
                        
                        try {
                            # ConexiÃ³n al contenedor de la mÃ¡quina remota
                            if ($usarCredenciales) {
                                # Se utiliza el ensamblador nativo de .NET para pasar las credenciales de forma segura
                                $username = $credenciales.UserName
                                $password = $credenciales.GetNetworkCredential().Password
                                $pcRemotaObj = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$ipRemota,computer", $username, $password)
                            }
                            else {
                                $pcRemotaObj = [ADSI]"WinNT://$ipRemota,computer"
                            }

                            # Filtrar solo objetos de tipo "User" (Cuentas de usuario)
                            $usuariosLocales = $pcRemotaObj.Children | Where-Object { $_.SchemaClassName -eq "user" }

                            if ($null -eq $usuariosLocales) {
                                Write-Host "[ERROR] No se pudieron recuperar los usuarios o la lista esta vacia." -ForegroundColor Red
                                break
                            }

                            # Mostrar los usuarios en una tabla limpia
                            Write-Host "`n--- Cuentas Locales Detectadas ---" -ForegroundColor White
                            $listaVisual = @()
                            foreach ($u in $usuariosLocales) {
                                # Propiedades extendidas nativas de la cuenta
                                $disabled = $u.Properties.UserFlags.Value -band 2 # 2 = ADS_UF_ACCOUNTDISABLE
                                $estado = if ($disabled) { "Deshabilitado" } else { "Activo" }
                                
                                $obj = New-Object PSObject -Property @{
                                    "Nombre de Usuario" = $u.Name
                                    "Estado"            = $estado
                                    "Descripcion"       = $u.Description
                                }
                                $listaVisual += $obj | Select-Object "Nombre de Usuario", Estado, Descripcion
                            }
                            
                            $listaVisual | Format-Table -AutoSize
                            
                        }
                        catch {
                            Write-Host "[ERROR CRITICO] No se pudo establecer la conexion remota via RPC/ADSI: $_" -ForegroundColor Red
                            break
                        }

                        # 4. SelecciÃ³n del usuario al que se le cambiarÃ¡ la contraseÃ±a
                        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
                        $usuarioSeleccionado = Read-Host "Ingrese el NOMBRE del usuario local a modificar"
                        
                        # Validar que el usuario ingresado exista en el listado previo
                        $existeUsuario = $listaVisual | Where-Object { $_."Nombre de Usuario".ToUpper() -eq $usuarioSeleccionado.ToUpper() }

                        if (-not $existeUsuario) {
                            Write-Host "[ERROR] El usuario '$usuarioSeleccionado' no pertenece a las cuentas locales de la PC remota." -ForegroundColor Red
                            break
                        }

                        # 5. Ingreso y cambio de la nueva contraseÃ±a
                        $nuevaPassword = Read-Host "Ingrese la NUEVA CONTRASENIA para el usuario ($usuarioSeleccionado)"
                        $confirmarPassword = Read-Host "Confirme la NUEVA CONTRASENIA"

                        if ($nuevaPassword -ne $confirmarPassword) {
                            Write-Host "[ERROR] Las contrasenias no coinciden. Operacion cancelada." -ForegroundColor Red
                            break
                        }

                        # 6. Aplicar el cambio de contraseÃ±a de forma remota
                        try {
                            Write-Host "`nAplicando cambios en el sistema remoto..." -ForegroundColor Yellow
                            
                            # Obtener el objeto ADSI especÃ­fico del usuario seleccionado
                            if ($usarCredenciales) {
                                $username = $credenciales.UserName
                                $password = $credenciales.GetNetworkCredential().Password
                                $usuarioObj = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$ipRemota/$usuarioSeleccionado,user", $username, $password)
                            }
                            else {
                                $usuarioObj = [ADSI]"WinNT://$ipRemota/$usuarioSeleccionado,user"
                            }

                            # Invocar el mÃ©todo nativo .SetPassword() de la API de Windows
                            $usuarioObj.SetPassword($nuevaPassword)
                            $usuarioObj.CommitChanges()

                            Write-Host "[EXITO] La contrasenia del usuario local '$usuarioSeleccionado' ha sido cambiada correctamente en $ipRemota." -ForegroundColor Green

                        }
                        catch {
                            Write-Host "[ERROR] Fallo al cambiar la contrasenia: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    Write-Host "`n==================================================" -ForegroundColor Cyan
                    Write-Host "`Proceso finalizado..." -ForegroundColor Cyan
                    
                }

                "3.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    
                }

                "3.3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"
   
                }

                "4.1" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminar Archivos TEMPORALES CARPETAS"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                        if ($null -ne $drive) {
                            Write-Host "Iniciando limpieza de temporales en el equipo remoto $ipRemota..." -ForegroundColor Yellow
                            
                            # 1. Limpieza de Windows\Temp
                            Write-Host " > Limpiando Temp de Windows..." -NoNewline
                            Remove-Item -Path "${drive}:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
                            Write-Host " [OK]" -ForegroundColor Green
                            
                            # 2. Limpieza de Windows\Prefetch
                            Write-Host " > Limpiando Prefetch de Windows..." -NoNewline
                            Remove-Item -Path "${drive}:\Windows\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
                            Write-Host " [OK]" -ForegroundColor Green
                            
                            # 3. Limpieza de Temp del Usuario con Sesion Activa
                            Write-Host " > Identificando usuario activo..." -NoNewline
                            try {
                                if ($null -ne $cred) {
                                    $compSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ipRemota -Credential $cred -ErrorAction Stop
                                }
                                else {
                                    $compSystem = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ipRemota -ErrorAction Stop
                                }
                                $activeUser = $compSystem.UserName
                                if ($activeUser) {
                                    $userName = $activeUser.Split('\')[-1]
                                    Write-Host " [$userName]" -ForegroundColor Cyan
                                    
                                    Write-Host " > Limpiando Temp de Usuario ($userName)..." -NoNewline
                                    $profilePath = "${drive}:\Users\$userName\AppData\Local\Temp"
                                    if (Test-Path $profilePath) {
                                        Remove-Item -Path "$profilePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                                        Write-Host " [OK]" -ForegroundColor Green
                                    }
                                    else {
                                        if ($null -ne $cred) {
                                            $profiles = Get-WmiObject -Class Win32_UserProfile -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                                        }
                                        else {
                                            $profiles = Get-WmiObject -Class Win32_UserProfile -ComputerName $ipRemota -ErrorAction SilentlyContinue
                                        }
                                        $matchProfile = $profiles | Where-Object { $_.LocalPath -like "*\$userName" } | Select-Object -First 1
                                        if ($matchProfile) {
                                            $customPath = $matchProfile.LocalPath.Replace("C:\", "${drive}:\")
                                            $tempPath = Join-Path $customPath "AppData\Local\Temp"
                                            if (Test-Path $tempPath) {
                                                Remove-Item -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                                                Write-Host " [OK]" -ForegroundColor Green
                                            }
                                            else {
                                                Write-Host " [No Encontrado]" -ForegroundColor Red
                                            }
                                        }
                                        else {
                                            Write-Host " [No Encontrado]" -ForegroundColor Red
                                        }
                                    }
                                }
                                else {
                                    Write-Host " [Ninguno]" -ForegroundColor Gray
                                }
                            }
                            catch {
                                Write-Host " [Error: $_]" -ForegroundColor Red
                            }
                            
                            Dismount-RemoteCShare -driveName $drive
                            Write-Host "Limpieza remota completada." -ForegroundColor White -BackgroundColor DarkGreen
                        }
                    }
                    Write-Host ""
                }

                "4.2" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminar Archivos Temporales ProgramData"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                        if ($null -ne $drive) {
                            Write-Host "Iniciando limpieza de ProgramData remota..." -ForegroundColor Yellow
                            
                            $excluir = @("*Microsoft*", "*Package Cache*", "*Antivirus*", "*SoftwareLicensing*", "*NVIDIA*")
                            
                            Write-Host " > Escaneando y eliminando temporales obsoletos..." -NoNewline
                            $targetPath = "${drive}:\ProgramData"
                            if (Test-Path $targetPath) {
                                Get-ChildItem -Path $targetPath -Recurse -File -Force -ErrorAction SilentlyContinue | 
                                Where-Object {
                                    $itemPath = $_.FullName
                                    $safe = $true
                                    foreach ($pattern in $excluir) {
                                        if ($itemPath -like $pattern) { $safe = $false; break }
                                    }
                                    $safe -and 
                                    ($_.Extension -match "\.(tmp|log|bak|old|chk|temp)$") -and 
                                    ($_.LastWriteTime -lt (Get-Date).AddDays(-7))
                                } | Remove-Item -Force -ErrorAction SilentlyContinue
                                Write-Host " [OK]" -ForegroundColor Green
                            }
                            else {
                                Write-Host " [Error: Ruta no encontrada]" -ForegroundColor Red
                            }
                            
                            Dismount-RemoteCShare -driveName $drive
                            Write-Host "Limpieza de ProgramData completada." -ForegroundColor White -BackgroundColor DarkGreen
                        }
                    }
                    Write-Host ""
                }

                "4.3" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Liberar RAM Remoto"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                        if ($null -ne $drive) {
                            Write-Host "Preparando ejecucion remota de optimizacion de RAM..." -ForegroundColor Yellow
                            
                            $remoteScriptContent = @'
$codigoC = "
    using System;
    using System.Runtime.InteropServices;
    public class RamUtil {
        [DllImport(\"psapi.dll\")]
        public static extern bool EmptyWorkingSet(IntPtr hProcess);
    }
"
if (-not ([System.Management.Automation.PSTypeName]"RamUtil").Type) {
    Add-Type -TypeDefinition $codigoC -ErrorAction SilentlyContinue
}
$procesos = [System.Diagnostics.Process]::GetProcesses()
$count = 0
foreach ($p in $procesos) {
    if ($p.Id -gt 4) {
        try {
            if ([RamUtil]::EmptyWorkingSet($p.Handle)) {
                $count++
            }
        } catch {}
    }
    if ($p) { $p.Dispose() }
}
Write-Output "Optimizado $count procesos."
'@
                            $remoteScriptPath = "${drive}:\Windows\Temp\clean_ram_remote.ps1"
                            try {
                                $remoteScriptContent | Out-File -FilePath $remoteScriptPath -Encoding ascii -Force -ErrorAction Stop
                                Write-Host "Script de limpieza copiado al equipo remoto." -ForegroundColor Green
                            }
                            catch {
                                Write-Host "[ERROR] No se pudo copiar el script de limpieza: $_" -ForegroundColor Red
                                Dismount-RemoteCShare -driveName $drive
                                break
                            }
                            
                            Dismount-RemoteCShare -driveName $drive
                            
                            $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\clean_ram_remote.ps1"
                            Write-Host "Ejecutando script de optimizacion en segundo plano..." -ForegroundColor Yellow
                            
                            try {
                                if ($null -ne $cred) {
                                    $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota -Credential $cred
                                }
                                else {
                                    $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota
                                }
                                
                                if ($result.ReturnValue -eq 0 -and $result.ProcessId) {
                                    $remotePid = $result.ProcessId
                                    Write-Host "Proceso remoto iniciado exitosamente (PID: $remotePid)." -ForegroundColor Green
                                    Write-Host "Esperando finalizacion..." -ForegroundColor Yellow
                                    
                                    $timeout = 20
                                    $elapsed = 0
                                    while ($elapsed -lt $timeout) {
                                        Start-Sleep -Seconds 1
                                        if ($null -ne $cred) {
                                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                                        }
                                        else {
                                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                                        }
                                        if ($null -eq $procCheck) { break }
                                        $elapsed++
                                    }
                                    Write-Host "Optimizacion finalizada en segundo plano." -ForegroundColor Green
                                    
                                    $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                                    if ($null -ne $drive) {
                                        Remove-Item -Path "${drive}:\Windows\Temp\clean_ram_remote.ps1" -Force -ErrorAction SilentlyContinue
                                        Dismount-RemoteCShare -driveName $drive
                                    }
                                }
                                else {
                                    Write-Host "[ERROR] El proceso remoto retorno un error: $($result.ReturnValue)" -ForegroundColor Red
                                }
                            }
                            catch {
                                Write-Host "[ERROR] Fallo la llamada WMI para crear el proceso: $_" -ForegroundColor Red
                            }
                        }
                    }
                    Write-Host ""
                }

                "4.4" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Liberar Procesador Remoto"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                        if ($null -ne $drive) {
                            Write-Host "Preparando ejecucion remota de optimizacion de CPU..." -ForegroundColor Yellow
                            
                            $remoteScriptContent = @'
$procesosPesados = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
$count = 0
foreach ($proc in $procesosPesados) {
    if ($proc.Name -ne "Idle" -and $proc.Name -ne "powershell") {
        try {
            $proc.PriorityClass = "BelowNormal"
            $count++
        } catch {}
    }
}
[System.GC]::Collect()
Write-Output "Ajustada prioridad para $count procesos pesados."
'@
                            $remoteScriptPath = "${drive}:\Windows\Temp\clean_cpu_remote.ps1"
                            try {
                                $remoteScriptContent | Out-File -FilePath $remoteScriptPath -Encoding ascii -Force -ErrorAction Stop
                                Write-Host "Script de optimizacion copiado al equipo remoto." -ForegroundColor Green
                            }
                            catch {
                                Write-Host "[ERROR] No se pudo copiar el script: $_" -ForegroundColor Red
                                Dismount-RemoteCShare -driveName $drive
                                break
                            }
                            
                            Dismount-RemoteCShare -driveName $drive
                            
                            $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\clean_cpu_remote.ps1"
                            Write-Host "Ejecutando script de optimizacion de CPU en segundo plano..." -ForegroundColor Yellow
                            
                            try {
                                if ($null -ne $cred) {
                                    $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota -Credential $cred
                                }
                                else {
                                    $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota
                                }
                                
                                if ($result.ReturnValue -eq 0 -and $result.ProcessId) {
                                    $remotePid = $result.ProcessId
                                    Write-Host "Proceso remoto iniciado exitosamente (PID: $remotePid)." -ForegroundColor Green
                                    Write-Host "Esperando finalizacion..." -ForegroundColor Yellow
                                    
                                    $timeout = 20
                                    $elapsed = 0
                                    while ($elapsed -lt $timeout) {
                                        Start-Sleep -Seconds 1
                                        if ($null -ne $cred) {
                                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                                        }
                                        else {
                                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                                        }
                                        if ($null -eq $procCheck) { break }
                                        $elapsed++
                                    }
                                    Write-Host "Optimizacion de CPU finalizada." -ForegroundColor Green
                                    
                                    $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                                    if ($null -ne $drive) {
                                        Remove-Item -Path "${drive}:\Windows\Temp\clean_cpu_remote.ps1" -Force -ErrorAction SilentlyContinue
                                        Dismount-RemoteCShare -driveName $drive
                                    }
                                }
                                else {
                                    Write-Host "[ERROR] El proceso remoto retorno un error: $($result.ReturnValue)" -ForegroundColor Red
                                }
                            }
                            catch {
                                Write-Host "[ERROR] Fallo la llamada WMI: $_" -ForegroundColor Red
                            }
                        }
                    }
                    Write-Host ""
                }

                "4.5" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Vaciar Papelera de Reciclaje"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                        if ($null -ne $drive) {
                            Write-Host "Vaciando Papelera de Reciclaje remota..." -ForegroundColor Yellow
                            
                            $recyclePath = "${drive}:\`$Recycle.Bin"
                            if (Test-Path $recyclePath) {
                                Write-Host " > Limpiando directorios de la papelera..." -NoNewline
                                Remove-Item -Path "$recyclePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                                Write-Host " [OK]" -ForegroundColor Green
                            }
                            else {
                                Write-Host "[AVISO] No se encontro la carpeta de la papelera ($recyclePath)." -ForegroundColor Yellow
                            }
                            
                            Dismount-RemoteCShare -driveName $drive
                            Write-Host "Papelera remota vaciada correctamente." -ForegroundColor White -BackgroundColor DarkGreen
                        }
                    }
                    Write-Host ""
                }

                "4.6" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminacion Avanzada (Todos los Usuarios)"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                        if ($null -ne $drive) {
                            Write-Host "Preparando ejecucion remota de limpieza profunda de temporales..." -ForegroundColor Yellow
                            
                            $remoteScriptContent = @'
$profilePaths = @()
try {
    # Obtener perfiles de usuario locales y de dominio
    $profiles = Get-WmiObject -Class Win32_UserProfile -Filter "Special=False" -ErrorAction Stop
    foreach ($p in $profiles) {
        if ($p.LocalPath -and (Test-Path $p.LocalPath)) {
            $profilePaths += $p.LocalPath
        }
    }
}
catch {
    # Fallback si WMI falla
    $fallbackPath = "C:\Users"
    if (Test-Path $fallbackPath) {
        $profilePaths = Get-ChildItem -Path $fallbackPath -Directory -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -notin "Default", "Default User", "All Users", "Public", "Publico" } | 
                        Select-Object -ExpandProperty FullName
    }
}

$filesDeleted = 0
$foldersDeleted = 0
$bytesFreed = 0
$errors = 0

function Clear-FolderContents {
    param([string]$FolderPath)
    if (-not (Test-Path $FolderPath)) { return }
    
    # Eliminar archivos y contar tamaño
    $items = Get-ChildItem -Path "$FolderPath\*" -Recurse -File -Force -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        $len = $item.Length
        try {
            Remove-Item -Path $item.FullName -Force -ErrorAction Stop
            $script:filesDeleted++
            $script:bytesFreed += $len
        }
        catch {
            $script:errors++
        }
    }
    
    # Eliminar carpetas recursivamente (de mas profunda a mas superficial)
    $dirs = Get-ChildItem -Path "$FolderPath\*" -Recurse -Directory -Force -ErrorAction SilentlyContinue |
            Sort-Object -Property @{Expression={$_.FullName.Length}} -Descending
    foreach ($dir in $dirs) {
        try {
            Remove-Item -Path $dir.FullName -Force -Confirm:$false -ErrorAction Stop
            $script:foldersDeleted++
        }
        catch {
            $script:errors++
        }
    }
}

# 1. Limpieza de perfiles de usuario (Locales y de Dominio)
foreach ($path in $profilePaths) {
    Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Temp")
    Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Microsoft\Windows\INetCache")
    Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Microsoft\Windows\Temporary Internet Files")
    Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\CrashDumps")
}

# 2. Limpieza de directorios del sistema
$systemPaths = @(
    "C:\Windows\Temp",
    "C:\Windows\Prefetch",
    "C:\Windows\SoftwareDistribution\Download"
)
foreach ($sysPath in $systemPaths) {
    Clear-FolderContents -FolderPath $sysPath
}

# Guardar resultados en un archivo simple
$outputPath = "C:\Windows\Temp\clean_temp_results.txt"
$report = @(
    "FilesDeleted=$filesDeleted",
    "FoldersDeleted=$foldersDeleted",
    "BytesFreed=$bytesFreed",
    "Errors=$errors"
)
$report | Out-File -FilePath $outputPath -Encoding ascii -Force
'@
                            $remoteScriptPath = "${drive}:\Windows\Temp\clean_temp_remote.ps1"
                            try {
                                $remoteScriptContent | Out-File -FilePath $remoteScriptPath -Encoding ascii -Force -ErrorAction Stop
                                Write-Host "Script de limpieza copiado al equipo remoto." -ForegroundColor Green
                            }
                            catch {
                                Write-Host "[ERROR] No se pudo copiar el script de limpieza al destino: $_" -ForegroundColor Red
                                Dismount-RemoteCShare -driveName $drive
                                break
                            }
                            
                            Dismount-RemoteCShare -driveName $drive
                            
                            $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\clean_temp_remote.ps1"
                            Write-Host "Ejecutando script de limpieza profunda en segundo plano..." -ForegroundColor Yellow
                            
                            try {
                                if ($null -ne $cred) {
                                    $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota -Credential $cred
                                }
                                else {
                                    $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota
                                }
                                
                                if ($result.ReturnValue -eq 0 -and $result.ProcessId) {
                                    $remotePid = $result.ProcessId
                                    Write-Host "Proceso remoto iniciado exitosamente (PID: $remotePid)." -ForegroundColor Green
                                    Write-Host "Realizando limpieza profunda (esto puede tardar unos momentos)..." -ForegroundColor Yellow
                                    
                                    $timeout = 300
                                    $elapsed = 0
                                    while ($elapsed -lt $timeout) {
                                        Start-Sleep -Seconds 2
                                        if ($null -ne $cred) {
                                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                                        }
                                        else {
                                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                                        }
                                        if ($null -eq $procCheck) { break }
                                        $elapsed += 2
                                        Write-Host "." -NoNewline
                                    }
                                    Write-Host ""
                                    
                                    # Volvemos a montar para leer resultados y limpiar archivos temporales creados
                                    $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
                                    if ($null -ne $drive) {
                                        $resultsPath = "${drive}:\Windows\Temp\clean_temp_results.txt"
                                        if (Test-Path $resultsPath) {
                                            $res = @{}
                                            Get-Content -Path $resultsPath | ForEach-Object {
                                                if ($_ -match "^([^=]+)=(.*)$") {
                                                    $res[$Matches[1]] = $Matches[2]
                                                }
                                            }
                                            
                                            $filesDeleted = [int]$res["FilesDeleted"]
                                            $foldersDeleted = [int]$res["FoldersDeleted"]
                                            $bytesFreed = [int64]$res["BytesFreed"]
                                            $errorsCount = [int]$res["Errors"]
                                            
                                            $totalMBLiberados = [Math]::Round($bytesFreed / 1MB, 2)
                                            
                                            Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                                            Write-Host "RESUMEN GLOBAL DE LIMPIEZA MULTI-USUARIO REMOTA (AVANZADA):" -ForegroundColor Cyan
                                            Write-Host "Total archivos eliminados: $filesDeleted" -ForegroundColor White
                                            Write-Host "Total carpetas eliminadas: $foldersDeleted" -ForegroundColor White
                                            Write-Host "Total espacio liberado:    $totalMBLiberados MB" -ForegroundColor Green
                                            Write-Host "Total errores/bloqueados:  $errorsCount" -ForegroundColor Yellow
                                            Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                                        }
                                        else {
                                            Write-Host "[ADVERTENCIA] No se pudo obtener el archivo de resultados remotos." -ForegroundColor Yellow
                                        }
                                        
                                        # Eliminar archivos creados
                                        Remove-Item -Path "${drive}:\Windows\Temp\clean_temp_remote.ps1" -Force -ErrorAction SilentlyContinue
                                        Remove-Item -Path "${drive}:\Windows\Temp\clean_temp_results.txt" -Force -ErrorAction SilentlyContinue
                                        Dismount-RemoteCShare -driveName $drive
                                    }
                                }
                                else {
                                    Write-Host "[ERROR] El proceso remoto retorno un error de inicio: $($result.ReturnValue)" -ForegroundColor Red
                                }
                            }
                            catch {
                                Write-Host "[ERROR] Fallo al invocar el metodo WMI: $_" -ForegroundColor Red
                            }
                        }
                    }
                    Write-Host ""
                }

                "30" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    Write-Host "`n[!] Reiniciando herramienta..." -ForegroundColor Cyan

                    # Si estamos en entorno de desarrollo, reconstruir primero
                    psReconstruirSiDesarrollo

                    # Start-Sleep -Milliseconds 500
                    Start-Sleep -Seconds 2
                    
                    # Recuperamos la ruta que guardamos en la cabecera .bat
                    $ruta = $env:SCRIPT_PATH
                    Write-Host "Ruta del Software:....... $ruta" -ForegroundColor Green
                    Start-Sleep -Seconds 3
                    
                    if ($ruta -and (Test-Path $ruta)) {
                        # Lanzamos el proceso usando CMD para que interprete el .bat correctamente
                        Start-Process cmd.exe -ArgumentList "/c `"$ruta`""
                        exit
                    }
                    else {
                        Write-Error "Error: No se pudo localizar la variable SCRIPT_PATH."
                        Pause
                    }
                }

                "31" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"
                    Write-Host "`n[!] Descargando y reiniciando desde repositorio remoto..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat | iex"
                    exit
                }
                
                "0" { 
                    # $salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 26: Presione ENTER para continuar..." }
        } # Cierra try
        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
        
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta despuÃ©s de cada opciÃ³n)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesiÃ³n para evitar errores de "cadena de entrada"
            # Mantenemos variables crÃ­ticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. PequeÃ±a pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.26*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.27 ******************************************************
#**********************************************************************************************************************************
