# Decisiones técnicas

## Arquitectura general

Se eligió un pipeline de 3 capas (Bronze, Silver, Gold) porque:

- **Bronze**: conserva los datos originales sin modificaciones. Permite re-procesar si cambian las reglas de negocio.
- **Silver**: datos limpios, tipados y con **llaves foráneas** (FOREIGN KEY) que garantizan que las relaciones entre tablas sean válidas. Por ejemplo, no puede existir una inscripción (enrollment) de un estudiante que no exista en la tabla de estudiantes.
- **Gold**: modelo dimensional (estrella) orientado al análisis. Incluye dimensiones, tablas de hechos y KPIs pre-calculados. También incluye una **tabla de hechos cruzada** que une University con Billing.

## Stack tecnológico

| Herramienta | Por qué |
|---|---|
| **PostgreSQL 15** | Motor relacional robusto, soporta COPY para carga masiva de CSVs y restricciones de integridad referencial |
| **Apache Airflow 2.9** | Orquestador estándar de la industria, DAGs en Python puro |
| **Jupyter** | Entorno ideal para análisis exploratorio y visualización |
| **Pandas + PyArrow** | Exportación a Parquet con un mínimo de código |

## Relaciones entre tablas

Las 3 áreas de negocio están conectadas:

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
Esto significa que un estudiante puede convertirse en cliente. La vista `silver.vw_student_customer` y la tabla `gold.fact_student_customer` materializan esta relación permitiendo analizar el ciclo de vida completo: desde que una persona es estudiante hasta que genera facturación como cliente. De los 10,000 clientes, 5,000 están vinculados a un estudiante (relación 1:1 sintética en los datos).

## Llaves foráneas (FOREIGN KEY)

En la capa Silver se agregaron restricciones FOREIGN KEY para garantizar que:
- No existan inscripciones de estudiantes que no existen
- No existan facturas de clientes que no existen
- No existan actividades de contactos que no existen
- No existan oportunidades de cuentas que no existen

Esto protege la calidad de los datos a nivel de base de datos.

## Índices

Se agregaron índices en las columnas más consultadas (student_id, customer_id, invoice_id, enrollment_id, etc.) para que las consultas sean más rápidas.

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

Sobre los 4 KPIs base (student_performance, monthly_revenue, sales_pipeline, student_to_customer), se agregaron 6 KPIs adicionales para cubrir más ángulos de negocio:

| KPI | Decisión |
|---|---|
| **RFM** | Segmentar clientes en VIP, Frecuente, Ocasional, Perdido según recencia, frecuencia y monto. Permite campañas de retención focalizadas. |
| **Rendimiento por curso** | Identificar los cursos con mejor y peor promedio de notas. Útil para revisar currícula y carga académica. |
| **Carga docente** | Medir cuántos estudiantes y cursos tiene cada profesor. Detecta sobrecarga o falta de asignación. |
| **Churn de suscripciones** | Calcular tasa de cancelación por producto. Permite identificar productos con alta rotación y tomar acciones. |
| **Ciclo de vida estudiante → cliente** | Medir cuántos días pasan desde que un estudiante se inscribe hasta que emite su primera factura como cliente. Indicador de maduración comercial. |
| **Riesgo de cobranza** | Clasificar clientes en Alto/Medio/Bajo riesgo según su deuda pendiente. Prioriza acciones de cobranza. |

La lógica de cada KPI queda materializada en tablas del esquema `gold` para que cualquier persona pueda consultarlas sin re-calcular.

## Alcance del notebook de análisis

El notebook `01_analisis.ipynb` contiene 14 secciones que cubren los 3 dominios:

- **University**: estudiantes por país, rendimiento por curso, carga docente, top estudiantes
- **Billing**: ingresos mensuales, top clientes, deudores, RFM, churn, riesgo de cobranza
- **CRM**: pipeline de ventas
- **Cruce**: conversión estudiante → cliente, ciclo de vida
- **Resumen ejecutivo**: hallazgos principales y próximos pasos recomendados

Cada sección incluye tabla de datos y gráfico para facilitar la interpretación.

## Calidad de datos (quality_checks)

El pipeline ejecuta validaciones automáticas después de construir Gold:
- Conteo de filas por tabla (Bronze vs Silver vs Gold)
- Detección de valores nulos en columnas críticas
- Verificación de llaves foráneas (estudiantes sin inscripciones, clientes sin facturas, etc.)
- Reporte de inconsistencias entre dominios

## Orquestación

El DAG `bootcamp_pipeline` ejecuta 5 tareas en serie:
```
bronze_ingest → silver_transform → gold_model → quality_checks → export_parquet
```
Cada tarea es un `BashOperator` que llama a `python src/run_pipeline.py <paso>`. El pipeline es manual (sin schedule) porque el proyecto no requiere ejecución periódica automatizada.
