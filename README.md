# FanHub — Core Database & Transactional Engine (SQL Server)

Arquitectura relacional, motor transaccional en **T-SQL** y módulo de inteligencia de negocios (BI) para **FanHub**, una plataforma SaaS de monetización de contenido por suscripción de alto tráfico.

Este proyecto abarca desde el modelado conceptual Entidad-Relación Extendido (EER) hasta la implementación física de la base de datos, automatización de reglas de negocio críticas mediante *Stored Procedures* y *Triggers*, carga masiva de datos (*Data Seeding*) y reportería analítica financiera y de retención.

---

## Aspectos Técnicos Destacados (Key Highlights)

* **Modelado Relacional Normalizado (16 Tablas):** Implementación de jerarquías de herencia (especialización solapada para roles `Usuario`/`Creador` y disjunta para contenido multimedia `Video`, `Texto`, `Imagen`), entidades débiles para facturación histórica y relaciones autorreferenciales (recursivas) para hilos de comentarios anidados.
* **Procesamiento Transaccional (ACID):** Uso de transacciones explícitas (`BEGIN TRAN`, `COMMIT`, `ROLLBACK`) y manejo de excepciones para garantizar la atomicidad en procesos críticos como el alta de suscripciones, emisión de facturas y etiquetado dinámico de publicaciones.
* **Seguridad e Integridad en el Motor:** Implementación de *Triggers* preventivos para auditoría antifraude en cambios bruscos de precios y control de acceso por mayoría de edad a contenido restringido (NSFW).
* **Business Intelligence & Analytics:** Batería de 14 consultas analíticas complejas optimizadas con CTEs, funciones de agregación, lógica condicional (`CASE`) y operadores de conjuntos (`INTERSECT`, `NOT EXISTS`) para métricas de *Churn Rate*, *Market Share*, liquidación de nómina y viralidad.

---

## Arquitectura del Esquema de Datos

El esquema físico está estructurado en cuatro dominios funcionales con integridad referencial estricta y restricciones de dominio (`CHECK`, `UNIQUE`, `DEFAULT`):

1. **Identidad y Perfiles:** `Usuario`, `Creador`, `Categoria`, `MetodoPago`.
2. **Suscripciones y Facturación (FinTech):** `NivelSuscripcion`, `Suscripcion`, `Factura` (manejo financiero con precisión `DECIMAL(10,2)` y validación de estados de ciclo de vida: `Activa`, `Cancelada`, `Vencida`).
3. **Gestión de Contenido (CMS):** `Publicacion` (entidad supertipo) y tablas especializadas `Video` (con control de resoluciones `144p` a `4K`), `Texto` e `Imagen`.
4. **Interacción Social y Taxonomía:** `Comentario` (relación recursiva `idComentarioPadre`), `TipoReaccion` (soporte Unicode `NVARCHAR` para códigos de reacción), `Usuario_Reaccion_Publicacion`, `Etiqueta` y `Publicacion_Etiqueta`.

---

## Lógica de Negocio y Programabilidad (T-SQL)

Toda la capa de reglas de negocio reside en `Programmability.sql`, desacoplando la lógica transaccional crítica de la capa de aplicación:

### Procedimientos Almacenados (Stored Procedures)
* **`sp_crear_suscripcion`**: Valida la inexistencia de suscripciones activas duplicadas entre el fan y el creador, congela el `precio_pactado` según la tarifa vigente del nivel y genera automáticamente la factura inicial dentro de una transacción atómica.
* **`sp_dashboard_creador`**: Endpoint analítico que retorna múltiples conjuntos de resultados (*Result Sets*) en una sola ejecución para un rango de fechas:
  1. Resumen de KPIs (ingresos totales y captación de nuevos suscriptores).
  2. Top 5 seguidores con mayor *engagement* (reacciones + comentarios).
  3. Publicación de mayor rendimiento en el período.
