# 1. PACKAGES

libs <- c(
  "terra",
  "giscoR",
  "sf",
  "tidyverse",
  "ggtern",
  "elevatr",
  "png",
  "rayshader",
  "magick"
)

installed_libraries <- libs %in% rownames(
  installed.packages()
)

if(any(installed_libraries == F)){
  install.packages(
    libs[!installed_libraries]
  )
}

invisible(
  lapply(
    libs, library, character.only = T
  )
)

# 2. COUNTRY BORDERS

country_sf <- giscoR::gisco_get_countries(
  country = "CH",
  resolution = "1"
)

plot(sf::st_geometry(country_sf))

png("ch-borders.png")
plot(sf::st_geometry(country_sf))
dev.off()

# 3 DOWNLOAD ESRI LAND COVER TILES

urls <- c(
  "https://lulctimeseries.blob.core.windows.net/lulctimeseriesv003/lc2022/32T_20220101-20230101.tif"
)

# Increase timeout for large files (from default 60 seconds to 600 seconds)
options(timeout = 600)

for(url in urls){
  destfile <- basename(url)
  
  # Skip if file already exists
  if(file.exists(destfile)){
    cat("File", destfile, "already exists. Skipping download.\n")
    next
  }
  
  cat("Downloading", destfile, "...\n")
  
  tryCatch({
    download.file(
      url = url,
      destfile = destfile,
      mode = "wb",
      method = "libcurl"  # More reliable for large files
    )
    cat("Successfully downloaded", destfile, "\n")
  }, error = function(e){
    cat("Error downloading", destfile, ":", e$message, "\n")
    cat("You may need to download this file manually from:\n", url, "\n")
  })
}

# 4 LOAD TILES

raster_files <- list.files(
  path = getwd(),
  pattern = "20230101.tif$",
  full.names = T
)

# Check if files were downloaded
if(length(raster_files) == 0){
  stop("No raster files found. Please ensure the downloads completed successfully.")
}

cat("Found", length(raster_files), "raster file(s)\n")

crs <- "EPSG:4326"

for(raster in raster_files){
  output_file <- paste0(raster, "_switzerland.tif")
  
  # Skip if already processed
  if(file.exists(output_file)){
    cat("Processed file", output_file, "already exists. Skipping.\n")
    next
  }
  
  cat("Processing", basename(raster), "...\n")
  
  rasters <- terra::rast(raster)
  
  country <- country_sf |>
    sf::st_transform(
      crs = terra::crs(
        rasters
      )
    )
  
  land_cover <- terra::crop(
    rasters,
    terra::vect(
      country
    ),
    snap = "in",
    mask = T
  ) |>
    terra::aggregate(
      fact = 5,
      fun = "modal"
    ) |>
    terra::project(crs)
  
  terra::writeRaster(
    land_cover,
    output_file,
    overwrite = T
  )
  
  cat("Saved", basename(output_file), "\n")
}

# 5 LOAD VIRTUAL LAYER

r_list <- list.files(
  path = getwd(),
  pattern = "_switzerland",
  full.names = T
)

cat("Creating virtual raster from", length(r_list), "file(s)\n")

land_cover_vrt <- terra::vrt(
  r_list,
  "switzerland_land_cover_vrt.vrt",
  overwrite = T
)

# 6 FETCH ORIGINAL COLORS

ras <- terra::rast(
  raster_files[[1]]
)

raster_color_table <- do.call(
  data.frame,
  terra::coltab(ras)
)

head(raster_color_table)

hex_code <- ggtern::rgb2hex(
  r = raster_color_table[,2],
  g = raster_color_table[,3],
  b = raster_color_table[,4]
)

# 7 ASSIGN COLORS TO RASTER

cols <- hex_code[c(2:3, 5:6, 8:12)]

from <- c(1:2, 4:5, 7:11)
to <- t(col2rgb(cols))
land_cover_vrt <- na.omit(land_cover_vrt)

land_cover_switzerland <- terra::subst(
  land_cover_vrt,
  from = from,
  to = to,
  names = cols
)

terra::plotRGB(land_cover_switzerland)

# 8 DIGITAL ELEVATION MODEL

