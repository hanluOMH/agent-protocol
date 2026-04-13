# a2a_cpp

## 简介

**A2A C++ SDK** 是基于 agent-to-agent 协议的 C++ 实现，旨在帮助开发者快速构建多智能体协作系统、任务编排系统、AI Agent 平台、边缘智能设备通信等场景。[A2A 协议规范](https://a2a-protocol.org/v0.3.0/specification/) 定义了任务、消息、时间和智能体能力描述等核心结构。SDK 提供统一的数据结构、序列化能力、协议校验机制以及通信接口，让智能体之间的交互更加稳定、高效、可维护。

## 快速开始

### 环境要求

- C++17 或更高版本编译器
- CMake >= 3.16
- 支持 Linux 和 macOS

### 安装构建依赖

#### macOS

```bash
brew install curl openssl@3 nlohmann-json cpp-httplib
```

#### Ubuntu / Debian

```bash
sudo apt-get update
sudo apt-get install -y libcurl4-openssl-dev libssl-dev nlohmann-json3-dev
```

#### CentOS / RHEL / Fedora

```bash
sudo yum install -y libcurl libcurl-devel openssl-libs openssl-devel
```

#### cpp-httplib 和 nlohmann_json

`third_party/third_party.cmake` 会优先查找系统已安装的依赖；如果本地未找到，则会尝试从 GitHub 拉取源码。

### 编译

推荐直接使用仓库自带脚本：

```bash
./build.sh
```

调试构建示例：

```bash
./build.sh -t Debug
```

也可以手动执行 CMake：

```bash
cmake -S . -B build
cmake --build build -j4
```

编译成功后，产物位于：

- `output/lib`：动态库
- `output/bin`：示例程序

### 运行示例

先启动服务端：

```bash
./output/bin/helloworld_server -i 127.0.0.1 -p 8080
```

再在另一个终端启动客户端：

```bash
./output/bin/helloworld_client -i 127.0.0.1 -p 8080
```

成功运行后，客户端会输出服务端返回的消息。

## 样例

让我们创建一个简单的 hello world 示例。详细实现可以参考 `examples/helloworld_client.cpp`。

client 代码：

```c++
#include <nlohmann/json.hpp>
#include <iostream>

#include "client/client_factory.h"
#include "client/a2a_card_resolver.h"

int main(int argc, char** argv)
{
    std::string base_url = "your server ip:port";

    a2a::client::A2ACardResolver resolver(base_url);
    auto card = resolver.GetAgentCard();
    a2a::client::ClientConfig cfg;
    cfg.streaming = false;
    cfg.supportedTransports = {"JSONRPC"};

    a2a::client::ClientFactory factory(cfg);
    auto client = factory.Create(card);

    a2a::Message msg;
    msg.role = a2a::Role::USER;
    msg.messageId = 123;

    a2a::TextPart tp;
    tp.text = "hello remote server";
    msg.parts.push_back(tp);

    a2a::DataPart dp;
    dp.data = nlohmann::json{
        {"key", "value"},
        {"number", 456}
    };
    msg.parts.push_back(dp);

    client->SendMessage(msg, nullptr, [&](const a2a::client::ClientEvent& ev, const a2a::AgentCard& card) {
        if (std::holds_alternative<a2a::Message>(ev)) {
            auto m = std::get<a2a::Message>(ev);
            std::cout << "<-- Response: " << nlohmann::json(m).dump(2) << std::endl;
        } else {
            std::cout << "<-- Unexpected Task variant received (non-streaming config)" << std::endl;
        }
    });

    return 0;
}
```

server 代码：

```c++
#include "server/request_handler.h"
#include "server/request_handler_factory.h"
#include "server/server.h"
#include "utils/types.h"
#include <iostream>
#include <csignal>
#include <atomic>
#include <memory>
#include <thread>

class MyAgentExecutor : public a2a::server::AgentExecutor {
public:
    void Execute(a2a::server::RequestContext& context, a2a::server::EventQueue& eventQueue) override
    {
        a2a::Message response_msg;
        response_msg.messageId = "msg-123";
        response_msg.role = a2a::Role::AGENT;

        a2a::TextPart response_part;
        response_part.text = "Processed: hello remote server";
        response_msg.parts.push_back(response_part);

        eventQueue.Enqueue(response_msg);
        eventQueue.TaskDone();
    }

    void Cancel(a2a::server::RequestContext& context, a2a::server::EventQueue& eventQueue) override
    {
    }
};

int main()
{
    std::shared_ptr<a2a::server::AgentExecutor> executor = std::make_shared<MyAgentExecutor>();

    auto agentCard = std::make_shared<a2a::AgentCard>();
    agentCard->name = "ExampleAgent";
    agentCard->description = "A2A Hello World Example";
    agentCard->url = "http://localhost:8080/jsonrpc";
    agentCard->version = "1.0.0";
    agentCard->defaultInputModes = {"text"};
    agentCard->defaultOutputModes = {"text"};
    agentCard->capabilities.streaming = false;

    a2a::server::RequestHandlerFactory fac;
    auto handler = fac.Create(executor, agentCard, nullptr);

    a2a::server::Server server(a2a::server::SERVER_TRANSPORT_TYPE_HTTP, handler, agentCard);

    a2a::server::ServerConfig config;
    config.type = a2a::server::SERVER_TRANSPORT_TYPE_HTTP;
    auto& httpConfig = std::get<a2a::server::HttpConfig>(config.config);
    httpConfig.ip = "127.0.0.1";
    httpConfig.port = 8080;

    int ret = server.Start(config);
    if (ret != 0) {
        return -1;
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(10000));

    return 0;
}
```

## 架构设计

**A2A C++ SDK** 采用模块化设计，核心模块包括：

- **SDK 接口层**：定义 Client、Server、A2ACardResolver、AgentExecutor 等类，提供对外结构。
- **协议结构层**：定义 Message、Task、Event、AgentCard 等结构，提供字段校验和默认值处理。
- **传输层**：抽象底层传输，对上层功能实现提供统一接口，便于扩展不同传输类型。

## 功能特性

### 智能体能力获取

A2A C++ SDK 提供根据智能体 URL 获取智能体能力的功能，查询智能体支持的基本信息、认证方式、输入输出模式和技能列表。

### 智能体之间标准化调用

A2A C++ SDK 支持任务管理、状态同步、多模态数据和实时通信，帮助用户快速完成多智能体之间的消息传递与协作。

## 参与贡献

欢迎所有形式的贡献，包括但不限于：

- 提交问题和功能建议
- 改进文档
- 提交代码
- 分享使用经验

## 开源许可证

本项目依据 Apache-2.0 许可证授权。
