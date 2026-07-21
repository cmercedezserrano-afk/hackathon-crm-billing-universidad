-- ============================================================
-- CAPA GOLD: Modelo Dimensional (Estrella)
-- ============================================================
-- Organizamos los datos en DIMENSIONES (tablas descriptivas)
-- y HECHOS (tablas de mediciones). Esto hace que las consultas
-- sean rpidas y fciles de entender.

CREATE SCHEMA IF NOT EXISTS gold;

-- ============================================================
-- DIMENSIONES COMPARTIDAS
-- ============================================================

DROP TABLE IF EXISTS gold.dim_date CASCADE;
CREATE TABLE gold.dim_date AS
SELECT DISTINCT
    d::DATE AS date,
    EXTRACT(YEAR FROM d) AS year,
    EXTRACT(MONTH FROM d) AS month,
    EXTRACT(QUARTER FROM d) AS quarter,
    TO_CHAR(d, 'Day') AS day_name,
    EXTRACT(DOW FROM d) AS day_of_week
FROM GENERATE_SERIES('2018-01-01'::DATE, '2026-12-31'::DATE, '1 day') AS d;

ALTER TABLE gold.dim_date ADD PRIMARY KEY (date);

-- UNIVERSITY
DROP TABLE IF EXISTS gold.dim_semesters CASCADE;
CREATE TABLE gold.dim_semesters AS SELECT * FROM silver.semesters;
ALTER TABLE gold.dim_semesters ADD PRIMARY KEY (semester_id);

DROP TABLE IF EXISTS gold.dim_professors CASCADE;
CREATE TABLE gold.dim_professors AS SELECT * FROM silver.professors;
ALTER TABLE gold.dim_professors ADD PRIMARY KEY (professor_id);

DROP TABLE IF EXISTS gold.dim_students CASCADE;
CREATE TABLE gold.dim_students AS SELECT * FROM silver.students;
ALTER TABLE gold.dim_students ADD PRIMARY KEY (student_id);

DROP TABLE IF EXISTS gold.dim_courses CASCADE;
CREATE TABLE gold.dim_courses AS SELECT * FROM silver.courses;
ALTER TABLE gold.dim_courses ADD PRIMARY KEY (course_id);

-- BILLING
DROP TABLE IF EXISTS gold.dim_customers CASCADE;
CREATE TABLE gold.dim_customers AS SELECT * FROM silver.customers;
ALTER TABLE gold.dim_customers ADD PRIMARY KEY (customer_id);

DROP TABLE IF EXISTS gold.dim_products CASCADE;
CREATE TABLE gold.dim_products AS SELECT * FROM silver.products;
ALTER TABLE gold.dim_products ADD PRIMARY KEY (product_id);

-- CRM
DROP TABLE IF EXISTS gold.dim_accounts CASCADE;
CREATE TABLE gold.dim_accounts AS SELECT * FROM silver.accounts;
ALTER TABLE gold.dim_accounts ADD PRIMARY KEY (account_id);

DROP TABLE IF EXISTS gold.dim_contacts CASCADE;
CREATE TABLE gold.dim_contacts AS SELECT * FROM silver.contacts;
ALTER TABLE gold.dim_contacts ADD PRIMARY KEY (contact_id);

-- ============================================================
-- TABLAS DE HECHOS
-- ============================================================

DROP TABLE IF EXISTS gold.fact_enrollments CASCADE;
CREATE TABLE gold.fact_enrollments AS
SELECT
    e.enrollment_id,
    e.student_id,
    e.course_id,
    e.semester_id,
    e.enrolled_at AS enrollment_date,
    e.status
FROM silver.enrollments e;

ALTER TABLE gold.fact_enrollments ADD PRIMARY KEY (enrollment_id);

DROP TABLE IF EXISTS gold.fact_grades CASCADE;
CREATE TABLE gold.fact_grades AS
SELECT
    g.grade_id,
    g.enrollment_id,
    g.assessment,
    g.score,
    g.weight,
    g.score * g.weight AS weighted_score,
    g.graded_at
FROM silver.grades g;

ALTER TABLE gold.fact_grades ADD PRIMARY KEY (grade_id);

DROP TABLE IF EXISTS gold.fact_subscriptions CASCADE;
CREATE TABLE gold.fact_subscriptions AS
SELECT
    s.subscription_id,
    s.customer_id,
    s.product_id,
    s.start_date,
    s.end_date,
    s.status,
    COALESCE(s.end_date, CURRENT_DATE) - s.start_date AS days_active
FROM silver.subscriptions s;

ALTER TABLE gold.fact_subscriptions ADD PRIMARY KEY (subscription_id);

DROP TABLE IF EXISTS gold.fact_invoices CASCADE;
CREATE TABLE gold.fact_invoices AS
SELECT
    i.invoice_id,
    i.customer_id,
    i.issued_at,
    i.due_at,
    i.total,
    i.status,
    i.currency,
    COALESCE(p.total_paid, 0) AS total_paid,
    i.total - COALESCE(p.total_paid, 0) AS balance_due
FROM silver.invoices i
LEFT JOIN (
    SELECT invoice_id, SUM(amount) AS total_paid
    FROM silver.payments
    GROUP BY invoice_id
) p ON i.invoice_id = p.invoice_id;

ALTER TABLE gold.fact_invoices ADD PRIMARY KEY (invoice_id);

DROP TABLE IF EXISTS gold.fact_opportunities CASCADE;
CREATE TABLE gold.fact_opportunities AS
SELECT
    o.opportunity_id,
    o.account_id,
    o.name,
    o.stage,
    o.amount,
    o.close_date,
    o.created_at
FROM silver.opportunities o;

ALTER TABLE gold.fact_opportunities ADD PRIMARY KEY (opportunity_id);

-- ============================================================
-- HECHO CRUZADO: Student  Customer
-- ============================================================
-- Esta tabla une University con Billing: un estudiante
-- que se convierte en cliente. El vnculo es external_ref.

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
-- TABLAS AGRAGADAS / KPIs
-- ============================================================

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

-- ============================================================
-- KPI CRUZADO: Estudiantes que tambin son clientes
-- ============================================================

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

-- ============================================================
-- KPI: RFM - Segmentacin de clientes
-- ============================================================
-- Clasifica clientes segn:
-- R (Recencia): ltima factura
-- F (Frecuencia): cantidad de facturas
-- M (Monto): total facturado

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

-- ============================================================
-- KPI: Rendimiento por curso
-- ============================================================

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

-- ============================================================
-- KPI: Carga docente por profesor
-- ============================================================

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

-- ============================================================
-- KPI: Churn de suscripciones
-- ============================================================

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

-- ============================================================
-- KPI: Ciclo de vida estudiante -> cliente
-- ============================================================

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

-- ============================================================
-- KPI: Riesgo de cobranza
-- ============================================================

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
