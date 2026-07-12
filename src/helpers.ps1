
<#
.SYNOPSIS
    Script de mantenimiento optimizado con correccion de sintaxis.
#>

function psLimpiarRAM {
    Write-Host "`n******* OPTIMIZACION DE RAM *******" -ForegroundColor Cyan
    
    # Definimos el codigo C# como una cadena simple para evitar el error de 'Atributo inesperado'
    $codigoC = "
        using System;
        using System.Runtime.InteropServices;
        public class RamUtil {
            [DllImport(`"psapi.dll`")]
            public static extern bool EmptyWorkingSet(IntPtr hProcess);
        }
    "

    # Cargamos el tipo solo si no existe
    if (-not ([System.Management.Automation.PSTypeName]"RamUtil").Type) {
        Add-Type -TypeDefinition $codigoC -ErrorAction SilentlyContinue
    }

    try {
        $procesos = [System.Diagnostics.Process]::GetProcesses()
        foreach ($p in $procesos) {
            if ($p.Id -gt 4) { # Omitimos Idle y System
                try {
                    [RamUtil]::EmptyWorkingSet($p.Handle) | Out-Null
                } catch {}
            }
            if ($p) { $p.Dispose() }
        }
        Write-Host "RAM optimizada correctamente." -ForegroundColor Green
    } catch {
        Write-Host "Error al optimizar." -ForegroundColor Red
    }
}

function Write-Header {
    param([string]$texto)
    
    $ancho = $texto.Length + 15
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "$linea" -ForegroundColor Yellow
}

function menuOpcion {
    param([string]$texto)
    
    $ancho = $texto.Length + 5
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor Black -BackgroundColor Yellow
    Write-Host "$linea" -ForegroundColor Yellow
}

#****************************************************** CABECERA ******************************************************************
function cabecera {

    Clear-Host
    $Host.UI.RawUI.WindowTitle = "Bienvenido: $env:COMPUTERNAME\$env:USERNAME ;; Copyright  spWil Derechos Reservados ;; Version 1.8.0"
    $os = Get-WmiObject Win32_OperatingSystem
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $fecha = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

    # Datos de ejecucion
    Write-Host " SO: $($os.Caption) ; Version S.O.: $($os.Version)"  -ForegroundColor Cyan
    Write-Host " Usuario: $user  ;  Fecha:   $fecha"  -ForegroundColor Cyan
    Write-Host " Ing. Wilson Yucra - Soft. Administracion y Gestion del Sistema Operativo" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------------------------------"  -ForegroundColor Cyan
}
#************************************************** FIN CABECERA ******************************************************************

function psReconstruirSiDesarrollo {
    $ruta = $env:SCRIPT_PATH
    if ($ruta) {
        # Resolver el directorio padre
        $parentDir = Split-Path $ruta
        $buildScript = Join-Path $parentDir "build.ps1"
        if (Test-Path $buildScript) {
            Write-Host "`n[DEV] Entorno de desarrollo detectado." -ForegroundColor Yellow
            Write-Host "[DEV] Ejecutando build.ps1 para actualizar ShellSW.bat..." -ForegroundColor Yellow
            try {
                # Iniciar la reconstrucción de forma síncrona
                $p = Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$buildScript`"" -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -eq 0) {
                    Write-Host "[DEV] Reconstruccion completa y exitosa." -ForegroundColor Green
                } else {
                    Write-Host "[DEV] Error en la reconstruccion (Codigo de salida: $($p.ExitCode))." -ForegroundColor Red
                }
            } catch {
                Write-Host "[DEV] Fallo al ejecutar el script de ensamblado: $_" -ForegroundColor Red
            }
        }
    }
}

#******************************************************** SUB MENU.20 *************************************************************
#**********************************************************************************************************************************

