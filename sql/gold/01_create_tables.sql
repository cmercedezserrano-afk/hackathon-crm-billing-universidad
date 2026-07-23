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
DROP TABLE IF EXISTS gold.date_dim CASCADE;
CREATE TABLE gold.date_dim AS
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

ALTER TABLE gold.date_dim ADD PRIMARY KEY (date_sk);
CREATE UNIQUE INDEX IF NOT EXISTS idx_dim_date_date ON gold.date_dim(date);

-- UNIVERSITY
DROP TABLE IF EXISTS gold.semesters CASCADE;
CREATE TABLE gold.semesters AS SELECT * FROM silver.semesters;
ALTER TABLE gold.semesters ADD PRIMARY KEY (semester_id);

DROP TABLE IF EXISTS gold.professors CASCADE;
CREATE TABLE gold.professors AS SELECT * FROM silver.professors;
ALTER TABLE gold.professors ADD PRIMARY KEY (professor_id);

DROP TABLE IF EXISTS gold.students CASCADE;
CREATE TABLE gold.students AS
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
ALTER TABLE gold.students ADD PRIMARY KEY (student_id);

DROP TABLE IF EXISTS gold.courses CASCADE;
CREATE TABLE gold.courses AS SELECT * FROM silver.courses;
ALTER TABLE gold.courses ADD PRIMARY KEY (course_id);

-- BILLING
DROP TABLE IF EXISTS gold.customers CASCADE;
CREATE TABLE gold.customers AS
SELECT
    *,
    EXTRACT(YEAR FROM AGE(created_at))::INTEGER AS tenure_years
FROM silver.customers;
ALTER TABLE gold.customers ADD PRIMARY KEY (customer_id);

DROP TABLE IF EXISTS gold.products CASCADE;
CREATE TABLE gold.products AS
SELECT
    *,
    CASE
        WHEN monthly_price < 30 THEN 'Basico'
        WHEN monthly_price < 60 THEN 'Estandar'
        ELSE 'Premium'
    END AS price_tier
FROM silver.products;
ALTER TABLE gold.products ADD PRIMARY KEY (product_id);

-- CRM
DROP TABLE IF EXISTS gold.accounts CASCADE;
CREATE TABLE gold.accounts AS SELECT * FROM silver.accounts;
ALTER TABLE gold.accounts ADD PRIMARY KEY (account_id);

DROP TABLE IF EXISTS gold.contacts CASCADE;
CREATE TABLE gold.contacts AS SELECT * FROM silver.contacts;
ALTER TABLE gold.contacts ADD PRIMARY KEY (contact_id);

DROP TABLE IF EXISTS gold.leads CASCADE;
CREATE TABLE gold.leads AS SELECT * FROM silver.leads;
ALTER TABLE gold.leads ADD PRIMARY KEY (lead_id);

-- ============================================================
-- TABLAS DE HECHOS (ESTRELLA)
-- ============================================================
-- Cada hecho responde a preguntas de negocio especificas.
-- Las columnas date_sk vinculan a dim_date para analisis temporal.

-- CASO DE USO: "?Que cursos tienen mayor/menor rendimiento por semestre?"
-- HECHO: fact_enrollments
-- Granularidad: 1 fila por inscripcion
DROP TABLE IF EXISTS gold.enrollments CASCADE;
CREATE TABLE gold.enrollments AS
SELECT
    e.enrollment_id,
    e.student_id,
    e.course_id,
    e.semester_id,
    e.enrolled_at AS enrollment_date,
    dd.date_sk AS enrolled_date_sk,
    e.status
FROM silver.enrollments e
LEFT JOIN gold.date_dim dd ON e.enrolled_at::DATE = dd.date;
ALTER TABLE gold.enrollments ADD PRIMARY KEY (enrollment_id);
CREATE INDEX IF NOT EXISTS idx_fact_enrollments_student ON gold.enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_fact_enrollments_course ON gold.enrollments(course_id);

