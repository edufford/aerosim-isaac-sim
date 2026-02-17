# AeroSim Isaac Sim

NVIDIA Isaac Sim host application for the [AeroSim](https://github.com/edufford/aerosim) aerospace simulation platform. Renders the AeroSim scene graph with Cesium geospatial terrain and captures camera sensor images using Isaac Sim's native sensor framework.

Built on the [isaacsim-app-template](https://github.com/isaac-sim/isaacsim-app-template) (Isaac Sim 5.1, Kit SDK 107.3).

## Prerequisites

- Linux x86_64
- NVIDIA GPU with RTX support
- NVIDIA drivers 535+
- Git, curl, unzip

## Setup and Build

```bash
# Set required environment variables
export AEROSIM_ISAAC_SIM_ROOT=/path/to/aerosim-isaac-sim
export AEROSIM_ASSETS_ROOT=/path/to/aerosim-assets
export AEROSIM_WORLD_LINK_LIB=/path/to/aerosim-world-link/lib
export AEROSIM_CESIUM_TOKEN=your_cesium_ion_token

# Build (first run fetches Kit SDK tools, downloads Cesium, compiles C++ extension)
./build.sh
```

The build script handles:
1. Downloads [Cesium for Omniverse](https://github.com/CesiumGS/cesium-omniverse) v0.27.0 (if not present)
2. Clones the [aerosim-omniverse-extension](https://github.com/edufford/aerosim-omniverse-extension) (if not present) — currently requires the `claude/isaac_sim` branch
3. Copies the `aerosim-world-link` shared library for middleware communication
4. Runs `repo.sh build` (NVIDIA's Kit SDK build toolchain via packman)

## Launch

```bash
# Production app (viewport rendering only, no GUI panels)
./launch_aerosim_isaac_sim.sh

# Development app (full Isaac Sim GUI with property panels, content browser, etc.)
./launch_aerosim_isaac_sim_dev.sh
```

Both apps connect to a running AeroSim simulation via middleware (Zenoh/Kafka). Start the simulation first:

```bash
# In the aerosim repo
./launch_aerosim.sh --isaac-sim
```

## Architecture

### Overview

```
┌─────────────────────────────────────────────────────────────┐
│  AeroSim Orchestrator (aerosim-world)                       │
│  SimClock → FMU Driver → VehicleState → SceneGraph (ECS)    │
└──────────────────────────┬──────────────────────────────────┘
                           │ Middleware (Zenoh/Kafka)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Isaac Sim Host App (this repo)                             │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  aerosim.omniverse.extension                        │    │
│  │                                                     │    │
│  │  C++ Plugin (AerosimConnector)                      │    │
│  │    • Receives scene graph JSON via aerosim-world-link    │
│  │    • Creates/updates USD prims (actors, sensors,    │    │
│  │      effectors, cameras, viewports)                 │    │
│  │    • Publishes camera images back to middleware      │    │
│  │                                                     │    │
│  │  Python Extension (aerosim_connector.py)            │    │
│  │    • Manages Isaac Sim World simulation context     │    │
│  │    • Loads default stage + Cesium terrain            │    │
│  │    • Controls viewport camera from scene graph      │    │
│  │    • Handles stop/reload lifecycle                   │    │
│  │                                                     │    │
│  │  Camera Sensor Manager (camera_sensor_manager.py)   │    │
│  │    • Discovers cameras from /Components/sensor/*    │    │
│  │    • Creates Isaac Sim Camera objects via World      │    │
│  │    • Captures RGBA frames with Camera.get_rgba()    │    │
│  │    • Publishes via publish_image_to_topic() → JPEG  │    │
│  │    • Injects camera frustums into Cesium tile       │    │
│  │      selection for off-screen terrain loading       │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  Cesium for Omniverse                                       │
│    • Streams 3D terrain tiles from Cesium Ion               │
│    • Georeference origin set from scene graph coordinates   │
│                                                             │
│  Isaac Sim Runtime                                          │
│    • RTX renderer, physics, sensor framework                │
│    • World manages simulation context for all sensors       │
└─────────────────────────────────────────────────────────────┘
                           │ Middleware (Zenoh/Kafka)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Subscribers                                                │
│    • WebSocket → Browser UI (camera_stream_opencv.py)       │
│    • MCAP recording (DataManager)                           │
│    • Sensor processing pipelines                            │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Scene graph in**: The AeroSim orchestrator publishes scene graph updates (actor positions, sensor configs, viewport settings) to middleware topics.

2. **USD scene update**: The C++ plugin (`AerosimConnector`) receives scene graph JSON via `aerosim-world-link` and creates/updates USD prims on the stage — actors with mesh references, camera sensors with resolution/FOV parameters, effectors, and viewport configuration.

3. **Terrain rendering**: Cesium for Omniverse streams 3D terrain tiles from Cesium Ion based on the georeference origin and camera frustums. The extension injects sensor camera frustums into Cesium's tile selection so terrain loads for off-screen camera views, not just the viewport.

4. **Camera capture**: Isaac Sim's `Camera` class (via `isaacsim.sensors.camera`) creates render products for each discovered camera sensor. The `World` simulation context manages initialization and stepping. Each frame, `Camera.get_rgba()` captures RGBA pixel data.

5. **Image publish**: Captured frames are passed to `publish_image_to_topic()` (pybind11 binding to `aerosim-world-link` C FFI), which JPEG-compresses the image and publishes it to the `aerosim.renderer.responses` middleware topic.

### Kit App Files

| File | Description |
|------|-------------|
| `source/apps/aerosim.isaac.renderer.kit` | Production app — Isaac Sim base experience + AeroSim extension + Cesium + camera sensors |
| `source/apps/aerosim.isaac.renderer.dev.kit` | Dev app — layers full Isaac Sim GUI on top of the production app |

### Extension Components

| File | Role |
|------|------|
| `AerosimConnector.cpp` | C++ Carbonite plugin — scene graph JSON → USD prims, middleware I/O via aerosim-world-link |
| `AerosimConnectorBindings.cpp` | pybind11 bindings — exposes `IAerosimConnector` interface and `publish_image_to_topic()` to Python |
| `aerosim_connector.py` | Python extension — Kit lifecycle, World management, Cesium setup, viewport camera, stop/reload |
| `camera_sensor_manager.py` | Camera sensor discovery, Isaac Sim Camera initialization, RGBA capture, Cesium viewport injection |

### Key Dependencies

| Dependency | Purpose |
|------------|---------|
| `aerosim-world-link` | Shared C library — middleware pub/sub, scene graph serialization, image compression |
| `isaacsim.core.api` | Isaac Sim World simulation context |
| `isaacsim.sensors.camera` | Isaac Sim Camera class for render product capture |
| `cesium.omniverse` | Cesium 3D terrain tile streaming |

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AEROSIM_ISAAC_SIM_ROOT` | Yes | Path to this repository |
| `AEROSIM_ASSETS_ROOT` | Yes | Path to aerosim-assets (USD models, default stage) |
| `AEROSIM_WORLD_LINK_LIB` | Yes | Path to built aerosim-world-link shared library |
| `AEROSIM_CESIUM_TOKEN` | Yes | Cesium Ion access token for terrain tile streaming |

## Project Structure

```
aerosim-isaac-sim/
├── build.sh                          # Build script (Cesium download, extension clone, repo.sh build)
├── repo.sh                           # Kit SDK bootstrap (from isaacsim-app-template)
├── repo.toml                         # Build configuration
├── premake5.lua                      # App and extension build definitions
├── launch_aerosim_isaac_sim.sh       # Launch production app
├── launch_aerosim_isaac_sim_dev.sh   # Launch dev app
├── source/
│   ├── apps/
│   │   ├── aerosim.isaac.renderer.kit      # Production .kit experience
│   │   └── aerosim.isaac.renderer.dev.kit  # Dev .kit experience
│   └── extensions/
│       ├── aerosim.omniverse.extension/    # AeroSim extension (cloned, branch: claude/isaac_sim)
│       ├── cesium.omniverse/               # Cesium extension (downloaded)
│       └── cesium.usd.plugins/             # Cesium USD plugins (downloaded)
├── tools/                            # Kit SDK build toolchain (from isaacsim-app-template)
└── deps/
    └── ext-deps.packman.xml          # USD library dependencies for C++ compilation
```
