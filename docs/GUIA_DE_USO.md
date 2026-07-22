# Guía de uso — Pipeline CRM + Billing + Universidad

Guía paso a paso para ejecutar el proyecto desde cero: qué servicios levantar, cómo correr el pipeline, cómo usar el notebook y cómo solucionar problemas comunes.

---

## 1. Requisitos previos

| Herramienta | Versión mínima | Para qué |
|---|---|---|
| **Docker** | 24+ | Contenedores de Postgres, Airflow y Jupyter |
| **WSL 2** (Windows) | Ubuntu 22.04+ | Terminal Linux para lanzar Docker |
| **Git** | 2.30+ | Clonar el repositorio |
| **Navegador web** | — | Airflow UI (puerto 8080) y Jupyter (puerto 8888) |

En Windows, Docker debe correr **dentro de WSL 2**. No usar Docker Desktop.

---

## 2. Estructura del proyecto

```
.
├── docker/
│   ├── docker-compose.yml   # Define los servicios (postgres, airflow, jupyter)
│   └── Dockerfile            # Imagen base de Airflow con dependencias
├── dags/
│   └── pipeline_dag.py       # DAG de Airflow: 5 tareas en serie
├── sql/
│   ├── bronze/               # Creación de tablas brutas + ingesta CSV
│   ├── silver/               # Tablas limpias con FK, transformación, índices
│   └── gold/                 # Modelo dimensional + KPIs + tablas analíticas
├── src/
│   ├── run_pipeline.py       # Orquestador Python que ejecuta cada paso
│   ├── utils.py              # Conexión a BD, lectura de archivos SQL
│   ├── quality_checks.py     # Validaciones post-pipeline
│   └── export_parquet.py     # Exporta capa Gold a formato Parquet
├── notebooks/
│   └── 01_analisis.ipynb     # Notebook principal con 14 secciones de análisis
├── data/
│   ├── raw/                  # Copia de los CSV originales
│   └── parquet/              # Exportaciones Gold en formato columnar
├── docs/
│   ├── decisiones.md         # Decisiones técnicas documentadas
│   ├── hallazgos_calidad.md  # Problemas de calidad detectados
│   └── presentacion_ejecutiva.md  # Resumen para negocio
└── README.md                 # Enunciado original del proyecto
```

---

## 3. Iniciar el entorno

Desde Ubuntu (WSL en Windows), pararse en la raíz del proyecto y ejecutar:

```bash
cd /ruta/al/proyecto
docker compose -f docker/docker-compose.yml up -d
```

Esto levanta 3 servicios:

| Servicio | Puerto | URL | Credenciales |
|---|---|---|---|
| **PostgreSQL 15** | 5432 | — | `bootcamp` / `bootcamp` |
| **Airflow 2.9** | 8080 | http://localhost:8080 | `admin` / `admin` |
| **Jupyter Notebook** | 8888 | http://localhost:8888 | Token: `bootcamp` |

En WSL, Jupyter puede requerir usar `http://[::1]:8888` si `localhost` no funciona.

Verificar que todos los servicios estén corriendo:

```bash
docker compose -f docker/docker-compose.yml ps
```

---

## 4. Ejecutar el pipeline

### Opción A — Desde Airflow (recomendado)

1. Abrir http://localhost:8080 en el navegador.
2. Iniciar sesión con `admin` / `admin`.
3. Buscar el DAG `bootcamp_pipeline`.
4. Hacer clic en el botón de play (Trigger DAG).
5. Esperar a que las 5 tareas se pongan verdes:
   - `bronze_ingest` → `silver_transform` → `gold_model` → `quality_checks` → `export_parquet`

### Opción B — Desde terminal

```bash
docker exec -it bootcamp-airflow bash -c "cd /opt/airflow && python src/run_pipeline.py"
```

### Qué hace cada paso

| Paso | Tarea Airflow | Descripción |
|---|---|---|
| 1 | `bronze_ingest` | Crea esquema `bronze`, copia los CSVs tal cual desde `/data/raw/` |
| 2 | `silver_transform` | Crea esquema `silver` con 18 tablas, FKs, tipos correctos, vista `vw_student_customer` e índices |
| 3 | `gold_model` | Crea esquema `gold` con 10 dimensiones, 6 tablas de hechos y 10 KPIs |
| 4 | `quality_checks` | Ejecuta validaciones: conteos, nulos, llaves huérfanas |
| 5 | `export_parquet` | Exporta todas las tablas Gold a `/data/parquet/` |

