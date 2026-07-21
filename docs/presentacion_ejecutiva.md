# Presentacin Ejecutiva

## Resumen del proyecto

Se construy un pipeline de datos que toma informacin de 3 reas del negocio (Universidad, Facturacin y CRM) y la transforma en informacin til para la toma de decisiones.

## Principales resultados

### Universidad
- **5,000 estudiantes** activos en el sistema
- **200 profesores** distribuidos en varios departamentos
- **300 cursos** ofrecidos en **8 semestres**
- **60,000 calificaciones** registradas

### Facturacin
- **10,000 clientes** con distintos segmentos (retail, smb, enterprise)
- **200 productos/servicios** facturables
- **50,000 facturas** emitidas con **80,000 pagos** asociados

### CRM
- **5,000 cuentas** (empresas/organizaciones)
- **15,000 contactos** vinculados a cuentas
- **2,000 leads** generados
- **3,000 oportunidades** de venta en pipeline

## Insights clave

1. **Distribucin geogrfica**: los estudiantes provienen de mltiples pases, lo que indica una institucin internacional.

2. **Ingresos recurrentes**: los pagos mensuales muestran la estacionalidad del negocio de suscripciones.

3. **Pipeline de ventas**: el CRM muestra oportunidades en distintas etapas, lo que permite pronosticar ingresos futuros.

4. **Rendimiento acadmico**: el promedio de calificaciones por estudiante permite identificar tanto talentos como estudiantes en riesgo.

## Recomendaciones

1. Validar la relacin entre estudiantes (University) y clientes (Billing) para entender la tasa de conversin de estudiante a cliente.

2. Analizar los segmentos de clientes para personalizar estrategias de retencin.

3. Automatizar alertas para estudiantes con bajo rendimiento (promedio menor a 4.0).

## Gua de uso del pipeline

1. Abrir una terminal en WSL y navegar a la carpeta del proyecto
2. Ejecutar: `docker compose -f docker/docker-compose.yml up -d`
3. Esperar a que todos los servicios estn saludables (unos 2 minutos)
4. Abrir Airflow en http://localhost:8080 (usuario: admin, clave: admin)
5. Activar el DAG `bootcamp_pipeline` y ejecutarlo
6. Los resultados en Parquet estarn en `data/parquet/`
7. Para ver el anlisis, abrir Jupyter en http://localhost:8888 (token: bootcamp)
