from utils import get_connection


def run_quality_checks():
    checks = []

    with get_connection() as conn:
        with conn.cursor() as cur:
            tables = [
                ("bronze.semesters", "semester_id"),
                ("bronze.professors", "professor_id"),
                ("bronze.students", "student_id"),
                ("bronze.courses", "course_id"),
                ("bronze.enrollments", "enrollment_id"),
                ("bronze.grades", "grade_id"),
                ("bronze.customers", "customer_id"),
                ("bronze.products", "product_id"),
                ("bronze.subscriptions", "subscription_id"),
                ("bronze.invoices", "invoice_id"),
                ("bronze.invoice_items", "invoice_item_id"),
                ("bronze.payments", "payment_id"),
                ("bronze.accounts", "account_id"),
                ("bronze.contacts", "contact_id"),
                ("bronze.leads", "lead_id"),
                ("bronze.opportunities", "opportunity_id"),
                ("bronze.opportunity_contacts", "opportunity_id"),
                ("bronze.activities", "activity_id"),
            ]

            for table, id_col in tables:
                cur.execute(f"SELECT COUNT(*) FROM {table}")
                count = cur.fetchone()[0]
                cur.execute(
                    f"SELECT COUNT(*) FROM {table} WHERE {id_col} IS NULL OR {id_col} = ''"
                )
                nulls = cur.fetchone()[0]
                checks.append(
                    {
                        "table": table,
                        "total_rows": count,
                        "null_ids": nulls,
                        "status": "OK" if nulls == 0 else f"WARN: {nulls} null IDs",
                    }
                )
                print(f"  {table}: {count} rows, {nulls} null IDs")

            print("\n=== VERIFICACIÓN DE RELACIONES (Llaves Foráneas) ===")

            fk_checks = [
                ("bronze.courses x professors",
                 "SELECT COUNT(*) FROM bronze.courses WHERE professor_id != '' AND SPLIT_PART(professor_id, '-', 2)::INTEGER NOT IN (SELECT SPLIT_PART(professor_id, '-', 2)::INTEGER FROM bronze.professors)"),
                ("bronze.enrollments x students",
                 "SELECT COUNT(*) FROM bronze.enrollments WHERE SPLIT_PART(student_id, '-', 2)::INTEGER NOT IN (SELECT SPLIT_PART(student_id, '-', 2)::INTEGER FROM bronze.students)"),
                ("bronze.enrollments x courses",
                 "SELECT COUNT(*) FROM bronze.enrollments WHERE SPLIT_PART(course_id, '-', 2)::INTEGER NOT IN (SELECT SPLIT_PART(course_id, '-', 2)::INTEGER FROM bronze.courses)"),
                ("bronze.invoices x customers",
                 "SELECT COUNT(*) FROM bronze.invoices WHERE SPLIT_PART(customer_id, '-', 2)::INTEGER NOT IN (SELECT SPLIT_PART(customer_id, '-', 2)::INTEGER FROM bronze.customers)"),
                ("bronze.contacts x accounts",
                 "SELECT COUNT(*) FROM bronze.contacts WHERE SPLIT_PART(account_id, '-', 2)::INTEGER NOT IN (SELECT SPLIT_PART(account_id, '-', 2)::INTEGER FROM bronze.accounts)"),
                ("bronze.opportunities x accounts",
                 "SELECT COUNT(*) FROM bronze.opportunities WHERE SPLIT_PART(account_id, '-', 2)::INTEGER NOT IN (SELECT SPLIT_PART(account_id, '-', 2)::INTEGER FROM bronze.accounts)"),
            ]

            all_ok = True
            for name, sql in fk_checks:
                cur.execute(sql)
                orphans = cur.fetchone()[0]
                status = "OK" if orphans == 0 else f"WARN: {orphans} orphan records"
                if orphans > 0:
                    all_ok = False
                print(f"  {name}: {status}")
                checks.append({"table": name, "total_rows": "FK check", "null_ids": orphans, "status": status})

            print("\n=== RELACIÓN CRUZADA University-Billing ===")
            cur.execute("""
                SELECT COUNT(*)
                FROM bronze.customers c
                JOIN bronze.students s ON c.external_ref = s.student_id
            """)
            matched = cur.fetchone()[0]
            cur.execute("SELECT COUNT(*) FROM bronze.customers")
            total_cust = cur.fetchone()[0]
            print(f"  Clientes que coinciden con estudiantes: {matched} de {total_cust} ({matched*100/total_cust:.1f}%)")
            checks.append({"table": "students<>customers (matched/total)", "total_rows": total_cust, "null_ids": matched, "status": "OK" if matched > 0 else "WARN: no match"})

    print(f"\nTotal verificaciones: {len(checks)}")
    return checks


if __name__ == "__main__":
    print("Ejecutando controles de calidad...\n")
    run_quality_checks()
