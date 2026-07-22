# Decisiones técnicas

## Arquitectura general

Se eligió un pipeline de 3 capas (Bronze, Silver, Gold) porque:

- **Bronze**: conserva los datos originales sin modificaciones. Permite re-procesar si cambian las reglas de negocio.
- **Silver**: datos limpios, tipados y con llaves foráneas (FOREIGN KEY) que garantizan que las relaciones entre tablas sean válidas.
- **Gold**: modelo dimensional en **esquema estrella** (star schema) orientado al análisis. Separamos **dimensiones** (tablas descriptivas) de **hechos** (tablas de mediciones) para que las consultas sean rápidas e intuitivas.

## Stack tecnológico

| Herramienta | Por qué |
|---|---|
| **PostgreSQL 15** | Motor relacional robusto, soporta COPY para carga masiva de CSVs y restricciones de integridad referencial |
| **Apache Airflow 2.9** | Orquestador estándar de la industria, DAGs en Python puro |
| **Jupyter** | Entorno ideal para análisis exploratorio y visualización |
| **Pandas + PyArrow** | Exportación a Parquet con un mínimo de código |

## Modelo dimensional (Esquema Estrella)

La capa Gold se organiza en torno a **casos de uso de negocio**. Cada tabla de hechos responde preguntas específicas y se relaciona con dimensiones compartidas (conformadas).

### Dimensiones conformadas

Son tablas descriptivas que se reutilizan entre múltiples hechos:

| Dimensión | Atributos clave | Compartida por |
|---|---|---|
| `dim_date` | date, year, month, quarter, day_name, is_weekend | Todos los hechos con fechas |
| `dim_students` | student_id, name, country, age_range | fact_enrollments, fact_grades |
| `dim_courses` | course_id, name, department, credits | fact_enrollments, fact_grades |
| `dim_semesters` | semester_id, year, half | fact_enrollments, fact_grades |
| `dim_professors` | professor_id, name, department | fact_enrollments (vía courses) |
| `dim_customers` | customer_id, name, country, segment, tenure_years | fact_invoices, fact_subscriptions, fact_payments |
| `dim_products` | product_id, name, category, price_tier | fact_subscriptions |
| `dim_accounts` | account_id, name, industry, country | fact_opportunities |
| `dim_contacts` | contact_id, name, email, title | fact_activities |
| `dim_opportunity_stage` | stage_sk, stage_name, stage_category, sort_order | fact_opportunities |

### Tablas de hechos con casos de uso

Cada hecho responde a una o más preguntas de negocio:

| Hecho | Granularidad | Casos de uso | Dimensiones vinculadas |
|---|---|---|---|
| `fact_enrollments` | 1 fila por inscripción | ¿Qué cursos tienen mayor/menor demanda por semestre? ¿Cómo varía la cantidad de inscripciones en el tiempo? | dim_students, dim_courses, dim_semesters, dim_date |
| `fact_grades` | 1 fila por calificación | ¿Cuál es el promedio de notas por curso, país del estudiante y semestre? ¿Qué estudiantes están en riesgo académico? | dim_students, dim_courses, dim_semesters, dim_date |
| `fact_subscriptions` | 1 fila por suscripción | ¿Qué productos tienen mayor/menor retención? ¿Cuál es la duración promedio de una suscripción? | dim_customers, dim_products, dim_date |
| `fact_invoices` | 1 fila por factura | ¿Cuál es la tendencia de ingresos mensuales? ¿Qué clientes tienen saldo pendiente? ¿Cuál es la estacionalidad de facturación? | dim_customers, dim_date |
| `fact_payments` | 1 fila por pago | ¿Cuál es el volumen de pagos por método y mes? ¿Qué métodos de pago son más usados? | dim_customers, dim_date (vía invoice) |
| `fact_opportunities` | 1 fila por oportunidad | ¿Cuál es el valor del pipeline por etapa? ¿Qué cuentas tienen más oportunidades abiertas? ¿Tasa de cierre? | dim_accounts, dim_opportunity_stage, dim_date |
| `fact_activities` | 1 fila por actividad | ¿Qué actividades de seguimiento se realizan por contacto y oportunidad? ¿Cuál es el volumen de llamadas vs reuniones? | dim_contacts, dim_date |

### Puente (bridge) entre dominios

`bridge_student_customer` relaciona University con Billing sin mezclar granularidades. Permite navegar de estudiante a cliente y calcular métricas como días hasta primera factura.

### Beneficios del esquema estrella

1. **Consultas simples**: un SELECT con JOINs directos a las dimensiones
2. **Rendimiento**: las tablas de hechos son largas y angostas; las dimensiones son cortas y anchas
3. **Consistencia**: las dimensiones conformadas garantizan que "país" signifique lo mismo en fact_invoices que en fact_grades
4. **Evolutividad**: agregar un nuevo hecho no requiere modificar los existentes

## Relaciones entre tablas

### Dentro de University
```
semesters  1---* enrollments *---1 courses *---1 professors
                            |
                          1---* grades
```

