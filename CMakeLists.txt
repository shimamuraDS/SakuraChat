cmake_minimum_required(VERSION 3.16)

project(SakuraChat VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
    add_compile_options(/utf-8)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Network)

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
        qml/RegisterDialog.qml
        qml/ClickableLabel.qml
        qml/TimerButton.qml
        qml/ResetDialog.qml
        qml/ChatDialog.qml
        qml/SidebarIconBtn.qml
        qml/AddGroupBtn.qml
        qml/ContactItem.qml
        qml/MessageBubble.qml
        qml/ToolbarBtn.qml
        qml/ChatUserWid.qml
        qml/SendBtn.qml
        qml/ChatView.qml
        qml/FindSuccessDialog.qml
    SOURCES
        src/global.h
        src/singleton.h
        src/httpmgr.h
        src/httpmgr.cpp
        src/registercontroller.h
        src/registercontroller.cpp
        src/resetcontroller.h
        src/resetcontroller.cpp
        src/logincontroller.h
        src/logincontroller.cpp
        src/tcpmgr.h
        src/tcpmgr.cpp
        src/usermgr.h
        src/usermgr.cpp
        src/customizeedit.h
        src/customizeedit.cpp
        src/configmanager.h
        src/configmanager.cpp
        src/chatuserlist.h
        src/chatuserlist.cpp
    RESOURCES
        sakurachat.qrc
        README.md
        DevDoc.md
        config.ini
        DevDoc.md
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
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Network
)
include(GNUInstallDirs)
install(TARGETS appSakuraChat
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

add_custom_command(TARGET appSakuraChat POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "${CMAKE_CURRENT_SOURCE_DIR}/config.ini"
        "$<TARGET_FILE_DIR:appSakuraChat>/config.ini"
    COMMENT "Copying config.ini to output directory"
)

