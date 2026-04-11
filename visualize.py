"""
Visualize hloc 3D reconstruction output as interactive HTML.

Usage (after running a reconstruction):
    python3 visualize.py /tmp/hloc_demo_output/sfm /tmp/reconstruction.html

Then transfer /tmp/reconstruction.html to your Windows machine and open in any browser.
Interactive 3D view: rotate, zoom, see cameras and 3D points.
"""
import sys
from pathlib import Path
import pycolmap

if len(sys.argv) < 3:
    print("Usage: python3 visualize.py <sfm_folder> <output.html>")
    print("Example: python3 visualize.py /tmp/hloc_demo_output/sfm /tmp/reconstruction.html")
    sys.exit(1)

sfm_path = Path(sys.argv[1])
output_html = Path(sys.argv[2])

print(f"Loading reconstruction from: {sfm_path}")
model = pycolmap.Reconstruction(str(sfm_path))
print(f"  {model.num_reg_images()} cameras")
print(f"  {model.num_points3D()} 3D points")

# Use hloc's built-in 3D viewer
from hloc.utils import viz_3d
fig = viz_3d.init_figure()
viz_3d.plot_reconstruction(fig, model, color="rgba(255,0,0,0.5)", name="Sacre Coeur")

# Save as interactive HTML
fig.write_html(str(output_html))
print(f"\nSaved interactive viewer to: {output_html}")
print(f"Transfer to Windows with:")
print(f"  scp user@server:{output_html} E:\\ViH\\")
print(f"Then open {output_html.name} in Chrome/Firefox/Edge.")
