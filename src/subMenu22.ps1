function psSubMenu22 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 22. ---)) LOCAL: SERVICIOS WINDOWS - HERRAMIENTAS AVANZADOS."
            Write-Host "  1. Ver estado Servicio Actualizacion Windows 7 en adelante."
            Write-Host "  2. Detener Servicio Actualizacion Windows 7 en adelante."
            Write-Host "  3. Iniciar Servicio Actualizacion Windows 10."
            Write-Host "  4. Agregar Registro Detener Actualizacion Windows."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  5. Abrir ventana de Administrador de Servicios de Windows."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  6. Herramienta de eliminacion de Software malintencionado."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  7. Pasos para restaurar indice de Windows."
            Write-Host "  8. Aplicaciones y procesos en la PC."
            Write-Host "     8.1 Cerrar aplicaciones de Usuario."
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "==========================================================="
            
            $op22 = Read-Host "Seleccione la tarea a realizar"

            switch ($op22) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # Configuración de codificación para evitar problemas con tildes en versiones antiguas
                    $OutputEncoding = [System.Text.Encoding]::UTF8

                    Write-Host "Este script verifica si los servicios de los cuales depende Windows Update estan corriendo" -ForegroundColor Cyan
                    Write-Host ""

                    # Pausa inicial (Equivalente a TIMEOUT /T 4)
                    Start-Sleep -Seconds 4

                    # Lista de servicios a verificar
                    # Nota: UsoSvc y WaasMedicSvc solo aparecerán en Windows 10/11
                    $servicios = @(
                        "BITS", 
                        "UsoSvc", 
                        "wuauserv", 
                        "WaasMedicSvc"
                    )

                    foreach ($nombreSvc in $servicios) {
                        # Intentamos obtener el servicio silenciosamente
                        $svc = Get-Service -Name $nombreSvc -ErrorAction SilentlyContinue
                        
                        if ($svc) {
                            # Si el servicio existe, mostramos su nombre real y su estado
                            $estado = $svc.Status.ToString().ToUpper()
                            
                            # Color diferenciador: Verde si corre, Rojo si está detenido
                            $color = if ($estado -eq "RUNNING") { "Green" } else { "Yellow" }
                            
                            Write-Host "Servicio: $($svc.DisplayName) ($nombreSvc)"
                            Write-Host "ESTADO: $estado" -ForegroundColor $color
                        }
                        else {
                            # Si el servicio no existe (como UsoSvc en Win 7)
                            Write-Host "Servicio: $nombreSvc - [NO INSTALADO EN ESTE SISTEMA]" -ForegroundColor Gray
                        }
                        
                        Write-Host ("-" * 30)
                        Start-Sleep -Seconds 2
                    }

                    Write-Host ""
                    Write-Host "-------------------------------------------------------" -ForegroundColor White
                    Write-Host "Si todo aca dice STOPPED o STOPPING, entonces SERVICIOS DETENIDOS" -ForegroundColor Cyan
                    Write-Host "-------------------------------------------------------"
                    Write-Host ""

                    # Write-Host "Presione una tecla para continuar . . ."
                    # $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                }
                "2" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificación de privilegios de Administrador (Compatible con PS v2.0+)
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                        Write-Host "ERROR: Este script DEBE ejecutarse como Administrador." -ForegroundColor Red
                        Write-Host "Haga clic derecho sobre el archivo y seleccione 'Ejecutar con PowerShell'."
                        Write-Host "Presione una tecla para salir..."
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        exit
                    }

                    Write-Host "--- DESACTIVACION DE SERVICIOS DE ACTUALIZACION ---" -ForegroundColor Cyan
                    Write-Host "Este script desactiva BITS, wuauserv y servicios de mantenimiento (Win10+)."
                    Write-Host "Presione CTRL+C en los proximos 10 segundos para cancelar..."

                    Start-Sleep -Seconds 10

                    # Lista de servicios y su ruta en el registro
                    # Nota: UsoSvc y WaasMedicSvc no existen en Win7, el script los saltará automáticamente.
                    $servicios = @("UsoSvc", "WaasMedicSvc", "BITS", "wuauserv")
                    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

                    Write-Host "`n[1/3] Modificando Registro para desactivar el inicio..." -ForegroundColor Yellow
                    foreach ($svcName in $servicios) {
                        $fullPath = "$registryPath\$svcName"
                        
                        if (Test-Path $fullPath) {
                            # Configurar Start = 4 (Deshabilitado)
                            Set-ItemProperty -Path $fullPath -Name "Start" -Value 4 -Force
                            Write-Host "OK: $svcName configurado como Deshabilitado."
                            
                            # Caso especial: Cambiar ObjectName a 'Guest' para bloquear ejecución (el 'truco' del original)
                            if ($svcName -eq "wuauserv") {
                                Set-ItemProperty -Path $fullPath -Name "ObjectName" -Value "Guest" -Force
                                Write-Host "CRITICO: Credenciales de $svcName cambiadas a 'Guest'." -ForegroundColor Cyan
                            }
                        }
                        else {
                            Write-Host "SKIP: $svcName no existe en este sistema (Normal en Windows 7)." -ForegroundColor Gray
                        }
                    }

                    Start-Sleep -Seconds 2

                    Write-Host "`n[2/3] Deteniendo servicios activos..." -ForegroundColor Yellow
                    foreach ($svcName in $servicios) {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($svc) {
                            if ($svc.Status -ne 'Stopped') {
                                Write-Host "Deteniendo $svcName..." -NoNewline
                                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                                Write-Host " [HECHO]" -ForegroundColor Green
                            }
                            else {
                                Write-Host "$svcName ya se encuentra detenido." -ForegroundColor Gray
                            }
                        }
                        Start-Sleep -Milliseconds 500
                    }

                    Write-Host "`n[3/3] Verificación final de estado:" -ForegroundColor Yellow
                    Write-Host "-------------------------------------------------------"
                    foreach ($svcName in $servicios) {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($svc) {
                            $color = if ($svc.Status -eq 'Stopped') { "Green" } else { "Red" }
                            Write-Host "Servicio: $($svcName.PadRight(15)) Estado: $($svc.Status)" -ForegroundColor $color
                        }
                    }
                    Write-Host "-------------------------------------------------------"
                    Write-Host "Si el estado es STOPPED, la operacion fue exitosa."
                    Write-Host "`nPresione cualquier tecla para continuar..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                }

                "3" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificación de privilegios de Administrador (Compatible PS v2.0+)
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                        Write-Host "ERROR: Este script DEBE ejecutarse como Administrador." -ForegroundColor Red
                        Write-Host "Haga clic derecho sobre el archivo y seleccione 'Ejecutar con PowerShell'."
                        Pause
                        exit
                    }

                    Clear-Host
                    Write-Host "--- RESTAURACIÓN DE SERVICIOS DE ACTUALIZACIÓN ---" -ForegroundColor Cyan
                    Write-Host "Restaurando permisos de ejecución e identidad LocalSystem..."
                    Write-Host "Presione CTRL+C en los próximos 10 segundos para cancelar..."

                    Start-Sleep -Seconds 10

                    # Lista de servicios a restaurar
                    $servicios = @("wuauserv", "UsoSvc", "BITS", "WaasMedicSvc")
                    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

                    Write-Host "`n[1/2] Restaurando identidad y tipo de inicio en el Registro..." -ForegroundColor Yellow

                    foreach ($svcName in $servicios) {
                        $fullPath = "$registryPath\$svcName"
                        
                        if (Test-Path $fullPath) {
                            # 1. Restaurar Identidad a 'LocalSystem' (fundamental para que el servicio arranque)
                            Set-ItemProperty -Path $fullPath -Name "ObjectName" -Value "LocalSystem" -Force
                            
                            # 2. Restaurar Inicio a '3' (Manual)
                            Set-ItemProperty -Path $fullPath -Name "Start" -Value 3 -Force
                            
                            Write-Host "OK: $svcName restaurado a LocalSystem y modo Manual." -ForegroundColor Green
                            Start-Sleep -Seconds 2
                        }
                        else {
                            Write-Host "SKIP: $svcName no existe en este sistema (ignorado)." -ForegroundColor Gray
                        }
                    }

                    Write-Host "`n[2/2] Finalizando..." -ForegroundColor Yellow
                    Write-Host "------------------------------------------------------------------------------------------"
                    Write-Host "LISTO, todo restaurado." -ForegroundColor White
                    Write-Host "ES NECESARIO REINICIAR el sistema para que los cambios de identidad surtan efecto." -ForegroundColor Red
                    Write-Host "Una vez reiniciada la PC, los servicios podrán arrancar cuando Windows los necesite."
                    Write-Host "------------------------------------------------------------------------------------------"

                    Write-Host "`nPresione cualquier tecla para continuar . . ."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    
                }
                
                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificacion de privilegios de Administrador
                    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
                    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

                    if (-not $currentPrincipal.IsInRole($adminRole)) {
                        Write-Host 'ERROR: Ejecute PowerShell como ADMINISTRADOR.' -ForegroundColor Red
                        Write-Host 'Presione una tecla para salir...'
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        exit
                    }

                    $regPath = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
                    Write-Host '--- FORZANDO DESACTIVACION DE ACTUALIZACIONES ---' -ForegroundColor Cyan

                    # Funcion para crear la clave y el valor
                    function Set-WindowsUpdatePolicy {
                        param($Name, $Value)
                        try {
                            $fullPath = "HKLM:\$regPath"
                            if (!(Test-Path $fullPath)) { 
                                New-Item -Path $fullPath -Force | Out-Null 
                            }
                            Set-ItemProperty -Path $fullPath -Name $Name -Value $Value -PropertyType 'DWord' -Force -ErrorAction 'Stop'
                            return $true
                        }
                        catch {
                            # Fallback a REG.EXE para maxima compatibilidad en Windows 7
                            $cmd = "reg add ""HKLM\$regPath"" /v $Name /t REG_DWORD /d $Value /f"
                            Invoke-Expression $cmd | Out-Null
                            return $?
                        }
                    }

                    # Aplicar las politicas
                    $items = @{ 'NoAutoUpdate' = 1; 'AUOptions' = 1 }

                    foreach ($key in $items.Keys) {
                        $val = $items[$key]
                        Write-Host "Configurando $key... " -NoNewline
                        if (Set-WindowsUpdatePolicy -Name $key -Value $val) {
                            Write-Host 'OK' -ForegroundColor Green
                        }
                        else {
                            Write-Host 'FALLO' -ForegroundColor Red
                        }
                    }

                    # 2. Refrescar las politicas del sistema
                    Write-Host 'Actualizando directivas de grupo...' -ForegroundColor Yellow
                    gpupdate /force | Out-Null

                    Write-Host '-------------------------------------------------------'
                    Write-Host 'PROCESO COMPLETADO' -ForegroundColor Cyan
                    Write-Host 'Si hubo fallos, revise si un antivirus bloquea el registro.'
                    Write-Host '-------------------------------------------------------'

                    
                }

                "5" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    Start-Process services.msc

                    Write-Host "Proceso ejecutado..."

                }
                "6" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    Start-Process mrt

                    Write-Host "Proceso ejecutado..."                    
                }
                
                "7" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # Titulo principal
                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host '    GUIA DE REPARACION: DISM CON FUENTE EXTERNA (WIM)' -ForegroundColor Cyan
                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host ' Realice estos pasos cuando "DISM /RestoreHealth" falle.' -ForegroundColor White
                    Write-Host ''

                    # Paso 1
                    Write-Host ' 1. MONTAR LA IMAGEN' -ForegroundColor Yellow
                    Write-Host '    Monte la imagen ISO de Windows en su sistema.'
                    Write-Host ''

                    # Paso 2
                    Write-Host ' 2. OBTENER INFORMACION DEL ARCHIVO WIM' -ForegroundColor Yellow
                    Write-Host '    Abra una terminal como administrador y ejecute:'
                    Write-Host '    dism /get-wiminfo /wimfile:N:\sources\install.wim' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''
                    Write-Host '    NOTA: Reemplace ' -NoNewline
                    Write-Host 'N:\sources\install.wim' -ForegroundColor Magenta -NoNewline
                    Write-Host ' con su ruta real.'
                    Write-Host '    En el listado, busque el INDICE que corresponde a su version de Windows.'
                    Write-Host ''

                    # Paso 3
                    Write-Host ' 3. EJECUTAR RESTAURACION CON FUENTE' -ForegroundColor Yellow
                    Write-Host '    Escriba el siguiente comando siguiendo este formato:'
                    Write-Host '    dism /online /cleanup-image /RestoreHealth /source:N:\sources\install.wim:6 /limitaccess' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''
                    Write-Host '    IMPORTANTE REVISAR:' -ForegroundColor Red
                    Write-Host '    * El numero de INDICE (al final de la ruta, ej: :6)'
                    Write-Host '    * La ruta exacta donde esta el archivo.'
                    Write-Host '    * La extension (.wim o .esd).'
                    Write-Host ''

                    # Paso final
                    Write-Host ' 4. VERIFICACION FINAL' -ForegroundColor Yellow
                    Write-Host '    Al terminar, ejecute el comando para reparar archivos de sistema:'
                    Write-Host '    sfc /scannow' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''

                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host ' '
                    
                    #$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

                }

                "8.1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # ==============================================================================
                    # Script: Monitor_Aplicaciones_Mejorado.ps1
                    # Compatibilidad: Windows 7, 8.1, 10, 11 (PowerShell 2.0+)
                    # Mejora: Opción de salida explícita y cancelación de cierre.
                    # ==============================================================================

                    Write-Host "Analizando aplicaciones abiertas con ventana activa..." -ForegroundColor Yellow
                    Write-Host ""

                    # 1. Obtener procesos con ventana principal
                    $procesosUsuario = Get-Process | Where-Object { $_.MainWindowTitle -ne "" }

                    $reporteApps = foreach ($p in $procesosUsuario) {
                        $ramMB = [Math]::Round($p.WorkingSet64 / 1MB, 2)
                        
                        New-Object PSObject -Property @{
                            ID         = $p.Id
                            Aplicacion = $p.ProcessName
                            Ventana    = if ($p.MainWindowTitle.Length -gt 45) { $p.MainWindowTitle.Substring(0, 42) + "..." } else { $p.MainWindowTitle }
                            RAM_MB     = $ramMB
                        }
                    }

                    # 2. Mostrar tabla de aplicaciones
                    $reporteApps | Select-Object ID, Aplicacion, RAM_MB, Ventana | 
                    Sort-Object RAM_MB -Descending | 
                    Format-Table -AutoSize

                    Write-Host ""
                    Write-Host "--- GESTION DE PROCESOS ---" -ForegroundColor Cyan
                    Write-Host "Opciones: Ingrese el [PID] para cerrar, o la letra [S] para Salir sin cambios." -ForegroundColor White

                    # 3. Interacción con opción de salida mejorada
                    $entrada = Read-Host "Seleccione una opcion"

                    # Validar si el usuario quiere salir (Letra S o vacío)
                    if ($entrada -eq "S" -or $entrada -eq "s" -or $entrada -eq "") {
                        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
                    } 
                    # Validar si la entrada es un número (PID)
                    elseif ($entrada -match '^\d+$') {
                        try {
                            $target = Get-Process -Id $entrada -ErrorAction Stop
                            Stop-Process -Id $entrada -Force
                            Write-Host "La aplicacion '$($target.ProcessName)' (PID: $entrada) ha sido cerrada." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error: No se encontro el PID o acceso denegado." -ForegroundColor Red
                        }
                    } 
                    else {
                        Write-Host "Entrada no valida. No se realizaron cambios." -ForegroundColor Red
                    }

                    # 4. Cierre del script (estándar de compatibilidad)
                    Write-Host ""
                    Write-Host "Saliendo del programa..." -ForegroundColor Gray
                    Start-Sleep -Seconds 2

                    Write-Host "Proceso ejecutado..."                    
                }
                
                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch
            if (-not $salirSub) { 
                Read-Host "SUB_MENU 22: Presione ENTER para continuar..." 
            }
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

#************************************************* FIN SUB MENU.22*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.23 ******************************************************
#**********************************************************************************************************************************
