-- ============================================================
-- CAPA GOLD: Modelo Dimensional (Estrella)
-- ============================================================
-- Esquema en estrella donde las DIMENSIONES (tablas descriptivas)
-- rodean a los HECHOS (tablas de mediciones). Cada hecho responde
-- a uno o varios CASOS DE USO de negocio.
--
-- BENEFICIOS DEL ESQUEMA ESTRELLA:
-- 1. Consultas simples: los JOINs van de un hecho a sus dimensiones
-- 2. Rendimiento: tablas desnormalizadas, menos joins profundos
-- 3. Consistencia: dimensiones conformadas (compartidas entre hechos)
-- 4. Intuitivo: el negocio entiende "clientes por país" vs "suma de ventas"

CREATE SCHEMA IF NOT EXISTS gold;

-- ============================================================
-- DIMENSIONES COMPARTIDAS (CONFORMADAS)
-- ============================================================
-- Una dimension conformada significa que la misma tabla se usa
-- desde multiples hechos. Ej: dim_date se usa en fact_invoices,
-- fact_grades, fact_subscriptions, etc.

-- dim_date: unica fuente de verdad para fechas
-- date_sk es clave sustituta entera para joins eficientes
DROP TABLE IF EXISTS gold.dim_date CASCADE;
CREATE TABLE gold.dim_date AS
SELECT
    ROW_NUMBER() OVER (ORDER BY d) AS date_sk,
    d::DATE AS date,
    EXTRACT(YEAR FROM d) AS year,
    EXTRACT(MONTH FROM d) AS month,
    EXTRACT(QUARTER FROM d) AS quarter,
    TO_CHAR(d, 'Day') AS day_name,
    EXTRACT(DOW FROM d) AS day_of_week,
    TO_CHAR(d, 'YYYY-MM') AS year_month,
    CASE WHEN EXTRACT(DOW FROM d) IN (0, 6) THEN TRUE ELSE FALSE END AS is_weekend
FROM GENERATE_SERIES('2018-01-01'::DATE, '2026-12-31'::DATE, '1 day') AS d;

ALTER TABLE gold.dim_date ADD PRIMARY KEY (date_sk);
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_date_date ON gold.dim_date(date);

-- UNIVERSITY
DROP TABLE IF EXISTS gold.dim_semesters CASCADE;
CREATE TABLE gold.dim_semesters AS SELECT * FROM silver.semesters;
ALTER TABLE gold.dim_semesters ADD PRIMARY KEY (semester_id);

DROP TABLE IF EXISTS gold.dim_professors CASCADE;
CREATE TABLE gold.dim_professors AS SELECT * FROM silver.professors;
ALTER TABLE gold.dim_professors ADD PRIMARY KEY (professor_id);

DROP TABLE IF EXISTS gold.dim_students CASCADE;
CREATE TABLE gold.dim_students AS
SELECT
    *,
    EXTRACT(YEAR FROM AGE(enrolled_at))::INTEGER AS enrollment_age_years,
    CASE
        WHEN EXTRACT(YEAR FROM AGE(birth_date))::INTEGER < 20 THEN 'Menor de 20'
        WHEN EXTRACT(YEAR FROM AGE(birth_date))::INTEGER BETWEEN 20 AND 25 THEN '20-25'
        WHEN EXTRACT(YEAR FROM AGE(birth_date))::INTEGER BETWEEN 26 AND 30 THEN '26-30'
        WHEN EXTRACT(YEAR FROM AGE(birth_date))::INTEGER BETWEEN 31 AND 40 THEN '31-40'
        ELSE 'Mayor de 40'
    END AS age_range
FROM silver.students;
ALTER TABLE gold.dim_students ADD PRIMARY KEY (student_id);

DROP TABLE IF EXISTS gold.dim_courses CASCADE;
CREATE TABLE gold.dim_courses AS SELECT * FROM silver.courses;
ALTER TABLE gold.dim_courses ADD PRIMARY KEY (course_id);

-- BILLING
DROP TABLE IF EXISTS gold.dim_customers CASCADE;
CREATE TABLE gold.dim_customers AS
SELECT
    *,
    EXTRACT(YEAR FROM AGE(created_at))::INTEGER AS tenure_years