* **`sp_publicar_con_etiquetas`**: Registra una publicación en su tabla especializada correspondiente, parsea dinámicamente cadenas de etiquetas separadas por comas, inserta nuevas etiquetas si no existen en el catálogo y construye las relaciones muchos-a-muchos de forma transaccional.
* **`sp_generar_factura_pago`**: Automatiza el ciclo de renovación y cobro, calculando subtotales, impuestos mediante UDF y generando un identificador único trazable (`YYYYMMDD-IDUsuario-IDSuscripcion-IDNivel-IDCreador`).

### Funciones Definidas por el Usuario (UDFs)
* **`fn_calcular_impuesto`**: Cálculo parametrizado del IVA (16%) sobre operaciones de facturación.
* **`fn_clasificar_ingreso`**: Segmentación automática de creadores en *tiers* comerciales (`Diamante`, `Oro`, `Plata`) según su volumen de facturación mensual.
* **`fn_calcular_reputacion`**: Algoritmo de *scoring* (escala 0–100) basado en suscriptores activos, volumen de interacciones del último mes y antigüedad de la cuenta.

### Triggers de Auditoría y Cumplimiento (Compliance)
* **Control Antifraude de Precios (`NivelSuscripcion`):** Intercepta actualizaciones de tarifas e impide incrementos o reducciones superiores al 50% respecto al precio previo, evitando errores humanos o manipulaciones abruptas de cobro.
* **Verificación de Edad NSFW (`Suscripcion`):** Evalúa en tiempo real la bandera `es_nsfw` del creador frente a la `fecha_nacimiento` del suscriptor, abortando la transacción si un menor de 18 años intenta suscribirse a contenido para adultos.

---

## Módulo de Inteligencia de Negocios (`Queries.sql`)

Consultas de extracción de métricas listas para integración con herramientas de visualización o paneles administrativos:

* **Finanzas y Liquidación:**
  * *Reporte de Nómina (Payouts):* Cálculo de ingresos brutos del mes en curso, retención de comisión de la plataforma (20%) y monto neto a liquidar por cuenta bancaria.
  * *Mapa de Calor Financiero:* Facturación total por país y cálculo dinámico de participación de mercado global (*Share %*) mediante CTEs.
  * *Clasificación de Ganancias:* Ranking mensual de facturación y suscriptores activos por creador.
* **Retención y Comportamiento del Usuario:**
  * *Análisis de Churn:* Promedio de días de retención previo a la cancelación, jerarquizado por creador y nivel de suscripción.
  * *Intereses Cruzados:* Identificación de usuarios de alto valor (gasto histórico > $140 USD) suscritos simultáneamente a nichos disjuntos (`Tecnología` ∩ `Fitness`) usando `INTERSECT`.
  * *Segmentación Demográfica:* Agrupación por cohortes generacionales (*Gen Z*, *Millennials*, *Gen X*) y cálculo de ticket promedio mensual.
  * *Detección de Usuarios Inactivos (Lurkers):* Suscriptores de pago activos sin registro de interacciones (`NOT EXISTS`).
* **Rendimiento de Contenido e Infraestructura:**
  * *Estimación de Almacenamiento (Cloud Storage):* Proyección de peso en Gigabytes (GB) del catálogo de video de creadores *Gaming* según duración y tasa de transferencia por resolución (`4K`, `1080p`, etc.).
  * *Viralidad y Tendencias:* Publicación líder por categoría según puntaje ponderado `(Reacciones * 1.5) + (Comentarios * 3)`, detección de creadores polémicos (ratio comentarios/reacciones > 2.0) y Top 3 etiquetas en tendencia.

---

## Despliegue y Orden de Ejecución

### Requisitos
* **Microsoft SQL Server** (2019 o superior).
* **SSMS (SQL Server Management Studio)**, **Azure Data Studio** o extensión **MSSQL** en VS Code.

### Instrucciones de Instalación
1. Crear e inicializar el entorno de base de datos:
   ```sql
   CREATE DATABASE FANHUB;
   GO
   USE FANHUB;
   GO
