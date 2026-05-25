# Laravel 测试规范

## **[P0] 测试要求**
- 新功能必须生成 Pest 自动化测试（`.tests/Feature/` 或 `.tests/Unit/`）。
- 核心业务逻辑的代码覆盖率目标 > 80%。
- 测试必须覆盖：正向场景（Happy Path）、反向场景（异常/非法输入）、边界场景。

## **[P1] 测试工具与写法**
- 使用 Pest 框架进行单元测试和功能测试，使用 Laravel Dusk 进行浏览器端到端测试。
- 所有测试都应在每个独立场景开始时使用 `RefreshDatabase` trait 或 `DatabaseTransactions`。
- 使用模型工厂（Model Factories）创建测试数据，不要手动插入。
- 对外部服务（第三方 API、邮件、队列）使用 Mock 或 Fake。

## **[P2] 命名与组织**
- 测试文件命名为 `*Test.php`，放在与被测代码对应的目录结构中。
- 测试方法名使用 `it_` 前缀（Pest 风格），清晰描述测试场景。
- CI/CD 管线中必须包含以下脚本：
  - `composer lint`：执行 Laravel Pint 代码风格检查
  - `composer analyse`：执行 PHPStan 静态分析（Level 8 目标）
  - `composer test`：执行 Pest 测试套件
