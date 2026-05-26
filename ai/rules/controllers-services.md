# 控制器与服务层架构规范

## **[P0] 瘦控制器原则**
- 控制器方法不超过 7 行代码。复杂的业务逻辑必须提取到 `app/Services/` 目录。
- 控制器只做三件事：接收请求 → 调用 Service → 返回响应。

## **[P1] Service 注入策略**
- 若 Service 类仅被该控制器的一个方法使用，直接在该方法中通过参数注入（方法级注入）。
- 若 Service 类被控制器中多个方法使用，在构造函数中注入。
- 所有依赖注入统一通过接口（`app/Contracts/`）实现，以支持测试 Mock。

## **[P2] Form Request 与枚举**
- 所有表单验证必须使用独立的 Form Request 类（`php artisan make:request`），不要在控制器中写验证逻辑。
- 所有枚举类统一存放在 `app/Enums/` 目录。
- 若数据库列的值来自枚举，必须在迁移文件中将枚举值设为默认值，并在模型中强制转换为枚举类型。
- 在 Blade 模板和测试代码中，凡是涉及枚举字段的地方，一律使用枚举类引用而非硬编码字符串。

## **[P3] Observer 注册方式**
- Eloquent Observer 统一使用 PHP 8 的 Attribute 方式注册在模型中，不要在 `AppServiceProvider::boot()` 中注册。
- 示例：`#[ObservedBy([UserObserver::class])]`