FROM silver.customers;
ALTER TABLE gold.dim_customers ADD PRIMARY KEY (customer_id);

DROP TABLE IF EXISTS gold.dim_products CASCADE;
CREATE TABLE gold.dim_products AS
SELECT
    *,
    CASE
        WHEN monthly_price < 30 THEN 'Basico'
        WHEN monthly_price < 60 THEN 'Estandar'
        ELSE 'Premium'
    END AS price_tier
FROM silver.products;
ALTER TABLE gold.dim_products ADD PRIMARY KEY (product_id);

-- CRM
DROP TABLE IF EXISTS gold.dim_accounts CASCADE;
CREATE TABLE gold.dim_accounts AS SELECT * FROM silver.accounts;
ALTER TABLE gold.dim_accounts ADD PRIMARY KEY (account_id);

DROP TABLE IF EXISTS gold.dim_contacts CASCADE;
CREATE TABLE gold.dim_contacts AS SELECT * FROM silver.contacts;
ALTER TABLE gold.dim_contacts ADD PRIMARY KEY (contact_id);

-- dim_opportunity_stage: dimension conformada para etapas del pipeline
-- Permite ordenar etapas y agregar metadatos de etapa sin tocar el hecho
DROP TABLE IF EXISTS gold.dim_opportunity_stage CASCADE;
CREATE TABLE gold.dim_opportunity_stage AS
SELECT
    ROW_NUMBER() OVER (ORDER BY sort_order) AS stage_sk,
    stage AS stage_name,
    CASE
        WHEN stage IN ('closed_won') THEN 'Ganada'
        WHEN stage IN ('closed_lost') THEN 'Perdida'
        WHEN stage IN ('negotiation', 'proposal') THEN 'Avanzada'
        ELSE 'Temprana'
    END AS stage_category,
    sort_order
FROM (
    SELECT DISTINCT stage,
        CASE stage
            WHEN 'prospecting' THEN 1
            WHEN 'qualification' THEN 2
            WHEN 'proposal' THEN 3
            WHEN 'negotiation' THEN 4
            WHEN 'closed_won' THEN 5
            WHEN 'closed_lost' THEN 6
            ELSE 7
        END AS sort_order
    FROM silver.opportunities
) s;
ALTER TABLE gold.dim_opportunity_stage ADD PRIMARY KEY (stage_sk);

-- ============================================================
-- TABLAS DE HECHOS (ESTRELLA)
-- ============================================================
-- Cada hecho responde a preguntas de negocio especificas.
-- Las columnas date_sk vinculan a dim_date para analisis temporal.

-- CASO DE USO: "?Que cursos tienen mayor/menor rendimiento por semestre?"
-- HECHO: fact_enrollments
-- Granularidad: 1 fila por inscripcion
DROP TABLE IF EXISTS gold.fact_enrollments CASCADE;
CREATE TABLE gold.fact_enrollments AS
SELECT
    e.enrollment_id,
    e.student_id,
    e.course_id,
    e.semester_id,
    e.enrolled_at AS enrollment_date,
    dd.date_sk AS enrolled_date_sk,
    e.status
FROM silver.enrollments e
LEFT JOIN gold.dim_date dd ON e.enrolled_at::DATE = dd.date;
ALTER TABLE gold.fact_enrollments ADD PRIMARY KEY (enrollment_id);
CREATE INDEX IF NOT EXISTS idx_fact_enrollments_student ON gold.fact_enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_fact_enrollments_course ON gold.fact_enrollments(course_id);

-- CASO DE USO: "?Cual es el promedio de notas por curso, pais del estudiante y semestre?"
-- HECHO: fact_grades (desnormalizado con claves de dimension directas para consultas estrella)
-- Granularidad: 1 fila por calificacion
DROP TABLE IF EXISTS gold.fact_grades CASCADE;
CREATE TABLE gold.fact_grades AS
SELECT
    g.grade_id,
    g.enrollment_id,
    e.student_id,
    e.course_id,
    e.semester_id,
    g.assessment,
    g.score,
    g.weight,
    g.score * g.weight AS weighted_score,
    g.graded_at,
    dd.date_sk AS graded_date_sk
