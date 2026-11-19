# ESTADO_PROYECTO.md — Memoria y Bitácora de Continuidad

> **Propósito:** Este archivo es la memoria central del proyecto `shellWil`. Permite que cualquier miembro del equipo o el asistente de Inteligencia Artificial (Antigravity) conozca exactamente en qué estado se encuentra el desarrollo, qué fue lo último que se hizo y cómo retomar el trabajo sin perder tiempo al escribir **`RECUERDAME`**.

---

## 📌 1. Ficha del Proyecto
* **Proyecto:** `shellWil` ([repositorio GitHub](https://github.com/spwil/shellWil.git))
* **Autor / Responsable:** Ing. Wilson Yucra Juan (`wyucra@gmsantacruz.gov.bo`)
* **Objetivo:** Suite integral y portable de administración, soporte técnico, auditoría y mantenimiento del Sistema Operativo Windows para Helpdesk.
* **Arquitectura:**
  - Código fuente modular en `src/` ([helpers.ps1](src/helpers.ps1), [menuPrincipal.ps1](src/menuPrincipal.ps1), [subMenu20.ps1](src/subMenu20.ps1) a [subMenu28.ps1](src/subMenu28.ps1)).
  - Script de ensamblado automático: [build.ps1](build.ps1).
  - Binario ejecutable compilado: [ShellSW.bat](ShellSW.bat).

---

## 🕒 2. Última Sesión de Trabajo
* **Fecha:** 19 de Noviembre de 2026
* **Hito Completado:** **Gestión y Clasificación de Procesos Remotos en Submenú 28 (Opciones 7.2 y 7.3 en `src/subMenu28.ps1` y `src/helpers.ps1`)**.
* **Cambios Clave Realizados:**
  1. **Incorporación de la Opción 7.2 en Submenú 28 (`psListarProcesosRemotos`):**
     - Permite listar procesos remotos o locales con selector para filtrar:
       - `[1]` Procesos y aplicaciones del **Usuario Final** (Sesión interactiva `SessionId > 0`, títulos de ventana, apps ofimáticas/navegadores).
       - `[2]` Procesos del **Sistema Operativo y Servicios** (`SessionId = 0`, svchost, drivers, background).
       - `[3]` **Todos los procesos** ordenados por consumo de Memoria RAM (WorkingSet en MB).
       - `[4]` **Todos los procesos** ordenados por consumo/tiempo de CPU.
       - `[5]` Búsqueda en tiempo real por nombre de proceso o título (ej: `chrome`, `excel`, `siaf`).
     - Atajos interactivos: `[K]` Matar proceso por PID directamente desde el visor, `[R]` Refrescar lista.
     - Formato de tabla alineada con métricas en MB, PID, Nombre, Usuario/Sesión y Título de ventana.
  2. **Incorporación de la Opción 7.3 en Submenú 28 (`psFinalizarProcesoRemoto`):**
     - Permite forzar el cierre de procesos en la PC remota especificando PID numérico o Nombre (`.exe`).
     - Validación previa de existencia del proceso con detalle de memoria consumida.
     - Confirmación de seguridad explícita antes de forzar el cierre.
     - Cierre redundante: Intento 1 vía WinRM/WMI (`.Terminate()`) con fallback a `taskkill /S /F`.
  3. **Compatibilidad Multi-Versión y Multi-Entorno:**
     - Conexión primaria ultra-rápida vía **WinRM** (`Get-Process -IncludeUserName`), con fallback automático a **WMI `Win32_Process`** (compatible desde Windows 7 hasta Windows 11).
     - Soporte transparente para equipos en Dominio (SSO Kerberos) y en Grupo de Trabajo / Workgroup (`.\admin` NTLM).
  4. **Compilación y verificación:**
     - Análisis sintáctico AST Parser verificado con 0 errores en todos los módulos.
     - Binario compilado y verificado con `build.ps1` -> [ShellSW.bat](ShellSW.bat).

---

## 📍 3. ¿En qué punto nos hemos quedado?
El grupo **"7. Consola Remota"** en [src/subMenu28.ps1](src/subMenu28.ps1) cuenta ahora con la suite completa de Consola Interactiva (7.1), Listado y Clasificación de Procesos (7.2) y Terminación de Procesos Remotos (7.3). Compilado y listo en [ShellSW.bat](ShellSW.bat).

* **Estado de Git:** Rama `main`, cambios listos en `ShellSW.bat`, `src/helpers.ps1`, `src/subMenu28.ps1` y `ESTADO_PROYECTO.md`.
* **Próxima acción técnica:** Probar las opciones en `ShellSW.bat` -> opción `28` -> grupo `7`:
  * `7.1`: Conexión directa PowerShell interactiva.
  * `7.2`: Listado de procesos con filtro Usuario / Sistema.
  * `7.3`: Finalización remota de procesos por PID o Nombre.
* **Publicación:** Cuando desees sincronizar a GitHub, usa la opción oculta `1010` en el menú principal.

---

## 🚀 4. Guía para Continuar (Paso a Paso)

### Si estás en la PC 2 (o en una máquina distinta a donde se programó):
1. Abre `ShellSW.bat` (o tu terminal).
2. En el menú, escribe **`1011`** y presiona Enter.
3. El sistema descargará todo lo nuevo desde GitHub, auto-compilará [ShellSW.bat](ShellSW.bat) y te preguntará si deseas reiniciar para cargar los cambios.
4. *(Solo la primera vez en PC 2)* Si te pide credenciales de GitHub, ejecuta:
   ```powershell
   git config --global credential.helper manager
   ```

### Si vas a continuar programando o agregando módulos:
1. Edita los módulos en la carpeta `src/`.
2. Para probar tus cambios en caliente o recompilar, ejecuta:
   ```powershell
   .\build.ps1
   ```
3. Al terminar la sesión, escribe **`1010`** en el menú de ShellSW (o ejecuta commit y push) para que la otra PC reciba tus avances.

---

## 📋 5. Tareas Pendientes y Roadmap Sugerido
- [x] Sincronización multi-PC automatizada (Opciones 1010 y 1011).
- [x] Ocultamiento de opciones de desarrollo en el menú por seguridad.
- [x] Documentación de sincronización y bitácora de memoria (`RECUERDAME`).
- [x] Opción 6: Gestión de Símbolos SIAF-SICE multi-capa en Submenú 28.
- [x] Opción 7: Consola Remota PowerShell Interactiva (WinRM + WMI auto-enable + PsExec fallback).
- [x] Optimización Opción 100: Captura de pantalla remota con SSO por defecto y caché de credenciales en Submenú 25.
- [x] Suite Completa de Monitoreo Remoto: Clip continuo de 15 segundos (GIF nativo .NET) y RDP Shadowing en tiempo real (mstsc /shadow).
- [ ] Probar flujo completo de bajada en la PC secundaria mediante la opción `1011`.
- [ ] Revisión periódica de submódulos de administración según requerimientos del equipo de Helpdesk.
