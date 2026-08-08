# =============================================================================
# 09_salud.R — Sección 9: Salud
#
# TABLAS (hojas del .xlsx de la sección):
#   bajo_peso               % de nacidos con bajo peso al nacer
#   enfermedades_tropicales tasas de dengue, malaria y leishmaniasis por 100 mil
#                           habitantes
#   suicidios               tasas de intento de suicidio y de suicidio consumado
#                           por 100 mil habitantes
#   aseguramiento_sgsss     afiliados al SGSSS por régimen y su composición
#   mortalidad_infantil     tasa por 1.000 nacidos vivos, serie 2020-2024
#
# INPUTS:  01_Data/01_Derived/20260504_SEGURIDAD_SALUD_DEFICT_VIVIENDA.dta
#            (bajo_peso, dengue, malaria, leishmaniasis)
#          01_Data/01_Derived/suicidios_e_intentos_medias_dicc.dta
#            (TIS_total, TS_total)
#          01_Data/00_Inputs/POBLACION MUNICIPAL.xlsx   (peso poblacional 2025)
#          01_Data/00_Inputs/NATALIDAD.xlsx             (nacidos vivos por año)
#          01_Data/00_Inputs/MORTALIDAD_INFANTIL.xlsx   (tasa por municipio y año)
#          01_Data/00_Inputs/ASEGURAMIENTO_MUNICIPIOS.xlsx
#          crosswalks territoriales (01_Derived)
# OUTPUTS: 03_Outputs/<Provincia>/09_Salud/salud.xlsx
#
# ETAPA DEL PIPELINE: 3. tablas de diagnóstico
# Migrado de Tablas_Diagnostico/09_Salud.do
#
# NOTA METODOLÓGICA — AGREGADO PROVINCIAL (se conserva del .do original):
#   - tasas por 100 mil (dengue/malaria/leishmaniasis, suicidios): ponderado por
#     poblacion = Sum(tasa*pob)/Sum(pob) = Sum(casos)/Sum(pob)*100mil  (correcto).
#   - bajo_peso (% de NACIMIENTOS) y mortalidad infantil (por 1.000 nacidos):
#     ponderados por NACIMIENTOS = Sum(tasa*nac)/Sum(nac) = Sum(casos)/Sum(nac)
#     (correcto; corregido 2026-08-06, antes se ponderaba por poblacion).
#   Es decir: el denominador del indicador manda cuál es el ponderador. Un
#   indicador medido POR NACIMIENTO no se pondera por población.
# =============================================================================

if (!exists("RUTAS")) stop("Cargue 02_Code/R/00_config.R antes de este script.", call. = FALSE)

# --- Lectura de matrices anchas con encabezado en dos filas -------------------
# NATALIDAD y MORTALIDAD_INFANTIL traen el año en una fila y el subencabezado
# ("Total"/"Tasa", "casos"/"Tasa x mil") en la siguiente. El .do los leía por
# posición de columna de Excel (AE, AG, …), que se rompe en silencio si la fuente
# cambia una columna. Aquí las columnas se localizan por su encabezado.

#' Índice de la columna de cada año en una matriz de encabezado doble.
#'
#' @param ruta,hoja archivo y hoja de Excel.
#' @param fila_anio fila (1-based) donde va el año; se rellena hacia la derecha
#'   porque viene combinada sobre varias columnas.
#' @param fila_sub fila con el subencabezado que distingue las columnas del año.
#' @param patron_sub expresión regular (sin tildes, en minúsculas) que identifica
#'   la columna buscada dentro de cada año.
#' @param anios años pedidos.
#' @return vector nombrado año -> índice de columna.
.columnas_por_anio <- function(ruta, hoja, fila_anio, fila_sub, patron_sub, anios) {
  cab <- readxl::read_excel(ruta, sheet = hoja, col_names = FALSE,
                            n_max = max(fila_anio, fila_sub),
                            .name_repair = "minimal") |> as.data.frame()

  anio_fila <- suppressWarnings(as.numeric(as.character(unlist(cab[fila_anio, ]))))
  # El año viene solo en la primera columna del bloque: se arrastra a la derecha.
  for (j in seq_along(anio_fila)[-1]) {
    if (is.na(anio_fila[j])) anio_fila[j] <- anio_fila[j - 1]
  }
  sub <- norm_txt(as.character(unlist(cab[fila_sub, ])))

  indices <- vapply(anios, function(a) {
    j <- which(!is.na(anio_fila) & anio_fila == a & stringr::str_detect(sub, patron_sub))
    if (!length(j)) {
      stop("En ", basename(ruta), " (hoja '", hoja, "') no encuentro la columna '",
           patron_sub, "' del año ", a, ".", call. = FALSE)
    }
    j[1]
  }, integer(1))
  stats::setNames(indices, as.character(anios))
}

