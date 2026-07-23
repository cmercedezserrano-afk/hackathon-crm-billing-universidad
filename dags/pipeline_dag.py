from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    "owner": "bootcamp",
    "depends_on_past": False,
    "start_date": datetime(2024, 1, 1),
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="bootcamp_pipeline",
    default_args=default_args,
    description="Pipeline completo: Bronce -> Plata -> Oro -> Calidad -> Parquet",
    schedule_interval=None,
    catchup=False,
    tags=["bootcamp"],
) as dag:

    bronze = BashOperator(
        task_id="bronze_ingest",
        bash_command="cd /opt/airflow && python src/run_pipeline.py bronze",
        doc="Crea esquema bronce y copia los 17 archivos CSV tal cual desde /data/raw/",
    )

    silver = BashOperator(
        task_id="silver_transform",
        bash_command="cd /opt/airflow && python src/run_pipeline.py silver",
        doc="Crea esquema plata: 18 tablas con llaves foráneas, tipos correctos, vista cruzada e índices",
    )

    gold = BashOperator(
        task_id="gold_model",
        bash_command="cd /opt/airflow && python src/run_pipeline.py gold",
        doc="Crea esquema gold: 11 dimensiones, 8 hechos y 12 KPIs en esquema estrella",
    )

    quality = BashOperator(
        task_id="quality_checks",
        bash_command="cd /opt/airflow && python src/run_pipeline.py quality",
        doc="Ejecuta validaciones: conteo de filas, nulos, llaves huérfanas y relación cruzada",
    )

    export = BashOperator(
        task_id="export_parquet",
        bash_command="cd /opt/airflow && python src/run_pipeline.py export",
        doc="Exporta todas las tablas oro a archivos Parquet en /data/parquet/",
    )

    bronze >> silver >> gold >> quality >> export
