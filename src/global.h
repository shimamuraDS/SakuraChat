#ifndef GLOBAL_H
#define GLOBAL_H
#include <QString>

// 请求ID枚举
enum ReqId {
    ID_GET_VARIFY_CODE = 1001, // 获取验证码
    ID_REG_USER = 1002, // 注册用户
    ID_RESET_PWD = 1003, // 重置密码
    ID_LOGIN_USER = 1004, // 登录
    ID_CHAT_LOGIN = 1005, // 登录聊天服务器
    ID_CHAT_LOGIN_RSP = 1006, // 登录聊天服务器回包
    ID_SEARCH_USER_REQ = 1007,
    ID_SEARCH_USER_RSP = 1008,
    ID_ADD_FRIEND_REQ = 1009,
    ID_ADD_FRIEND_RSP = 1010,
    ID_NOTIFY_ADD_FRIEND_REQ = 1011,
    ID_AUTH_FRIEND_REQ = 1012,
    ID_AUTH_FRIEND_RSP = 1013,
    ID_NOTIFY_AUTH_FRIEND_REQ = 1014,
    ID_TEXT_CHAT_MSG_REQ = 1015,
    ID_TEXT_CHAT_MSG_RSP = 1016,
    ID_NOTIFY_TEXT_CHAT_MSG_REQ = 1017,
    ID_FRIEND_LIST_REQ = 1018,
    ID_FRIEND_LIST_RSP = 1019,
};

// 错误代码枚举
enum ErrorCodes {
    SUCCESS = 0,
    ERR_JSON = 1, // Json解析失败
    ERR_NETWORK = 2,
};

// 错误提示枚举
enum TipErr {
    TIP_SUCCESS = 0,
    TIP_EMAIL_ERR = 1,
    TIP_PWD_ERR = 2,
    TIP_CONFIRM_ERR = 3,
    TIP_PWD_CONFIRM = 4,
    TIP_VARIFY_ERR = 5,
    TIP_USER_ERR = 6
};

// 模块枚举
enum Modules {
    REGISTERMOD = 0,
    RESETMOD = 1,
    LOGINMOD = 2,
};

struct ServerInfo {
    QString Host;
    QString Port;
    QString Token;
    int Uid;
};

#endif // GLOBAL_H
