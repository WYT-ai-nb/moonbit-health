# 检查规则说明

MoonBit Maintainer Compass 使用确定性规则和固定扣分值，保证同一个项目在相同输入下得到相同结果。规则可以通过配置文件关闭或调整严重级别。

| 规则 | 检查内容 | 扣分 |
| --- | --- | ---: |
| MBH001 | 根目录存在 `moon.mod` 或 `moon.mod.json` | 20 |
| MBH002 | 存在 `moon.pkg` 或 `moon.pkg.json` 包配置 | 20 |
| MBH003 | 存在 `README.md` | 20 |
| MBH004 | README 包含使用或验证命令 | 10 |
| MBH005 | 存在常见许可证文件 | 20 |
| MBH006 | 存在测试文件或测试声明 | 10 |
| MBH007 | 存在 `examples/`、`example/` 或 `cmd/` | 5 |
| MBH008 | 存在贡献指南或维护者说明 | 10 |
| MBH009 | 存在 `CHANGELOG.md` 或 `HISTORY.md` | 10 |
| MBH010 | 存在 GitHub Actions 工作流 | 5 |
| MBH011 | README 同时包含测试和演示命令 | 10 |

基础分为 100 分，最低分为 0 分。错误、警告和提示分别用于表示必须修复、建议改进和可选改进的问题。

## 配置

```text
profile = release
minimum_score = 95
maximum_warnings = 1
require_ci = true
require_changelog = true
ignore = fixtures/generated
rule.MBH007 = off
rule.MBH010 = warning
```

可用配置级别为 `community`、`release` 和 `strict`。单条规则可以设置为 `off`、`info`、`warning` 或 `error`。

## 结果产物

- 项目盘点：统计源码、测试、文档、配置、自动化、夹具和生成文件。
- 基线对比：区分新增问题、已解决问题、严重度升级和严重度下降。
- 趋势记录：记录多个版本的维护准备度变化。
- 策略门禁：检查最低分数、错误/警告/提示预算和必需材料。
- 动作队列：按照预计分数收益和修复成本排序下一步工作。

## 真实目录扫描

命令行工具会直接读取项目目录，并自动跳过以下生成目录或依赖目录：

- `.git`
- `.mooncakes`
- `_build`
- `target`
- `node_modules`
- `dist`
- `coverage`

目录内的子项按名称排序，保证不同机器和多次运行得到稳定结果。扫描器只把常见文本文件加载到内存，避免读取图片、压缩包和其他二进制内容。
