# =============================================================================
# comparar_referencia.R — Valida las tablas generadas contra el informe publicado
#
# El Anexo 1 (00_Documentos) es la salida final del pipeline anterior para la
# provincia Bioenergética del Norte: 52 tablas ya curadas. Este script compara,
# municipio por municipio, los valores que produce el pipeline R contra los que
# se publicaron, y reporta las diferencias.
#
# Es el criterio de aceptación de la migración: una sección no se da por
# migrada mientras no reproduzca las cifras publicadas (o mientras la diferencia
# no esté explicada).
#
# USO:
#   Rscript 02_Code/99_checks/comparar_referencia.R
#
# REQUIERE: tests/referencia/ (generar con tests/extraer_referencia_anexo1.py)
# ETAPA DEL PIPELINE: verificación
# =============================================================================

if (!exists("RUTAS")) {
  source(file.path(getwd(), "02_Code", "R", "00_config.R"), encoding = "UTF-8")
}

#' Convierte texto de una tabla del informe a número.
#' El informe usa formato colombiano ("2.841", "38%", "1.234,5").
.num_ref <- function(x) {
  y <- stringr::str_squish(as.character(x))
  y <- stringr::str_remove_all(y, "[%$\\s]")
  y <- stringr::str_remove_all(y, "\\.")     # separador de miles
  y <- stringr::str_replace(y, ",", ".")     # decimal
  suppressWarnings(as.numeric(y))
}

#' Ruta del CSV de una tabla del Anexo, buscada por su título.
#'
#' Se busca por título y no por número de archivo: el orden de los archivos
#' depende de cuántas tablas sin título (contenedores de mapas) haya antes, así
#' que un número fijo se desactualiza en cuanto cambia el documento.
#'
#' @param patron texto o expresión regular que identifica la tabla,
#'   p. ej. "Tabla 45." o "Cobertura neta".
tabla_referencia <- function(patron) {
  indice <- utils::read.csv(file.path(RUTAS$referencia, "tablas", "indice.csv"),
                            encoding = "UTF-8", stringsAsFactors = FALSE)
  i <- grep(patron, indice$titulo, ignore.case = TRUE, fixed = FALSE)
  if (length(i) == 0) {
    warning("Ninguna tabla del Anexo coincide con: ", patron, call. = FALSE)
    return(NA_character_)
  }
  if (length(i) > 1) {
    warning(length(i), " tablas coinciden con '", patron, "'; se usa la primera: ",
            indice$titulo[i[1]], call. = FALSE)
  }
  file.path(RUTAS$referencia, "tablas", indice$archivo[i[1]])
}

#' Extrae de una tabla del Anexo los pares (municipio, valor) de cada columna
#' numérica, emparejando los municipios por nombre normalizado.
#'
#' @param csv ruta del CSV extraído del Anexo (use `tabla_referencia()`).
#' @param municipios nombres de municipio esperados (los de la provincia).
leer_tabla_referencia <- function(csv, municipios) {
  if (is.na(csv) || !file.exists(csv)) return(NULL)
  crudo <- utils::read.csv(csv, header = FALSE, colClasses = "character",
                           encoding = "UTF-8")
  clave <- norm_txt(municipios)

  # Columna de municipios: la que más nombres reconocidos contiene
  aciertos <- vapply(crudo, function(cl) sum(norm_txt(cl) %in% clave), integer(1))
  if (max(aciertos) < length(municipios) * 0.6) {
    return(NULL)  # no es una tabla municipal comparable
  }
  j_mun <- which.max(aciertos)

  filas <- which(norm_txt(crudo[[j_mun]]) %in% clave)
  d <- crudo[filas, , drop = FALSE]
  salida <- data.frame(municipio_norm = norm_txt(d[[j_mun]]), stringsAsFactors = FALSE)

  # `decimales` guarda con cuántos decimales se publicó cada columna: el informe
  # redondea (p. ej. 1,57 % aparece como 2 %), así que la comparación debe
  # hacerse a esa precisión y no a la del pipeline.
  decimales <- integer(0)
  for (j in seq_along(crudo)) {
    if (j == j_mun) next
    v <- .num_ref(d[[j]])
    if (sum(!is.na(v)) >= length(filas) * 0.6) {
      nombre <- paste0("col_", j)
      salida[[nombre]] <- v
      texto <- stringr::str_squish(d[[j]])
      dec <- stringr::str_match(texto, ",(\\d+)")[, 2]
      decimales[nombre] <- max(c(0L, nchar(dec[!is.na(dec)])))
    }
  }
  attr(salida, "decimales") <- decimales
  salida
}

