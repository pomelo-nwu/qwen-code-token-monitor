idf_component_register(
    SRCS "ble_app.c"
    INCLUDE_DIRS "./"
    REQUIRES bt usage_client
)

if(DEFINED RLCD_BLE_DEVICE_NAME)
    target_compile_definitions(${COMPONENT_LIB} PRIVATE RLCD_BLE_DEVICE_NAME="${RLCD_BLE_DEVICE_NAME}")
endif()
