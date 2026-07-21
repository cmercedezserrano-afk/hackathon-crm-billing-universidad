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
    description="Pipeline completo: Bronze -> Silver -> Gold -> Parquet",
    schedule_interval=None,
    catchup=False,
    tags=["bootcamp"],
) as dag:

    bronze = BashOperator(
        task_id="bronze_ingest",
        bash_command="cd /opt/airflow && python src/run_pipeline.py bronze",
    )

    silver = BashOperator(
        task_id="silver_transform",
        bash_command="cd /opt/airflow && python src/run_pipeline.py silver",
    )

    gold = BashOperator(
        task_id="gold_model",
        bash_command="cd /opt/airflow && python src/run_pipeline.py gold",
    )

    quality = BashOperator(
        task_id="quality_checks",
        bash_command="cd /opt/airflow && python src/run_pipeline.py quality",
    )

    export = BashOperator(
        task_id="export_parquet",
        bash_command="cd /opt/airflow && python src/run_pipeline.py export",
    )

    bronze >> silver >> gold >> quality >> export
