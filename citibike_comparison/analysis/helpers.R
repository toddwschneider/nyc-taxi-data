library(tidyverse)
library(lubridate)
library(scales)
library(broom)
library(extrafont)
library(RPostgreSQL)

taxi_con = dbConnect(dbDriver("PostgreSQL"), dbname = "nyc-taxi-data", host = "localhost")
citi_con = dbConnect(dbDriver("PostgreSQL"), dbname = "nyc-citibike-data", host = "localhost")

query = function(sql, con = taxi_con) {
  dbSendQuery(con, sql) %>%
    fetch(n = 1e8) %>%
    as_data_frame()
}

taxi_hex = "#f7b731"
citi_hex = "#146eff"

font_family = ifelse("Open Sans" %in% fonts(), "Open Sans", "Arial")
title_font_family = ifelse("Fjalla One" %in% fonts(), "Fjalla One", "Arial")

theme_tws = function(base_size = 12) {
  bg_color = "#f4f4f4"
  bg_rect = element_rect(fill = bg_color, color = bg_color)

  theme_bw(base_size) +
    theme(
      text = element_text(family = font_family),
      plot.title = element_text(family = title_font_family),
      plot.subtitle = element_text(size = rel(0.7), lineheight = 1),
      plot.caption = element_text(size = rel(0.5), margin = unit(c(1, 0, 0, 0), "lines"), lineheight = 1.1, color = "#555555"),
      plot.background = bg_rect,
      axis.ticks = element_blank(),
      axis.text.x = element_text(size = rel(1)),
      axis.title.x = element_text(size = rel(1), margin = margin(1, 0, 0, 0, unit = "lines")),
      axis.text.y = element_text(size = rel(1)),
      axis.title.y = element_text(size = rel(1)),
      panel.background = bg_rect,
      panel.border = element_blank(),
      panel.grid.major = element_line(color = "grey80", size = 0.25),
      panel.grid.minor = element_line(color = "grey80", size = 0.25),
      panel.spacing = unit(1.25, "lines"),
      legend.background = bg_rect,
      legend.key.width = unit(1.5, "line"),
      legend.key = element_blank(),
      strip.background = element_blank()
    )
}

no_axis_titles = function() {
  theme(axis.title = element_blank())
}
