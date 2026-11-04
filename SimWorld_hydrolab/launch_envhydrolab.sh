#!/bin/bash
set -e

# ==========================================
# 1. FIXED CLEANUP TRAP
# Disables itself immediately so it doesn't loop forever!
# ==========================================
cleanup() {
    echo -e "\n[1/2] Sending graceful shutdown signal..."
    trap - SIGINT SIGTERM EXIT # Disable the trap so it doesn't loop
    
    # 1. Ask nicely: Gracefully terminate only the processes started by this script
    kill 0 
    
    # Give PX4 and Gazebo 2 seconds to save their log files
    sleep 2 
    
    echo "[2/2] Hunting down lingering zombie processes..."
    # 2. Force cleanup: Run a standard killall (WITHOUT the destructive -9 flag)
    # The '2>/dev/null || true' hides ugly error messages if the processes are already dead
    killall px4 gz ruby MicroXRCEAgent 2>/dev/null || true
    
    echo "Cleanup complete. Goodbye!"
}
trap cleanup SIGINT SIGTERM EXIT

# ADJUST THESE PATHS TO YOUR ENVIRONMENT!
PX4_ROOT=~/repos/PX4-Autopilot
WORKSPACE_ROOT=~/repos/Absolute-Edge-ROS
Q_GROUND_CONTROL_PATH=~/QGroundControl.AppImage

echo "========================================"
echo "1. Generating Randomized HydroLab World"
echo "========================================"
python3 build_world.py

echo ""
echo "========================================"
echo "2. Setting Environment Variables"
echo "========================================"
export PX4_GZ_WORLD=hydrolab_built
# x,y,z,roll,pitch,yaw — on start_base pad (top z=0.1 m; x500 legs ~0.012 m above spawn origin)
export PX4_GZ_MODEL_POSE="0,0,0.1,0,0,0"
echo "PX4_GZ_WORLD is set to: $PX4_GZ_WORLD"
echo "PX4_GZ_MODEL_POSE is set to: $PX4_GZ_MODEL_POSE"

echo ""
echo "========================================"
echo "3. Launching PX4 SITL and Gazebo"
echo "========================================"
cd "$PX4_ROOT"
make px4_sitl gz_x500_gimbal &
sleep 20

echo ""
echo "========================================"
echo "4. Starting Micro XRCE-DDS Agent"
echo "========================================"
source "$WORKSPACE_ROOT/install/setup.bash"
MicroXRCEAgent udp4 -p 8888 &
sleep 2

echo ""
echo "========================================"
echo "5. Starting QGroundControl"
echo "========================================"
if [ -f $Q_GROUND_CONTROL_PATH ]; then
    $Q_GROUND_CONTROL_PATH &
else
    echo "WARNING: QGroundControl not found at $Q_GROUND_CONTROL_PATH"
fi
sleep 20


echo ""
echo "========================================"
echo "6. Launching ROS2 mission"
echo "========================================"
export HYDROLAB_CONFIG_DIR="$WORKSPACE_ROOT/runtime_config/hydrolab_mission"
# Directly targeting the python engine inside the venv avoids all activation bugs!
source /opt/ros/jazzy/setup.bash  # Change 'humble' if you use a different ROS 2 version
# Launch the ROS mission in the background (&)
ros2 launch hydrolab_mission system_launch.py &


echo ""
echo "==========================================================="
echo "✅ All systems running!"
echo "🛑 Press [Ctrl+C] in this terminal to shut down everything."
echo "==========================================================="

wait
