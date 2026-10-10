# INFORME TÉCNICO: ESTADO DEL PROYECTO, MIGRACIÓN A GOOGLE DRIVE Y ACCESIBILIDAD MULTI-PC

**Proyecto:** ShellSW / shellWil (Herramienta de Administración y Gestión del S.O.)  
**Autor:** Ing. Wilson Yucra  
**Fecha de Revisión:** 10 de Octubre de 2026  
**Nueva Ubicación:** `H:\Mi unidad\ProyectosIA\shellWil` (Google Drive Sincronizado)  
**Repositorio GitHub:** `https://github.com/spwil/shellWil.git`  
**Estado General:** 🟢 **OPERATIVO Y COMPATIBLE**

---

## 1. RESUMEN EJECUTIVO

Se ha completado una revisión exhaustiva de todo el proyecto tras su reubicación a la unidad sincronizada de Google Drive (`H:\Mi unidad\ProyectosIA\shellWil`). 

El objetivo principal de esta migración es **permitir el desarrollo y ejecución del proyecto en otra PC mediante Antigravity**, manteniendo la capacidad de publicación en GitHub mediante la **Opción 1010** y garantizando la estabilidad operativa del script ejecutable `ShellSW.bat`.

### Resumen de Pruebas Realizadas:
| Componente / Prueba | Estado | Observación |
| :--- | :---: | :--- |
| **Sintaxis de Código PowerShell (AST)** | 🟢 APROBADO | Los 11 módulos en `src/` no contienen errores de sintaxis. |
| **Motor de Compilación (`build.ps1`)** | 🟢 APROBADO | Ensambla correctamente los módulos en `ShellSW.bat`. |
| **Credenciales de GitHub (Push / Remote)** | 🟢 APROBADO | Verificado con `git ls-remote` y `git push --dry-run` (Exit Code 0). |
| **URL Remota de Descarga Directa** | 🟢 APROBADO | `https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat` responde HTTP 200 OK. |
| **Detección Dinámica de Rutas** | 🟢 APROBADO | Se eliminaron rutas absolutas fijas (`E:\...`); ahora se resuelven dinámicamente. |
| **Soporte Google Drive en Opción 1010** | 🟢 OPTIMIZADO | Detección ampliada de bloqueos (`*.lock`) y normalización de `safe.directory`. |

---

## 2. REVISIÓN Y VALIDACIÓN DE CREDENCIALES GITHUB (OPCIÓN 1010)

La Opción 1010 (`MODO DESARROLLADOR: PUBLICAR EN GITHUB`) fue auditada y probada:

1. **Estado de Autenticación Actual:**
   - La PC actual cuenta con las credenciales registradas en el Administrador de Credenciales de Windows bajo el destino `git:https://github.com` asociado al usuario `spwil`.
   - La prueba en seco (`git push --dry-run origin main`) confirmó acceso total de escritura sin rechazo de permisos.
   - El origen remoto está configurado correctamente en `.git/config`:
     ```ini
     [remote "origin"]
         url = https://github.com/spwil/shellWil.git
         fetch = +refs/heads/*:refs/remotes/origin/*
     [user]
         name = Wilson Yucra Juan
         email = wyucra@gmsantacruz.gov.bo
     ```

2. **Comportamiento en la Segunda PC (Punto Crítico):**
   > [!IMPORTANT]
   > Las credenciales de Windows Credential Manager **NO se sincronizan a través de Google Drive** por motivos de seguridad del sistema operativo (están cifradas con el DPAPI del usuario local).
   
   **Cuando abra el proyecto por primera vez en la otra PC:**
   - El repositorio ya tendrá configurado el usuario y correo (`user.name` y `user.email`) porque residen en `.git/config`.
   - Sin embargo, para hacer `push` mediante la Opción 1010 en la segunda PC, Git requerirá autenticación.
   - Se optimizó la Opción 1010 en `src/menuPrincipal.ps1` para que, en caso de fallo de autenticación en la otra PC, muestre instrucciones exactas para iniciar sesión con `git-credential-manager`.

---

## 3. ANÁLISIS DE RUTAS Y DIRECCIÓN URL DEL PROYECTO

### 3.1. Rutas Locales vs. Multi-PC
El cambio de ruta a `H:\Mi unidad\ProyectosIA\shellWil` introduce dos factores clave que fueron corregidos:
1. **Espacios en la ruta ("Mi unidad"):**
   Toda invocación en consola o script batch debe mantener comillas dobles (`"$path"`). Los scripts de arranque ya cuentan con este soporte mediante `"%~f0"` y `"$env:SCRIPT_PATH"`.
2. **Diferencias de letra de unidad entre PCs:**
   - En una PC, Google Drive puede asignarse como `H:`.
   - En otra PC, Google Drive suele montarse como `G:`, `D:`, o incluso como ruta relativa de carpeta sincronizada (`C:\Users\<Usuario>\Google Drive\Mi unidad\...`).
   - **Solución implementada:** Ningún script del proyecto depende de la letra `H:`. Todas las funciones resuelven su ubicación mediante:
     ```powershell
     $scriptDir = if ($env:SCRIPT_PATH) { Split-Path $env:SCRIPT_PATH } elseif ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
     ```

