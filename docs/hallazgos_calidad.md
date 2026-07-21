# Hallazgos de calidad de datos

## 1. IDs alfanumricos

Todos los IDs usan el formato `PREFIJO-NUMERO` (ej: `CUS-0000001`, `STU-0000001`). Esto es consistente en los 3 dominios.

**Accin**: Se extrae el nmero para tener IDs enteros en Silver.

## 2. Fechas

Las fechas vienen en formato texto. Se convierten a tipo DATE de PostgreSQL en Silver.

**Riesgo potencial**: fechas fuera de rango o mal formateadas. Se manejan con CASE convirtiendo a NULL si hay algn problema.

## 3. Campos numricos

Campos como `score`, `weight`, `monthly_price`, `total`, `amount` vienen como texto.

**Accin**: Se convierten al tipo numrico correspondiente (NUMERIC, INTEGER) en Silver.

## 4. Valores vacos

Se detectaron campos vacos en los CSVs (especialmente en fechas).

**Accin**: En Silver se convierten a NULL de base de datos.

## 5. Relaciones entre dominios

Se observ que el campo `external_ref` en `customers` tiene valores como `STU-0000001`, lo que sugiere una relacin entre estudiantes y clientes. Esto debera validarse con el negocio.

## 6. Segmentos de clientes

El campo `segment` tiene categoras como `smb`, `retail`, `enterprise`. Se recomienda documentar el significado de cada una.

## 7. Moneda

El campo `currency` en facturas permite manejar multi-moneda. Se recomienda estandarizar a una moneda base para los reportes globales.
