function menuPrincipal {
    Clear-Host
    $salirPrincipal = $false

    # 1. Validacion de privilegios de Administrador
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "ERROR: Debes ejecutar este script como ADMINISTRADOR." -ForegroundColor Red
        Pause
        exit
    }

    do {
        try {
            #cabecera con informacion del autor
            cabecera

            Write-Header " ATENCION: ESTA HERRAMIENTA REALIZA CAMBIOS EN EL SISTEMA OPERATIVO"
            #Write-Host "======================================================================" -ForegroundColor Cyan -BackgroundColor Black
            Write-Host "  1.  Hostname e IP" -ForegroundColor Green
            Write-Host "  3.  Desfragmentar Unidad C: (Principal)" -ForegroundColor DarkCyan
            Write-Host "  4.  Desfragmentar Otras Unidades (HDD)"
            Write-Host "    4.1 Optimizar Unidades de SSD (alternativa a defrag)."
            Write-Host "  5.  Eliminar Archivos Temporales S.O." -ForegroundColor DarkCyan

            Write-Host "  7.  Resetear Internet Explorer"
            Write-Host "  9.  Abrir Internet Explorer con Topacio"
            Write-Host "  10. Ping Infraestructura"
            Write-Host "  11. Revisar Unidades (CHKDSK) - Reparar, localizar y desmontar - chkdsk.exe /F /R /X." -ForegroundColor DarkCyan
            Write-Host "  12. Mostrar Todo el Contenido de UNIDAD (ATTRIB)."
            Write-Host "  13. Abrir Google CHROME con Buscador (Modo Incognito)."
            Write-Host "  14. Abrir Propiedades de INTERNET EXPLORER."
            Write-Host "  15. Cerrar Proceso Explorer.exe (explorer)." -ForegroundColor DarkCyan
            Write-Host "  16. Abrir Proceso Explorer.exe (explorer)."
            Write-Host "  17. Abrir Administrador de Tareas (taskmgr)."
            Write-Host "  18. Abrir Simbolo de SISTEMA (cmd)."
            Write-Host "  19. Abrir PowerShell Administrador"
            Write-Host "  20. ---)) LOCAL: INFORMACION SISTEMA CMD [RAM] [HDD] - DISM - RESETEAR RED."
            Write-Host "  21. ---)) LOCAL: VENTANAS ADMINISTRACION WINDOWS - ANTIVIRUS."
            Write-Host "  22. ---)) LOCAL: SERVICIOS WINDOWS - HERRAMIENTAS AVANZADOS."
            Write-Host "  23. ---)) LOCAL: HELPDESK LOCAL - HERRAMIENTAS DE SISTEMA." -ForegroundColor Green
            Write-Host "  24. ***)) LOCAL: COMANDOS WINDOWS 11 *****"
            Write-Host "  25. +++)) AD: COMANDOS RED - ADMINISTRACION REMOTA +++++" -ForegroundColor Cyan
            Write-Host "  26. ===)) AD: COMANDOS AD =====" -ForegroundColor Cyan
            Write-Host "  27. ###)) ONLINE: Herramientas en INTERNET #####"
            Write-Host "  28. ---)) AD: GESTION HELPDESK -----" -ForegroundColor Cyan
            Write-Host "  29. ***)) LOCAL: APAGADO Y REINICIADO DE PC *****"
            Write-Host "    29.1 Apagar PC." -ForegroundColor Green
            Write-Host "    29.2 Reiniciar Sistema Operativo (shutdown)." -ForegroundColor Green
            Write-Host "  30. REFRESH (Modo LOCAL)."
            Write-Host "  31. REFRESH desde GitHub (Online)." -ForegroundColor Cyan
            Write-Host "  0.  Salir"
            Write-Host "======================================================================" -ForegroundColor Yellow
            
            Write-Host $header -ForegroundColor Cyan

            # 3. Bucle Principal

            $opcion = Read-Host "Seleccione una opcion"

            switch ($opcion) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion (Hostname e IP)"

                    # 1. Obtener Hostname
                    $hostname = [System.Net.Dns]::GetHostName()
                    
                    # 2. Obtener adaptadores de red activos
                    $interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
                    
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "                  INFORMACION DE RED                       " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "  Nombre del Equipo (Hostname): " -NoNewline
                    Write-Host "$hostname" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "  --- Adaptadores de Red Detectados ---" -ForegroundColor Yellow
                    Write-Host ""

                    $hayAdaptadorActivo = $false

                    foreach ($adapter in $interfaces) {
                        # Solo procesar adaptadores activos/conectados que no sean de loopback
                        if ($adapter.OperationalStatus -eq "Up" -and $adapter.NetworkInterfaceType -ne "Loopback") {
                            $properties = $adapter.GetIPProperties()
                            
                            # Obtener IPs
                            $ips = @()
                            foreach ($unicast in $properties.UnicastAddresses) {
                                if ($unicast.Address.AddressFamily -eq "InterNetwork") {
                                    $ips += $unicast.Address.ToString()
                                }
                            }

                            if ($ips.Count -gt 0) {
                                $hayAdaptadorActivo = $true
                                Write-Host "  [+] Adaptador: " -NoNewline
                                Write-Host $adapter.Description -ForegroundColor Cyan
                                Write-Host "      Estado:    " -NoNewline
                                Write-Host "Conectado / Activo" -ForegroundColor Green
                                Write-Host "      Tipo:      " -NoNewline
                                Write-Host $adapter.NetworkInterfaceType
                                Write-Host "      IP(s):     " -NoNewline
                                Write-Host ($ips -join ", ") -ForegroundColor Yellow

                                # Obtener Puerta de Enlace (Gateway)
                                $gateways = @()
                                foreach ($gateway in $properties.GatewayAddresses) {
                                    $gateways += $gateway.Address.ToString()
                                }
                                if ($gateways.Count -gt 0) {
                                    Write-Host "      Gateway:   " -NoNewline
                                    Write-Host ($gateways -join ", ") -ForegroundColor Gray
                                }

                                # Obtener Servidores DNS
                                $dnsServers = @()
                                foreach ($dns in $properties.DnsAddresses) {
                                    if ($dns.AddressFamily -eq "InterNetwork") {
                                        $dnsServers += $dns.ToString()
                                    }
                                }
                                if ($dnsServers.Count -gt 0) {
                                    Write-Host "      DNS:       " -NoNewline
                                    Write-Host ($dnsServers -join ", ") -ForegroundColor Green
                                } else {
                                    Write-Host "      DNS:       " -NoNewline
                                    Write-Host "No configurados" -ForegroundColor DarkGray
                                }
                                Write-Host ""
                            }
                        }
                    }

                    if (-not $hayAdaptadorActivo) {
                        Write-Host "  No se detectaron adaptadores de red activos con IPv4 configurada." -ForegroundColor Red
                    }

                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""
                }
                "3" { 
                    # clear-Host 
                    cabecera
                    menuOpcion "Haz elegido la opcion:  $opcion"

                    Write-Host "Desfragmentando C:..." -ForegroundColor Green
                    DEFRAG.exe C:\ /B /U /V /H
                    # El parámetro /B en el comando defrag se usa para realizar una optimización de arranque
                    Write-Host " "
                }
                "4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # $u = Read-Host "Letra de unidad (ej. D:)"
                    # if ($u) { defrag $u /U /V } 
                        
                    fsutil fsinfo drives
                    powershell.exe Get-Volume
                    $unit = Read-Host "Letra de la unidad a desfragmentar y presiona ENTER"
                    DEFRAG.exe /U /O /V /H ${unit}":"
                        
                    # /A /U /V /H
                        
                    #Read-Host "Presione Enter para volver..."
                    Write-Host " "
                }

                "4.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    fsutil fsinfo drives
                    # powershell.exe Get-WmiObject Win32_LogicalDisk
                    powershell.exe Get-Volume
                    Write-Host ""
                    $unidad = Read-Host "Letra de la unidad a desfragmentar y presiona ENTER"
                    Optimize-Volume -DriveLetter ${unidad} -ReTrim -Verbose
                        
                    Write-Host " "
                }
                "5" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    Write-Host "Iniciando Liberador de espacio (Configuracion 64)..." -ForegroundColor Yellow
                    try {
                        # Ejecuta el proceso de limpieza
                        Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:64" -Wait
                        Write-Host "Limpieza completada con exito." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error al ejecutar Cleanmgr." -ForegroundColor Red
                    }
                        
                    Write-Host " "
                }

                "7" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process iexplore.exe
                    taskkill.exe /F /IM iexplore.exe /T

                    # Limpiar todo (Equivalente a 255)
                    Write-Host "Iniciado limpieza de todo lo (Equivalente a 255)"
                    Start-Process "rundll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 255" -Wait
                    Write-Host " [OK]" -ForegroundColor Green

                    # Limpiar datos específicos incluyendo complementos (Equivalente a 4351)
                    Write-Host "Iniciado limpieza de datos específicos incluyendo complementos (Equivalente a 4351)"
                    Start-Process "rundll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 4351" -Wait
                    Write-Host " [OK]" -ForegroundColor Green

                    Start-Process "rundll32.exe" -ArgumentList "inetcpl.cpl,ResetIEtoDefaults" -Wait
                    Write-Host "Proceso de restablecimiento finalizado." -ForegroundColor Green

                    Write-Host ""

                }

                "9" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        

                    Write-Host "Iniciando IE..." -ForegroundColor Yellow
                    Start-Process -FilePath "C:\Program Files\Internet Explorer\iexplore.exe" -ArgumentList "https://topacioprod.gmsantacruz.gob.bo/"

                    Write-Host ""

                }
                "10" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # Definimos las IPs y sus etiquetas en una tabla para facilitar cambios
                    $destinos = @(
                        @{Nombre = "DNS Google 1 - 8.8.8.8"; IP = "8.8.8.8" },
                        @{Nombre = "Bolivianita - 192.168.13.249"; IP = "192.168.13.249" },
                        @{Nombre = "Berilo 1 - 192.168.13.243"; IP = "192.168.13.243" },
                        @{Nombre = "Berilo 2 - 192.168.13.36"; IP = "192.168.13.36" },
                        @{Nombre = "SRV H. PLAN - 192.168.176.254"; IP = "192.168.176.254" },
                        @{Nombre = "DNS 1 GAM - 172.25.108.100"; IP = "172.25.108.100" },
                        @{Nombre = "DNS 2 GAM - 192.168.13.214"; IP = "192.168.13.214" }
                    )

                    Write-Host "Iniciando monitoreo de red en ventanas independientes..." -ForegroundColor Cyan

                    foreach ($item in $destinos) {
                        # Ejecutamos CMD, le pasamos el título y el comando Ping infinito (-t)
                        Start-Process cmd.exe -ArgumentList "/c title $($item.Nombre) && ping $($item.IP) -t"
                    }

                        
                    Write-Host ""

                }
                "10.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    $ip = Read-Host "IP/Host para Ping"

                    if ($ip) {
                        # start: abre nueva ventana
                        # cmd /k: ejecuta el comando y mantiene la ventana abierta
                        # ping -t: ping continuo en CMD
                        Start-Process cmd.exe "/k ping $ip -t"
                    }

                    Write-Host ""
                }
                "11" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    # 1. Mostrar información de las unidades de forma legible
                    Write-Host "--- UNIDADES DETECTADAS ---" -ForegroundColor Cyan
                    Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, 
                    @{Name = "Tipo"; Expression = { $_.Description } }, 
                    @{Name = "Tamaño(GB)"; Expression = { [Math]::Round($_.Size / 1GB, 2) } } | Format-Table -AutoSize

                    # 2. CAPTURA DE DATO: Solicitar la letra de la unidad
                    $letra = Read-Host "Escribe la letra de la unidad a REVISAR (ejemplo: D)"

                    # Limpiar la entrada (por si el usuario escribió "D:" o "d ")
                    $unidad = $letra.Replace(":", "").Trim().ToUpper()

                    # 3. Validación y ejecución
                    if (-not [string]::IsNullOrWhiteSpace($unidad) -and $unidad.Length -eq 1) {
                            
                        $pathUnidad = "${unidad}:"
                        Write-Host "Preparando CHKDSK para la unidad $pathUnidad..." -ForegroundColor Yellow
                        Write-Host "Nota: Si la unidad está en uso, se solicitara programar para el proximo reinicio." -ForegroundColor Gray

                        # Ejecución de chkdsk con los parámetros originales
                        # /F (Corregir), /R (Recuperar sectores), /X (Forzar desmontaje)
                        chkdsk.exe $pathUnidad /F /R /X
                    }
                    else {
                        Write-Host "Error: Letra de unidad no valida." -ForegroundColor Red
                    }                

                    Write-Host ""
                }
                "12" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # 1. Mostrar información de las unidades de forma profesional
                    Write-Host "--- UNIDADES DISPONIBLES ---" -ForegroundColor Cyan
                    Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, Description | Format-Table -AutoSize

                    # 2. CAPTURA DE DATO: Solicitar la letra de la unidad
                    $letraInput = Read-Host "Escribe la letra de la UNIDAD para quitar atributos"
                    $unidad = $letraInput.Replace(":", "").Trim().ToUpper() + ":\"

                    # 3. Validación de existencia
                    if (Test-Path $unidad) {
                        Write-Host "`nQuitando atributos (Solo lectura, Sistema, Oculto) en $unidad..." -ForegroundColor Yellow
                            
                        # Buscamos todos los archivos y carpetas de forma recursiva
                        $elementos = Get-ChildItem -Path $unidad -Recurse -Force -ErrorAction SilentlyContinue

                        foreach ($item in $elementos) {
                            try {
                                # Establecemos los atributos a "Normal" (equivale a quitar R, S, H, A)
                                Set-ItemProperty -Path $item.FullName -Name Attributes -Value "Normal"
                            }
                            catch {
                                # Algunos archivos del sistema pueden estar bloqueados, los ignoramos
                                continue
                            }
                        }
                            
                        Write-Host "Proceso completado en $unidad" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Error: La unidad $unidad no existe o no es válida." -ForegroundColor Red
                    }

                    Write-Host ""
                }
                "13" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "chrome.exe" -ArgumentList "--incognito"

                    Write-Host ""
                }
                "14" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    Start-Process "control.exe" -ArgumentList "inetcpl.cpl"

                    Write-Host ""
                }
                "15" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "taskkill.exe" -ArgumentList "/F /IM explorer.exe" -NoNewWindow -Wait

                    Write-Host ""
                }
                "16" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "explorer.exe"               

                    Write-Host ""
                }

                "17" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process taskmgr

                    Write-Host ""
                }

                "18" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process cmd

                    Write-Host ""
                }

                "19" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "PowerShell.exe"

                    Write-Host ""
                }

                "20" { 
                    # Llamada a submenu.20
                    psSubMenu20
                }
                "21" { 
                    # Llamada a submenu.21
                    psSubMenu21
                }
                "22" { 
                    # Llamada a submenu.22
                    psSubMenu22
                }
                "23" { 
                    # Llamada a submenu.23
                    psSubMenu23
                }
                "24" { 
                    # Llamada a submenu.24
                    psSubMenu24
                }
                "25" { 
                    # Llamada a submenu.25
                    psSubMenu25
                }
                "26" { 
                    # Llamada a submenu.26
                    psSubMenu26
                }
                "27" { 
                    # Llamada a submenu.27
                    psSubMenu27
                }
                "28" {
                    # Llamada a submenu.28
                    psSubMenu28
                }
                
                "29.1" {
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "shutdown.exe" -ArgumentList "/s /f /t 5"

                    Write-Host ""
                        
                }
                "29.2" {
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "shutdown.exe" -ArgumentList "/g /f /t 5"

                    Write-Host ""
                        
                }
                "30" {
                    cabecera
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
                    Write-Host "`n[!] Descargando y reiniciando desde repositorio remoto..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat | iex"
                    exit
                }

                "1010" {
                    cabecera
                    menuOpcion "MODO DESARROLLADOR: PUBLICAR EN GITHUB (Opcion 1010)"
                    
                    # 1. Resolver ruta del repositorio
                    $repoPath = if ($env:SCRIPT_PATH) { Split-Path $env:SCRIPT_PATH } else { $PSScriptRoot }
                    if (-not $repoPath) { $repoPath = Get-Location }

                    # 2. Detección técnica estricta de entorno de desarrollo
                    $esDesarrollo = $false
                    $gitPath = Get-Command git -ErrorAction SilentlyContinue
                    
                    if ($gitPath -and (Test-Path (Join-Path $repoPath ".git"))) {
                        Push-Location $repoPath
                        try {
                            $remoteUrl = git remote get-url origin 2>$null
                            # Validamos que el origin coincida con el repositorio del proyecto
                            if ($remoteUrl -like "*spwil/shellWil*") {
                                $esDesarrollo = $true
                            }
                        }
                        finally {
                            Pop-Location
                        }
                    }

                    if (-not $esDesarrollo) {
                        Write-Host "`n[INFO] Esta opcion solo esta disponible en el entorno de desarrollo autorizado." -ForegroundColor Yellow
                        Write-Host "No se detecto la carpeta local de Git o el repositorio origin correcto." -ForegroundColor Gray
                        Write-Host ""
                    }
                    else {
                        # 3. Auto-compilación automática
                        Write-Host "`n[*] Iniciando auto-compilacion del script unificado (build.ps1)..." -ForegroundColor Cyan
                        psReconstruirSiDesarrollo

                        # 4. Mostrar resumen de cambios
                        Push-Location $repoPath
                        try {
                            Write-Host "`n[*] Resumen de archivos modificados para subir:" -ForegroundColor Yellow
                            $gitStatus = git status -s
                            if ([string]::IsNullOrEmpty($gitStatus)) {
                                Write-Host "No hay cambios pendientes de confirmacion en el repositorio." -ForegroundColor Green
                                Pop-Location
                                return
                            }
                            Write-Host $gitStatus -ForegroundColor Gray
                            Write-Host ""

                            # 5. Solicitar descripción del commit
                            $desc = Read-Host "Ingrese la descripcion para el commit (Mensaje de Git)"
                            if ([string]::IsNullOrEmpty($desc)) {
                                Write-Host "`n[!] Operacion cancelada: El mensaje de commit no puede estar vacio." -ForegroundColor Red
                                Pop-Location
                                return
                            }

                            # 6. Confirmación de seguridad
                            $confirmar = Read-Host "¿Proceder con la actualizacion en GitHub? (S/N) [N]"
                            if ($confirmar -notmatch "^[sS]$") {
                                Write-Host "`n[!] Operacion cancelada por el usuario." -ForegroundColor Yellow
                                Pop-Location
                                return
                            }

                            # 7. Ejecución de Git
                            Write-Host "`n[*] Agregando archivos al area de preparacion (git add -A)..." -ForegroundColor Gray
                            git add -A
                            
                            Write-Host "[*] Confirmando cambios localmente (git commit)..." -ForegroundColor Gray
                            $commitResult = git commit -m "$desc" 2>&1
                            Write-Host $commitResult -ForegroundColor Gray

                            # Detectar rama activa actual dinámicamente
                            $activeBranch = git branch --show-current
                            if ([string]::IsNullOrEmpty($activeBranch)) {
                                $activeBranch = "main" # fallback
                            }

                            Write-Host "[*] Subiendo cambios a GitHub en la rama '$activeBranch' (git push)..." -ForegroundColor Yellow
                            $pushResult = git push origin $activeBranch 2>&1
                            
                            # Comprobar código de salida
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "`n[OK] ¡Repositorio de GitHub actualizado exitosamente en la rama '$activeBranch'!" -ForegroundColor Green
                            } else {
                                Write-Host "`n[ERROR] Ocurrio un problema al subir los cambios." -ForegroundColor Red
                                Write-Host "Detalle del error:" -ForegroundColor Red
                                Write-Host $pushResult -ForegroundColor Gray
                            }
                        }
                        catch {
                            Write-Host "`n[ERROR NO ESPERADO] Error al interactuar con Git: $_" -ForegroundColor Red
                        }
                        finally {
                            Pop-Location
                        }
                    }
                    Write-Host ""
                }

                "0" { 
                    #$salirPrincipal = $true 
                    Write-Host "C E R R A N D O   A P L I C A C I O N  ..." -ForegroundColor Magenta

                    Write-Host "La tarea ha finalizado. La consola se cerrara en 3 segundos..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 3

                    # Comando para cerrar
                    exit
                }

                Default { 
                    Write-Host "OPCION INVALIDO." -ForegroundColor Red 
                    Start-Sleep -Seconds 1
                }
            } # Cierra switch
            if (-not $salirSub) { Read-Host "MENU PRINCIPAL: Presione ENTER para continuar..." }
        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."            
        } # Cierra catch

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

    } while (-not $salirPrincipal)
}
#************************************************* FIN PRINCIPAL ******************************************************************
#**********************************************************************************************************************************

