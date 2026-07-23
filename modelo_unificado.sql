-- ============================================================
-- MODELO UNIFICADO: UNIVERSIDAD + CRM + BILLING
-- Generado a partir de los diagramas ER (mermaid) proporcionados
-- Dialecto: estándar SQL (compatible con PostgreSQL / MySQL)
-- Notas:
--   * Los IDs se modelan como VARCHAR(36) pensando en UUIDs.
--     Si tus IDs son numéricos autoincrementales, cambia el tipo
--     a INT / BIGINT y ajusta las PK según corresponda.
--   * Los campos "string" sin longitud especificada en el mermaid
--     se mapearon a VARCHAR(150) por defecto (ajustable).
--   * Las tablas están en orden de dependencia para que el script
--     corra sin errores de FK.
-- ============================================================

-- ============================================================
-- TABLAS SIN DEPENDENCIAS
-- ============================================================

CREATE TABLE LEADS (
    lead_id      VARCHAR(36)  PRIMARY KEY,
    first_name   VARCHAR(150),
    last_name    VARCHAR(150),
    email        VARCHAR(150),
    company      VARCHAR(150),
    status       VARCHAR(50)  -- new, qualified, converted
);

CREATE TABLE CUSTOMERS (
    customer_id  VARCHAR(36)  PRIMARY KEY,
    external_ref VARCHAR(150),
    first_name   VARCHAR(150),
    last_name    VARCHAR(150),
    email        VARCHAR(150),
    country      VARCHAR(100),
    segment      VARCHAR(100)
);

CREATE TABLE PRODUCTS (
    product_id    VARCHAR(36)  PRIMARY KEY,
    sku           VARCHAR(100),
    name          VARCHAR(150),
    category      VARCHAR(100),
    monthly_price DECIMAL(10,2),
    active        BOOLEAN
);

CREATE TABLE PROFESSORS (
    professor_id VARCHAR(36)  PRIMARY KEY,
    first_name   VARCHAR(150),
    last_name    VARCHAR(150),
    department   VARCHAR(150),
    email        VARCHAR(150)
);

CREATE TABLE SEMESTERS (
    semester_id  VARCHAR(36)  PRIMARY KEY,
    name         VARCHAR(50),  -- Ej. 2023-1
    start_date   DATE,
    end_date     DATE
);

CREATE TABLE STUDENTS (
    student_id      VARCHAR(36)  PRIMARY KEY,
    first_name      VARCHAR(150),
    last_name       VARCHAR(150),
    email           VARCHAR(150),
    enrollment_date DATE,
    status          VARCHAR(50)
);

-- ============================================================
-- PUENTE CRM -> BILLING
-- ============================================================

CREATE TABLE ACCOUNTS (
    account_id      VARCHAR(36)  PRIMARY KEY,
    customer_id     VARCHAR(36)  UNIQUE,  -- Vínculo 1:1 con Billing
    name            VARCHAR(150),         -- Nombre de la Empresa
    industry        VARCHAR(150),
    website         VARCHAR(150),
    billing_country VARCHAR(100),
    CONSTRAINT fk_accounts_customer
        FOREIGN KEY (customer_id) REFERENCES CUSTOMERS(customer_id)
);

-- ============================================================
-- MÓDULO UNIVERSIDAD
-- ============================================================

CREATE TABLE COURSES (
    course_id    VARCHAR(36)  PRIMARY KEY,
    professor_id VARCHAR(36),
    course_code  VARCHAR(20),   -- Ej. MAT101
    title        VARCHAR(150),  -- Ej. Cálculo I
    credits      INT,
    department   VARCHAR(150),
    CONSTRAINT fk_courses_professor
        FOREIGN KEY (professor_id) REFERENCES PROFESSORS(professor_id)
);

-- ============================================================
-- MÓDULO CRM
-- ============================================================

CREATE TABLE CONTACTS (
    contact_id VARCHAR(36)  PRIMARY KEY,
    account_id VARCHAR(36),
    first_name VARCHAR(150),
    last_name  VARCHAR(150),
    email      VARCHAR(150),
    job_title  VARCHAR(150),
    CONSTRAINT fk_contacts_account
        FOREIGN KEY (account_id) REFERENCES ACCOUNTS(account_id)
);

CREATE TABLE OPPORTUNITIES (
    opportunity_id     VARCHAR(36)  PRIMARY KEY,
    account_id         VARCHAR(36),
    name               VARCHAR(150),
    amount              DECIMAL(12,2),
    stage              VARCHAR(50),
    expected_close_date DATE,
    CONSTRAINT fk_opportunities_account
        FOREIGN KEY (account_id) REFERENCES ACCOUNTS(account_id)
);

-- ============================================================
-- MÓDULO BILLING
-- ============================================================

CREATE TABLE SUBSCRIPTIONS (
    subscription_id VARCHAR(36)  PRIMARY KEY,
    customer_id     VARCHAR(36),
    product_id      VARCHAR(36),
    start_date      DATE,
    end_date        DATE,
    status          VARCHAR(50),
    CONSTRAINT fk_subscriptions_customer
        FOREIGN KEY (customer_id) REFERENCES CUSTOMERS(customer_id),
    CONSTRAINT fk_subscriptions_product
        FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id)
);