# --- Insumos compartidos ------------------------------------------------------

#' Población total municipal 2025 de TODO el departamento: es el ponderador de
#' las tasas por 100 mil habitantes.
.pesos_poblacion <- function() {
  d <- leer_excel(entrada("POBLACION MUNICIPAL.xlsx"), hoja = 1)
  c_cod  <- col_req(d, "DPMP")
  c_ano  <- col_req(d, "AÑO")
  c_area <- col_req(d, "ÁREA GEOGRÁFICA")
  c_pob  <- col_req(d, "Total General")

  d |>
    dplyr::filter(a_numero(.data[[c_ano]]) == 2025, .data[[c_area]] == "Total") |>
    dplyr::transmute(
      ind_mpio = as.integer(a_numero(.data[[c_cod]])),
      pob_peso = a_numero(.data[[c_pob]])
    ) |>
    dplyr::filter(!is.na(.data$ind_mpio))
}

#' Nacidos vivos por municipio y año (2020-2024): es el ponderador de los
#' indicadores medidos POR NACIMIENTO (bajo peso, mortalidad infantil).
#' Se descartan las filas de subregión (código "SR0x") y la de departamento
#' (código 05 -> 5), que no son municipios.
.nacidos_vivos <- function(anios = 2020:2024) {
  ruta <- entrada("NATALIDAD.xlsx")
  cols <- .columnas_por_anio(ruta, "Natalidad total", fila_anio = 1, fila_sub = 2,
                             patron_sub = "^total$", anios = anios)
  d <- leer_excel(ruta, hoja = "Natalidad total", saltar = 3)

  salida <- data.frame(ind_mpio = as.integer(a_numero(d[[1]])))
  for (a in anios) salida[[paste0("nac", a)]] <- a_numero(d[[cols[[as.character(a)]]]])
  salida[!is.na(salida$ind_mpio) & salida$ind_mpio >= 1000, , drop = FALSE]
}

#' Renombra las filas agregadas para dejar explícito el ponderador, como en el
#' .do original ("PROMEDIO PONDERADO PROVINCIA … (por nacimientos)").
.marcar_ponderado <- function(datos, sufijo) {
  dplyr::mutate(datos, municipio = ifelse(
    .data$tipo_fila == "Municipio",
    .data$municipio,
    paste0(stringr::str_replace(.data$municipio, "^TOTAL ", "PROMEDIO PONDERADO "),
           " (", sufijo, ")")
  ))
}

#' El .do deja "DEPARTAMENTO DE ANTIOQUIA" en la columna Provincia de la fila
#' departamental; las demás filas agregadas la dejan vacía.
.provincia_de_totales <- function(datos) {
  dplyr::mutate(datos, provincia = ifelse(
    .data$tipo_fila == "Total departamento", "DEPARTAMENTO DE ANTIOQUIA",
    .data$provincia
  ))
}

ETIQUETAS_TERRITORIO <- c(
  ind_mpio  = "Código DANE",
  municipio = "Municipio",
  subregion = "Subregión",
  provincia = "Provincia"
)

# --- Hoja 1: bajo peso al nacer ----------------------------------------------

.hoja_bajo_peso <- function(prov, archivo, nacimientos) {
  salud <- haven::read_dta(derivado("20260504_SEGURIDAD_SALUD_DEFICT_VIVIENDA.dta"))

  # El indicador viene en puntos porcentuales; se guarda como proporción.
  universo <- data.frame(
    ind_mpio  = as.integer(salud$ind_mpio),
    bajo_peso = as.numeric(salud$bajo_peso) / 100
  ) |>
    dplyr::left_join(nacimientos[, c("ind_mpio", "nac2024")], by = "ind_mpio") |>
    con_territorio()

  municipios <- universo |>
    filtrar_provincia(prov) |>
    dplyr::arrange(.data$nvl_label) |>
    dplyr::select(ind_mpio, municipio, subregion, provincia, nac2024, bajo_peso)

  # Ponderador = NACIMIENTOS (el bajo peso es % de nacimientos, no de población).
  tabla <- agregar_totales(
    municipios, universo = universo, prov = prov,
    columnas = "bajo_peso", como = list(bajo_peso = "promedio_ponderado"),
    pesos = "nac2024"
  ) |>
    .marcar_ponderado("por nacimientos") |>
    .provincia_de_totales() |>
    dplyr::select(ind_mpio, municipio, subregion, provincia, bajo_peso, tipo_fila)

  escribir_hoja(
    dplyr::select(tabla, -tipo_fila), archivo, "bajo_peso",
    etiquetas = c(ETIQUETAS_TERRITORIO,
                  bajo_peso = "Nacidos con bajo peso al nacer (%)"),
    formatos = c(bajo_peso = "0.0%")
  )

  tabla
}