#' Compara una columna generada contra la columna de la referencia que mejor le
#' corresponda, y reporta el resultado.
#'
#' @param generada data.frame con `municipio` y la columna de valores.
#' @param columna nombre de la columna de valores en `generada`.
#' @param referencia salida de leer_tabla_referencia().
#' @param tolerancia diferencia relativa admitida (por defecto 0,5 %, que
#'   absorbe el redondeo con que se publicaron las cifras).
comparar_columna <- function(generada, columna, referencia, tolerancia = 0.005) {
  g <- data.frame(
    municipio_norm = norm_txt(generada$municipio),
    valor = as.numeric(generada[[columna]]),
    stringsAsFactors = FALSE
  )
  g <- g[!is.na(g$valor), , drop = FALSE]

  decimales <- attr(referencia, "decimales")
  mejor <- NULL
  for (cl in setdiff(names(referencia), "municipio_norm")) {
    m <- merge(g, referencia[, c("municipio_norm", cl)], by = "municipio_norm")
    if (nrow(m) == 0) next
    ref <- m[[cl]]
    dec <- decimales[[cl]] %||% 2L
    # La referencia puede venir en % (38) donde el pipeline da proporción (0,38)
    for (k in c(1, 100, 1 / 100)) {
      # Se compara a la precisión con que se publicó la cifra
      gen <- round(m$valor * k, dec)
      dif <- abs(gen - ref) / pmax(abs(ref), 1e-9)
      dif[is.na(dif)] <- Inf
      ok <- mean(dif <= tolerancia)
      if (is.null(mejor) || ok > mejor$ok) {
        mejor <- list(ok = ok, col = cl, escala = k, decimales = dec, n = nrow(m),
                      peor = if (all(is.infinite(dif))) NA else max(dif[is.finite(dif)]),
                      detalle = data.frame(municipio = m$municipio_norm,
                                           generado = gen, publicado = ref,
                                           dif_rel = dif))
      }
    }
  }
  mejor
}

# Diferencias verificadas una a una que NO son fallos de la migración: el valor
# del pipeline es el correcto según la fuente y el publicado tiene una errata.
# Formato: "seccion|columna|municipio" -> explicación.
DIFERENCIAS_CONOCIDAS <- c(
  "01_Generalidades|Área municipal (km²)|toledo" = paste(
    "AREA_ORIGINAL.xlsx da 122,578 km², que redondea a 123; el Anexo 1 publica",
    "122. Los otros 15 valores de la tabla sí redondean bien, así que es una",
    "errata del informe."
  )
)

#' Informe de comparación de una columna, listo para leer en consola.
reportar <- function(etiqueta, resultado, seccion = "") {
  if (is.null(resultado)) {
    cat(sprintf("  %-40s SIN REFERENCIA COMPARABLE\n", etiqueta))
    return(invisible(FALSE))
  }
  malos <- resultado$detalle[which(resultado$detalle$dif_rel > 0.005), ]
  malos <- malos[order(-malos$dif_rel), ]
  # paste() con un vector vacío devuelve un elemento, no cero: sin este guard,
  # una columna sin diferencias reportaría una diferencia inexistente.
  clave <- if (nrow(malos)) {
    paste(seccion, etiqueta, malos$municipio, sep = "|")
  } else {
    character(0)
  }
  explicadas <- clave %in% names(DIFERENCIAS_CONOCIDAS)

  n_ok <- resultado$n - sum(!explicadas)
  estado <- if (n_ok == resultado$n) {
    if (any(explicadas)) "COINCIDE (con erratas del informe registradas)" else "COINCIDE"
  } else {
    "DIFIERE"
  }
  cat(sprintf("  %-40s %s  (%d/%d municipios)\n", etiqueta, estado, n_ok, resultado$n))

  for (i in seq_len(nrow(malos))) {
    marca <- if (explicadas[i]) "errata conocida" else "REVISAR"
    cat(sprintf("      [%s] %-24s pipeline %10.3f   publicado %10.3f\n",
                marca, malos$municipio[i], malos$generado[i], malos$publicado[i]))
    if (explicadas[i]) {
      cat("          ", DIFERENCIAS_CONOCIDAS[[clave[i]]], "\n")
    }
  }
  invisible(n_ok == resultado$n)
}

# --- Ejecución ----------------------------------------------------------------
if (sys.nframe() == 0 || identical(environment(), globalenv())) {
  dir_ref <- file.path(RUTAS$referencia, "tablas")
  if (!dir.exists(dir_ref)) {
    stop("No hay referencia extraída. Ejecute primero:\n",
         "  python3 tests/extraer_referencia_anexo1.py", call. = FALSE)
  }

  prov <- provincia(2)  # el Anexo 1 corresponde a esta provincia
  municipios <- crosswalk_provincias() |>
    filtrar_provincia(prov) |>
    dplyr::pull(municipio)

  cat("== Comparación contra el Anexo 1 —", prov$etiqueta, "==\n\n")

  # Sección 01 — distribución territorial (Tabla 6 del informe)
  archivo <- file.path(RUTAS$outputs, prov$carpeta, "01_Generalidades",
                       "distribucion_territorial.xlsx")
  if (file.exists(archivo)) {
    generada <- openxlsx2::wb_to_df(openxlsx2::wb_load(archivo), sheet = 1)
    names(generada)[names(generada) == "Municipio"] <- "municipio"
    ref <- leer_tabla_referencia(tabla_referencia("Extensión territorial"),
                                 municipios)
    cat("01_Generalidades / distribucion_territorial\n")
    reportar("Área municipal (km²)",
             comparar_columna(generada, "Área municipal (km²)", ref),
             "01_Generalidades")
    reportar("Participación en el área provincial",
             comparar_columna(generada, "Participación en el área provincial", ref),
             "01_Generalidades")
  } else {
    cat("01_Generalidades: no se ha generado todavía\n")
  }
  cat("\n")
}