cat("Downloading elevation data...\n")

elev <- elevatr::get_elev_raster(
  locations = country_sf,
  z = 9, clip = "locations"
)

crs_lambert <-
  "+proj=laea +lat_0=52 +lon_0=10 +x_0=4321000 +y_0=3210000 +datum=WGS84 +units=m +no_frfs"

land_cover_switzerland_resampled <- terra::resample(
  x = land_cover_switzerland,
  y = terra::rast(elev),
  method = "near"
) |>
  terra::project(crs_lambert)

terra::plotRGB(land_cover_switzerland_resampled)

img_file <- "land_cover_switzerland.png"

terra::writeRaster(
  land_cover_switzerland_resampled,
  img_file,
  overwrite = T,
  NAflag = 255
)

img <- png::readPNG(img_file)

# 9. RENDER SCENE
#----------------

cat("Creating 3D scene...\n")

elev_lambert <- elev |>
  terra::rast() |>
  terra::project(crs_lambert)

elmat <- rayshader::raster_to_matrix(
  elev_lambert
)

h <- nrow(elev_lambert)
w <- ncol(elev_lambert)

elmat |>
  rayshader::height_shade(
    texture = colorRampPalette(
      cols[9]
    )(256)
  ) |>
  rayshader::add_overlay(
    img,
    alphalayer = 1
  ) |>
  rayshader::plot_3d(
    elmat,
    zscale = 12,
    solid = F,
    shadow = T,
    shadow_darkness = 1,
    background = "white",
    windowsize = c(
      w / 5, h / 5
    ),
    zoom = .5,
    phi = 85,
    theta = 0
  )

rayshader::render_camera(
  zoom = .58
)

# 10. RENDER OBJECT
#-----------------

cat("Downloading HDRI file...\n")

u <- "https://dl.polyhaven.org/file/ph-assets/HDRIs/hdr/4k/air_museum_playground_4k.hdr"
hdri_file <- basename(u)

if(!file.exists(hdri_file)){
  download.file(
    url = u,
    destfile = hdri_file,
    mode = "wb",
    method = "libcurl"
  )
}

filename <- "3d_land_cover_switzerland-dark.png"

cat("Rendering high-quality image (this may take several minutes)...\n")

rayshader::render_highquality(
  filename = filename,
  preview = T,
  light = F,
  environment_light = hdri_file,
  intensity_env = 1,
  rotate_env = 90,
  interactive = F,
  parallel = T,
  width = w * 1.5,
  height = h * 1.5
)

cat("High-quality render saved as:", filename, "\n")

# 11. PUT EVERYTHING TOGETHER

cat("Creating final composite image...\n")

c(
  "#419bdf", "#397d49", "#7a87c6", 
  "#e49635", "#c4281b", "#a59b8f", 
  "#a8ebff", "#616161", "#e3e2c3"
)

legend_name <- "land_cover_legend.png"
png(legend_name)
par(family = "mono")

plot(
  NULL,
  xaxt = "n",
  yaxt = "n",
  bty = "n",
  ylab = "",
  xlab = "",
  xlim = 0:1,
  ylim = 0:1,
  xaxs = "i",
  yaxs = "i"
)
legend(
  "center",
  legend = c(
    "Water",
    "Trees",
    "Crops",
    "Built area",
    "Rangeland"
  ),
  pch = 15,
  cex = 2,
  pt.cex = 1,
  bty = "n",
  col = c(cols[c(1:2, 4:5, 9)]),
  fill = c(cols[c(1:2, 4:5, 9)]),
  border = "grey20"
)
dev.off()

lc_img <- magick::image_read(
  filename
)

my_legend <- magick::image_read(
  legend_name
)

my_legend_scaled <- magick::image_scale(
  magick::image_background(
    my_legend, "none"
  ), 2500
)

p <- magick::image_composite(
  magick::image_scale(
    lc_img, "x7000" 
  ),
  my_legend_scaled,
  gravity = "southwest",
  offset = "+100+0"
)

magick::image_write(
  p, "3d_switzerland_land_cover_final.png"
)

cat("\n=== COMPLETE ===\n")
cat("Final image saved as: 3d_switzerland_land_cover_final.png\n")