CREATE SCHEMA IF NOT EXISTS silver;

-- ============================================================
-- UNIVERSITY
-- ============================================================

DROP TABLE IF EXISTS silver.semesters CASCADE;
CREATE TABLE silver.semesters (
    semester_id INTEGER PRIMARY KEY,
    code VARCHAR(20) NOT NULL,
    year INTEGER NOT NULL,
    half INTEGER NOT NULL,
    start_date DATE,
    end_date DATE
);

DROP TABLE IF EXISTS silver.professors CASCADE;
CREATE TABLE silver.professors (
    professor_id INTEGER PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200),
    department VARCHAR(100),
    hired_at DATE
);

DROP TABLE IF EXISTS silver.students CASCADE;
CREATE TABLE silver.students (
    student_id INTEGER PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200),
    birth_date DATE,
    enrolled_at DATE NOT NULL,
    country VARCHAR(10)
);

DROP TABLE IF EXISTS silver.courses CASCADE;
CREATE TABLE silver.courses (
    course_id INTEGER PRIMARY KEY,
    code VARCHAR(20) NOT NULL,
    name VARCHAR(200) NOT NULL,
    credits NUMERIC(4,1),
    department VARCHAR(100),
    professor_id INTEGER REFERENCES silver.professors(professor_id)
);

DROP TABLE IF EXISTS silver.enrollments CASCADE;
CREATE TABLE silver.enrollments (
    enrollment_id INTEGER PRIMARY KEY,
    enrolled_at DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    student_id INTEGER NOT NULL REFERENCES silver.students(student_id),
    course_id INTEGER NOT NULL REFERENCES silver.courses(course_id),
    semester_id INTEGER NOT NULL REFERENCES silver.semesters(semester_id)
);

DROP TABLE IF EXISTS silver.grades CASCADE;
CREATE TABLE silver.grades (
    grade_id INTEGER PRIMARY KEY,
    assessment VARCHAR(100) NOT NULL,
    score NUMERIC(6,2),
    weight NUMERIC(4,3),
    graded_at DATE,
    enrollment_id INTEGER NOT NULL REFERENCES silver.enrollments(enrollment_id)
);

-- ============================================================
-- BILLING
-- ============================================================

DROP TABLE IF EXISTS silver.customers CASCADE;
CREATE TABLE silver.customers (
    customer_id INTEGER PRIMARY KEY,
    external_ref VARCHAR(50),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200),
    country VARCHAR(10),
    created_at DATE,
    segment VARCHAR(50)
);

DROP TABLE IF EXISTS silver.products CASCADE;
CREATE TABLE silver.products (
    product_id INTEGER PRIMARY KEY,
    sku VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    category VARCHAR(100),
    monthly_price NUMERIC(10,2) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

DROP TABLE IF EXISTS silver.subscriptions CASCADE;
CREATE TABLE silver.subscriptions (
    subscription_id INTEGER PRIMARY KEY,
    status VARCHAR(20) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    customer_id INTEGER NOT NULL REFERENCES silver.customers(customer_id),
    product_id INTEGER NOT NULL REFERENCES silver.products(product_id)
);

DROP TABLE IF EXISTS silver.invoices CASCADE;
CREATE TABLE silver.invoices (
    invoice_id INTEGER PRIMARY KEY,
    issued_at DATE NOT NULL,
    due_at DATE,
    total NUMERIC(12,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'USD',
    customer_id INTEGER NOT NULL REFERENCES silver.customers(customer_id)
);

DROP TABLE IF EXISTS silver.invoice_items CASCADE;
CREATE TABLE silver.invoice_items (
    invoice_item_id INTEGER PRIMARY KEY,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL,
    line_total NUMERIC(12,2) NOT NULL,
    invoice_id INTEGER NOT NULL REFERENCES silver.invoices(invoice_id),
    product_id INTEGER NOT NULL REFERENCES silver.products(product_id)
);

DROP TABLE IF EXISTS silver.payments CASCADE;
CREATE TABLE silver.payments (
    payment_id INTEGER PRIMARY KEY,
    amount NUMERIC(12,2) NOT NULL,
    paid_at DATE,
    method VARCHAR(50),
    invoice_id INTEGER NOT NULL REFERENCES silver.invoices(invoice_id)
);

-- ============================================================
-- CRM
-- ============================================================

DROP TABLE IF EXISTS silver.accounts CASCADE;
CREATE TABLE silver.accounts (
    account_id INTEGER PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    industry VARCHAR(100),
    country VARCHAR(10),
    annual_revenue NUMERIC(14,2),
    employees INTEGER,
    created_at DATE
);

DROP TABLE IF EXISTS silver.contacts CASCADE;
CREATE TABLE silver.contacts (
    contact_id INTEGER PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200),
    phone VARCHAR(50),
    title VARCHAR(200),
    created_at DATE,
    account_id INTEGER NOT NULL REFERENCES silver.accounts(account_id)
);

DROP TABLE IF EXISTS silver.leads CASCADE;
CREATE TABLE silver.leads (
    lead_id INTEGER PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(200),
    source VARCHAR(100),
    status VARCHAR(50),
    score NUMERIC(6,2),
    created_at DATE
);

DROP TABLE IF EXISTS silver.opportunities CASCADE;
CREATE TABLE silver.opportunities (
    opportunity_id INTEGER PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    stage VARCHAR(50) NOT NULL,
    amount NUMERIC(14,2),
    close_date DATE,
    created_at DATE,
    account_id INTEGER NOT NULL REFERENCES silver.accounts(account_id)
);

DROP TABLE IF EXISTS silver.opportunity_contacts CASCADE;
CREATE TABLE silver.opportunity_contacts (
    opportunity_id INTEGER NOT NULL REFERENCES silver.opportunities(opportunity_id),
    contact_id INTEGER NOT NULL REFERENCES silver.contacts(contact_id),
    role VARCHAR(100),
    PRIMARY KEY (opportunity_id, contact_id)
);

DROP TABLE IF EXISTS silver.activities CASCADE;
CREATE TABLE silver.activities (
    activity_id INTEGER PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    subject TEXT,
    occurred_at DATE,
    contact_id INTEGER REFERENCES silver.contacts(contact_id),
    opportunity_id INTEGER REFERENCES silver.opportunities(opportunity_id)
);

-- ============================================================
-- RELACIN CRUZADA: University Billing
-- ============================================================
-- customers.external_ref almacena el student_id del estudiante
-- que se convirti en cliente. Esta vista cruza ambos mundos.

DROP VIEW IF EXISTS silver.vw_student_customer CASCADE;
CREATE VIEW silver.vw_student_customer AS
SELECT
    s.student_id,
    s.first_name AS student_first_name,
    s.last_name AS student_last_name,
    s.country AS student_country,
    s.enrolled_at,
    c.customer_id,
    c.segment,
    c.created_at AS customer_since
FROM silver.students s
JOIN silver.customers c ON c.external_ref = 'STU-' || LPAD(s.student_id::TEXT, 7, '0');
