function psSubMenu26 {
    # Detección y fallback de Active Directory usando ADSI (LDAP nativo sin RSAT)
    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        Write-Host "[INFO] Modulo ActiveDirectory (RSAT) no detectado. Cargando emulacion LDAP nativa..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500

        # Declarar funciones de compatibilidad
        function Get-ADUser {
            param(
                [Parameter(Position=0, Mandatory=$true)]
                [string]$Identity,
                [Parameter(Position=1)]
                [string[]]$Properties
            )
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                
                # Función para traducir fechas de LargeInteger
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
                    } catch {}
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
                $prop["ObjectGUID"] = (if ($entry.Guid) { [Guid]$entry.Guid } else { $null })
                $prop["SID"] = (if ($entry.Properties["objectSid"].Value) { 
                    (New-Object System.Security.Principal.SecurityIdentifier($entry.Properties["objectSid"].Value, 0)).Value 
                } else { $null })

                $uac = $entry.Properties["userAccountControl"].Value
                $prop["Enabled"] = (if ($uac) { -not ($uac -band 2) } else { $true })
                $prop["PasswordExpired"] = (if ($uac) { [bool]($uac -band 0x800000) } else { $false })
                $prop["PasswordNeverExpires"] = (if ($uac) { [bool]($uac -band 0x10000) } else { $false })

                $prop["PasswordLastSet"] = $entry.Properties["pwdLastSet"].Value | Get-ADDate
                $prop["AccountExpirationDate"] = $entry.Properties["accountExpires"].Value | Get-ADDate
                
                $lastLogonVal = $entry.Properties["lastLogonTimestamp"].Value
                if ($null -eq $lastLogonVal) { $lastLogonVal = $entry.Properties["lastLogon"].Value }
                $prop["LastLogonDate"] = $lastLogonVal | Get-ADDate

                $managerDN = $entry.Properties["manager"].Value
                $prop["Manager"] = (if ($managerDN) { ($managerDN -split ',')[0].Replace('CN=','') } else { $null })

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
                [Parameter(Mandatory=$true)]
                [string]$Identity,
                [Parameter(Mandatory=$true)]
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
            } else {
                throw "No se pudo encontrar al usuario '$Identity' en el dominio."
            }
        }

        function Set-ADUser {
            param(
                [Parameter(Mandatory=$true)]
                [string]$Identity,
                [bool]$ChangePasswordAtLogon
            )
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                if ($ChangePasswordAtLogon) {
                    $entry.Properties["pwdLastSet"].Value = 0
                } else {
                    $entry.Properties["pwdLastSet"].Value = -1
                }
                $entry.CommitChanges()
            } else {
                throw "No se pudo encontrar al usuario '$Identity' en el dominio."
            }
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
                        "Description",    # Descripción
                        "Title",          # Cargo / Puesto
                        "Office",         # Oficina (PhysicalDeliveryOfficeName)
                        "Department",     # Área / Departamento
                        "Manager",        # Dependencia (Jefe Directo)
                        "OfficePhone",    # Teléfono
                        "PostalCode",     # Código Postal
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
                        # 2. Obtener datos básicos y última conexión del AD
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
                                StartTime = $hoy.AddDays(-7) # Últimos 7 días
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

                        # 3. Determinar lógica de expiración de cuenta
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

                    # 2. Solicitar la contraseña de forma segura (Asteriscos)
                    # Usamos un bloque try/catch para manejar errores de permisos o de usuario no encontrado
                    try {
                        Write-Host "Preparando cambio de contrasenia para: $usuarioAD" -ForegroundColor Cyan
                        
                        # Captura la contraseña de forma segura (AsSecureString oculta la entrada)
                        $NuevaContrasenia = Read-Host "Introduzca la nueva contrasenia para $usuarioAD" -AsSecureString

                        # 3. Aplicar el cambio (Equivalente a Reset de Administrador)
                        Set-ADAccountPassword -Identity $usuarioAD -NewPassword $NuevaContrasenia -Reset
                        
                        # 4. Forzar que el usuario cambie la contraseña en el próximo inicio de sesión (Opcional pero recomendado)
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
                        # 2. Obtención de datos extendidos
                        # Agregamos: Enabled (Estado), Office (Oficina) y Description (Descripción)
                        $user = Get-ADUser -Identity $dato -Properties LastLogonDate, MemberOf, AccountExpirationDate, Title, Department, PasswordLastSet, Enabled, Office, Description

                        if ($user) {
                            Write-Host "`n====================================================" -ForegroundColor Cyan
                            Write-Host "   REPORTE DETALLADO DE SEGURIDAD: $($user.Name)"
                            Write-Host "====================================================" -ForegroundColor Cyan

                            # --- NUEVO APARTADO: DATOS DE FILIACIÓN ---
                            Write-Host "[*] DATOS GENERALES:" -ForegroundColor Yellow
                            $estado = if ($user.Enabled) { "ACTIVO" } else { "DESHABILITADO" }
                            Write-Host "    Estado Usuario: $estado"
                            Write-Host "    Oficina:        $($user.Office)"
                            Write-Host "    Descripcion:    $($user.Description)"
                            Write-Host "    Cargo:          $($user.Title)"
                            Write-Host "    Area/Depto:     $($user.Department)"

                            # --- APARTADO: ULTIMO CAMBIO DE CONTRASEÑA ---
                            Write-Host "`n[*] FECHA ULTIMO CAMBIO DE CONTRASENIA:" -ForegroundColor Yellow
                            if ($user.PasswordLastSet) { 
                                Write-Host "    $($user.PasswordLastSet)" 
                            }
                            else { 
                                Write-Host "    El usuario nunca ha cambiado su contrasenia." 
                            }
                            
                            # --- APARTADO: CONEXIÓN Y ESTADO ---
                            Write-Host "`n[*] ULTIMA CONEXION ESTABLECIDA:" -ForegroundColor Yellow
                            if ($user.LastLogonDate) { 
                                Write-Host "    $($user.LastLogonDate)" 
                            }
                            else { 
                                Write-Host "    Nunca ha iniciado sesión o el dato no se ha replicado." 
                            }

                            # --- APARTADO: EXPIRACIÓN DE CUENTA ---
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

                            # --- APARTADO: MEMBRESÍA DE GRUPOS ---
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

                    # 1. Definición del segmento de red base
                    $baseIP = "192.168.176."

                    # 2. Captura del último OCTETO con validación simple
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    if ($hostID -match '^\d{1,3}$') {
                        $fullIP = $baseIP + $hostID
                        Write-Host "`n--- Consultando Host: $fullIP ---" -ForegroundColor Cyan
                        
                        try {
                            # 3. Ejecución optimizada de quser (query user)
                            # Redirigimos el error 2 al flujo de éxito para procesar el texto de "No hay usuarios"
                            $resultado = quser /server:$fullIP 2>&1

                            # 4. Procesamiento de la respuesta
                            if ($resultado -like "*No hay ningún usuario*" -or $resultado -like "*No user exists*") {
                                Write-Host "Estado: Equipo encendido, pero sin sesiones activas." -ForegroundColor Cyan
                            }
                            elseif ($resultado -like "*Error*") {
                                Write-Host "Error: No se pudo establecer conexion RPC con $fullIP." -ForegroundColor Red
                                Write-Host "Verifique que el equipo esté en línea y el Firewall permita RPC." -ForegroundColor Gray
                            }
                            else {
                                # Limpiamos líneas vacías y mostramos la tabla de quser
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

                    # 1. Configuración del segmento
                    $segmento = "192.168.176."
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    # Validar que la entrada sea numérica
                    if ($hostID -match '^\d{1,3}$') {
                        $targetIP = $segmento + $hostID
                        Write-Host "`n--- Buscando recursos compartidos en: $targetIP ---" -ForegroundColor Yellow

                        try {
                            # 2. Uso de Get-WmiObject para máxima compatibilidad (Win7 en adelante)
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
                                Write-Host "No se encontraron carpetas compartidas (públicas) en este equipo." -ForegroundColor Cyan
                            }
                        }
                        catch {
                            Write-Host "ERROR: No se pudo conectar a $targetIP." -ForegroundColor Red
                            Write-Host "Causas posibles: Equipo apagado, IP incorrecta o Firewall bloqueando WMI/RPC." -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "Entrada invalida. Ingrese solo números." -ForegroundColor Red
                    }

                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan

                }

                "3.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # ==============================================================================
                    #   HERRAMIENTA REMOTA DE GESTIÓN DE USUARIOS LOCALES (GMSANTACRUZ)
                    #   Compatibilidad: Windows 7 hasta Windows 11
                    # ==============================================================================

                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "     GESTOR DE USUARIOS LOCALES REMOTOS           " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan

                    do {
                        # 1. Construcción de la Dirección IP
                        Write-Host "--- Estructura de Red ---\n" -ForegroundColor White
                        $ultimoOcteto = Read-Host "Ingrese el ULTIMO octeto para el segmento 192.168.176.xxx"
                        
                        # Validación básica de entrada numérica
                        if ($ultimoOcteto -notmatch '^\d+$' -or [int]$ultimoOcteto -lt 1 -or [int]$ultimoOcteto -gt 254) {
                            Write-Host "[ERROR] El octeto ingresado no es valido." -ForegroundColor Red
                            break
                        }
                        
                        $ipRemota = "192.168.176.$ultimoOcteto"
                        Write-Host "Conectando a: $ipRemota..." -ForegroundColor Yellow

                        # 2. Manejo opcional de credenciales de Dominio
                        $opcionCred = Read-Host "¿Desea usar credenciales de un usuario de Dominio? (SI/NO)"
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
                            # Conexión al contenedor de la máquina remota
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

                        # 4. Selección del usuario al que se le cambiará la contraseña
                        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
                        $usuarioSeleccionado = Read-Host "Ingrese el NOMBRE del usuario local a modificar"
                        
                        # Validar que el usuario ingresado exista en el listado previo
                        $existeUsuario = $listaVisual | Where-Object { $_."Nombre de Usuario".ToUpper() -eq $usuarioSeleccionado.ToUpper() }

                        if (-not $existeUsuario) {
                            Write-Host "[ERROR] El usuario '$usuarioSeleccionado' no pertenece a las cuentas locales de la PC remota." -ForegroundColor Red
                            break
                        }

                        # 5. Ingreso y cambio de la nueva contraseña
                        $nuevaPassword = Read-Host "Ingrese la NUEVA CONTRASENIA para el usuario ($usuarioSeleccionado)"
                        $confirmarPassword = Read-Host "Confirme la NUEVA CONTRASENIA"

                        if ($nuevaPassword -ne $confirmarPassword) {
                            Write-Host "[ERROR] Las contrasenias no coinciden. Operacion cancelada." -ForegroundColor Red
                            break
                        }

                        # 6. Aplicar el cambio de contraseña de forma remota
                        try {
                            Write-Host "`nAplicando cambios en el sistema remoto..." -ForegroundColor Yellow
                            
                            # Obtener el objeto ADSI específico del usuario seleccionado
                            if ($usarCredenciales) {
                                $username = $credenciales.UserName
                                $password = $credenciales.GetNetworkCredential().Password
                                $usuarioObj = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$ipRemota/$usuarioSeleccionado,user", $username, $password)
                            }
                            else {
                                $usuarioObj = [ADSI]"WinNT://$ipRemota/$usuarioSeleccionado,user"
                            }

                            # Invocar el método nativo .SetPassword() de la API de Windows
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
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.26*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.27 ******************************************************
#**********************************************************************************************************************************
