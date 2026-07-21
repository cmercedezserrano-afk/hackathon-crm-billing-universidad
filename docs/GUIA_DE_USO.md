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

## 10. KPIs disponibles en Gold

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

---

## 11. Datos disponibles (volumen)

| Dominio | Archivos | Total filas |
|---|---|---|
| University | 6 (semesters, professors, students, courses, enrollments, grades) | ~90,300 |
| Billing | 6 (customers, products, subscriptions, invoices, invoice_items, payments) | ~305,200 |
| CRM | 5 (accounts, contacts, leads, opportunities, opportunity_contacts, activities) | ~51,000 |
| **Total** | **17 archivos CSV** | **~446,500 filas** |