-- ============================================================
-- MÓDULO UNIVERSIDAD (continuación)
-- ============================================================

CREATE TABLE ENROLLMENTS (
    enrollment_id VARCHAR(36)  PRIMARY KEY,
    student_id    VARCHAR(36),
    course_id     VARCHAR(36),
    semester_id   VARCHAR(36),
    enroll_date   DATE,
    status        VARCHAR(50),  -- active, dropped, completed
    CONSTRAINT fk_enrollments_student
        FOREIGN KEY (student_id) REFERENCES STUDENTS(student_id),
    CONSTRAINT fk_enrollments_course
        FOREIGN KEY (course_id) REFERENCES COURSES(course_id),
    CONSTRAINT fk_enrollments_semester
        FOREIGN KEY (semester_id) REFERENCES SEMESTERS(semester_id)
);

-- ============================================================
-- MÓDULO CRM (continuación)
-- ============================================================

CREATE TABLE OPPORTUNITY_CONTACTS (
    opportunity_id VARCHAR(36),
    contact_id     VARCHAR(36),
    role           VARCHAR(100),  -- Ej. Decisor, Influenciador
    PRIMARY KEY (opportunity_id, contact_id),
    CONSTRAINT fk_oppcontacts_opportunity
        FOREIGN KEY (opportunity_id) REFERENCES OPPORTUNITIES(opportunity_id),
    CONSTRAINT fk_oppcontacts_contact
        FOREIGN KEY (contact_id) REFERENCES CONTACTS(contact_id)
);

CREATE TABLE ACTIVITIES (
    activity_id     VARCHAR(36)  PRIMARY KEY,
    account_id      VARCHAR(36),
    contact_id      VARCHAR(36),
    opportunity_id  VARCHAR(36),
    lead_id         VARCHAR(36),
    type            VARCHAR(50),  -- Call, Email, Meeting
    activity_date   DATETIME,
    CONSTRAINT fk_activities_account
        FOREIGN KEY (account_id) REFERENCES ACCOUNTS(account_id),
    CONSTRAINT fk_activities_contact
        FOREIGN KEY (contact_id) REFERENCES CONTACTS(contact_id),
    CONSTRAINT fk_activities_opportunity
        FOREIGN KEY (opportunity_id) REFERENCES OPPORTUNITIES(opportunity_id),
    CONSTRAINT fk_activities_lead
        FOREIGN KEY (lead_id) REFERENCES LEADS(lead_id)
);

-- ============================================================
-- MÓDULO BILLING (continuación)
-- ============================================================

CREATE TABLE INVOICES (
    invoice_id      VARCHAR(36)  PRIMARY KEY,
    customer_id     VARCHAR(36),
    subscription_id VARCHAR(36),
    issue_date      DATE,
    due_date        DATE,
    total_amount    DECIMAL(12,2),
    currency        VARCHAR(10),
    status          VARCHAR(50),
    CONSTRAINT fk_invoices_customer
        FOREIGN KEY (customer_id) REFERENCES CUSTOMERS(customer_id),
    CONSTRAINT fk_invoices_subscription
        FOREIGN KEY (subscription_id) REFERENCES SUBSCRIPTIONS(subscription_id)
);

-- ============================================================
-- MÓDULO UNIVERSIDAD (cierre)
-- ============================================================

CREATE TABLE GRADES (
    grade_id       VARCHAR(36)  PRIMARY KEY,
    enrollment_id  VARCHAR(36),
    grade_point    DECIMAL(4,2),  -- Ej. 4.5, 7.0
    letter_grade   VARCHAR(5),    -- Ej. A, B, C
    recorded_date  DATE,
    CONSTRAINT fk_grades_enrollment
        FOREIGN KEY (enrollment_id) REFERENCES ENROLLMENTS(enrollment_id)
);

-- ============================================================
-- MÓDULO BILLING (cierre)
-- ============================================================

CREATE TABLE INVOICE_ITEMS (
    invoice_item_id VARCHAR(36)  PRIMARY KEY,
    invoice_id      VARCHAR(36),
    product_id      VARCHAR(36),
    description     VARCHAR(255),
    quantity        INT,
    unit_amount     DECIMAL(10,2),
    total_amount    DECIMAL(12,2),
    CONSTRAINT fk_invoiceitems_invoice
        FOREIGN KEY (invoice_id) REFERENCES INVOICES(invoice_id),
    CONSTRAINT fk_invoiceitems_product
        FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id)
);

CREATE TABLE PAYMENTS (
    payment_id   VARCHAR(36)  PRIMARY KEY,
    invoice_id   VARCHAR(36),
    payment_date DATE,
    amount_paid  DECIMAL(12,2),
    method       VARCHAR(50),
    status       VARCHAR(50),
    CONSTRAINT fk_payments_invoice
        FOREIGN KEY (invoice_id) REFERENCES INVOICES(invoice_id)
);
