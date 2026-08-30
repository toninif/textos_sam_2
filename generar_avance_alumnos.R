# ============================================================
# generar_avance_alumnos.R
#
# Cuenta, para cada alumno (columna codigo_participante = el "p" de
# su enlace), cuantos casos VALIDOS lleva recolectados EN CADA PERFIL
# pedido -varon 18-39, varon 40+, mujer 40+, 5 cada uno- y escribe un
# JSON por alumno en avance/<codigo>.json.
#
# "Valido" = participante que paso los 2 controles de atencion, mismo
# criterio que generar_cupos.R. La celda demografica se calcula igual
# que alli (genero "otro" cuenta como varon; edad >= 40 es "40+").
#
# mujer_18-39 NO cuenta para la meta del alumno: esa celda ya esta
# cerrada a nivel del estudio completo (ver cupos.json), asi que un
# caso valido de ese perfil, o uno sin genero declarado ("nc"), se sigue
# contando en "otros" para que el total cuadre, pero no suma a ningun
# perfil pedido.
#
# Uso: bajar los CSV nuevos a data_raw/ (misma carpeta que usa
# generar_cupos.R), correr este script entero, y subir/commitear
# la carpeta avance/ actualizada.
# ============================================================

library(tidyverse)
library(jsonlite)

CARPETA <- "data_raw"            # csv descargados de OSF
ALUMNOS <- "enlaces_alumnos.csv" # codigo -> apellido/nombre
SALIDA  <- "avance"              # un json por alumno
META_CELDA <- 5                  # casos validos pedidos, por perfil
PERFILES   <- c("varon_18-39", "varon_40+", "mujer_40+")  # los que piden

# ── 1. leer y unificar ──────────────────────────────────────
archivos <- list.files(CARPETA, pattern = "\\.csv$", full.names = TRUE)
raw <- map_dfr(archivos, read_csv, col_types = cols(.default = "c"))

# ── 2. controles de atencion (mismo criterio que generar_cupos.R) ──
validos <- raw %>%
  filter(tarea == "sam", id_texto %in% c("CHECK_01", "CHECK_02")) %>%
  mutate(across(c(valencia, activacion), as.numeric),
         paso = case_when(
           id_texto == "CHECK_01" ~ (valencia == 3 & activacion == 5) |
                                    (valencia == 5 & activacion == 9),
           id_texto == "CHECK_02" ~ valencia == 5 & activacion == 5
         )) %>%
  group_by(sujeto) %>%
  summarise(n_checks = n(), aprobados = sum(paso), .groups = "drop") %>%
  filter(n_checks == 2, aprobados == 2) %>%
  pull(sujeto)

# ── 3. celda demografica de cada caso valido (igual que generar_cupos.R) ──
socio <- raw %>%
  filter(tarea == "sociodemograficos", sujeto %in% validos) %>%
  distinct(sujeto, codigo_participante, edad, genero) %>%
  mutate(edad = as.numeric(edad),
         gen  = if_else(genero == "otro", "varon", genero),
         ed   = if_else(edad >= 40, "40+", "18-39"),
         celda = if_else(gen %in% c("mujer", "varon") & !is.na(edad),
                          paste0(gen, "_", ed), "otros"),
         celda = if_else(celda %in% PERFILES, celda, "otros"))

# ── 4. conteo por alumno x perfil ───────────────────────────
conteo <- socio %>% count(codigo_participante, celda, name = "n")

tabla_alumno <- function(codigo) {
  fila <- conteo %>% filter(codigo_participante == codigo)
  celdas <- map(PERFILES, function(p) {
    n <- fila %>% filter(celda == p) %>% pull(n)
    list(validos = if (length(n) == 0) 0L else n, meta = META_CELDA)
  })
  names(celdas) <- PERFILES
  otros <- fila %>% filter(celda == "otros") %>% pull(n)
  otros <- if (length(otros) == 0) 0L else otros
  list(celdas = celdas, otros = otros,
       total_validos = sum(map_dbl(celdas, "validos")) + otros,
       total_meta = META_CELDA * length(PERFILES))
}

# ── 5. cruzar con la lista completa de alumnos ──────────────
# Se arma desde la lista de alumnos (no desde los datos) para que los
# que todavia tienen 0 casos tambien tengan su archivo.
alumnos <- read_csv(ALUMNOS, show_col_types = FALSE)

# ── 6. mirar antes de escribir ──────────────────────────────
resumen <- alumnos %>%
  mutate(t = map(codigo, tabla_alumno))

for (p in PERFILES) {
  resumen[[p]] <- map_int(resumen$t, ~ .x$celdas[[p]]$validos)
}
resumen$otros <- map_int(resumen$t, "otros")
resumen$total <- map_dbl(resumen$t, "total_validos")

cat("\n== AVANCE POR ALUMNO Y PERFIL ==\n")
print(resumen %>% select(codigo, apellido, nombre, all_of(PERFILES), otros, total),
      n = Inf)

# ── 7. escribir un json por alumno ──────────────────────────
dir.create(SALIDA, showWarnings = FALSE)
hoy <- as.character(Sys.Date())

walk2(alumnos$codigo, resumen$t, function(codigo, t) {
  write_json(
    list(codigo = codigo, actualizado = hoy,
         celdas = t$celdas, otros = t$otros,
         total_validos = t$total_validos, total_meta = t$total_meta),
    file.path(SALIDA, paste0(codigo, ".json")),
    auto_unbox = TRUE
  )
})

cat("\nEscritos", nrow(alumnos), "archivos en", SALIDA,
    "- commitealos para que tablero_alumnos.html los vea.\n")
