cmake_minimum_required(VERSION 3.16)

project(SakuraChat VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.8)

set(CMAKE_AUTORCC ON)
qt_add_executable(appSakuraChat
    main.cpp sakurachat.qrc
)

qt_add_qml_module(appSakuraChat
    URI SakuraChat
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/LoginDialog.qml
    RESOURCES sakurachat.qrc
    QML_FILES qml/RegisterDialog.qml
    SOURCES src/global.h src/global.cpp
    RESOURCES README.md
    SOURCES src/singleton.h
    SOURCES src/httpmgr.h src/httpmgr.cpp
    SOURCES src/registercontroller.h src/registercontroller.cpp
    RESOURCES config.ini
    QML_FILES qml/ClickableLabel.qml
    QML_FILES qml/TimerButton.qml
)

if(WIN32)
    set(APP_ICON_RESOURCE_WINDOWS "${CMAKE_CURRENT_SOURCE_DIR}/icon.rc")
    target_sources(appSakuraChat PRIVATE ${APP_ICON_RESOURCE_WINDOWS})
endif()

target_include_directories(appSakuraChat PRIVATE ${CMAKE_SOURCE_DIR}/src)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appSakuraChat PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appSakuraChat
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appSakuraChat
    PRIVATE Qt6::Quick
)

include(GNUInstallDirs)
install(TARGETS appSakuraChat
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(WIN32 AND CMAKE_BUILD_TYPE STREQUAL "Release")
    # 拷贝 config.ini 到输出目录
    add_custom_command(
        TARGET appSakuraChat POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${CMAKE_CURRENT_SOURCE_DIR}/config.ini"
            "$<TARGET_FILE_DIR:appSakuraChat>/config.ini"
        COMMENT "Copying config.ini to output directory"
    )
endif()