### Diagrama del pipeline

```
Bronze ──→ Silver ──→ Gold ──→ Quality ──→ Parquet
(ingesta)   (limpieza)  (modelo)   (checks)    (export)
```

---

## 5. Usar el notebook de análisis

1. Abrir http://localhost:8888 (token: `bootcamp`).
2. Entrar a la carpeta `work/`.
3. Abrir `01_analisis.ipynb`.
4. Ejecutar todas las celdas (menú **Run** → **Run All Cells**).

### Secciones del notebook

| # | Sección | Fuente | Qué muestra |
|---|---|---|---|
| 1 | Estudiantes por país | University | Barra de estudiantes por país |
| 2 | Ingresos mensuales | Billing | Línea de ingresos mes a mes |
| 3 | Pipeline de ventas | CRM | Barras de monto por etapa |
| 4 | Top 10 estudiantes | University | Tabla de mejores promedios |
| 5 | Top 10 clientes | Billing | Tabla de mayores facturadores |
| 6 | Deudores | Billing | Clientes con saldo pendiente |
| 7 | Cruce University-Billing | Gold | Facturación por país (estudiantes → clientes) |
| 8 | Resumen ejecutivo | — | Hallazgos principales |
| 9 | RFM | Billing | Segmentación VIP / Frecuente / Ocasional / Perdido |
| 10 | Rendimiento por curso | University | Top 10 cursos por nota + peores 5 |
| 11 | Carga docente | University | Profesores con más estudiantes |
| 12 | Churn de suscripciones | Billing | Activas vs canceladas por producto |
| 13 | Ciclo de vida estudiante → cliente | Cruce | Días hasta primera factura por país |
| 14 | Riesgo de cobranza | Billing | Clientes en riesgo Alto / Medio / Bajo |
| 15 | Tasa de aprobación | University | % de aprobación por curso |
| 16 | Matrículas por semestre | University | Evolución de inscripciones |

---

## 6. Conexión a la base de datos

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `5432` |
| Base de datos | `bootcamp` |
| Usuario | `bootcamp` |
| Contraseña | `bootcamp` |

Ejemplo desde terminal:

```bash
docker exec -it bootcamp-postgres psql -U bootcamp -d bootcamp
```

---

## 7. Re-ejecutar desde cero (reset completo)

```bash
# 1. Eliminar contenedores y volúmenes (borra la BD)
docker compose -f docker/docker-compose.yml down -v

# 2. Volver a levantar
docker compose -f docker/docker-compose.yml up -d

# 3. Esperar 15 segundos a que Postgres esté listo

# 4. Ejecutar pipeline (Airflow UI o terminal)
docker exec -it bootcamp-airflow bash -c "cd /opt/airflow && python src/run_pipeline.py"
```

El flag `-v` elimina el volumen de Postgres, borrando todos los datos.
No usar `-v` si hay datos que preservar.

---

## 8. Solución de problemas comunes

| Problema | Causa | Solución |
|---|---|---|
| `airflow-init` falla | Postgres no responde | Esperar 10s y ejecutar `docker compose up -d` de nuevo |
| Jupyter no carga | Token incorrecto | Usar token `bootcamp` |
| Jupyter da `Connection refused` | IPv6 | Usar `http://[::1]:8888` |
| Pipeline falla en `bronze_ingest` | CSV no encontrados | Verificar que `data/raw/` tenga los 18 archivos |
| Error `relation "bronze.students" does not exist` | Pipeline incompleto | Trigger DAG completo, no tareas sueltas |
| Puerto 8080/8888/5432 ocupado | Otro servicio usando el puerto | Cambiar puerto en `docker-compose.yml` o detener el otro servicio |
| WSL no encuentra Docker | Docker no instalado en WSL | Instalar Docker Engine en Ubuntu WSL (no Docker Desktop) |

---

## 9. Comandos rápidos

```bash
# Ver logs de Airflow
docker logs bootcamp-airflow -f

# Ver logs de Postgres
docker logs bootcamp-postgres -f

# Entrar a Postgres por consola
docker exec -it bootcamp-postgres psql -U bootcamp -d bootcamp

# Listar tablas Gold
docker exec -it bootcamp-postgres psql -U bootcamp -d bootcamp -c "\dt gold.*"

# Ejecutar un paso específico del pipeline
docker exec -it bootcamp-airflow bash -c "cd /opt/airflow && python src/run_pipeline.py gold"

# Ver los Parquet exportados
ls data/parquet/
```

