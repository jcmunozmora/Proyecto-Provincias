# =============================================================================
# run_all.R — Pipeline completo: de los datos crudos a las salidas por provincia
#
# USO:
#   Rscript 02_Code/run_all.R              # las 11 provincias
#   Rscript 02_Code/run_all.R 2 4 5        # solo estas provincias
#
# ETAPAS
#   1. Homogeneización  01_Data/00_Inputs  -> 01_Data/01_Derived
#   2. Consolidación    derivados          -> base municipal única
#   3. Tablas           derivados          -> 03_Outputs/<Prov>/<NN>/*.xlsx
#   4. Figuras          tablas             -> .../figuras/*.{png,pdf}
#
# Es idempotente: se puede volver a correr las veces que haga falta. Una etapa
# que falle por un insumo ausente no detiene el resto; el resumen final dice
# qué quedó sin correr y por qué.
# =============================================================================

# La configuración puede venir ya cargada (p. ej. si otro script hizo source de
# este); en ese caso no se vuelve a resolver la raíz.
if (!exists("RUTAS")) {
  .raiz <- Sys.getenv("PROVINCIAS_ROOT", unset = "")
  if (!nzchar(.raiz)) {
    .args <- commandArgs(trailingOnly = FALSE)
    .f <- sub("^--file=", "", .args[grepl("^--file=", .args)])
    .raiz <- if (length(.f)) dirname(dirname(normalizePath(.f[1]))) else getwd()
  }
  source(file.path(.raiz, "02_Code", "R", "00_config.R"), encoding = "UTF-8")
}
source(file.path(RUTAS$codigo, "run_provincia.R"), encoding = "UTF-8")

inicio <- Sys.time()

# --- Etapa 1: homogeneización -------------------------------------------------
# Orden: el crosswalk territorial va primero porque casi todo lo demás lo usa.
HOMOGENEIZACION <- c(
  "crosswalk_territorial.R"
)

message("\n#########################################################")
message("#  ETAPA 1 — Homogeneización de insumos")
message("#########################################################")

estado_homog <- lapply(HOMOGENEIZACION, function(s) {
  ruta <- file.path(RUTAS$codigo, "01_homogeneizacion", s)
  if (!file.exists(ruta)) return(c(script = s, estado = "NO EXISTE", detalle = ""))
  r <- tryCatch({ source(ruta, encoding = "UTF-8"); NULL }, error = function(e) e)
  if (is.null(r)) {
    c(script = s, estado = "OK", detalle = "")
  } else {
    message("  [FALLO] ", s, ": ", conditionMessage(r))
    c(script = s, estado = "FALLO", detalle = conditionMessage(r))
  }
})
estado_homog <- as.data.frame(do.call(rbind, estado_homog), stringsAsFactors = FALSE)

# --- Etapa 2: consolidación ---------------------------------------------------
CONSOLIDACION <- character(0)  # se llena a medida que se migre 00_BuildData.do

if (length(CONSOLIDACION)) {
  message("\n#########################################################")
  message("#  ETAPA 2 — Consolidación")
  message("#########################################################")
  for (s in CONSOLIDACION) {
    ruta <- file.path(RUTAS$codigo, "02_consolidacion", s)
    if (file.exists(ruta)) {
      tryCatch(source(ruta, encoding = "UTF-8"),
               error = function(e) message("  [FALLO] ", s, ": ", conditionMessage(e)))
    }
  }
}

# --- Etapas 3 y 4: tablas y figuras por provincia -----------------------------
cli <- commandArgs(trailingOnly = TRUE)
ids <- if (length(cli)) as.integer(cli) else PROVINCIAS$id

message("\n#########################################################")
message("#  ETAPAS 3 y 4 — Tablas y figuras (", length(ids), " provincias)")
message("#########################################################")

resumen <- do.call(rbind, lapply(ids, function(i) {
  r <- correr_provincia(i)
  cbind(provincia = provincia(i)$etiqueta, r)
}))

# --- Resumen final ------------------------------------------------------------
duracion <- round(as.numeric(difftime(Sys.time(), inicio, units = "mins")), 1)

message("\n#########################################################")
message("#  RESUMEN  (", duracion, " min)")
message("#########################################################")

message("\nHomogeneización:")
for (i in seq_len(nrow(estado_homog))) {
  message(sprintf("  %-34s %s", estado_homog$script[i], estado_homog$estado[i]))
}

message("\nSecciones por estado:")
conteo <- table(resumen$estado)
for (e in names(conteo)) message(sprintf("  %-12s %d", e, conteo[[e]]))

pendientes <- unique(resumen$seccion[resumen$estado == "PENDIENTE"])
if (length(pendientes)) {
  message("\nSecciones sin migrar todavía: ", paste(pendientes, collapse = ", "))
}
errores <- resumen[resumen$estado == "ERROR", ]
if (nrow(errores)) {
  message("\nErrores:")
  for (i in seq_len(nrow(errores))) {
    message(sprintf("  %-28s %-22s %s", errores$provincia[i], errores$seccion[i],
                    errores$detalle[i]))
  }
}
message("")
invisible(resumen)
