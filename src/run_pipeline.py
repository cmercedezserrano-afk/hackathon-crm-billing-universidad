"""Script que ejecuta todo el pipeline paso a paso."""
import sys
from pathlib import Path

from utils import get_connection, run_sql_file, SQL_DIR


def step_bronze():
    print("=== PASO 1: Crear tablas Bronze ===")
    with get_connection() as conn:
        with conn.cursor() as cur:
            run_sql_file(cur, SQL_DIR / "bronze" / "01_create_tables.sql")
            conn.commit()
    print("  OK")

    print("=== PASO 2: Cargar CSVs a Bronze ===")
    with get_connection() as conn:
        with conn.cursor() as cur:
            run_sql_file(cur, SQL_DIR / "bronze" / "02_ingest_csv.sql")
            conn.commit()
    print("  OK")


def step_silver():
    print("=== PASO 3: Crear tablas Silver con llaves forneas ===")
    with get_connection() as conn:
        with conn.cursor() as cur:
            run_sql_file(cur, SQL_DIR / "silver" / "01_create_tables.sql")
            conn.commit()
    print("  OK")

    print("=== PASO 4: Transformar Bronze a Silver ===")
    with get_connection() as conn:
        with conn.cursor() as cur:
            run_sql_file(cur, SQL_DIR / "silver" / "02_transform.sql")
            conn.commit()
    print("  OK")

    print("=== PASO 4b: Agregar ndices de rendimiento ===")
    with get_connection() as conn:
        with conn.cursor() as cur:
            run_sql_file(cur, SQL_DIR / "silver" / "03_add_indexes.sql")
            conn.commit()
    print("  OK")


def step_gold():
    print("=== PASO 5: Crear tablas Gold ===")
    with get_connection() as conn:
        with conn.cursor() as cur:
            run_sql_file(cur, SQL_DIR / "gold" / "01_create_tables.sql")
            conn.commit()
    print("  OK")


def step_quality():
    print("=== PASO 6: Controles de calidad ===")
    from quality_checks import run_quality_checks
    run_quality_checks()
    print("  OK")


def step_export():
    print("=== PASO 7: Exportar a Parquet ===")
    from export_parquet import export_gold_to_parquet
    export_gold_to_parquet()
    print("  OK")


if __name__ == "__main__":
    steps = {
        "bronze": step_bronze,
        "silver": step_silver,
        "gold": step_gold,
        "quality": step_quality,
        "export": step_export,
    }

    if len(sys.argv) > 1:
        for name in sys.argv[1:]:
            if name in steps:
                steps[name]()
            else:
                print(f"Paso desconocido: {name}")
                print(f"Usa: bronze, silver, gold, quality, export")
    else:
        step_bronze()
        step_silver()
        step_gold()
        step_quality()
        step_export()

    print("=== PIPELINE COMPLETADO ===")