# --- Hoja 2: enfermedades transmitidas por vectores --------------------------

.hoja_enfermedades_tropicales <- function(prov, archivo, pesos) {
  salud <- haven::read_dta(derivado("20260504_SEGURIDAD_SALUD_DEFICT_VIVIENDA.dta"))
  columnas <- c("dengue", "malaria", "leishmaniasis")

  # El .do calcula SOLO el agregado provincial en esta hoja (sin subregión ni
  # departamento): filtra la provincia antes de cruzar el peso poblacional.
  municipios <- data.frame(
    ind_mpio      = as.integer(salud$ind_mpio),
    dengue        = as.numeric(salud$dengue),
    malaria       = as.numeric(salud$malaria),
    leishmaniasis = as.numeric(salud$leishmaniasis)
  ) |>
    con_territorio() |>
    filtrar_provincia(prov) |>
    dplyr::left_join(pesos, by = "ind_mpio") |>
    dplyr::arrange(.data$nvl_label) |>
    dplyr::select(ind_mpio, municipio, subregion, provincia, pob_peso,
                  dplyr::all_of(columnas))

  # Ponderador = POBLACIÓN (son tasas por 100 mil habitantes).
  tabla <- agregar_totales(
    municipios, universo = NULL, prov = prov, columnas = columnas,
    como = stats::setNames(as.list(rep("promedio_ponderado", length(columnas))), columnas),
    pesos = "pob_peso"
  ) |>
    .marcar_ponderado("por población") |>
    dplyr::select(ind_mpio, municipio, subregion, provincia,
                  dplyr::all_of(columnas), tipo_fila)

  escribir_hoja(
    dplyr::select(tabla, -tipo_fila), archivo, "enfermedades_tropicales",
    etiquetas = c(ETIQUETAS_TERRITORIO,
                  dengue        = "Tasa de dengue por 100 mil hab.",
                  malaria       = "Tasa de malaria por 100 mil hab.",
                  leishmaniasis = "Tasa de leishmaniasis por 100 mil hab."),
    formatos = stats::setNames(rep("#,##0.00", length(columnas)), columnas)
  )

  tabla
}

# --- Hoja 3: intento de suicidio y suicidio consumado ------------------------

.hoja_suicidios <- function(prov, archivo, pesos) {
  # El derivado trae todo como texto: hay que forzar la conversión.
  su <- haven::read_dta(derivado("suicidios_e_intentos_medias_dicc.dta"))
  columnas <- c("tis_total", "ts_total")

  universo <- data.frame(
    ind_mpio  = as.integer(a_numero(su$ind_mpio)),
    tis_total = a_numero(su$TIS_total),
    ts_total  = a_numero(su$TS_total)
  ) |>
    dplyr::left_join(pesos, by = "ind_mpio") |>
    con_territorio()

  municipios <- universo |>
    filtrar_provincia(prov) |>
    dplyr::arrange(.data$nvl_label) |>
    dplyr::select(ind_mpio, municipio, subregion, provincia, pob_peso,
                  dplyr::all_of(columnas))

  # Ponderador = POBLACIÓN (son tasas por 100 mil habitantes).
  tabla <- agregar_totales(
    municipios, universo = universo, prov = prov, columnas = columnas,
    como = stats::setNames(as.list(rep("promedio_ponderado", length(columnas))), columnas),
    pesos = "pob_peso"
  ) |>
    .marcar_ponderado("por población") |>
    .provincia_de_totales() |>
    dplyr::select(ind_mpio, municipio, subregion, provincia,
                  dplyr::all_of(columnas), tipo_fila)

  escribir_hoja(
    dplyr::select(tabla, -tipo_fila), archivo, "suicidios",
    etiquetas = c(ETIQUETAS_TERRITORIO,
                  tis_total = "Tasa de intento de suicidio por 100 mil hab.",
                  ts_total  = "Tasa de suicidio consumado por 100 mil hab."),
    formatos = c(tis_total = "#,##0.00", ts_total = "#,##0.00")
  )

  tabla
}

