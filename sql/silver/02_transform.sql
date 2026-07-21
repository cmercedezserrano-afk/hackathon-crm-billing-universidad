-- ============================================================
-- TRANSFORMACIN: Bronze  Silver
-- ============================================================
-- Cada paso extrae el nmero del ID (CUS-0000001  1),
-- convierte textos a tipos correctos y maneja nulos.
-- Las llaves forneas garantizan que solo existan
-- relaciones vlidas entre tablas.

-- ============================================================
-- 1. UNIVERSITY
-- ============================================================

INSERT INTO silver.semesters
SELECT
    CAST(SPLIT_PART(semester_id, '-', 2) AS INTEGER),
    code,
    CAST(year AS INTEGER),
    CAST(half AS INTEGER),
    NULLIF(start_date, '')::DATE,
    NULLIF(end_date, '')::DATE
FROM bronze.semesters;

INSERT INTO silver.professors
SELECT
    CAST(SPLIT_PART(professor_id, '-', 2) AS INTEGER),
    first_name,
    last_name,
    email,
    department,
    NULLIF(hired_at, '')::DATE
FROM bronze.professors;

INSERT INTO silver.students
SELECT
    CAST(SPLIT_PART(student_id, '-', 2) AS INTEGER),
    first_name,
    last_name,
    email,
    NULLIF(birth_date, '')::DATE,
    NULLIF(enrolled_at, '')::DATE,
    country
FROM bronze.students;

INSERT INTO silver.courses
SELECT
    CAST(SPLIT_PART(course_id, '-', 2) AS INTEGER),
    code,
    name,
    NULLIF(credits, '')::NUMERIC(4,1),
    department,
    NULLIF(SPLIT_PART(NULLIF(professor_id, ''), '-', 2), '')::INTEGER
FROM bronze.courses;

INSERT INTO silver.enrollments
SELECT
    CAST(SPLIT_PART(enrollment_id, '-', 2) AS INTEGER),
    NULLIF(enrolled_at, '')::DATE,
    status,
    SPLIT_PART(student_id, '-', 2)::INTEGER,
    SPLIT_PART(course_id, '-', 2)::INTEGER,
    SPLIT_PART(semester_id, '-', 2)::INTEGER
FROM bronze.enrollments;

INSERT INTO silver.grades
SELECT
    CAST(SPLIT_PART(grade_id, '-', 2) AS INTEGER),
    assessment,
    NULLIF(score, '')::NUMERIC(6,2),
    NULLIF(weight, '')::NUMERIC(4,3),
    NULLIF(graded_at, '')::DATE,
    SPLIT_PART(enrollment_id, '-', 2)::INTEGER
FROM bronze.grades;

-- ============================================================
-- 2. BILLING
-- ============================================================

INSERT INTO silver.customers
SELECT
    CAST(SPLIT_PART(customer_id, '-', 2) AS INTEGER),
    external_ref,
    first_name,
    last_name,
    email,
    country,
    NULLIF(created_at, '')::DATE,
    segment
FROM bronze.customers;

INSERT INTO silver.products
SELECT
    CAST(SPLIT_PART(product_id, '-', 2) AS INTEGER),
    sku,
    name,
    category,
    NULLIF(monthly_price, '')::NUMERIC(10,2),
    CASE WHEN LOWER(active) IN ('true', '1', 'yes') THEN TRUE ELSE FALSE END
FROM bronze.products;

INSERT INTO silver.subscriptions
SELECT
    CAST(SPLIT_PART(subscription_id, '-', 2) AS INTEGER),
    status,
    NULLIF(start_date, '')::DATE,
    NULLIF(end_date, '')::DATE,
    SPLIT_PART(customer_id, '-', 2)::INTEGER,
    SPLIT_PART(product_id, '-', 2)::INTEGER
FROM bronze.subscriptions;

INSERT INTO silver.invoices
SELECT
    CAST(SPLIT_PART(invoice_id, '-', 2) AS INTEGER),
    NULLIF(issued_at, '')::DATE,
    NULLIF(due_at, '')::DATE,
    NULLIF(total, '')::NUMERIC(12,2),
    status,
    currency,
    SPLIT_PART(customer_id, '-', 2)::INTEGER
FROM bronze.invoices;

INSERT INTO silver.invoice_items
SELECT
    CAST(SPLIT_PART(invoice_item_id, '-', 2) AS INTEGER),
    NULLIF(quantity, '')::INTEGER,
    NULLIF(unit_price, '')::NUMERIC(10,2),
    NULLIF(line_total, '')::NUMERIC(12,2),
    SPLIT_PART(invoice_id, '-', 2)::INTEGER,
    SPLIT_PART(product_id, '-', 2)::INTEGER
FROM bronze.invoice_items;

INSERT INTO silver.payments
SELECT
    CAST(SPLIT_PART(payment_id, '-', 2) AS INTEGER),
    NULLIF(amount, '')::NUMERIC(12,2),
    NULLIF(paid_at, '')::DATE,
    method,
    SPLIT_PART(invoice_id, '-', 2)::INTEGER
FROM bronze.payments;

-- ============================================================
-- 3. CRM
-- ============================================================

INSERT INTO silver.accounts
SELECT
    CAST(SPLIT_PART(account_id, '-', 2) AS INTEGER),
    name,
    industry,
    country,
    NULLIF(annual_revenue, '')::NUMERIC(14,2),
    NULLIF(employees, '')::INTEGER,
    NULLIF(created_at, '')::DATE
FROM bronze.accounts;

INSERT INTO silver.contacts
SELECT
    CAST(SPLIT_PART(contact_id, '-', 2) AS INTEGER),
    first_name,
    last_name,
    email,
    phone,
    title,
    NULLIF(created_at, '')::DATE,
    SPLIT_PART(account_id, '-', 2)::INTEGER
FROM bronze.contacts;

INSERT INTO silver.leads
SELECT
    CAST(SPLIT_PART(lead_id, '-', 2) AS INTEGER),
    first_name,
    last_name,
    email,
    source,
    status,
    NULLIF(score, '')::NUMERIC(6,2),
    NULLIF(created_at, '')::DATE
FROM bronze.leads;

INSERT INTO silver.opportunities
SELECT
    CAST(SPLIT_PART(opportunity_id, '-', 2) AS INTEGER),
    name,
    stage,
    NULLIF(amount, '')::NUMERIC(14,2),
    NULLIF(close_date, '')::DATE,
    NULLIF(created_at, '')::DATE,
    SPLIT_PART(account_id, '-', 2)::INTEGER
FROM bronze.opportunities;

INSERT INTO silver.opportunity_contacts
SELECT
    SPLIT_PART(opportunity_id, '-', 2)::INTEGER,
    SPLIT_PART(contact_id, '-', 2)::INTEGER,
    role
FROM bronze.opportunity_contacts;

INSERT INTO silver.activities
SELECT
    CAST(SPLIT_PART(activity_id, '-', 2) AS INTEGER),
    type,
    subject,
    NULLIF(occurred_at, '')::DATE,
    NULLIF(SPLIT_PART(NULLIF(contact_id, ''), '-', 2), '')::INTEGER,
    NULLIF(SPLIT_PART(NULLIF(opportunity_id, ''), '-', 2), '')::INTEGER
FROM bronze.activities;