-- CASO DE USO: "?Cual es el promedio de notas por curso, pais del estudiante y semestre?"
-- HECHO: fact_grades (desnormalizado con claves de dimension directas para consultas estrella)
-- Granularidad: 1 fila por calificacion
DROP TABLE IF EXISTS gold.grades CASCADE;
CREATE TABLE gold.grades AS
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
LEFT JOIN gold.date_dim dd ON g.graded_at::DATE = dd.date;
ALTER TABLE gold.grades ADD PRIMARY KEY (grade_id);
CREATE INDEX IF NOT EXISTS idx_fact_grades_student ON gold.grades(student_id);
CREATE INDEX IF NOT EXISTS idx_fact_grades_course ON gold.grades(course_id);
CREATE INDEX IF NOT EXISTS idx_fact_grades_semester ON gold.grades(semester_id);

-- CASO DE USO: "?Que productos tienen mayor/menor retencion de clientes?"
-- HECHO: fact_subscriptions
-- Granularidad: 1 fila por suscripcion
DROP TABLE IF EXISTS gold.subscriptions CASCADE;
CREATE TABLE gold.subscriptions AS
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
LEFT JOIN gold.date_dim dd_start ON s.start_date::DATE = dd_start.date
LEFT JOIN gold.date_dim dd_end ON s.end_date::DATE = dd_end.date;
ALTER TABLE gold.subscriptions ADD PRIMARY KEY (subscription_id);
CREATE INDEX IF NOT EXISTS idx_fact_subscriptions_customer ON gold.subscriptions(customer_id);
CREATE INDEX IF NOT EXISTS idx_fact_subscriptions_product ON gold.subscriptions(product_id);

-- CASO DE USO: "?Cual es la tendencia de ingresos mensuales? ?Que clientes tienen saldo pendiente?"
-- HECHO: fact_invoices
-- Granularidad: 1 fila por factura
DROP TABLE IF EXISTS gold.invoices CASCADE;
CREATE TABLE gold.invoices AS
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
LEFT JOIN gold.date_dim dd_issued ON i.issued_at::DATE = dd_issued.date
LEFT JOIN gold.date_dim dd_due ON i.due_at::DATE = dd_due.date
LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS total_paid
    FROM silver.payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id;
ALTER TABLE gold.invoices ADD PRIMARY KEY (invoice_id);
CREATE INDEX IF NOT EXISTS idx_fact_invoices_customer ON gold.invoices(customer_id);

DROP TABLE IF EXISTS gold.invoice_items CASCADE;
CREATE TABLE gold.invoice_items AS SELECT * FROM silver.invoice_items;
ALTER TABLE gold.invoice_items ADD PRIMARY KEY (invoice_item_id);

-- CASO DE USO: "?Cual es el volumen de pagos por metodo y mes?"
-- HECHO: fact_payments (separado de fact_invoices para granularidad de pago)
-- Granularidad: 1 fila por pago
DROP TABLE IF EXISTS gold.payments CASCADE;
CREATE TABLE gold.payments AS
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
LEFT JOIN gold.date_dim dd ON p.paid_at::DATE = dd.date;
ALTER TABLE gold.payments ADD PRIMARY KEY (payment_id);
CREATE INDEX IF NOT EXISTS idx_fact_payments_invoice ON gold.payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_fact_payments_customer ON gold.payments(customer_id);

-- CASO DE USO: "?Cual es el valor del pipeline de ventas por etapa?"
-- HECHO: fact_opportunities
-- Granularidad: 1 fila por oportunidad
DROP TABLE IF EXISTS gold.opportunities CASCADE;
CREATE TABLE gold.opportunities AS
SELECT
    o.opportunity_id,
    o.account_id,
    o.name,
    o.stage,
    o.amount,
    o.close_date,
    dd_close.date_sk AS close_date_sk,
    o.created_at,
    dd_created.date_sk AS created_date_sk
FROM silver.opportunities o
LEFT JOIN gold.date_dim dd_close ON o.close_date::DATE = dd_close.date
LEFT JOIN gold.date_dim dd_created ON o.created_at::DATE = dd_created.date;
ALTER TABLE gold.opportunities ADD PRIMARY KEY (opportunity_id);
CREATE INDEX IF NOT EXISTS idx_fact_opportunities_account ON gold.opportunities(account_id);