---

## 10. Modelo dimensional (Esquema Estrella)

La capa Gold usa **esquema estrella**: las dimensiones rodean a los hechos para consultas rápidas e intuitivas.

### Dimensiones (10 tablas descriptivas)

| Dimensión | Filas | Descripción |
|---|---|---|
| `dim_date` | 3,287 | Calendario con año, mes, trimestre, día, fin de semana |
| `dim_students` | 5,000 | Estudiantes con rango de edad |
| `dim_courses` | 300 | Cursos con departamento y créditos |
| `dim_semesters` | 8 | Semestres académicos |
| `dim_professors` | 200 | Profesores |
| `dim_customers` | 10,000 | Clientes con segmento y antigüedad |
| `dim_products` | 200 | Productos con categoría y precio |
| `dim_accounts` | 5,000 | Cuentas (empresas) |
| `dim_contacts` | 15,000 | Contactos |
| `dim_opportunity_stage` | 6 | Etapas del pipeline con orden y categoría |

### Hechos (7 tablas de mediciones)

| Hecho | Filas | Casos de uso |
|---|---|---|
| `fact_enrollments` | 25,000 | ¿Qué cursos tienen más demanda por semestre? |
| `fact_grades` | 60,000 | ¿Cuál es el promedio por curso y país? |
| `fact_subscriptions` | 15,000 | ¿Qué productos tienen mayor retención? |
| `fact_invoices` | 50,000 | ¿Cuál es la tendencia de ingresos mensuales? |
| `fact_payments` | 80,000 | ¿Qué métodos de pago son más usados? |
| `fact_opportunities` | 3,000 | ¿Cuánto vale el pipeline por etapa? |
| `fact_activities` | 20,000 | ¿Qué actividades de seguimiento se realizan? |

### Puente (bridge)

| Tabla | Filas | Descripción |
|---|---|---|
| `bridge_student_customer` | 5,000 | Relaciona estudiantes con clientes |
| `fact_student_customer` | 5,000 | Hecho cruzado (agregado para análisis) |

---

## 11. KPIs disponibles en Gold

| KPI | Tabla | Filas | Descripción |
|---|---|---|---|
| Rendimiento estudiantes | `kpi_student_performance` | 5,000 | Promedio por estudiante |
| Ingresos mensuales | `kpi_monthly_revenue` | ~50 | Revenue por mes |
| Pipeline de ventas | `kpi_sales_pipeline` | 6 | Monto por etapa |
| Conversión estudiante → cliente | `kpi_student_to_customer` | 8 | % por país |
| RFM | `kpi_rfm_segments` | 10,000 | Segmentación de clientes |
| Rendimiento por curso | `kpi_course_performance` | 300 | Nota promedio por curso |
| Carga docente | `kpi_professor_load` | 200 | Estudiantes por profesor |
| Churn de suscripciones | `kpi_subscription_churn` | 200 | Tasa de cancelación |
| Ciclo de vida | `kpi_student_lifecycle` | 5,000 | Días de estudiante a cliente |
| Riesgo de cobranza | `kpi_collection_risk` | 9,933 | Clientes por nivel de riesgo |
| Tasa de aprobación | `kpi_pass_rate` | 300 | % aprobados y reprobados por curso |
| Matrículas por semestre | `kpi_enrollment_trend` | 8 | Evolución de inscripciones por semestre |

---

## 12. Conectar Power BI Desktop

Power BI Desktop puede conectarse directamente al esquema Gold para crear dashboards.

### Requisitos
- **Power BI Desktop** instalado en Windows.
- PostgreSQL accesible desde Windows (localhost:5432).

### Pasos

1. Abrir Power BI Desktop.
2. **Obtener datos** → **Más...** → **Base de datos PostgreSQL** → **Conectar**.
3. Ingresar las credenciales:

   | Campo | Valor |
   |---|---|
   | Servidor | `localhost:5432` |
   | Base de datos | `bootcamp` |
   | Modo | Importar (recomendado) |
   | Usuario | `bootcamp` |
   | Contraseña | `bootcamp` |

