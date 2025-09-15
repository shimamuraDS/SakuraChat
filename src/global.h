#ifndef GLOBAL_H
#define GLOBAL_H
#include <QString>

// 请求ID枚举
enum ReqId {
    ID_GET_VARIFY_CODE = 1001, // 获取验证码
    ID_REG_USER = 1002, // 注册用户
};

// 错误代码枚举
enum ErrorCodes {
    SUCCESS = 0,
    ERR_JSON = 1, // Json解析失败
    ERR_NETWORK = 2,
};

// 模块枚举
enum Modules {
    REGISTERMOD = 0,
};

// 全局配置变量声明
extern QString gate_url_prefix;

#endif // GLOBAL_H