DROP TABLE IF EXISTS gold.opportunity_contacts CASCADE;
CREATE TABLE gold.opportunity_contacts AS SELECT * FROM silver.opportunity_contacts;
ALTER TABLE gold.opportunity_contacts ADD PRIMARY KEY (opportunity_id, contact_id);

-- CASO DE USO: "?Cuales son las actividades de seguimiento por contacto y oportunidad?"
-- HECHO: fact_activities
-- Granularidad: 1 fila por actividad
DROP TABLE IF EXISTS gold.activities CASCADE;
CREATE TABLE gold.activities AS
SELECT
    a.activity_id,
    a.contact_id,
    a.opportunity_id,
    a.type,
    a.subject,
    a.occurred_at,
    dd.date_sk AS occurred_date_sk
FROM silver.activities a
LEFT JOIN gold.date_dim dd ON a.occurred_at::DATE = dd.date;
ALTER TABLE gold.activities ADD PRIMARY KEY (activity_id);

-- ============================================================
-- MARTES ANALITICOS / KPIs
-- ============================================================
-- Tablas agregadas pre-calculadas para consultas rapidas.
-- No forman parte del esquema estrella sino que son vistas
-- materializadas para reportes y dashboards.

-- KPI: Rendimiento por estudiante
DROP TABLE IF EXISTS gold.calculo_tabestudiantes_tabmatriculas_tabnotas_datopromedio;
CREATE TABLE gold.calculo_tabestudiantes_tabmatriculas_tabnotas_datopromedio AS
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
DROP TABLE IF EXISTS gold.calculo_tabpagos_tabfacturas_datorecaudacion;
CREATE TABLE gold.calculo_tabpagos_tabfacturas_datorecaudacion AS
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

-- KPI: Pipeline de ventas (etapas en espanol)
DROP TABLE IF EXISTS gold.calculo_taboportunidades_datomontoporetapa;
CREATE TABLE gold.calculo_taboportunidades_datomontoporetapa AS
SELECT
    CASE stage
        WHEN 'prospect' THEN 'Prospeccion'
        WHEN 'qualification' THEN 'Calificacion'
        WHEN 'proposal' THEN 'Propuesta'
        WHEN 'negotiation' THEN 'Negociacion'
        WHEN 'won' THEN 'Ganada'
        WHEN 'lost' THEN 'Perdida'
        ELSE stage
    END AS etapa,
    COUNT(*) AS oportunidades,
    SUM(amount) AS monto_total,
    ROUND(AVG(amount), 2) AS monto_promedio
FROM silver.opportunities
GROUP BY stage
ORDER BY
    CASE stage
        WHEN 'prospect' THEN 1
        WHEN 'qualification' THEN 2
        WHEN 'proposal' THEN 3
        WHEN 'negotiation' THEN 4
        WHEN 'won' THEN 5
        WHEN 'lost' THEN 6
        ELSE 7
    END;

-- KPI: Conversion estudiante a cliente por pais
DROP TABLE IF EXISTS gold.calculo_tabestudiantes_tabclientes_datoconversion;
CREATE TABLE gold.calculo_tabestudiantes_tabclientes_datoconversion AS
SELECT
    s.country,
    COUNT(DISTINCT s.student_id) AS total_students,
    COUNT(DISTINCT v.customer_id) AS became_customers,
    ROUND(COUNT(DISTINCT v.customer_id) * 100.0 / NULLIF(COUNT(DISTINCT s.student_id), 0), 2) AS conversion_pct,
    ROUND(COALESCE(AVG(inv.total), 0), 2) AS avg_revenue_per_student
FROM silver.students s
LEFT JOIN silver.vw_student_customer v ON s.student_id = v.student_id
LEFT JOIN silver.invoices inv ON v.customer_id = inv.customer_id
GROUP BY s.country
ORDER BY conversion_pct DESC;

