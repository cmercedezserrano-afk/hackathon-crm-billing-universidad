import pandas as pd
from pathlib import Path

from utils import get_connection, DATA_DIR


GOLD_TABLES = [
    "dim_semesters",
    "dim_professors",
    "dim_students",
    "dim_courses",
    "dim_customers",
    "dim_products",
    "dim_accounts",
    "dim_contacts",
    "fact_enrollments",
    "fact_grades",
    "fact_subscriptions",
    "fact_invoices",
    "fact_opportunities",
    "kpi_student_performance",
    "kpi_monthly_revenue",
    "kpi_sales_pipeline",
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

    print("Exportacin completada.")


if __name__ == "__main__":
    export_gold_to_parquet()
