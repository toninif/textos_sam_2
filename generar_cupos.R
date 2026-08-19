# =============================================================
# generar_cupos.R
#
# Regenera cupos.json a partir de los datos ya descargados.
# El JSON dice, para cada celda demografica x grupo, CUANTOS FALTAN.
# estudio.html lo lee y sortea el grupo solo entre los que tienen lugar.
#
# Uso: correr, revisar la tabla que imprime, y commitear cupos.json.
# =============================================================

library(tidyverse)
library(jsonlite)

CARPETA   <- "data_raw"   # donde estan los csv bajados de OSF
META      <- 25           # participantes validos por celda x grupo (100 por grupo)
SALIDA    <- "cupos.json"

# ── 1. leer y unificar ──────────────────────────────────────
archivos <- list.files(CARPETA, pattern = "\\.csv$", full.names = TRUE)
raw <- map_dfr(archivos, read_csv, col_types = cols(.default = "c"))

# ── 2. controles de atencion ────────────────────────────────
# CHECK_01 acepta las dos lecturas de "la tercera casilla": la posicion
# numerica (3,5) y la posicion del maniqui (5,9). Ver nota metodologica.
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

# ── 3. celda demografica de cada participante valido ────────
# "otro" se cuenta con varon; "nc" no entra en ninguna celda.
celdas <- raw %>%
  filter(tarea == "sociodemograficos", sujeto %in% validos) %>%
  mutate(edad = as.numeric(edad),
         gen  = if_else(genero == "otro", "varon", genero),
         ed   = if_else(edad >= 40, "40+", "18-39"),
         celda = paste0(gen, "_", ed)) %>%
  filter(gen %in% c("mujer", "varon"), !is.na(edad)) %>%
  count(celda, grupo)

# ── 4. grilla completa (celdas x grupos, incluyendo los ceros) ──
grilla <- expand_grid(
    celda = c("mujer_18-39", "mujer_40+", "varon_18-39", "varon_40+"),
    grupo = as.character(1:4)
  ) %>%
  left_join(celdas, by = c("celda", "grupo")) %>%
  mutate(tengo = replace_na(n, 0L),
         faltan = pmax(0, META - tengo)) %>%
  select(-n)

# ── 5. mirar antes de escribir ──────────────────────────────
cat("\n== YA TENGO ==\n")
grilla %>% select(celda, grupo, tengo) %>%
  pivot_wider(names_from = grupo, values_from = tengo) %>% print()

cat("\n== FALTAN (0 = cerrado) ==\n")
grilla %>% select(celda, grupo, faltan) %>%
  pivot_wider(names_from = grupo, values_from = faltan) %>% print()

cat("\nDeficit total:", sum(grilla$faltan), "validos ->",
    round(sum(grilla$faltan) / 0.86), "tomas aprox.\n\n")

# ── 6. escribir el json ─────────────────────────────────────
a_lista <- function(col) {
  grilla %>%
    select(celda, grupo, valor = all_of(col)) %>%
    split(.$celda) %>%
    map(~ set_names(as.list(.x$valor), .x$grupo))
}

write_json(
  list(
    actualizado = as.character(Sys.Date()),
    meta_por_celda_grupo = META,
    nota = "valores = cuantos participantes VALIDOS faltan en cada celda x grupo. 0 = cerrado.",
    celdas = a_lista("faltan"),
    ya_tengo = a_lista("tengo")
  ),
  SALIDA, auto_unbox = TRUE, pretty = TRUE
)

cat("Escrito:", SALIDA, "- commitealo para que estudio.html lo vea.\n")