FROM silver.grades g
JOIN silver.enrollments e ON g.enrollment_id = e.enrollment_id
LEFT JOIN gold.dim_date dd ON g.graded_at::DATE = dd.date;
ALTER TABLE gold.fact_grades ADD PRIMARY KEY (grade_id);
CREATE INDEX IF NOT EXISTS idx_fact_grades_student ON gold.fact_grades(student_id);
CREATE INDEX IF NOT EXISTS idx_fact_grades_course ON gold.fact_grades(course_id);
CREATE INDEX IF NOT EXISTS idx_fact_grades_semester ON gold.fact_grades(semester_id);

-- CASO DE USO: "?Que productos tienen mayor/menor retencion de clientes?"
-- HECHO: fact_subscriptions
-- Granularidad: 1 fila por suscripcion
DROP TABLE IF EXISTS gold.fact_subscriptions CASCADE;
CREATE TABLE gold.fact_subscriptions AS
SELECT
    s.subscription_id,
    s.customer_id,
    s.product_id,
    s.start_date,
    dd_start.date_sk AS start_date_sk,
    s.end_date,
    dd_end.date_sk AS end_date_sk,
    s.status,
    COALESCE(s.end_date, CURRENT_DATE) - s.start_date AS days_active
FROM silver.subscriptions s
LEFT JOIN gold.dim_date dd_start ON s.start_date::DATE = dd_start.date
LEFT JOIN gold.dim_date dd_end ON s.end_date::DATE = dd_end.date;
ALTER TABLE gold.fact_subscriptions ADD PRIMARY KEY (subscription_id);
CREATE INDEX IF NOT EXISTS idx_fact_subscriptions_customer ON gold.fact_subscriptions(customer_id);
CREATE INDEX IF NOT EXISTS idx_fact_subscriptions_product ON gold.fact_subscriptions(product_id);

-- CASO DE USO: "?Cual es la tendencia de ingresos mensuales? ?Que clientes tienen saldo pendiente?"
-- HECHO: fact_invoices
-- Granularidad: 1 fila por factura
DROP TABLE IF EXISTS gold.fact_invoices CASCADE;
CREATE TABLE gold.fact_invoices AS
SELECT
    i.invoice_id,
    i.customer_id,
    i.issued_at,
    dd_issued.date_sk AS issued_date_sk,
    i.due_at,
    dd_due.date_sk AS due_date_sk,
    i.total,
    i.status,
    i.currency,
    COALESCE(p.total_paid, 0) AS total_paid,
    i.total - COALESCE(p.total_paid, 0) AS balance_due
FROM silver.invoices i
LEFT JOIN gold.dim_date dd_issued ON i.issued_at::DATE = dd_issued.date
LEFT JOIN gold.dim_date dd_due ON i.due_at::DATE = dd_due.date
LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS total_paid
    FROM silver.payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id;
ALTER TABLE gold.fact_invoices ADD PRIMARY KEY (invoice_id);
CREATE INDEX IF NOT EXISTS idx_fact_invoices_customer ON gold.fact_invoices(customer_id);

-- CASO DE USO: "?Cual es el volumen de pagos por metodo y mes?"
-- HECHO: fact_payments (separado de fact_invoices para granularidad de pago)
-- Granularidad: 1 fila por pago
DROP TABLE IF EXISTS gold.fact_payments CASCADE;
CREATE TABLE gold.fact_payments AS
SELECT
    p.payment_id,
    p.invoice_id,
    i.customer_id,
    p.amount,
    p.paid_at,
    dd.date_sk AS paid_date_sk,
    p.method
FROM silver.payments p
JOIN silver.invoices i ON p.invoice_id = i.invoice_id
LEFT JOIN gold.dim_date dd ON p.paid_at::DATE = dd.date;
ALTER TABLE gold.fact_payments ADD PRIMARY KEY (payment_id);
CREATE INDEX IF NOT EXISTS idx_fact_payments_invoice ON gold.fact_payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_fact_payments_customer ON gold.fact_payments(customer_id);

-- CASO DE USO: "?Cual es el valor del pipeline de ventas por etapa?"
-- HECHO: fact_opportunities
-- Granularidad: 1 fila por oportunidad
DROP TABLE IF EXISTS gold.fact_opportunities CASCADE;
CREATE TABLE gold.fact_opportunities AS
SELECT
    o.opportunity_id,
    o.account_id,
    o.name,
    o.stage,
    dos.stage_sk,
    o.amount,
    o.close_date,
    dd_close.date_sk AS close_date_sk,
    o.created_at,
    dd_created.date_sk AS created_date_sk