4. En el navegador, seleccionar el esquema **gold** y marcar las tablas deseadas:

   - **Dimensiones**: `dim_date`, `dim_students`, `dim_customers`, `dim_products`, `dim_courses`, `dim_accounts`, `dim_contacts`, `dim_opportunity_stage`, `dim_professors`, `dim_semesters`
   - **Hechos**: `fact_enrollments`, `fact_grades`, `fact_subscriptions`, `fact_invoices`, `fact_payments`, `fact_opportunities`, `fact_activities`
   - **Puente**: `bridge_student_customer`, `fact_student_customer`
   - **KPIs**: las 10 tablas `kpi_*`

5. Cargar los datos.

### Relaciones automáticas

Power BI detecta automáticamente las relaciones por las claves foráneas definidas en PostgreSQL. Verificar en **Modelo** que las relaciones sean correctas:

```
dim_date.date_sk ← fact_*.date_sk
dim_students.student_sk ← fact_enrollments.student_sk / fact_grades.student_sk
dim_courses.course_sk ← fact_enrollments.course_sk / fact_grades.course_sk
dim_customers.customer_sk ← fact_*.customer_sk
dim_products.product_sk ← fact_subscriptions.product_sk / fact_invoices.product_sk
dim_opportunity_stage.stage_sk ← fact_opportunities.stage_sk
```

### Sugerencia de dashboards

| Dashboard | Tablas base | KPIs |
|---|---|---|
| Ingresos y cobranza | `fact_invoices`, `fact_payments`, `dim_date`, `kpi_collection_risk` | Ingreso mensual, mora, riesgo |
| Rendimiento académico | `fact_grades`, `fact_enrollments`, `dim_students`, `dim_courses`, `kpi_course_performance` | Promedio por curso, carga docente |
| CRM y ventas | `fact_opportunities`, `fact_activities`, `dim_opportunity_stage`, `kpi_sales_pipeline` | Pipeline por etapa, actividades |
| Segmentación clientes | `kpi_rfm_segments`, `kpi_subscription_churn`, `bridge_student_customer` | RFM, churn, estudiantes → clientes |

---

## 13. Recomendación para presentación en Millicom (Tigo) Bolivia

Este proyecto se construyó con datos de University, Billing y CRM, pero las técnicas aplicadas son directamente transferibles a un operador de telecomunicaciones como Tigo.

### Cómo traducir los dominios a telecomunicaciones

| Dominio original | Equivalente en Tigo | Datos similares |
|---|---|---|
| University | Clientes pospago / prepago | Suscripciones, recargas, planes |
| Billing | Facturación Tigo Money | Facturas, pagos, métodos de pago, mora |
| CRM | Gestión de clientes Tigo | Cuentas corporativas, contactos, oportunidades, actividades de venta |

### KPIs que aplican directamente a telecom

| KPI | Traducción a Tigo |
|---|---|
| RFM | Clientes VIP vs ocasionales vs perdidos por falta de recarga |
| Churn de suscripciones | Rotación de líneas pospago por plan |
| Ciclo de vida cliente | Tiempo desde activación de línea hasta primera recarga o primer pago |
| Riesgo de cobranza | Clientes con mora en facturación |
| Pipeline de ventas | Oportunidades de venta corporativa (cuentas business) |
| Ingresos mensuales | Revenue recurrente vs recargas eventuales |

### Qué destacar en la presentación

1. **Pipeline automatizado** — los datos llegan crudos y se transforman solos hasta tener KPIs listos. En Tigo, los datos de facturación, recargas y CRM llegarían al mismo pipeline.
2. **Esquema estrella** — modelado profesional que cualquier analista de Tigo puede consultar con SQL básico.
3. **10 KPIs pre-calculados** — nada de esperar queries complejas. Los indicadores ya están listos para dashboards en Power BI, Superset o Metabase.
4. **Cross-domain** — la capacidad de cruzar estudiantes con clientes (en este proyecto) equivale a cruzar recargas con facturación o CRM con cobranza en Tigo.

---

## 14. Datos disponibles (volumen)

| Dominio | Archivos | Total filas |
|---|---|---|
| University | 6 (semesters, professors, students, courses, enrollments, grades) | ~90,300 |
| Billing | 6 (customers, products, subscriptions, invoices, invoice_items, payments) | ~305,200 |
| CRM | 5 (accounts, contacts, leads, opportunities, opportunity_contacts, activities) | ~51,000 |
| **Total** | **17 archivos CSV** | **~446,500 filas** |