### Dentro de Billing
```
customers 1---* subscriptions *---1 products
         |
        1---* invoices 1---* invoice_items *---1 products
         |
        1---* payments
```

### Dentro de CRM
```
accounts 1---* contacts
        |
        1---* opportunities 1---* opportunity_contacts *---1 contacts
        |
        1---* activities
```

### Relación CRUCE University → Billing
```
students.student_id = customers.external_ref (formato: STU-0000001)
```
De los 10,000 clientes, 5,000 están vinculados a un estudiante (relación 1:1 sintética en los datos). La vista `silver.vw_student_customer`, el puente `gold.bridge_student_customer` y el hecho `gold.fact_student_customer` materializan esta relación.

## Llaves foráneas (FOREIGN KEY)

En la capa Silver se agregaron 17 restricciones FOREIGN KEY para garantizar que:
- No existan inscripciones de estudiantes que no existen
- No existan facturas de clientes que no existen
- No existan actividades de contactos que no existen
- No existan oportunidades de cuentas que no existen
- etc.

## Claves sustitutas (surrogate keys)

En Gold se agregan claves sustitutas para:
- **date_sk**: vínculo a `dim_date` en cada hecho con fechas. Permite agrupar por año/mes/trimestre sin funciones de fecha.
- **stage_sk**: vínculo a `dim_opportunity_stage` que ordena y categoriza etapas del pipeline.

## Índices

Se agregaron índices en las columnas más consultadas de cada hecho (student_id, course_id, customer_id, invoice_id, etc.) para optimizar consultas analíticas.

## Formato de IDs

Los IDs vienen como `CUS-0000001`, `STU-0000001`, etc. Se extrae la parte numérica para usar como clave entera en Silver y Gold. Esto facilita joins y reduce espacio de almacenamiento.

## Manejo de nulos

Se detectaron campos vacíos en los CSVs. En Silver se convierten a NULL de PostgreSQL para mantener la integridad referencial. Las columnas obligatorias tienen la restricción NOT NULL.

## Idempotencia

Cada paso del pipeline hace DROP TABLE IF EXISTS antes de crear. Esto permite re-ejecutar el pipeline completo sin duplicar datos.

## Parquet

Se eligió Parquet como formato de salida porque:
- Es columnar (eficiente para análisis)
- Ocupa menos espacio que CSV
- Es el estándar en data lakes modernos

## KPIs adicionales (6 nuevos)

Sobre los 4 KPIs base, se agregaron 6 KPIs adicionales para cubrir más ángulos de negocio:

| KPI | Decisión |
|---|---|
| **RFM** | Segmentar clientes en VIP, Frecuente, Ocasional, Perdido según recencia, frecuencia y monto. Permite campañas de retención focalizadas. |
| **Rendimiento por curso** | Identificar los cursos con mejor y peor promedio de notas. Útil para revisar currícula y carga académica. |
| **Carga docente** | Medir cuántos estudiantes y cursos tiene cada profesor. Detecta sobrecarga o falta de asignación. |
| **Churn de suscripciones** | Calcular tasa de cancelación por producto. Permite identificar productos con alta rotación y tomar acciones. |
| **Ciclo de vida estudiante → cliente** | Medir cuántos días pasan desde que un estudiante se inscribe hasta que emite su primera factura como cliente. Indicador de maduración comercial. |
| **Riesgo de cobranza** | Clasificar clientes en Alto/Medio/Bajo riesgo según su deuda pendiente. Prioriza acciones de cobranza. |

## Dimensiones con atributos derivados

Para enriquecer el análisis sin recurrir a funciones en cada consulta:
- `dim_students`: incluye `age_range` y `enrollment_age_years`
- `dim_customers`: incluye `tenure_years`
- `dim_products`: incluye `price_tier` (Básico, Estándar, Premium)
- `dim_date`: incluye `year_month` y `is_weekend`

## Alcance del notebook de análisis

El notebook `01_analisis.ipynb` contiene 14 secciones que cubren los 3 dominios:

- **University**: estudiantes por país, rendimiento por curso, carga docente, top estudiantes
- **Billing**: ingresos mensuales, top clientes, deudores, RFM, churn, riesgo de cobranza
- **CRM**: pipeline de ventas
- **Cruce**: conversión estudiante → cliente, ciclo de vida
- **Resumen ejecutivo**: hallazgos principales y próximos pasos recomendados

## Calidad de datos (quality_checks)

El pipeline ejecuta validaciones automáticas después de construir Gold:
- Conteo de filas por tabla (Bronze vs Silver vs Gold)
- Detección de valores nulos en columnas críticas
- Verificación de llaves foráneas
- Reporte de inconsistencias entre dominios

## Orquestación

El DAG `bootcamp_pipeline` ejecuta 5 tareas en serie:
```
bronze_ingest → silver_transform → gold_model → quality_checks → export_parquet
```
Cada tarea es un `BashOperator` que llama a `python src/run_pipeline.py <paso>`. El pipeline es manual (trigger manual en Airflow).
