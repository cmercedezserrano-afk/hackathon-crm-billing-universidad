-- ============================================================
-- NDICES PARA RENDIMIENTO
-- ============================================================
-- Los ndices hacen que las consultas sean ms rpidas,
-- como el ndice de un libro: encontrs lo que buscars sin
-- hojar pgina por pgina.

-- UNIVERSITY
CREATE INDEX IF NOT EXISTS idx_courses_professor ON silver.courses(professor_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_student ON silver.enrollments(student_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON silver.enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_semester ON silver.enrollments(semester_id);
CREATE INDEX IF NOT EXISTS idx_grades_enrollment ON silver.grades(enrollment_id);

-- BILLING
CREATE INDEX IF NOT EXISTS idx_customers_external_ref ON silver.customers(external_ref);
CREATE INDEX IF NOT EXISTS idx_subscriptions_customer ON silver.subscriptions(customer_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_product ON silver.subscriptions(product_id);
CREATE INDEX IF NOT EXISTS idx_invoices_customer ON silver.invoices(customer_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON silver.invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_product ON silver.invoice_items(product_id);
CREATE INDEX IF NOT EXISTS idx_payments_invoice ON silver.payments(invoice_id);

-- CRM
CREATE INDEX IF NOT EXISTS idx_contacts_account ON silver.contacts(account_id);
CREATE INDEX IF NOT EXISTS idx_opportunities_account ON silver.opportunities(account_id);
CREATE INDEX IF NOT EXISTS idx_activities_contact ON silver.activities(contact_id);
CREATE INDEX IF NOT EXISTS idx_activities_opportunity ON silver.activities(opportunity_id);
