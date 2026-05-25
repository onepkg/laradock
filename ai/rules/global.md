# Laravel / PHP 全局编码规范

## **[P0] 铁律级别——绝对不可违反**
- 每个 PHP 文件第一行必须是 `declare(strict_types=1);`。
- 严禁使用 `md5()` 或 `sha1()` 处理密码，统一使用 `Hash::make()`。
- 严禁在控制器或 Blade 模板中编写原始 SQL 查询，所有查询必须走 Eloquent ORM 或 Query Builder。
- 所有用户输入必须在控制器边界进行验证（Form Request 或 `$request->validate()`）。
- 绝对不要 `catch (\Exception $e)` 吞掉异常而不做处理或重新抛出。

## **[P1] 命名与代码风格**
- 遵循 PSR-12 编码标准。文件使用 kebab-case，类使用 PascalCase，方法使用 camelCase，变量使用 snake_case。
- 优先使用 `match` 操作符而非 `switch`。
- 优先使用 Laravel 全局辅助函数而非 Facade 静态调用。例如：使用 `auth()->id()` 而非 `Auth::id()`，使用 `redirect()->route()` 而非 `Redirect::route()`，使用 `str()->slug()` 而非 `Str::slug()`。
- 避免声明只使用一次的临时变量（如 `$currentUser = auth()->user()`），直接链式调用即可。

## **[P2] 注释规范**
- 不要在显而易见的代码或变量上方生成注释。
- 不要在变量定义时添加 `/** @var */` docblock 注释，除非明确要求。
- 仅在逻辑复杂、需要额外解释"为什么这么写"的地方添加注释。