# --- Hoja 4: composición de afiliados al SGSSS por régimen -------------------

.hoja_aseguramiento <- function(prov, archivo) {
  # ASEGURAMIENTO_MUNICIPIOS.xlsx, hoja "1. Población_Afiliada_Regimen".
  # CORTE: DICIEMBRE 2025 (no es total anual). El código municipal viene con
  # 3 dígitos -> ind_mpio = 5000 + cod. Régimen especial y de excepción =
  # Excepción + Fuerza Pública + INPEC. El encabezado ocupa dos filas: el
  # régimen en la primera y "Total Afiliados"/"% de cobertura" en la segunda.
  ruta <- entrada("ASEGURAMIENTO_MUNICIPIOS.xlsx")
  hoja <- "1. Población_Afiliada_Regimen"

  cab <- readxl::read_excel(ruta, sheet = hoja, col_names = FALSE, n_max = 3,
                            .name_repair = "minimal") |> as.data.frame()
  regimen <- norm_txt(as.character(unlist(cab[2, ])))
  for (j in seq_along(regimen)[-1]) {
    if (is.na(regimen[j]) || !nzchar(regimen[j])) regimen[j] <- regimen[j - 1]
  }
  sub <- norm_txt(as.character(unlist(cab[3, ])))

  col_regimen <- function(patron) {
    j <- which(stringr::str_detect(regimen, patron) & startsWith(sub, "total"))
    if (!length(j)) {
      stop("No encuentro la columna de afiliados del régimen '", patron,
           "' en ", basename(ruta), ".", call. = FALSE)
    }
    j[1]
  }

  d <- leer_excel(ruta, hoja = hoja, saltar = 4)
  bruto <- data.frame(
    cod = a_numero(d[[1]]),
    afil_subsidiado   = a_numero(d[[col_regimen("regimen subsidiado")]]),
    afil_contributivo = a_numero(d[[col_regimen("regimen contributivo")]]),
    afil_exc          = a_numero(d[[col_regimen("regimen excepcion")]]),
    afil_fp           = a_numero(d[[col_regimen("fuerza publica")]]),
    afil_inpec        = a_numero(d[[col_regimen("^inpec")]])
  )
  bruto <- bruto[!is.na(bruto$cod), , drop = FALSE]

  columnas <- c("afil_contributivo", "afil_subsidiado", "afil_especial")

  municipios <- bruto |>
    dplyr::mutate(
      ind_mpio      = 5000L + as.integer(.data$cod),
      afil_especial = .data$afil_exc + .data$afil_fp + .data$afil_inpec
    ) |>
    con_territorio() |>
    filtrar_provincia(prov) |>
    dplyr::arrange(.data$nvl_label) |>
    dplyr::select(ind_mpio, municipio, subregion, provincia, dplyr::all_of(columnas))

  # Composición = régimen / total de afiliados. El agregado provincial suma los
  # afiliados y recalcula las proporciones (exacto, no promedia proporciones).
  tabla <- agregar_totales(municipios, universo = NULL, prov = prov,
                           columnas = columnas, como = "suma") |>
    dplyr::mutate(
      .total = .data$afil_contributivo + .data$afil_subsidiado + .data$afil_especial,
      prop_contributivo = .data$afil_contributivo / .data$.total,
      prop_subsidiado   = .data$afil_subsidiado   / .data$.total,
      prop_especial     = .data$afil_especial     / .data$.total
    ) |>
    dplyr::select(ind_mpio, municipio, subregion, provincia,
                  dplyr::all_of(columnas),
                  prop_contributivo, prop_subsidiado, prop_especial, tipo_fila)

  escribir_hoja(
    dplyr::select(tabla, -tipo_fila), archivo, "aseguramiento_sgsss",
    etiquetas = c(ETIQUETAS_TERRITORIO,
                  afil_contributivo = "Afiliados al régimen contributivo",
                  afil_subsidiado   = "Afiliados al régimen subsidiado",
                  afil_especial     = "Afiliados al régimen especial y de excepción",
                  prop_contributivo = "% afiliados régimen contributivo",
                  prop_subsidiado   = "% afiliados régimen subsidiado",
                  prop_especial     = "% afiliados régimen especial y de excepción"),
    formatos = c(afil_contributivo = "#,##0", afil_subsidiado = "#,##0",
                 afil_especial = "#,##0", prop_contributivo = "0.0%",
                 prop_subsidiado = "0.0%", prop_especial = "0.0%")
  )

  tabla
}

