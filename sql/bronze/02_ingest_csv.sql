-- Copia los CSVs desde /data/raw/ a las tablas bronze
-- Los archivos CSV deben estar accesibles desde el contenedor en /data/raw/

COPY bronze.semesters FROM '/data/raw/university/semesters.csv' DELIMITER ',' CSV HEADER;
COPY bronze.professors FROM '/data/raw/university/professors.csv' DELIMITER ',' CSV HEADER;
COPY bronze.students FROM '/data/raw/university/students.csv' DELIMITER ',' CSV HEADER;
COPY bronze.courses FROM '/data/raw/university/courses.csv' DELIMITER ',' CSV HEADER;
COPY bronze.enrollments FROM '/data/raw/university/enrollments.csv' DELIMITER ',' CSV HEADER;
COPY bronze.grades FROM '/data/raw/university/grades.csv' DELIMITER ',' CSV HEADER;

COPY bronze.customers FROM '/data/raw/billing/customers.csv' DELIMITER ',' CSV HEADER;
COPY bronze.products FROM '/data/raw/billing/products.csv' DELIMITER ',' CSV HEADER;
COPY bronze.subscriptions FROM '/data/raw/billing/subscriptions.csv' DELIMITER ',' CSV HEADER;
COPY bronze.invoices FROM '/data/raw/billing/invoices.csv' DELIMITER ',' CSV HEADER;
COPY bronze.invoice_items FROM '/data/raw/billing/invoice_items.csv' DELIMITER ',' CSV HEADER;
COPY bronze.payments FROM '/data/raw/billing/payments.csv' DELIMITER ',' CSV HEADER;

COPY bronze.accounts FROM '/data/raw/crm/accounts.csv' DELIMITER ',' CSV HEADER;
COPY bronze.contacts FROM '/data/raw/crm/contacts.csv' DELIMITER ',' CSV HEADER;
COPY bronze.leads FROM '/data/raw/crm/leads.csv' DELIMITER ',' CSV HEADER;
COPY bronze.opportunities FROM '/data/raw/crm/opportunities.csv' DELIMITER ',' CSV HEADER;
COPY bronze.opportunity_contacts FROM '/data/raw/crm/opportunity_contacts.csv' DELIMITER ',' CSV HEADER;
COPY bronze.activities FROM '/data/raw/crm/activities.csv' DELIMITER ',' CSV HEADER;