FROM silver.opportunities o
LEFT JOIN gold.dim_opportunity_stage dos ON o.stage = dos.stage_name
LEFT JOIN gold.dim_date dd_close ON o.close_date::DATE = dd_close.date
LEFT JOIN gold.dim_date dd_created ON o.created_at::DATE = dd_created.date;
ALTER TABLE gold.fact_opportunities ADD PRIMARY KEY (opportunity_id);
CREATE INDEX IF NOT EXISTS idx_fact_opportunities_account ON gold.fact_opportunities(account_id);
CREATE INDEX IF NOT EXISTS idx_fact_opportunities_stage ON gold.fact_opportunities(stage_sk);

-- CASO DE USO: "?Cuales son las actividades de seguimiento por contacto y oportunidad?"
-- HECHO: fact_activities
-- Granularidad: 1 fila por actividad
DROP TABLE IF EXISTS gold.fact_activities CASCADE;
CREATE TABLE gold.fact_activities AS
SELECT
    a.activity_id,
    a.contact_id,
    a.opportunity_id,
    a.type,
    a.subject,
    a.occurred_at,
    dd.date_sk AS occurred_date_sk
FROM silver.activities a
LEFT JOIN gold.dim_date dd ON a.occurred_at::DATE = dd.date;
ALTER TABLE gold.fact_activities ADD PRIMARY KEY (activity_id);

-- ============================================================
-- PUENTE CRUZADO: Student <-> Customer (Asociacion)
-- ============================================================
-- Tabla puente (bridge) que relaciona estudiantes con clientes.
-- No es un hecho puro porque no tiene medidas numericas.
-- Permite navegar de un dominio a otro sin mezclar granularidades.

DROP TABLE IF EXISTS gold.bridge_student_customer CASCADE;
CREATE TABLE gold.bridge_student_customer AS
SELECT
    s.student_id,
    s.customer_id,
    s.enrolled_at,
    s.customer_since,
    MIN(i.issued_at) AS first_invoice_date,
    MIN(i.issued_at) - s.enrolled_at AS days_to_first_invoice
FROM silver.vw_student_customer s
LEFT JOIN silver.invoices i ON s.customer_id = i.customer_id
GROUP BY s.student_id, s.customer_id, s.enrolled_at, s.customer_since;
ALTER TABLE gold.bridge_student_customer ADD PRIMARY KEY (student_id, customer_id);

-- HECHO CRUZADO: Student Customer (agregado para analisis)
-- Mantiene compatibilidad con notebooks existentes
DROP TABLE IF EXISTS gold.fact_student_customer CASCADE;
CREATE TABLE gold.fact_student_customer AS
WITH invoice_balance AS (
    SELECT
        i.invoice_id,
        i.customer_id,
        i.total,
        COALESCE(p.total_paid, 0) AS total_paid,
        i.total - COALESCE(p.total_paid, 0) AS balance_due
    FROM silver.invoices i
    LEFT JOIN (
        SELECT invoice_id, SUM(amount) AS total_paid
        FROM silver.payments
        GROUP BY invoice_id
    ) p ON i.invoice_id = p.invoice_id
)
SELECT
    s.student_id,
    s.student_first_name || ' ' || s.student_last_name AS student_name,
    s.student_country,
    s.enrolled_at,
    s.customer_id,
    s.student_first_name || ' ' || s.student_last_name AS customer_name,
    s.segment,
    s.customer_since,
    COUNT(DISTINCT i.invoice_id) AS total_invoices,
    COALESCE(SUM(i.total), 0) AS total_billed,
    COALESCE(SUM(i.balance_due), 0) AS total_balance
FROM silver.vw_student_customer s
LEFT JOIN invoice_balance i ON s.customer_id = i.customer_id
GROUP BY s.student_id, s.student_first_name, s.student_last_name, s.student_country,
         s.enrolled_at, s.customer_id, s.segment, s.customer_since;
ALTER TABLE gold.fact_student_customer ADD PRIMARY KEY (student_id, customer_id);