# --- Hoja 5: mortalidad infantil 2020-2024 -----------------------------------

.hoja_mortalidad_infantil <- function(prov, archivo, nacimientos, anios = 2020:2024) {
  # MORTALIDAD_INFANTIL.xlsx (hoja "INFANTIL"): matriz ancha con, por año, el
  # número de casos y la "Tasa x mil Nacidos vivos". Se toma la tasa.
  ruta <- entrada("MORTALIDAD_INFANTIL.xlsx")
  cols <- .columnas_por_anio(ruta, "INFANTIL", fila_anio = 4, fila_sub = 5,
                             patron_sub = "^tasa", anios = anios)
  d <- leer_excel(ruta, hoja = "INFANTIL", saltar = 4)

  ancho <- data.frame(ind_mpio = as.integer(a_numero(d[[1]])))
  for (a in anios) ancho[[as.character(a)]] <- a_numero(d[[cols[[as.character(a)]]]])
  ancho <- ancho[!is.na(ancho$ind_mpio) & ancho$ind_mpio >= 1000, , drop = FALSE]

  largo <- ancho |>
    tidyr::pivot_longer(cols = -"ind_mpio", names_to = "anio",
                        values_to = "tasa_mort_infantil") |>
    dplyr::mutate(anio = as.integer(.data$anio))

  nac_largo <- nacimientos |>
    tidyr::pivot_longer(cols = -"ind_mpio", names_to = "anio", values_to = "nac") |>
    dplyr::mutate(anio = as.integer(stringr::str_remove(.data$anio, "^nac")))

  universo <- largo |>
    dplyr::left_join(nac_largo, by = c("ind_mpio", "anio")) |>
    con_territorio()

  # Un bloque de filas por año: municipios, provincia, subregión y departamento.
  # Ponderador = NACIDOS VIVOS de ese año (la tasa es por 1.000 nacidos vivos):
  # tasa_agregada = Σ(tasa_i·nac_i)/Σnac_i = Σcasos/Σnacidos · 1.000.
  # La tasa = 0 se maneja bien: aporta 0 al numerador y sus nacidos al denominador.
  bloques <- lapply(anios, function(a) {
    u_a <- dplyr::filter(universo, .data$anio == a)
    m_a <- u_a |>
      filtrar_provincia(prov) |>
      dplyr::arrange(.data$nvl_label) |>
      dplyr::select(ind_mpio, municipio, subregion, provincia, anio, nac,
                    tasa_mort_infantil)

    agregar_totales(
      m_a, universo = u_a, prov = prov, columnas = "tasa_mort_infantil",
      como = list(tasa_mort_infantil = "promedio_ponderado"), pesos = "nac"
    ) |>
      .marcar_ponderado("por nacidos vivos") |>
      .provincia_de_totales() |>
      dplyr::mutate(anio = a)
  })

  tabla <- dplyr::bind_rows(bloques) |>
    dplyr::select(ind_mpio, municipio, subregion, provincia, anio,
                  tasa_mort_infantil, tipo_fila)

  escribir_hoja(
    dplyr::select(tabla, -tipo_fila), archivo, "mortalidad_infantil",
    etiquetas = c(ETIQUETAS_TERRITORIO,
                  anio = "Año",
                  tasa_mort_infantil = "Tasa de mortalidad infantil (x 1.000 nacidos vivos)"),
    formatos = c(tasa_mort_infantil = "#,##0.00")
  )

  tabla
}

# --- Punto de entrada ---------------------------------------------------------

tabla_salud <- function(prov) {
  message("== 09 Salud — ", prov$etiqueta, " ==")

  archivo <- file.path(dir_seccion(prov, "09_Salud"), "salud.xlsx")
  if (file.exists(archivo)) unlink(archivo)

  pesos       <- .pesos_poblacion()
  nacimientos <- .nacidos_vivos()

  resultado <- list(
    bajo_peso               = .hoja_bajo_peso(prov, archivo, nacimientos),
    enfermedades_tropicales = .hoja_enfermedades_tropicales(prov, archivo, pesos),
    suicidios               = .hoja_suicidios(prov, archivo, pesos),
    aseguramiento_sgsss     = .hoja_aseguramiento(prov, archivo),
    mortalidad_infantil     = .hoja_mortalidad_infantil(prov, archivo, nacimientos)
  )

  message("  09 Salud: ", length(resultado), " hojas en ", basename(archivo))
  invisible(resultado)
}
