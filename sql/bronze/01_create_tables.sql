CREATE SCHEMA IF NOT EXISTS bronze;

-- ============================================================
-- UNIVERSITY
-- ============================================================

DROP TABLE IF EXISTS bronze.semesters;
CREATE TABLE bronze.semesters (
    semester_id TEXT,
    code TEXT,
    year TEXT,
    half TEXT,
    start_date TEXT,
    end_date TEXT
);

DROP TABLE IF EXISTS bronze.professors;
CREATE TABLE bronze.professors (
    professor_id TEXT,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    department TEXT,
    hired_at TEXT
);

DROP TABLE IF EXISTS bronze.students;
CREATE TABLE bronze.students (
    student_id TEXT,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    birth_date TEXT,
    enrolled_at TEXT,
    country TEXT
);

DROP TABLE IF EXISTS bronze.courses;
CREATE TABLE bronze.courses (
    course_id TEXT,
    code TEXT,
    name TEXT,
    credits TEXT,
    department TEXT,
    professor_id TEXT
);

DROP TABLE IF EXISTS bronze.enrollments;
CREATE TABLE bronze.enrollments (
    enrollment_id TEXT,
    enrolled_at TEXT,
    status TEXT,
    student_id TEXT,
    course_id TEXT,
    semester_id TEXT
);

DROP TABLE IF EXISTS bronze.grades;
CREATE TABLE bronze.grades (
    grade_id TEXT,
    assessment TEXT,
    score TEXT,
    weight TEXT,
    graded_at TEXT,
    enrollment_id TEXT
);

-- ============================================================
-- BILLING
-- ============================================================

DROP TABLE IF EXISTS bronze.customers;
CREATE TABLE bronze.customers (
    customer_id TEXT,
    external_ref TEXT,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    country TEXT,
    created_at TEXT,
    segment TEXT
);

DROP TABLE IF EXISTS bronze.products;
CREATE TABLE bronze.products (
    product_id TEXT,
    sku TEXT,
    name TEXT,
    category TEXT,
    monthly_price TEXT,
    active TEXT
);

DROP TABLE IF EXISTS bronze.subscriptions;
CREATE TABLE bronze.subscriptions (
    subscription_id TEXT,
    status TEXT,
    start_date TEXT,
    end_date TEXT,
    customer_id TEXT,
    product_id TEXT
);

DROP TABLE IF EXISTS bronze.invoices;
CREATE TABLE bronze.invoices (
    invoice_id TEXT,
    issued_at TEXT,
    due_at TEXT,
    total TEXT,
    status TEXT,
    currency TEXT,
    customer_id TEXT
);

DROP TABLE IF EXISTS bronze.invoice_items;
CREATE TABLE bronze.invoice_items (
    invoice_item_id TEXT,
    quantity TEXT,
    unit_price TEXT,
    line_total TEXT,
    invoice_id TEXT,
    product_id TEXT
);

DROP TABLE IF EXISTS bronze.payments;
CREATE TABLE bronze.payments (
    payment_id TEXT,
    amount TEXT,
    paid_at TEXT,
    method TEXT,
    invoice_id TEXT
);

-- ============================================================
-- CRM
-- ============================================================

DROP TABLE IF EXISTS bronze.accounts;
CREATE TABLE bronze.accounts (
    account_id TEXT,
    name TEXT,
    industry TEXT,
    country TEXT,
    annual_revenue TEXT,
    employees TEXT,
    created_at TEXT
);

DROP TABLE IF EXISTS bronze.contacts;
CREATE TABLE bronze.contacts (
    contact_id TEXT,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    phone TEXT,
    title TEXT,
    created_at TEXT,
    account_id TEXT
);

DROP TABLE IF EXISTS bronze.leads;
CREATE TABLE bronze.leads (
    lead_id TEXT,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    source TEXT,
    status TEXT,
    score TEXT,
    created_at TEXT
);

DROP TABLE IF EXISTS bronze.opportunities;
CREATE TABLE bronze.opportunities (
    opportunity_id TEXT,
    name TEXT,
    stage TEXT,
    amount TEXT,
    close_date TEXT,
    created_at TEXT,
    account_id TEXT
);

DROP TABLE IF EXISTS bronze.opportunity_contacts;
CREATE TABLE bronze.opportunity_contacts (
    opportunity_id TEXT,
    contact_id TEXT,
    role TEXT
);

DROP TABLE IF EXISTS bronze.activities;
CREATE TABLE bronze.activities (
    activity_id TEXT,
    type TEXT,
    subject TEXT,
    occurred_at TEXT,
    contact_id TEXT,
    opportunity_id TEXT
);
