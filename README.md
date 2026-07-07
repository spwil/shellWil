# ShellSW - Soft. Administración y Gestión del Sistema Operativo

Herramienta híbrida (Batch + PowerShell) diseñada para optimizar, diagnosticar y administrar sistemas operativos Windows de forma rápida y centralizada a través de un menú interactivo en consola.

## 🧑‍💻 Autoría y Versión
* **Autor**: Ing. Wilson Yucra - spWil
* **Versión**: 1.7.0
* **Derechos**: Derechos Reservados © spWil

---

## 🚀 Requisitos para la Ejecución
Para que todas las funciones del script se ejecuten correctamente (como desfragmentación, reparación de imágenes de Windows con DISM, y administración de usuarios), debes iniciar la herramienta con **privilegios de Administrador**:

1. Haz clic derecho sobre el archivo `ShellSW.bat`.
2. Selecciona **Ejecutar como administrador**.

---

## 🛠️ Estructura de Funcionalidades

El script principal se divide en un **Menú Principal** y varios **Submenús Especializados**:

### 🔹 Menú Principal
* **Red y Conectividad**: Ver IP local, hacer ping continuo a servidores críticos, abrir Chrome en incógnito.
* **Mantenimiento y Rendimiento**: Desfragmentar unidades (HDD/SSD), eliminar archivos temporales (Temp, Prefetch, ProgramData), liberar memoria RAM y optimizar procesos pesados de CPU.
* **Reparación del Sistema**: Revisar discos con CHKDSK, quitar atributos restrictivos a unidades (ATTRIB) y reiniciar componentes de red.
* **Acceso Directo**: Administrador de tareas, CMD, PowerShell y restablecimiento de Internet Explorer.

### 🔸 Submenús Especializados
* **Submenú 20**: Información detallada de hardware (RAM/HDD), diagnóstico de salud con DISM y configuración IP.
* **Submenú 21**: Ventanas de administración nativas de Windows y accesos a Antivirus.
* **Submenú 22**: Servicios de Windows y Herramientas del Sistema Avanzadas.
* **Submenú 23**: Comandos avanzados en PowerShell y utilidades de reparación.
* **Submenú 24**: Comandos específicos optimizados para **Windows 11**.
* **Submenú 25**: Comandos de Red y Administración Remota de equipos.
* **Submenú 26**: Comandos administrativos para **Active Directory (AD)**.
* **Submenú 27**: Enlaces rápidos a utilidades en Internet (test de teclado, mouse, monitor, etc.).

---

## ⚙️ ¿Cómo funciona internamente?
El script utiliza una estructura **polyglot (híbrida)**:
1. El archivo se abre como un script `.bat` (Batch) convencional.
2. Inmediatamente ejecuta un cargador en PowerShell que lee el contenido del mismo archivo (`ShellSW.bat`) y lo interpreta como código de PowerShell puro.
3. Esto permite tener la versatilidad de PowerShell con la facilidad de ejecución de doble clic de un archivo Batch.
