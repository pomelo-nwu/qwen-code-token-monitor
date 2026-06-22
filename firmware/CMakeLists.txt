# The following lines of boilerplate have to be in your project's
# CMakeLists in this exact order for cmake to work correctly
cmake_minimum_required(VERSION 3.16)

# Greeting name on the dashboard. Override with:
#   idf.py -DRLCD_GREETING_NAME="YourName" build
set(RLCD_GREETING_NAME "" CACHE STRING "Greeting name for dashboard header")

# BLE device name. Override with:
#   idf.py -DRLCD_BLE_DEVICE_NAME="QwenToken-YourName" build
# When multiple devices are in BLE range, give each a unique name so the
# bridge can target a specific one via QWEN_BLE_DEVICE_NAME env var.
set(RLCD_BLE_DEVICE_NAME "QwenToken" CACHE STRING "BLE advertising name")

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(qwen_token_monitor_ble)
