# El pipeline en Stata (retirado)

Este es el código con el que se produjo el diagnóstico hasta agosto de 2026,
antes de migrarlo a R. **No lo ejecuta nada.** Se conserva por tres razones:

1. Es la especificación con la que se hizo la migración, y permite auditarla.
2. Documenta decisiones metodológicas que no están escritas en ningún otro sitio
   (por ejemplo, cómo se agregan las tasas provinciales).
3. Algunas de sus notas fechadas explican correcciones concretas
   (`09_Salud.do`: *"corregido 2026-08-06, antes se ponderaba por poblacion"*).

## Qué hacía y quién lo reemplaza

| Antes | Ahora |
|---|---|
| `Tablas_Diagnostico/00_master.do` | `02_Code/run_provincia.R` |
| `Tablas_Diagnostico/NN_Seccion.do` | `02_Code/03_tablas/NN_seccion.R` + `02_Code/04_figuras/NN_seccion.R` |
| `00_Homogeneizacion_Inputs/*.do` | `02_Code/01_homogeneizacion/*.R` |
| `00_BuildData.do` (crosswalk) | `02_Code/01_homogeneizacion/crosswalk_territorial.R` |

## Por qué no se puede correr tal cual

- **Rutas absolutas de otra máquina.** Cada `.do` empieza fijando
  `global path "D:/LAURA/…"` o `"D:\IA Provincias\…"`.
- **Depende del orden.** Los sectoriales no definen sus propios globals: se caen
  si no se ejecuta antes `00_master.do`.
- **`00_BuildData.do` aborta** en la línea 65: usa `use "archivo.dta", replace`,
  y `replace` no es una opción válida de `use` (son cuatro ocurrencias).

## Errores que la migración encontró en este código

Se dejan aquí anotados porque son la razón de que el pipeline en R no sea una
traducción literal:

- **La provincia 5 desaparecería hoy.** El código compara el nombre contra la
  cadena `"POVINCIA DEL AGUA, BOSQUES Y TURISMO"` (sin la R). El Excel fuente se
  corrigió después, así que esos 12 municipios se quedarían sin `id_provincia` y
  la provincia desaparecería del crosswalk sin ningún error visible.
- **Se perdían 47 de 102 títulos mineros.** `05_Economia.do` cruza el catastro
  minero contra la celda `Municipios` completa, de modo que descarta todo título
  que cubra varios municipios (`"REMEDIOS, SEGOVIA"`).
- **Los ponderadores de salud estaban corrompidos.** `09_Salud.do` referencia
  las columnas de `NATALIDAD.xlsx` por su letra de Excel (AE, AG, AI…). Al
  leerlas así se tomaba la tasa bruta de natalidad como si fuera el número de
  nacimientos.
- **Un script se reescribía encima.** `20260504_HOMOGENEIZACIÓN_SALUD_SEGURIDAD.do`
  lee su propia salida y la vuelve a guardar, así que cada corrida acumulaba
  transformaciones sobre el resultado anterior.
- **Temporales junto al código.** `poblacion_municipal_2025.do` guarda
  `_tmp_*.dta` en el directorio de trabajo; una corrida fallida dejó cuatro
  commiteados en el repositorio.
- **Dos scripts trabajaban fuera del repositorio**, sobre un OneDrive personal, y
  sus resultados se copiaban a mano.

## Si necesita volver a correrlo

Hay un master preparado que no toca ningún `.do`: `tests/golden_run.do` replica
`00_master.do` con rutas derivadas del repositorio y escribe a `tests/golden/`.
Requiere una licencia de Stata vigente (Stata ≥ 16, por `frame put`).
