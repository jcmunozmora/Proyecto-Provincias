# 99_Legacy — Material retirado del pipeline activo

Nada de lo que está aquí lo ejecuta ni lo lee el pipeline vigente. Se conserva
porque documenta cómo se produjeron resultados anteriores y sirve de referencia
para auditar la migración a R.

**Si busca cómo correr el pipeline actual, vaya al `README.md` de la raíz.**

---

## `codigo/`

### Tablas monolíticas en Stata (reemplazadas por el pipeline por provincia)

| Archivo | Qué hacía | Reemplazado por |
|---|---|---|
| `02_Tablas_3.3_5.4.do` | 13 hojas en `tablas_3.3_5.4.xlsx` | `02_Code/03_tablas/` |
| `02_Tablas_Provincias.do` | 11 hojas en `tablas_provincias.xlsx` | `02_Code/03_tablas/` |
| `02_Tablas_seguridad.do` | 8 hojas en `tablas_seguridad.xlsx` | `02_Code/03_tablas/10_seguridad.R` |
| `02_Tablas_Gobernanza.do` | 4 hojas en `tablas_gobernanza.xlsx` | `02_Code/03_tablas/04_gobernabilidad.R` |
| `02_Tablas_economía.do` | 7 hojas en `Tablas_5_economia.xlsx` | `02_Code/03_tablas/05_economia.R` |
| `02_Tablas_Paz.do` | 1 hoja | `02_Code/03_tablas/10_seguridad.R` |
| `03_Gráficos.do` | pirámide poblacional + PNG | `02_Code/04_figuras/` |

Producían un `.xlsx` con **todas** las provincias juntas. El pipeline vigente
genera un juego de salidas **por provincia**, que es lo que necesitan los informes.

### Scripts sueltos

- **`correccion tablas subregiones.do`** — no es un script ejecutable: son 86 líneas
  entre `preserve`/`restore` pensadas para pegarse dentro de `02_Tablas_3.3_5.4.do`.
  Además está roto: la línea 37 hace `merge ... using \`subregiones'`, pero el bloque
  que crea ese `tempfile` quedó dentro de un comentario `/* ... */`.
- **`20250506_HOMOGENEIZACIÓN INDICADORES DEyC.do`** y **`... ECV.do`** — versiones
  de abril con rutas absolutas a un OneDrive de Proantioquia (usuario `aarenas`):
  leían y escribían **fuera del repositorio**. Reemplazados por
  `Homogeneizacion DeyC.do` y `20260518_HOMOGENEIZACIÓN INDICADORES ECV.do`,
  que sí escriben en `01_Data/01_Derived/`.
- **`20250509_Análisis variabilidad de tasas.ipynb`** — notebook exploratorio
  (ANOVA/Kruskal y k-means sobre tasas municipales) con rutas del usuario `ylondono`.
  Análisis puntual, no parte del pipeline.

---

## `outputs/`

Salidas del pipeline Stata anterior:

- `tablas_3.3_5.4.xlsx`, `tablas_provincias.xlsx`, `tablas_seguridad.xlsx`,
  `tablas_gobernanza.xlsx`, `Tablas_5_economia.xlsx` — tablas de todas las provincias juntas.
- `graficos_stata_legacy/` — los `Graficos_PAP_*.xlsx` y 31 PNG, únicamente de la
  provincia **Bioenergética Norte** (era la única generada). Útiles como referencia
  visual de qué figuras se esperaban.

---

## `datos/`

Archivos derivados sin productor ni consumidor en ninguna parte de la historia
del repositorio (verificado con `git log --all --diff-filter=A`):

- **Familia `pca_ds*`** (14 archivos: `pca_ds`, `_sub`, `_total`, `_transicion`,
  `_vulnerable`, `_consolida`, `_consolidado`) — resultados de un análisis de
  componentes principales cuyo código nunca se versionó. `pca_ds_consolida.rds` y
  `pca_ds_consolidado.rds` son byte a byte idénticos; los dos `.xlsx` homónimos
  difieren en 6 bytes. Se conservan por si el análisis se retoma, pero **no son
  reproducibles** tal como están.
- **`labels_2.xlsx`** — segundo diccionario de etiquetas, sin referencias en código.
  El vigente es `01_Data/01_Derived/label.xlsx`, que produce
  `02_Code/02_consolidacion/build_final_data.R`.

---

## Qué NO está aquí (y por qué)

Archivos que parecían obsoletos pero que el código vigente **sí consume**:

| Archivo | Lo lee |
|---|---|
| `20250505_SEGURIDAD_SALUD_DEFICT_VIVIENDA.dta` | consolidación (`build_data.R`) |
| `20250506_DEyC.dta`, `20250506_ECV*.dta`, `20250506_EDUCACION.dta` | consolidación |
| `20250506 EDUCACION.xlsx` (con espacio) | tablas, sección 03 Ordenamiento |
| `INVENTARIO_VARIABLES.xlsx` | `build_final_data.R` (el `_v_2` es el inventario de trabajo del equipo) |

Coexisten variantes con espacio y con guion bajo del mismo nombre, y prefijos de
fecha que no corresponden a la fecha real del archivo. Ver
`01_Data/01_Derived/README.md` para saber qué produce cada uno.
