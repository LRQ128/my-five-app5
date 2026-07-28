/// 计算器工具。
///
/// 支持安全地解析并计算数学表达式，包括：
/// - 基本运算：+ - * / % ^
/// - 括号优先级
/// - 常用数学函数：sin, cos, tan, sqrt, abs, log, ln, exp, round, floor, ceil
///
/// 内置表达式解析器（递归下降），不依赖 dart:eval 等危险机制，
/// 对恶意表达式（import / exec 等关键词）做安全过滤。

import 'dart:math' as math;

import 'tool_base.dart';

/// 计算器工具
class CalculatorTool extends ToolBase {
  CalculatorTool()
      : super(
          name: 'calculator',
          description: '执行数学计算，支持加减乘除、幂运算、三角函数等',
          parameters: const {
            'type': 'object',
            'properties': {
              'expression': {
                'type': 'string',
                'description': '数学表达式，如 "1+2*3" 或 "sqrt(16)"',
              },
            },
            'required': ['expression'],
          },
        );

  /// 正则表达式，用于匹配合法的数学表达式字符
  static final _allowedPattern =
      RegExp(r'^[\d\s+\-*/%.^()a-z_A-Z,]+$');

  /// 危险关键词列表——包含这些关键词的表达式直接拒绝
  static const _dangerKeywords = [
    'import',
    'exec',
    'eval',
    'dart:',
    'File',
    'Process',
    'System',
    'Runtime',
    'exit',
    'Isolate',
    'spawn',
    '__',
  ];

  @override
  Future<String> execute(Map<String, dynamic> args) async {
    final expression =
        (args['expression'] as String?)?.trim() ?? '';

    if (expression.isEmpty) {
      return '错误：数学表达式不能为空';
    }

    // ===== 安全过滤 =====

    // 1. 字符白名单检查
    if (!_allowedPattern.hasMatch(expression)) {
      return '错误：表达式包含不允许的字符。支持数字、运算符 (+-*/%^)、括号和常见数学函数';
    }

    // 2. 危险关键词检查
    final lowerExpr = expression.toLowerCase();
    for (final keyword in _dangerKeywords) {
      if (lowerExpr.contains(keyword)) {
        return '错误：表达式包含不允许的关键词：$keyword';
      }
    }

    // ===== 计算 =====
    try {
      final evaluator = _ExpressionEvaluator(expression);
      final result = evaluator.evaluate();
      // 格式化输出——整数不显示小数点
      if (result == result.truncateToDouble() && result.isFinite) {
        return '计算结果：${result.toInt()}';
      }
      return '计算结果：$result';
    } on FormatException catch (e) {
      return '表达式格式错误：${e.message}';
    } catch (e) {
      return '计算错误：${e.toString()}';
    }
  }
}

// =============================================================================
// 表达式求值器 —— 递归下降解析
// =============================================================================

/// 表达式求值器（递归下降法）
class _ExpressionEvaluator {
  final String _expr;
  int _pos = 0;

  _ExpressionEvaluator(this._expr);

  /// 当前字符（跳过空白后）
  int? get _current {
    _skipWhitespace();
    if (_pos >= _expr.length) return null;
    return _expr.codeUnitAt(_pos);
  }

  void _skipWhitespace() {
    while (_pos < _expr.length &&
        (_expr.codeUnitAt(_pos) == 0x20 || // space
            _expr.codeUnitAt(_pos) == 0x09)) {
      // tab
      _pos++;
    }
  }

  /// 消费当前字符（需匹配预期字符）
  void _expect(int char) {
    _skipWhitespace();
    if (_pos >= _expr.length || _expr.codeUnitAt(_pos) != char) {
      throw FormatException(
        '期望 "${String.fromCharCode(char)}"，'
        '实际 "${_pos < _expr.length ? _expr[_pos] : 'EOF'}"',
      );
    }
    _pos++;
  }

