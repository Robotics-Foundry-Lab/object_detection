"""
Object detection bringup: Isaac ROS YOLOv8 + visualizer + compressed image republisher.

run_mode:
    standalone  RealSense camera + rectification + YOLOv8 in this container
    composite   YOLOv8 only, /image_rect + /camera_info_rect come from another container
    bag         YOLOv8 fed by the looping Isaac ROS quickstart rosbag (no camera needed)

vis_mode:
    sparse      draw only person, dog and potted plant
    full        draw all classes
    none        no visualizer

Example:
    ros2 launch object_detection object_detection.launch.py run_mode:=bag vis_mode:=full
"""

import os

from launch import LaunchDescription
from launch.actions import (DeclareLaunchArgument, ExecuteProcess, IncludeLaunchDescription,
                            LogInfo, OpaqueFunction, RegisterEventHandler, Shutdown)
from launch.event_handlers import OnProcessExit
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare

ISAAC_ROS_WS = os.environ.get('ISAAC_ROS_WS', '/workspaces/object_detection')
MODEL_DIR = os.path.join(ISAAC_ROS_WS, 'isaac_ros_assets', 'models', 'yolov8')
QUICKSTART_DIR = os.path.join(ISAAC_ROS_WS, 'isaac_ros_assets', 'isaac_ros_yolov8')

# Isaac ROS launch fragments and interface specs used by each run mode
FRAGMENTS = {
    'standalone': 'realsense_mono_rect,yolov8',
    'composite': 'yolov8',
    'bag': 'yolov8',
}
INTERFACE_SPECS = {
    'standalone': os.path.join(ISAAC_ROS_WS, 'realsense_specs.json'),
    'composite': os.path.join(ISAAC_ROS_WS, 'realsense_specs.json'),
    'bag': os.path.join(QUICKSTART_DIR, 'quickstart_interface_specs.json'),
}

# (package, executable) of the visualizer for each vis mode
VISUALIZERS = {
    'sparse': ('object_detection', 'yolov8_sparse_visualizer'),
    'full': ('isaac_ros_yolov8', 'isaac_ros_yolov8_visualizer.py'),
    'none': None,
}


def launch_setup(context):
    run_mode = LaunchConfiguration('run_mode').perform(context)
    vis_mode = LaunchConfiguration('vis_mode').perform(context)
    model = LaunchConfiguration('model').perform(context)

    actions = [
        LogInfo(msg=f'run_mode={run_mode} vis_mode={vis_mode} model={model}'),
        IncludeLaunchDescription(
            PythonLaunchDescriptionSource(os.path.join(
                FindPackageShare('isaac_ros_examples').perform(context),
                'launch', 'isaac_ros_examples.launch.py')),
            launch_arguments={
                'launch_fragments': FRAGMENTS[run_mode],
                'interface_specs_file': INTERFACE_SPECS[run_mode],
                'model_file_path': os.path.join(MODEL_DIR, f'{model}.onnx'),
                'engine_file_path': os.path.join(MODEL_DIR, f'{model}.plan'),
            }.items(),
        ),
    ]

    critical = []
    if run_mode == 'bag':
        bag_player = ExecuteProcess(
            cmd=['ros2', 'bag', 'play', '--loop', os.path.join(QUICKSTART_DIR, 'quickstart.bag')],
            output='screen',
        )
        critical.append(bag_player)
        actions.append(bag_player)

    if VISUALIZERS[vis_mode]:
        package, executable = VISUALIZERS[vis_mode]
        actions.append(Node(package=package, executable=executable, output='screen',
                            respawn=True, respawn_delay=2.0))

    actions.append(Node(
        package='image_transport', executable='republish', name='yolov8_image_republisher',
        arguments=['raw', 'compressed'],
        remappings=[('in', '/yolov8_processed_image'),
                    ('out/compressed', '/yolov8_processed_image/compressed')],
        parameters=[{'out.jpeg_quality': 80}],  # prefix is the publisher's base topic name 'out'
        output='screen', respawn=True, respawn_delay=2.0,
    ))

    # Visualizer and republisher respawn on their own. If the Isaac ROS container (camera +
    # YOLOv8) or the bag player dies, shut everything down so Docker restarts the container
    # instead of leaving it running half-broken.
    def shutdown_if_critical(event, context):
        if context.is_shutdown:  # processes exiting because of an ongoing shutdown
            return None
        executable = getattr(event.action, 'node_executable', None)
        if event.action in critical or executable == 'component_container_mt':
            return [Shutdown(reason=f'{event.action.name} exited with code {event.returncode}')]
        return None

    actions.append(RegisterEventHandler(OnProcessExit(on_exit=shutdown_if_critical)))
    return actions


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument('run_mode', default_value='composite', choices=list(FRAGMENTS),
                              description='Where the camera images come from'),
        DeclareLaunchArgument('vis_mode', default_value='sparse', choices=list(VISUALIZERS),
                              description='Which detections are drawn on /yolov8_processed_image'),
        DeclareLaunchArgument('model', default_value='yolov8n',
                              description=f'Model name, expects <model>.onnx in {MODEL_DIR}'),
        OpaqueFunction(function=launch_setup),
    ])
