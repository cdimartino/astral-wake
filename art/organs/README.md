# Living circuit specimens

Eighteen original, transparent SVG organ illustrations, authored as vector artwork for the routing console. Reproduce with `python3 tools/make_organ_art.py` (standard library only).

Each organ has its own anatomical silhouette, mineral ribs, luminous internal tissue and a functional core: lenses, branching vessels, paired chambers, sutures, gills, crystals, memory coils and resonating tubes. Teal belongs to the Cartographer, ivory to the Palimpsest, and violet to the Hollow Choir; restorative organs share a mint accent. No external images are used.

The connecting nerve sheaths, ribbed conduits, severed ends and directional signal pulses are drawn at runtime by `scripts/organ_circuit.gd`, so their artwork follows the actual network, including added and severed links. Reduced motion freezes the pulses while preserving route direction markers.
