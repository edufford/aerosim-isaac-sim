# AeroSim Isaac Sim

NVIDIA Isaac Sim host application for the AeroSim aerospace simulation platform. Renders the AeroSim scene graph with Cesium geospatial terrain and captures camera sensor images using Isaac Sim's sensor framework.

Based on the [isaacsim-app-template](https://github.com/isaac-sim/isaacsim-app-template) (Isaac Sim 5.1, Kit 107.3).

## Prerequisites

- Linux x86_64
- NVIDIA GPU with RTX support
- NVIDIA drivers 535+
- Git, curl, unzip

## Setup and Build

The build script automatically fetches NVIDIA's Kit SDK build tools on first run:

```bash
# Set required environment variables
export AEROSIM_ISAAC_SIM_ROOT=/path/to/aerosim-isaac-sim
export AEROSIM_ASSETS_ROOT=/path/to/aerosim-assets
export AEROSIM_WORLD_LINK_LIB=/path/to/aerosim-world-link/lib
export AEROSIM_CESIUM_TOKEN=your_cesium_ion_token

# Build (first run fetches tools, downloads Cesium, compiles extension)
./build.sh
```

## Launch

```bash
# Production app (viewport only)
./launch_aerosim_isaac_sim.sh

# Development app (full Isaac Sim GUI)
./launch_aerosim_isaac_sim_dev.sh
```

## Architecture

### Kit App Files

| File | Description |
|------|-------------|
| `aerosim.isaac.renderer.kit` | Production app: `isaacsim.exp.base` + AeroSim + Cesium |
| `aerosim.isaac.renderer.dev.kit` | Dev app: `isaacsim.exp.full` + AeroSim + Cesium |

### AeroSim Extension (`aerosim.omniverse.extension`)

The extension (cloned from [aerosim-omniverse-extension](https://github.com/edufford/aerosim-omniverse-extension)) provides:

- **C++ plugin** (`AerosimConnector.cpp`): Receives scene graph JSON from the AeroSim middleware (via `aerosim-world-link`), creates/updates USD prims, manages actor hierarchy, connects Cesium georeference.
- **Python extension** (`aerosim_connector.py`): Manages Kit extension lifecycle, loads default stage, enables Cesium, controls viewport camera.
- **Camera sensor manager** (`camera_sensor_manager.py`): Uses Isaac Sim's `isaacsim.sensors.camera.Camera` to capture RGBA frames from scene graph camera sensors and publishes them via `publish_image_to_topic()` to the `aerosim.renderer.responses` middleware topic.

### Data Flow

```
AeroSim Orchestrator
  -> aerosim-world-link (Zenoh/Kafka) -> Scene Graph JSON
  -> C++ plugin: Create/update USD prims
  -> Cesium: Geospatial terrain rendering
  -> Isaac Sim Camera: Capture RGBA frames
  -> publish_image_to_topic() -> JPEG compress -> Middleware
  -> WebSocket/MCAP subscribers
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AEROSIM_ISAAC_SIM_ROOT` | Path to this repository |
| `AEROSIM_ASSETS_ROOT` | Path to aerosim-assets (USD models, default stage) |
| `AEROSIM_WORLD_LINK_LIB` | Path to built aerosim-world-link library |
| `AEROSIM_CESIUM_TOKEN` | Cesium Ion access token for terrain tiles |