-- KPI: RFM - Segmentacion de clientes
DROP TABLE IF EXISTS gold.calculo_tabclientes_datorfm;
CREATE TABLE gold.calculo_tabclientes_datorfm AS
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
DROP TABLE IF EXISTS gold.calculo_tabcursos_tabmatriculas_tabnotas_datopromedio;
CREATE TABLE gold.calculo_tabcursos_tabmatriculas_tabnotas_datopromedio AS
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
DROP TABLE IF EXISTS gold.calculo_tabprofesores_tabcursos_tabmatriculas_datoalumnos;
CREATE TABLE gold.calculo_tabprofesores_tabcursos_tabmatriculas_datoalumnos AS
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
DROP TABLE IF EXISTS gold.calculo_tabsuscripciones_tabproductos_datotasaabandono;
CREATE TABLE gold.calculo_tabsuscripciones_tabproductos_datotasaabandono AS
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
DROP TABLE IF EXISTS gold.calculo_tabestudiantes_tabclientes_datociclovida;
CREATE TABLE gold.calculo_tabestudiantes_tabclientes_datociclovida AS
SELECT
    v.student_first_name || ' ' || v.student_last_name AS student_name,
    v.student_country,
    v.enrolled_at AS enrollment_date,
    MIN(inv.issued_at) AS first_invoice_date,
    MIN(inv.issued_at) - v.enrolled_at AS days_to_first_invoice,
    COALESCE(SUM(inv.total), 0) AS total_billed
FROM silver.vw_student_customer v
LEFT JOIN silver.invoices inv ON v.customer_id = inv.customer_id
GROUP BY v.student_id, v.student_first_name, v.student_last_name, v.student_country, v.enrolled_at
ORDER BY days_to_first_invoice;

-- KPI: Riesgo de cobranza
DROP TABLE IF EXISTS gold.calculo_tabclientes_tabfacturas_datoriesgo;
CREATE TABLE gold.calculo_tabclientes_tabfacturas_datoriesgo AS
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
FROM gold.invoices i
JOIN silver.customers c ON i.customer_id = c.customer_id
GROUP BY c.customer_id, c.first_name, c.last_name, c.country
ORDER BY total_debt DESC;

-- KPI: Tasa de aprobacion por curso (nota minima 51)
DROP TABLE IF EXISTS gold.calculo_tabcursos_tabmatriculas_tabnotas_datoaprobacion;
CREATE TABLE gold.calculo_tabcursos_tabmatriculas_tabnotas_datoaprobacion AS
SELECT
    c.course_id,
    c.code,
    c.name AS course_name,
    c.department,
    COUNT(DISTINCT e.student_id) AS total_students,
    ROUND(AVG(g.score), 2) AS avg_score,
    SUM(CASE WHEN g.score >= 51 THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN g.score < 51 THEN 1 ELSE 0 END) AS failed,
    ROUND(SUM(CASE WHEN g.score >= 51 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(g.grade_id), 0), 1) AS pass_rate_pct,
    ROUND(SUM(CASE WHEN g.score < 51 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(g.grade_id), 0), 1) AS fail_rate_pct
FROM silver.courses c
LEFT JOIN silver.enrollments e ON c.course_id = e.course_id
LEFT JOIN silver.grades g ON e.enrollment_id = g.enrollment_id
GROUP BY c.course_id, c.code, c.name, c.department
ORDER BY pass_rate_pct DESC;

-- KPI: Matriculas por semestre
DROP TABLE IF EXISTS gold.calculo_tabsemestres_tabmatriculas_datoinscripciones;
CREATE TABLE gold.calculo_tabsemestres_tabmatriculas_datoinscripciones AS
SELECT
    sem.semester_id,
    sem.code AS semester_name,
    sem.start_date,
    sem.end_date,
    COUNT(DISTINCT e.enrollment_id) AS total_enrollments,
    COUNT(DISTINCT e.student_id) AS total_students,
    COUNT(DISTINCT e.course_id) AS total_courses
FROM silver.semesters sem
LEFT JOIN silver.enrollments e ON sem.semester_id = e.semester_id
GROUP BY sem.semester_id, sem.code, sem.start_date, sem.end_date
ORDER BY sem.start_date;
