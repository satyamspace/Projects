# Automated Wind Flow Visualization Over Bangladesh Using **Python**
### Automating extraction, analysis, and animation of 10m wind components (u10 & v10) over Bangladesh  

![Bangladesh Wind Map](https://raw.githubusercontent.com/imtiajiqbalmahfuj/imtiajiqbal-portfolio/refs/heads/main/Projects/25015%20Automated%20wind%20flow%20map%20of%20Bangladesh/Bangladesh_Wind_Streamlines-0000.jpg)  

[Animated GIF](https://github.com/imtiajiqbalmahfuj/imtiajiqbal-portfolio/blob/main/Projects/25015%20Automated%20wind%20flow%20map%20of%20Bangladesh/Bangladesh_Wind_Streamlines_small.gif)  


![Date](https://img.shields.io/badge/17/09/2025-18/09/2025-blue) 
![Location](https://img.shields.io/badge/Location-Bangladesh-green) 
---

## 📝 Overview
Wind patterns play a crucial role in climate dynamics, disaster management, and environmental research. Manually analyzing large climate datasets is often time-consuming and prone to error.

This project automates the extraction, clipping, analysis, and visualization of 10m wind data (u10 & v10 components) over Bangladesh using ERA5 NetCDF datasets and shapefiles of Bangladesh's administrative boundaries.

The workflow produces static wind speed maps, vector field plots, and animated streamline GIFs, allowing researchers and GIS professionals to easily explore temporal wind dynamics across the country.
---

## 🛠️ Tools & Technologies
![Python](https://img.shields.io/badge/Geospatial-Python-red)  
![GIS](https://img.shields.io/badge/GIS-Geopandas%2CCartopy-green)  

---

## ⚙️ Methodology
| Step | Description |
|------|-------------|
| 1. Data Collection | Download ERA5 10m wind components (u10, v10) for selected dates via CDS API. |
| 2. Preprocessing   | Load Bangladesh shapefile (GADM), convert CRS to EPSG:4326, clip NetCDF wind data to Bangladesh boundaries. |
| 3. Analysis        | Create 2D grids of longitude/latitude, mask points outside Bangladesh, compute wind speed and direction. |
| 4. Visualization   | Generate static wind speed maps, vector field plots, and animated streamline GIFs using Matplotlib & Cartopy. |

---

## 📊 Codes & Results

Import Packages
```python
import geopandas as gpd
import xarray as xr
import geopandas as gpd
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import cartopy.crs as ccrs
import numpy as np
from shapely.geometry import Point
import matplotlib.colors as mcolors
from cartopy.mpl.ticker import LongitudeFormatter, LatitudeFormatter
import cdsapi
```
Connect Data Source
```python
c = cdsapi.Client()
print("CDS API is working!")
```
Fetch Data
```python
import cdsapi

dataset = "reanalysis-era5-single-levels"

request = {
    "product_type": "reanalysis",
    "variable": ["10m_u_component_of_wind", "10m_v_component_of_wind"],
    "year": "2025",
    "month": "08",
    "day": [
        "25", "26", "27", "28", "29", "30"
    ],
    "time": [f"{h:02d}:00" for h in range(0, 24, 3)],
    "format": "netcdf",
    "area": [37.5, 68.7, 6.7, 97.25]
}

client = cdsapi.Client()

output_file = "I:\Planning\Geospatial Python\geopy environment\Practices\Wind Data Visualization\Data\wind_25to30Aug2025.nc"

client.retrieve(dataset, request, output_file)

print(f"Data successfully downloaded to {output_file}")
```
Read AOI
```python
bd = gpd.read_file("Data\Administrative areas (GADM) BD\BGD_adm0.shp")
bd = bd.to_crs(epsg=4326)
```
Select data and work on it 
```python
ds = xr.open_dataset("I:\Planning\Geospatial Python\geopy environment\Practices\Wind Data Visualization\Data\wind_25to30Aug2025.nc")

u = ds['u10']
v = ds['v10']
lons = ds.longitude.values
lats = ds.latitude.values
times = ds.valid_time.values

lon2d, lat2d = np.meshgrid(lons, lats)
points = np.array([lon2d.flatten(), lat2d.flatten()]).T
points_gdf = gpd.GeoDataFrame(geometry=[Point(x, y) for x, y in points], crs="EPSG:4326")

inside = points_gdf.within(bd.unary_union)
mask = inside.values.reshape(lat2d.shape)
```
Plot Data (Visualization) & Animate 
```python
# --------------------------
# Map and figure setup
# --------------------------
fig, ax = plt.subplots(
    figsize=(10, 10),
    subplot_kw={'projection': ccrs.PlateCarree()},
    facecolor='black'
)

# Set map extent for Bangladesh
ax.set_facecolor('black')
ax.set_extent([88.0, 92.7, 20.7, 26.6], crs=ccrs.PlateCarree())

# Plot Bangladesh boundary
bd.boundary.plot(ax=ax, edgecolor='white', linewidth=1)

# --------------------------
# Colorbar setup
# --------------------------
cmap = plt.cm.plasma
norm = mcolors.Normalize(vmin=0, vmax=20)  # Adjust vmax according to wind speed range

sm = plt.cm.ScalarMappable(cmap=cmap, norm=norm)
sm.set_array([])

cbar = fig.colorbar(sm, ax=ax, orientation='vertical', fraction=0.03, pad=0.04)
cbar.set_label('Wind Speed (m/s)', color='white')
cbar.ax.yaxis.set_tick_params(color='white')
plt.setp(cbar.ax.get_yticklabels(), color='white')

# --------------------------
# Scale bar function
# --------------------------
def add_scalebar(ax, length_km=200, location=(0.05, 0.05), linewidth=3, text_color='white'):
    extent = ax.get_extent(ccrs.PlateCarree())
    lon_start = extent[0]
    lat_start = extent[2]
    lon_end = extent[1]
    lat_end = extent[3]

    km_per_deg = 111  # Approximate conversion
    length_deg = length_km / km_per_deg

    # Bar position
    bar_lon = lon_start + (lon_end - lon_start) * location[0]
    bar_lat = lat_start + (lat_end - lat_start) * location[1]

    # Draw the scale bar
    ax.plot(
        [bar_lon, bar_lon + length_deg], [bar_lat, bar_lat],
        transform=ccrs.PlateCarree(),
        color=text_color, linewidth=linewidth
    )

    # Place text slightly below the bar dynamically
    lat_offset = (lat_end - lat_start) * 0.01  # 1% of map height
    ax.text(
        bar_lon + length_deg / 2, bar_lat - lat_offset,
        f"{length_km} km",
        transform=ccrs.PlateCarree(),
        ha='center', va='top',
        color=text_color, fontsize=9
    )

# --------------------------
# Animation function
# --------------------------
def animate(i):
    ax.clear()
    ax.set_facecolor('black')
    ax.set_extent([88.0, 92.7, 20.7, 26.6], crs=ccrs.PlateCarree())

    # Bangladesh boundary
    bd.boundary.plot(ax=ax, edgecolor='white', linewidth=1)

    # Gridlines
    gl = ax.gridlines(draw_labels=True, color='gray', linewidth=0.5, linestyle='--')
    gl.top_labels = False
    gl.right_labels = False
    gl.xlabel_style = {'color': 'white', 'fontsize': 9}
    gl.ylabel_style = {'color': 'white', 'fontsize': 9}

    # Wind data (replace u, v, mask, lon2d, lat2d, times with your arrays)
    u_data = u[i].values
    v_data = v[i].values
    u_masked = np.where(mask, u_data, np.nan)
    v_masked = np.where(mask, v_data, np.nan)
    wind_speed = np.sqrt(u_masked**2 + v_masked**2)

    ax.streamplot(
        lon2d, lat2d,
        u_masked, v_masked,
        transform=ccrs.PlateCarree(),
        color=wind_speed,
        cmap=cmap,
        norm=norm,
        linewidth=0.7,
        density=5
    )

    # Title
    ax.set_title(
        f"Wind at 10m Height\n{np.datetime_as_string(times[i], unit='h')}",
        fontsize=14,
        color='white'
    )

    # Add scale bar
    add_scalebar(ax, length_km=200, location=(0.07, 0.06), text_color='white')

# --------------------------
# Create animation
# --------------------------
anim = animation.FuncAnimation(fig, animate, frames=len(times), interval=500)

# Save GIF
output_path = r"I:\Planning\Geospatial Python\geopy environment\Practices\Wind Data Visualization\Bangladesh_Wind_Streamlines.gif"
anim.save(output_path, writer="pillow", dpi=900)

print("✅ Wind streamline animation saved as GIF.")
plt.show()
```
![2](https://raw.githubusercontent.com/imtiajiqbalmahfuj/imtiajiqbal-portfolio/refs/heads/main/Projects/25015%20Automated%20wind%20flow%20map%20of%20Bangladesh/Bangladesh_Wind_Streamlines-0000.jpg)  


---

## 📎 Links
- 🔗 [See more](https://www.linkedin.com/posts/imtiajiqbalmahfuj_era5abr10m-xarray-netcdf4-activity-7374184762648875010-rTvb?utm_source=share&utm_medium=member_desktop&rcm=ACoAAETCC3UBjMNBwycvXEm57I2FBEXCxvdKcM0)  

---

## 🔖 Tags
`GIS` `Remote Sensing` `Geospatial Python`

> Honorable mention
> A few months ago, Milos created an amazing wind flow map. I really wanted to try it myself, but since Dr. Milos teaches in R and I was a beginner Python user at that stage, I couldn’t follow along. A few days ago, I saw Subham Roy 'dada' create a similar wind flow map using Python — and that was the trigger I needed! I reached out to him, learned the workflow, and decided to make my own automated workflow visualization over Bangladesh.
