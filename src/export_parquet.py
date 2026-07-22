import pandas as pd
from pathlib import Path

from utils import get_connection, DATA_DIR


GOLD_TABLES = [
    "dim_date",
    "dim_semesters",
    "dim_professors",
    "dim_students",
    "dim_courses",
    "dim_customers",
    "dim_products",
    "dim_accounts",
    "dim_contacts",
    "dim_opportunity_stage",
    "fact_enrollments",
    "fact_grades",
    "fact_subscriptions",
    "fact_invoices",
    "fact_payments",
    "fact_opportunities",
    "fact_activities",
    "bridge_student_customer",
    "fact_student_customer",
    "kpi_student_performance",
    "kpi_monthly_revenue",
    "kpi_sales_pipeline",
    "kpi_student_to_customer",
    "kpi_rfm_segments",
    "kpi_course_performance",
    "kpi_professor_load",
    "kpi_subscription_churn",
    "kpi_student_lifecycle",
    "kpi_collection_risk",
]


def export_gold_to_parquet():
    output_dir = DATA_DIR / "parquet"
    output_dir.mkdir(parents=True, exist_ok=True)

    with get_connection() as conn:
        for table in GOLD_TABLES:
            print(f"Exportando gold.{table} ...")
            df = pd.read_sql(f"SELECT * FROM gold.{table}", conn)
            filepath = output_dir / f"{table}.parquet"
            df.to_parquet(filepath, index=False)
            print(f"  -> {filepath} ({len(df)} filas)")

    print("Exportación completada.")


if __name__ == "__main__":
    export_gold_to_parquet()
