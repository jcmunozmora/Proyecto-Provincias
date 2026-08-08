# 01_Derived — Datos derivados

Resultados intermedios del pipeline. **Todo lo que está aquí debería poder
borrarse y regenerarse** corriendo el pipeline… salvo las excepciones que se
listan más abajo, que son el principal hueco de reproducibilidad del proyecto.

No edite estos archivos a mano: el pipeline los sobrescribe.

---

## Con productor en el repositorio (se regeneran solos)

| Archivo | Lo produce |
|---|---|
| `codigos_provincias.dta` | `02_Code/01_homogeneizacion/crosswalk_territorial.R` |
| `subreg_completo.dta` | `02_Code/01_homogeneizacion/crosswalk_territorial.R` |
| `ECV_nbi_pobreza.dta` | homogeneización ECV |
| `ECV_oficial_agregados.dta` | homogeneización ECV oficial |
| `estructura_productiva.{dta,xlsx}`, `imca_2022.{dta,xlsx}` | homogeneización DEyC |
| `20250506 EDUCACION.xlsx` | homogeneización educación |
| `seguridad_policia.xlsx` | homogeneización Policía Nacional |
| `poblacion_municipal_total_2025*.dta`, `poblacion_total_2025.dta` | homogeneización población |
| `infraestructura_internet_2025.dta` | homogeneización infraestructura |
| `uso_del_suelo_pota.xlsx` | homogeneización uso del suelo |
| `percepcion_seguridad.{dta,xlsx}` | homogeneización percepción de seguridad |
| `01_final_data.dta`, `01_final_data_long.xlsx`, `01_DATOS_INICIALES*.xlsx`, `label.xlsx` | consolidación |

## Sin productor en el repositorio ⚠️

Estos archivos **se construyen a mano en Excel** y nadie los regenera. Si se
pierden o quedan desactualizados, no hay forma de reconstruirlos desde el
código: hay que rehacerlos a mano. Es el hueco de reproducibilidad más grande
del proyecto y conviene irlos migrando a scripts.

Familia `*_PROVINCIAS.xlsx` (agregados provinciales preparados a mano):

`617_PROVINCIAS` · `AREAPROTEGIDA_PROVINCIAS` · `AREA_PROVINCIAS` ·
`CULTILICITOS_PROVINCIAS` · `CULTIVOS_PROVINCIAS` · `EDUCACION_PROVINCIAS` ·
`EMERGENCIAS_PROVINCIAS` · `EVOA_PROVINCIAS` · `EXTRANJEROS_PROVINCIAS` ·
`HECHOSVICTIM_PROVINCIAS` · `ICM_PROVINCIAS` · `IDF_PROVINCIAS` ·
`IMRC_PROVINCIAS` · `IRCA_PROVINCIAS` · `MDM_PROVINCIAS` ·
`PECUARIO_PROVINCIAS` · `SRDAFT_PROVINCIAS`

Otros sin productor:

`ESTADO_CATASTRO.xlsx` · `VALOR_AGREGADO_20152024_MUNICIPIOS.xlsx` ·
`indice_gobierno_digital_2024.dta` · `20260504_SEGURIDAD_SALUD_DEFICT_VIVIENDA.*`
(el nombre trae el error "DEFICT"; es el archivo vigente, no lo renombre sin
actualizar a quienes lo leen)

Los `*_dicc` (`IRCA_dicc`, `natalidad_dicc`, `mortalidad_iam_dicc`,
`i_datalake_ges_pub_dicc`, `infraestructura_municipios_dicc`,
`poblacion_municipal_total_2023_dicc`, `suicidios_e_intentos_medias_dicc`)
vienen de scripts R que corrieron **fuera** del repositorio, sobre insumos que
tampoco están aquí; su código está en `02_Code/01_homogeneizacion/externos/`.
Al `.csv`/`.xlsx` que producían se le añadió a mano una hoja `Data`, y esa
versión con sufijo `_dicc` es la que consume el pipeline.

---

## Nombres que confunden (y por qué siguen así)

- **Prefijos de fecha que no son la fecha del archivo.** `20250505_…` y
  `20250506_…` se refieren a la entrega original de mayo de 2025; algunos se
  actualizaron después conservando el nombre. `20260504_…` es la revisión de
  2026 y es la vigente para seguridad, salud y déficit de vivienda.
- **Mismo nombre con espacio y con guion bajo, y no son lo mismo.**
  `20250506 EDUCACION.xlsx` (con espacio) lo produce la homogeneización y lo
  consume la sección de ordenamiento; `20250506_EDUCACION.{dta,xlsx}` (con guion
  bajo) es la versión de abril y la consume la consolidación. Igual con `DEyC`.
  Antes de tocar cualquiera de los dos, verifique con `grep` quién lo lee.

Las versiones obsoletas de estos pares y los archivos huérfanos se movieron a
`99_Legacy/datos/`; allí está explicado qué era cada uno.