-- ============================================================
-- MARTES ANALITICOS / KPIs
-- ============================================================
-- Tablas agregadas pre-calculadas para consultas rapidas.
-- No forman parte del esquema estrella sino que son vistas
-- materializadas para reportes y dashboards.

-- KPI: Rendimiento por estudiante
DROP TABLE IF EXISTS gold.kpi_student_performance;
CREATE TABLE gold.kpi_student_performance AS
SELECT
    s.student_id,
    s.first_name || ' ' || s.last_name AS student_name,
    s.country,
    COUNT(DISTINCT e.course_id) AS total_courses,
    COUNT(DISTINCT g.grade_id) AS total_grades,
    ROUND(AVG(g.score), 2) AS avg_score,
    ROUND(SUM(g.score * g.weight) / NULLIF(SUM(g.weight), 0), 2) AS weighted_avg_score
FROM silver.students s
LEFT JOIN silver.enrollments e ON s.student_id = e.student_id
LEFT JOIN silver.grades g ON e.enrollment_id = g.enrollment_id
GROUP BY s.student_id, s.first_name, s.last_name, s.country;

-- KPI: Ingresos mensuales
DROP TABLE IF EXISTS gold.kpi_monthly_revenue;
CREATE TABLE gold.kpi_monthly_revenue AS
SELECT
    DATE_TRUNC('month', p.paid_at) AS month,
    COUNT(DISTINCT p.payment_id) AS total_payments,
    SUM(p.amount) AS total_revenue,
    COUNT(DISTINCT i.customer_id) AS paying_customers,
    SUM(p.amount) / NULLIF(COUNT(DISTINCT i.customer_id), 0) AS avg_revenue_per_customer
FROM silver.payments p
JOIN silver.invoices i ON p.invoice_id = i.invoice_id
GROUP BY DATE_TRUNC('month', p.paid_at)
ORDER BY month;

-- KPI: Pipeline de ventas
DROP TABLE IF EXISTS gold.kpi_sales_pipeline;
CREATE TABLE gold.kpi_sales_pipeline AS
SELECT
    stage,
    COUNT(*) AS opportunities_count,
    SUM(amount) AS total_amount,
    ROUND(AVG(amount), 2) AS avg_amount
FROM silver.opportunities
GROUP BY stage
ORDER BY
    CASE stage
        WHEN 'prospecting' THEN 1
        WHEN 'qualification' THEN 2
        WHEN 'proposal' THEN 3
        WHEN 'negotiation' THEN 4
        WHEN 'closed_won' THEN 5
        WHEN 'closed_lost' THEN 6
        ELSE 7
    END;

-- KPI: Conversion estudiante a cliente por pais
DROP TABLE IF EXISTS gold.kpi_student_to_customer;
CREATE TABLE gold.kpi_student_to_customer AS
SELECT
    s.country,
    COUNT(DISTINCT s.student_id) AS total_students,
    COUNT(DISTINCT fsc.customer_id) AS became_customers,
    ROUND(COUNT(DISTINCT fsc.customer_id) * 100.0 / NULLIF(COUNT(DISTINCT s.student_id), 0), 2) AS conversion_pct,
    ROUND(AVG(fsc.total_billed), 2) AS avg_revenue_per_student
FROM silver.students s
LEFT JOIN gold.fact_student_customer fsc ON s.student_id = fsc.student_id
GROUP BY s.country
ORDER BY conversion_pct DESC;

-- KPI: RFM - Segmentacion de clientes
DROP TABLE IF EXISTS gold.kpi_rfm_segments;
CREATE TABLE gold.kpi_rfm_segments AS
WITH rfm AS (
    SELECT
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.country,
        c.segment AS original_segment,
        MAX(i.issued_at) AS last_invoice_date,
        COUNT(i.invoice_id) AS frequency,
        SUM(i.total) AS monetary,
        CURRENT_DATE - MAX(i.issued_at) AS days_since_last_invoice
    FROM silver.customers c
    LEFT JOIN silver.invoices i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name, c.country, c.segment
)
SELECT
    customer_id, customer_name, country, original_segment,
    frequency, monetary, days_since_last_invoice,
    CASE
        WHEN days_since_last_invoice <= 90 AND frequency >= 20 AND monetary >= 2000 THEN 'VIP'
        WHEN days_since_last_invoice <= 180 AND frequency >= 10 THEN 'Frecuente'
        WHEN days_since_last_invoice <= 365 THEN 'Ocasional'
        ELSE 'Perdido'
    END AS rfm_segment
