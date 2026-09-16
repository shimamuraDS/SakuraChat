cmake_minimum_required(VERSION 3.16)

project(SakuraChat VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(MSVC)
    add_compile_options(/utf-8)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick QuickControls2 Network Sql Concurrent Widgets)

qt_standard_project_setup(REQUIRES 6.8)
include(cmake/Distribution.cmake)

set(CMAKE_AUTORCC ON)
qt_add_executable(appSakuraChat
    main.cpp sakurachat.qrc
)

set_source_files_properties(qml/UiTheme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(appSakuraChat
    URI SakuraChat
    VERSION 1.0
    QML_FILES
        qml/LanChatPage.qml
        qml/UiTheme.qml
        qml/AuthPanel.qml
        qml/ConversationInfo.qml
        qml/Main.qml
        qml/WindowTitleBar.qml
        qml/SakuraButton.qml
        qml/SakuraField.qml
        qml/SakuraDialog.qml
        qml/SakuraComboBox.qml
        qml/SakuraIcon.qml
        qml/SakuraCheckBox.qml
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
        qml/CommonButton.qml
        qml/TagChip.qml
        qml/TagInputBar.qml
        qml/TagGrid.qml
        qml/ApplyFriend.qml
        qml/ApplyFriendItem.qml
        qml/ApplyFriendPage.qml
        qml/ReviewFriendApplication.qml
    SOURCES
        src/updatecontroller.h
        src/updatecontroller.cpp
        src/messagelistmodel.h
        src/messagelistmodel.cpp
        src/lanchat.h
        src/lanchat.cpp
        src/applock.h
        src/applock.cpp
        src/localprotection.h
        src/localprotection.cpp
        src/privatenotifications.h
        src/privatenotifications.cpp
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
        src/clickedoncelabel.h
        src/clickedoncelabel.cpp
        src/applyfriendmodel.h
        src/applyfriendmodel.cpp
        src/contactuserlist.h
        src/contactuserlist.cpp
        src/applyfriendlist.h
        src/applyfriendlist.cpp
        src/chatstore.h
        src/chatstore.cpp
        src/chatrepository.h
        src/chatrepository.cpp
    RESOURCES
        sakurachat.qrc
        config.ini
)

if(WIN32)
    target_link_libraries(appSakuraChat PRIVATE crypt32 dwmapi)
    target_sources(appSakuraChat PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/generated/version.rc)
    set(APP_ICON_RESOURCE_WINDOWS "${CMAKE_CURRENT_SOURCE_DIR}/icon.rc")
    target_sources(appSakuraChat PRIVATE ${APP_ICON_RESOURCE_WINDOWS})
endif()

target_include_directories(appSakuraChat PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_include_directories(appSakuraChat PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/generated)
if(SAKURA_DISTRIBUTION)
    target_compile_definitions(appSakuraChat PRIVATE SAKURA_PACKAGED=1)
endif()

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
        Qt6::Sql
        Qt6::Concurrent
        Qt6::Widgets
        Qt6::Qml
)
include(GNUInstallDirs)
add_library(privatechat_core STATIC
    src/privatechat/privatechatengine.cpp src/privatechat/privatechatengine.h
    src/privatechat/privatechatcontroller.cpp src/privatechat/privatechatcontroller.h
    src/privatechat/privatechattransport.cpp src/privatechat/privatechattransport.h
    src/privatechat/signalbridge.cpp src/privatechat/signalbridge.h
    src/privatechat/privatechatstore.cpp src/privatechat/privatechatstore.h src/localprotection.cpp)
target_include_directories(privatechat_core PUBLIC src)
target_link_libraries(privatechat_core PUBLIC Qt6::Core Qt6::Sql Qt6::Network)
target_link_libraries(appSakuraChat PRIVATE privatechat_core)
if(WIN32)
    target_link_libraries(privatechat_core PRIVATE crypt32)
endif()
add_executable(privatechatstore_tests EXCLUDE_FROM_ALL tests/privatechatstore_tests.cpp)
add_executable(updatecontroller_tests EXCLUDE_FROM_ALL tests/updatecontroller_tests.cpp src/updatecontroller.cpp src/updatecontroller.h)
target_include_directories(updatecontroller_tests PRIVATE src ${CMAKE_CURRENT_BINARY_DIR}/generated)
target_link_libraries(updatecontroller_tests PRIVATE Qt6::Core Qt6::Gui Qt6::Network)
add_executable(messagelistmodel_tests EXCLUDE_FROM_ALL tests/messagelistmodel_tests.cpp src/messagelistmodel.cpp src/messagelistmodel.h)
target_include_directories(messagelistmodel_tests PRIVATE src)
target_link_libraries(messagelistmodel_tests PRIVATE Qt6::Core Qt6::Qml)
add_executable(chatview_tests EXCLUDE_FROM_ALL tests/chatview_tests.cpp src/messagelistmodel.cpp src/messagelistmodel.h)
target_include_directories(chatview_tests PRIVATE src)
target_compile_definitions(chatview_tests PRIVATE SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(chatview_tests PRIVATE Qt6::Quick Qt6::QuickControls2)
qt_add_resources(chatview_tests "chatview_qml" PREFIX "/qt/qml/SakuraChat" FILES
    qml/ChatView.qml qml/MessageBubble.qml qml/SakuraButton.qml qml/UiTheme.qml)
add_executable(privatechatengine_tests EXCLUDE_FROM_ALL tests/privatechatengine_tests.cpp)
add_executable(privatechatcontroller_tests EXCLUDE_FROM_ALL tests/privatechatcontroller_tests.cpp)
target_link_libraries(privatechatcontroller_tests PRIVATE privatechat_core)
add_executable(privatechat_e2e_tests EXCLUDE_FROM_ALL tests/privatechat_e2e_tests.cpp)
target_link_libraries(privatechat_e2e_tests PRIVATE privatechat_core)
target_link_libraries(privatechatengine_tests PRIVATE privatechat_core)
target_link_libraries(privatechatstore_tests PRIVATE privatechat_core)
add_executable(signalbridge_tests EXCLUDE_FROM_ALL tests/signalbridge_tests.cpp)
target_link_libraries(signalbridge_tests PRIVATE privatechat_core)
add_executable(privatechattransport_tests EXCLUDE_FROM_ALL tests/privatechattransport_tests.cpp)
target_link_libraries(privatechattransport_tests PRIVATE privatechat_core)
add_executable(lanchat_tests EXCLUDE_FROM_ALL tests/lanchat_tests.cpp src/lanchat.cpp src/lanchat.h)
target_include_directories(lanchat_tests PRIVATE src)
target_link_libraries(lanchat_tests PRIVATE Qt6::Core Qt6::Network)
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