  /// 主入口：expression = term ( ('+'|'-') term )*
  double evaluate() {
    double result = _term();
    while (true) {
      _skipWhitespace();
      final ch = _current;
      if (ch == 0x2B /* '+' */) {
        _pos++;
        result += _term();
      } else if (ch == 0x2D /* '-' */) {
        _pos++;
        result -= _term();
      } else {
        break;
      }
    }
    return result;
  }

  /// term = factor ( ('*'|'/'|'%') factor )*
  double _term() {
    double result = _factor();
    while (true) {
      _skipWhitespace();
      final ch = _current;
      if (ch == 0x2A /* '*' */) {
        _pos++;
        result *= _factor();
      } else if (ch == 0x2F /* '/' */) {
        _pos++;
        final divisor = _factor();
        if (divisor == 0) throw FormatException('除数不能为零');
        result /= divisor;
      } else if (ch == 0x25 /* '%' */) {
        _pos++;
        final divisor = _factor();
        if (divisor == 0) throw FormatException('模除数不能为零');
        result %= divisor;
      } else {
        break;
      }
    }
    return result;
  }

  /// factor = unary ( '^' factor )?
  double _factor() {
    double base = _unary();
    while (true) {
      _skipWhitespace();
      if (_current == 0x5E /* '^' */) {
        _pos++;
        final exponent = _factor();
        base = math.pow(base, exponent).toDouble();
      } else {
        break;
      }
    }
    return base;
  }

  /// unary = '-' unary | primary
  double _unary() {
    _skipWhitespace();
    if (_current == 0x2D /* '-' */) {
      _pos++;
      return -_unary();
    }
    return _primary();
  }

  /// primary = NUMBER | '(' expression ')' | function '(' expression (',' expression)* ')'
  double _primary() {
    _skipWhitespace();
    final ch = _current;

    // 数字（整数或小数）
    if (ch != null &&
        ((ch >= 0x30 && ch <= 0x39) || ch == 0x2E /* '.' */)) {
      return _parseNumber();
    }

    // 括号
    if (ch == 0x28 /* '(' */) {
      _pos++;
      final result = evaluate();
      _expect(0x29 /* ')' */);
      return result;
    }

    // 函数调用
    if (ch != null &&
        ((ch >= 0x41 && ch <= 0x5A) || // A-Z
            (ch >= 0x61 && ch <= 0x7A) || // a-z
            ch == 0x5F)) {
      // '_'
      final funcName = _parseIdentifier();
      _expect(0x28 /* '(' */);

      // 收集参数
      final args = <double>[];
      if (_current != 0x29 /* ')' */) {
        args.add(evaluate());
        while (_current == 0x2C /* ',' */) {
          _pos++;
          args.add(evaluate());
        }
      }
      _expect(0x29 /* ')' */);

      return _callFunction(funcName, args);
    }

    throw FormatException(
      '意外的字符 "${_pos < _expr.length ? _expr[_pos] : 'EOF'}"',
    );
  }

  /// 解析数字字面量
  double _parseNumber() {
    final start = _pos;
    // 整数部分
    while (_pos < _expr.length) {
      final ch = _expr.codeUnitAt(_pos);
      if (ch >= 0x30 && ch <= 0x39) {
        _pos++;
      } else {
        break;
      }
    }
    // 小数部分
    if (_pos < _expr.length && _expr.codeUnitAt(_pos) == 0x2E /* '.' */) {
      _pos++;
      while (_pos < _expr.length) {
        final ch = _expr.codeUnitAt(_pos);
        if (ch >= 0x30 && ch <= 0x39) {
          _pos++;
        } else {
          break;
        }
      }
    }
    // 科学计数法
    if (_pos < _expr.length &&
        (_expr.codeUnitAt(_pos) == 0x65 /* 'e' */ ||
            _expr.codeUnitAt(_pos) == 0x45 /* 'E' */)) {
      _pos++;
      if (_pos < _expr.length &&
          (_expr.codeUnitAt(_pos) == 0x2B /* '+' */ ||
              _expr.codeUnitAt(_pos) == 0x2D /* '-' */)) {
        _pos++;
      }
      while (_pos < _expr.length) {
        final ch = _expr.codeUnitAt(_pos);
        if (ch >= 0x30 && ch <= 0x39) {
          _pos++;
        } else {
          break;
        }
      }
    }
    final numStr = _expr.substring(start, _pos);
    final result = double.tryParse(numStr);
    if (result == null) {
      throw FormatException('无效的数字格式：$numStr');
    }
    return result;
  }