FROM rfm
ORDER BY monetary DESC;

-- KPI: Rendimiento por curso
DROP TABLE IF EXISTS gold.kpi_course_performance;
CREATE TABLE gold.kpi_course_performance AS
SELECT
    c.course_id,
    c.code,
    c.name AS course_name,
    c.department,
    COUNT(DISTINCT e.enrollment_id) AS total_students,
    ROUND(AVG(g.score), 2) AS avg_score,
    ROUND(SUM(g.score * g.weight) / NULLIF(SUM(g.weight), 0), 2) AS weighted_avg_score
FROM silver.courses c
LEFT JOIN silver.enrollments e ON c.course_id = e.course_id
LEFT JOIN silver.grades g ON e.enrollment_id = g.enrollment_id
GROUP BY c.course_id, c.code, c.name, c.department
ORDER BY avg_score DESC;

-- KPI: Carga docente por profesor
DROP TABLE IF EXISTS gold.kpi_professor_load;
CREATE TABLE gold.kpi_professor_load AS
SELECT
    p.professor_id,
    p.first_name || ' ' || p.last_name AS professor_name,
    p.department,
    COUNT(DISTINCT c.course_id) AS total_courses,
    COUNT(DISTINCT e.enrollment_id) AS total_students
FROM silver.professors p
LEFT JOIN silver.courses c ON p.professor_id = c.professor_id
LEFT JOIN silver.enrollments e ON c.course_id = e.course_id
GROUP BY p.professor_id, p.first_name, p.last_name, p.department
ORDER BY total_students DESC;

-- KPI: Churn de suscripciones
DROP TABLE IF EXISTS gold.kpi_subscription_churn;
CREATE TABLE gold.kpi_subscription_churn AS
SELECT
    p.category AS product_category,
    p.name AS product_name,
    COUNT(*) AS total_subscriptions,
    SUM(CASE WHEN s.status = 'active' THEN 1 ELSE 0 END) AS active,
    SUM(CASE WHEN s.status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled,
    ROUND(SUM(CASE WHEN s.status = 'cancelled' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS churn_rate_pct
FROM silver.subscriptions s
JOIN silver.products p ON s.product_id = p.product_id
GROUP BY p.category, p.name
ORDER BY churn_rate_pct DESC;

-- KPI: Ciclo de vida estudiante -> cliente
DROP TABLE IF EXISTS gold.kpi_student_lifecycle;
CREATE TABLE gold.kpi_student_lifecycle AS
SELECT
    fsc.student_name,
    fsc.student_country,
    fsc.enrolled_at AS enrollment_date,
    MIN(i.issued_at) AS first_invoice_date,
    MIN(i.issued_at) - fsc.enrolled_at AS days_to_first_invoice,
    fsc.total_billed
FROM gold.fact_student_customer fsc
LEFT JOIN silver.invoices i ON fsc.customer_id = i.customer_id
GROUP BY fsc.student_name, fsc.student_country, fsc.enrolled_at, fsc.total_billed
ORDER BY days_to_first_invoice;

-- KPI: Riesgo de cobranza
DROP TABLE IF EXISTS gold.kpi_collection_risk;
CREATE TABLE gold.kpi_collection_risk AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.country,
    COUNT(i.invoice_id) AS total_invoices,
    SUM(CASE WHEN i.balance_due > 0 THEN 1 ELSE 0 END) AS unpaid_invoices,
    SUM(i.balance_due) AS total_debt,
    ROUND(SUM(i.balance_due) * 100.0 / NULLIF(SUM(i.total), 0), 1) AS debt_ratio_pct,
    CASE
        WHEN SUM(i.balance_due) > 5000 THEN 'Alto'
        WHEN SUM(i.balance_due) > 1000 THEN 'Medio'
        WHEN SUM(i.balance_due) > 0 THEN 'Bajo'
        ELSE 'Sin deuda'
    END AS risk_level
FROM gold.fact_invoices i
JOIN silver.customers c ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.country
ORDER BY total_debt DESC;