### 3.2. Rutas URL Web y del Repositorio
* **URL de Publicación:** `https://github.com/spwil/shellWil` (Rama `main`).
* **URL Raw para descarga y auto-actualización (Opción 31):**  
  `https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat`  
  *Verificación:* Se ejecutó una petición HTTP HEAD a esta URL obteniendo código **200 OK**.
* **Enlaces Internos de Documentación:**  
  Se corrigieron los enlaces absolutos con esquema `file:///e:/ProyectosIA/...` dentro de `Varios/informe_herramientas_similares_y_mejoras.md`, cambiándolos a enlaces relativos markdown (`../src/...`, `../build.ps1`), garantizando que funcionen tanto en Windows, Google Drive o GitHub web.

---

## 4. ADAPTACIÓN AL ENTORNO GOOGLE DRIVE

Trabajar con un repositorio Git dentro de una carpeta sincronizada en la nube presenta desafíos específicos que han sido blindados:

### 4.1. Prevención de Bloqueos (`*.lock`)
Cuando Git realiza operaciones (`add`, `commit`, `checkout`), crea archivos temporales como `.git/index.lock` o `.git/refs/heads/main.lock`. En unidades sincronizadas, el agente de Google Drive intenta leer o subir esos archivos instantáneamente, lo que puede causar que Git lance el error `Unable to create '.git/index.lock': File exists`.
- **Mejora aplicada en Opción 1010:** Ahora se escanean recursivamente **todos** los archivos `*.lock` en `.git/` y se ofrece al desarrollador liberarlos automáticamente con confirmación.

### 4.2. Registro de Directorio Seguro (`safe.directory`)
En Windows, cuando una herramienta se ejecuta como Administrador en una unidad virtual de red o sincronizada, Git 2.35.2+ bloquea el acceso reportando `dubious ownership`.
- **Mejora aplicada:** La Opción 1010 ahora normaliza la ruta con barras estándar (`/`) y la registra automáticamente en `git config --global safe.directory` sin duplicar entradas.

### 4.3. Reglas de Exclusión en `.gitignore`
Se añadieron reglas de exclusión para evitar que Google Drive y Antigravity interfieran con el versionado:
```gitignore
# Google Drive y metadatos de sincronización
desktop.ini
*.tmp.drivedownload
* - Copia.*
* - copia.*
* (1).*
*.gdoc
*.gsheet
*.gslides

# Entorno de desarrollo local Antigravity
.gemini/
```

---

## 5. NUEVAS SUGERENCIAS Y RECOMENDACIONES TÉCNICAS

Para maximizar la productividad y evitar pérdidas de datos al trabajar en dos PCs con Antigravity y Google Drive, se sugieren las siguientes mejores prácticas:

### 💡 Sugerencia 1: Flujo de Trabajo Recomendado entre las dos PCs
Aunque Google Drive sincroniza archivos automáticamente, el motor de Git `.git` está diseñado para sistemas de archivos locales directos. 
* **Regla de oro:** No mantengas ambas PCs con Antigravity o el script abierto simultáneamente modificando código al mismo tiempo, ya que Google Drive podría generar copias de conflicto en la base de objetos de Git (`.git/objects/`).
* **Mejor práctica:**
  1. En la **PC 1**: Realiza tus cambios, prueba con `build.ps1` y publica con la **Opción 1010**.
  2. En la **PC 2**: Antes de empezar a trabajar, verifica que Google Drive indique *"Los archivos están actualizados"* o ejecuta `git pull origin main`.

### 💡 Sugerencia 2: Configuración de Google Drive en modo "Archivos Disponibles sin Conexión"
En Google Drive para Computadoras existen dos modalidades:
- **Transmisión de archivos (Streaming):** Los archivos se descargan bajo demanda en un disco virtual. Puede generar lentitud o desconexiones en compilaciones pesadas.
- **Duplicar archivos (Mirroring):** Los archivos existen localmente en el disco duro y se sincronizan en segundo plano.
> **Recomendación:** Haz clic derecho sobre la carpeta `shellWil` en el explorador de Windows, ve a **Acceso sin conexión** y selecciona **Disponible sin conexión**. Esto asegura que todos los módulos de `src/` respondan de forma instantánea sin latencia de red.

### 💡 Sugerencia 3: Submódulo de Chequeo de Salud al Iniciar el Menú Desarrollador
Agregar una pequeña función de autodiagnóstico en la Opción 1010 que verifique:
1. Conectividad a `github.com`.
2. Estado de sincronización local (si no hay archivos de bloqueo pendientes).
3. Si la rama local está detrás del remoto (`git fetch; git status`).

### 💡 Sugerencia 4: Estandarización de la Carpeta de Reportes y Logs
Actualmente el módulo desacoplado `AuditoriaNavegadores.ps1` guarda logs en `C:\shellWil\logs`. Se sugiere parametrizar esta ruta para que use preferentemente `$env:ProgramData\ShellSW\logs` o cree una subcarpeta `logs/` dentro del directorio de trabajo cuando se ejecute de forma autónoma.

---

## 6. CONCLUSIÓN

El proyecto `shellWil` se encuentra en un estado **óptimo y robusto**. Todas las funcionalidades originales se mantienen 100% operativas, la auto-compilación con `build.ps1` funciona con alta velocidad y la Opción 1010 ha sido enriquecida para operar con total transparencia en entornos sincronizados con Google Drive y en múltiples equipos con Antigravity.