  /// 解析标识符（函数名）
  String _parseIdentifier() {
    final start = _pos;
    while (_pos < _expr.length) {
      final ch = _expr.codeUnitAt(_pos);
      if ((ch >= 0x41 && ch <= 0x5A) ||
          (ch >= 0x61 && ch <= 0x7A) ||
          (ch >= 0x30 && ch <= 0x39) ||
          ch == 0x5F) {
        _pos++;
      } else {
        break;
      }
    }
    if (_pos == start) throw FormatException('期望函数名');
    return _expr.substring(start, _pos);
  }

  /// 调用数学函数
  double _callFunction(String name, List<double> args) {
    switch (name.toLowerCase()) {
      case 'sin':
        _checkArgCount(name, args, 1);
        return math.sin(args[0]);
      case 'cos':
        _checkArgCount(name, args, 1);
        return math.cos(args[0]);
      case 'tan':
        _checkArgCount(name, args, 1);
        return math.tan(args[0]);
      case 'asin':
        _checkArgCount(name, args, 1);
        return math.asin(args[0]);
      case 'acos':
        _checkArgCount(name, args, 1);
        return math.acos(args[0]);
      case 'atan':
        _checkArgCount(name, args, 1);
        return math.atan(args[0]);
      case 'atan2':
        _checkArgCount(name, args, 2);
        return math.atan2(args[0], args[1]);
      case 'sqrt':
        _checkArgCount(name, args, 1);
        if (args[0] < 0) throw FormatException('sqrt 参数不能为负数');
        return math.sqrt(args[0]);
      case 'abs':
        _checkArgCount(name, args, 1);
        return args[0].abs();
      case 'log':
      case 'log10':
        _checkArgCount(name, args, 1);
        if (args[0] <= 0) throw FormatException('$name 参数必须为正数');
        return math.log(args[0]) / math.ln10;
      case 'ln':
        _checkArgCount(name, args, 1);
        if (args[0] <= 0) throw FormatException('$name 参数必须为正数');
        return math.log(args[0]);
      case 'exp':
        _checkArgCount(name, args, 1);
        return math.exp(args[0]);
      case 'round':
        _checkArgCount(name, args, 1);
        return args[0].roundToDouble();
      case 'floor':
        _checkArgCount(name, args, 1);
        return args[0].floorToDouble();
      case 'ceil':
        _checkArgCount(name, args, 1);
        return args[0].ceilToDouble();
      case 'pow':
        _checkArgCount(name, args, 2);
        return math.pow(args[0], args[1]).toDouble();
      case 'pi':
      case 'π':
        _checkArgCount(name, args, 0);
        return math.pi;
      case 'e':
        _checkArgCount(name, args, 0);
        return math.e;
      case 'min':
        if (args.length < 2) throw FormatException('$name 需要至少 2 个参数');
        return args.reduce(math.min);
      case 'max':
        if (args.length < 2) throw FormatException('$name 需要至少 2 个参数');
        return args.reduce(math.max);
      default:
        throw FormatException('未知函数：$name');
    }
  }

  void _checkArgCount(String name, List<double> args, int expected) {
    if (args.length != expected) {
      throw FormatException(
        '$name 需要 $expected 个参数，实际提供了 ${args.length} 个',
      );
    }
  }
}
