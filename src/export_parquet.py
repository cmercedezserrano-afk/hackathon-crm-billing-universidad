import pandas as pd
from pathlib import Path

from utils import get_connection, DATA_DIR

SILVER_TABLES = [
    "accounts", "activities", "contacts", "courses", "customers",
    "enrollments", "grades", "invoice_items", "invoices", "leads",
    "opportunities", "opportunity_contacts", "payments", "products",
    "professors", "semesters", "students", "subscriptions",
]

GOLD_TABLES = [
    "date_dim",
    "semesters",
    "professors",
    "students",
    "courses",
    "customers",
    "products",
    "accounts",
    "contacts",
    "leads",
    "enrollments",
    "grades",
    "subscriptions",
    "invoices",
    "invoice_items",
    "payments",
    "opportunities",
    "opportunity_contacts",
    "activities",
    "calculo_tabestudiantes_tabmatriculas_tabnotas_datopromedio",
    "calculo_tabpagos_tabfacturas_datorecaudacion",
    "calculo_taboportunidades_datomontoporetapa",
    "calculo_tabestudiantes_tabclientes_datoconversion",
    "calculo_tabclientes_datorfm",
    "calculo_tabcursos_tabmatriculas_tabnotas_datopromedio",
    "calculo_tabprofesores_tabcursos_tabmatriculas_datoalumnos",
    "calculo_tabsuscripciones_tabproductos_datotasaabandono",
    "calculo_tabestudiantes_tabclientes_datociclovida",
    "calculo_tabclientes_tabfacturas_datoriesgo",
    "calculo_tabcursos_tabmatriculas_tabnotas_datoaprobacion",
    "calculo_tabsemestres_tabmatriculas_datoinscripciones",
]


def export_schema(schema, tables, output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    with get_connection() as conn:
        for table in tables:
            print(f"Exportando {schema}.{table} ...")
            df = pd.read_sql(f"SELECT * FROM {schema}.{table}", conn)
            filepath = output_dir / f"{table}.parquet"
            df.to_parquet(filepath, index=False)
            print(f"  -> {filepath} ({len(df)} filas)")


def export_all():
    export_schema("silver", SILVER_TABLES, DATA_DIR / "silver")
    export_schema("gold", GOLD_TABLES, DATA_DIR / "parquet")
    print("Exportación completada.")


if __name__ == "__main__":
    export_all()
