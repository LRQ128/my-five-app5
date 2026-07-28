Build failed at Tue Jul 28 04:35:46 UTC 2026

## Run #23
Commit: abbc792e8808182eaeb53139239dc195282ac4cc

```

Running Gradle task 'assembleRelease'...                        
Checking the license for package Android SDK Build-Tools 33.0.1 in /usr/local/lib/android/sdk/licenses
License for package Android SDK Build-Tools 33.0.1 accepted.
Preparing "Install Android SDK Build-Tools 33.0.1 v.33.0.1".
"Install Android SDK Build-Tools 33.0.1 v.33.0.1" ready.
Installing Android SDK Build-Tools 33.0.1 in /usr/local/lib/android/sdk/build-tools/33.0.1
"Install Android SDK Build-Tools 33.0.1 v.33.0.1" complete.
"Install Android SDK Build-Tools 33.0.1 v.33.0.1" finished.
lib/services/llm_service.dart:26:13: Error: Type 'Utf8' not found.
    Pointer<Utf8> path, Pointer<Void> params);
            ^^^^
lib/services/llm_service.dart:28:13: Error: Type 'Utf8' not found.
    Pointer<Utf8> path, Pointer<Void> params);
            ^^^^
lib/services/llm_service.dart:41:40: Error: Type 'Utf8' not found.
typedef LlamaModelDescNative = Pointer<Utf8> Function(Pointer<Void> model);
                                       ^^^^
lib/services/llm_service.dart:42:38: Error: Type 'Utf8' not found.
typedef LlamaModelDescDart = Pointer<Utf8> Function(Pointer<Void> model);
                                     ^^^^
lib/services/llm_service.dart:52:34: Error: Type 'Utf8' not found.
    Pointer<Void> model, Pointer<Utf8> text, Int32 textLen,
                                 ^^^^
lib/services/llm_service.dart:55:34: Error: Type 'Utf8' not found.
    Pointer<Void> model, Pointer<Utf8> text, int textLen,
                                 ^^^^
lib/services/llm_service.dart:59:47: Error: Type 'Utf8' not found.
    Pointer<Void> model, Int32 token, Pointer<Utf8> buf, Int32 length, Int32 lstrip);
                                              ^^^^
lib/services/llm_service.dart:61:45: Error: Type 'Utf8' not found.
    Pointer<Void> model, int token, Pointer<Utf8> buf, int length, int lstrip);
                                            ^^^^
lib/services/llm_service.dart:114:43: Error: Type 'Utf8' not found.
typedef LlamaPrintTimingsNative = Pointer<Utf8> Function(Pointer<Void> ctx);
                                          ^^^^
lib/services/llm_service.dart:115:41: Error: Type 'Utf8' not found.
typedef LlamaPrintTimingsDart = Pointer<Utf8> Function(Pointer<Void> ctx);
                                        ^^^^
lib/services/llm_service.dart:707:36: Error: Type 'Utf8' not found.
extension Utf8PointerEx on Pointer<Utf8> {
                                   ^^^^
lib/services/llm_service.dart:716:21: Error: Type 'Utf8' not found.
int _strlen(Pointer<Utf8> ptr) {
                    ^^^^
lib/models/model_config.dart:27:22: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
    this.modelSize = 7_000_000_000,
                     ^^^^^^^^^^^^^
lib/models/model_config.dart:108:18: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
      modelSize: 7_000_000_000,
                 ^^^^^^^^^^^^^
lib/models/model_config.dart:117:18: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
      modelSize: 14_000_000_000,
                 ^^^^^^^^^^^^^^
lib/models/model_config.dart:125:18: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
      modelSize: 7_000_000_000,
                 ^^^^^^^^^^^^^
lib/models/model_config.dart:133:18: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
      modelSize: 3_000_000_000,
                 ^^^^^^^^^^^^^
lib/app.dart:48:9: Error: No named parameter with the name 'toolRegistry'.
        toolRegistry: toolRegistry,
        ^^^^^^^^^^^^
lib/services/agent_engine.dart:112:3: Context: Found this candidate, but the arguments don't match.
  AgentEngine({
  ^^^^^^^^^^^
lib/app.dart:36:20: Error: The method 'registerDefaults' isn't defined for the class 'ToolRegistry'.
 - 'ToolRegistry' is from 'package:local_ai_assistant/tools/tool_registry.dart' ('lib/tools/tool_registry.dart').
Try correcting the name to the name of an existing method, or defining a method named 'registerDefaults'.
      toolRegistry.registerDefaults();
                   ^^^^^^^^^^^^^^^^
lib/app.dart:43:33: Error: The method 'initialize' isn't defined for the class 'ConversationService'.
 - 'ConversationService' is from 'package:local_ai_assistant/services/conversation_service.dart' ('lib/services/conversation_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'initialize'.
      await conversationService.initialize();
                                ^^^^^^^^^^
lib/app.dart:169:7: Error: No named parameter with the name 'modelManager'.
      modelManager: modelManager,
      ^^^^^^^^^^^^
lib/ui/chat/chat_page.dart:12:9: Context: Found this candidate, but the arguments don't match.
  const ChatPage({super.key, this.conversationId});
        ^^^^^^^^
lib/services/conversation_service.dart:352:12: Error: The getter 'sqflite' isn't defined for the class 'ConversationService'.
 - 'ConversationService' is from 'package:local_ai_assistant/services/conversation_service.dart' ('lib/services/conversation_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'sqflite'.
    return sqflite.firstIntValue(result) ?? 0;
           ^^^^^^^
lib/services/agent_engine.dart:500:26: Error: 'await' can only be used in 'async' or 'async*' methods.
          final result = await _executeToolSync(tool, toolCallInfo.arguments);
                         ^^^^^
lib/services/agent_engine.dart:502:11: Error: Can't assign to the final variable 'toolCallInfo'.
          toolCallInfo = ToolCallInfo(
          ^^^^^^^^^^^^
lib/services/agent_engine.dart:511:11: Error: Can't assign to the final variable 'toolCallInfo'.
          toolCallInfo = ToolCallInfo(
          ^^^^^^^^^^^^
lib/services/agent_engine.dart:533:12: Error: A value of type 'List<Message>' can't be returned from a function with return type 'Future<List<Message>>'.
 - 'List' is from 'dart:core'.
 - 'Message' is from 'package:local_ai_assistant/models/message.dart' ('lib/models/message.dart').
 - 'Future' is from 'dart:async'.
    return newMessages;
           ^
lib/services/llm_service.dart:356:39: Error: The method 'toNativeUtf8' isn't defined for the class 'String'.
Try correcting the name to the name of an existing method, or defining a method named 'toNativeUtf8'.
      final pathPtr = config.filePath.toNativeUtf8();
                                      ^^^^^^^^^^^^
lib/services/llm_service.dart:358:7: Error: The getter 'calloc' isn't defined for the class 'LlamaCppService'.
 - 'LlamaCppService' is from 'package:local_ai_assistant/services/llm_service.dart' ('lib/services/llm_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'calloc'.
      calloc.free(pathPtr);
      ^^^^^^
lib/services/llm_service.dart:473:62: Error: Cannot invoke a non-'const' factory where a const expression is expected.
Try using a constructor or factory that is 'const'.
      await Future.delayed(const Duration(milliseconds: 30 + Random().nextInt(30)));
                                                             ^^^^^^
lib/services/llm_service.dart:473:71: Error: Method invocation is not a constant expression.
      await Future.delayed(const Duration(milliseconds: 30 + Random().nextInt(30)));
                                                                      ^^^^^^^
lib/services/llm_service.dart:473:60: Error: The argument type 'double' can't be assigned to the parameter type 'int'.
      await Future.delayed(const Duration(milliseconds: 30 + Random().nextInt(30)));
                                                           ^
lib/services/llm_service.dart:516:64: Error: Cannot invoke a non-'const' factory where a const expression is expected.
Try using a constructor or factory that is 'const'.
        await Future.delayed(const Duration(milliseconds: 25 + Random().nextInt(25)));
                                                               ^^^^^^
lib/services/llm_service.dart:516:73: Error: Method invocation is not a constant expression.
        await Future.delayed(const Duration(milliseconds: 25 + Random().nextInt(25)));
                                                                        ^^^^^^^
lib/services/llm_service.dart:516:62: Error: The argument type 'double' can't be assigned to the parameter type 'int'.
        await Future.delayed(const Duration(milliseconds: 25 + Random().nextInt(25)));
                                                             ^
lib/services/llm_service.dart:661:23: Error: The method 'calloc' isn't defined for the class 'LlamaCppService'.
 - 'LlamaCppService' is from 'package:local_ai_assistant/services/llm_service.dart' ('lib/services/llm_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'calloc'.
    final tokensPtr = calloc<Int32>(nTokensMax);
                      ^^^^^^
lib/services/llm_service.dart:662:26: Error: The method 'toNativeUtf8' isn't defined for the class 'String'.
Try correcting the name to the name of an existing method, or defining a method named 'toNativeUtf8'.
    final textPtr = text.toNativeUtf8();
                         ^^^^^^^^^^^^
lib/services/llm_service.dart:674:5: Error: The getter 'calloc' isn't defined for the class 'LlamaCppService'.
 - 'LlamaCppService' is from 'package:local_ai_assistant/services/llm_service.dart' ('lib/services/llm_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'calloc'.
    calloc.free(textPtr);
    ^^^^^^
lib/services/llm_service.dart:680:5: Error: The getter 'calloc' isn't defined for the class 'LlamaCppService'.
 - 'LlamaCppService' is from 'package:local_ai_assistant/services/llm_service.dart' ('lib/services/llm_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'calloc'.
    calloc.free(tokensPtr);
    ^^^^^^
lib/services/llm_service.dart:688:32: Error: 'Utf8' isn't a type.
    final pieceBuffer = calloc<Utf8>(256);
                               ^^^^
lib/services/llm_service.dart:699:2: Error: Expected ';' after this.
 3}
 ^
lib/services/llm_service.dart:688:25: Error: The method 'calloc' isn't defined for the class 'LlamaCppService'.
 - 'LlamaCppService' is from 'package:local_ai_assistant/services/llm_service.dart' ('lib/services/llm_service.dart').
Try correcting the name to the name of an existing method, or defining a method named 'calloc'.
    final pieceBuffer = calloc<Utf8>(256);
                        ^^^^^^
lib/services/llm_service.dart:697:5: Error: The getter 'calloc' isn't defined for the class 'LlamaCppService'.
 - 'LlamaCppService' is from 'package:local_ai_assistant/services/llm_service.dart' ('lib/services/llm_service.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'calloc'.
    calloc.free(pieceBuffer);
    ^^^^^^
lib/services/llm_service.dart:711:41: Error: The method 'elementAt' is defined in multiple extensions for 'Pointer<invalid-type>' and neither is more specific.
 - 'Pointer' is from 'dart:ffi'.
Try using an explicit extension application of the wanted extension or hiding unwanted extensions from scope.
      List<int>.generate(length, (i) => elementAt(i).value),
                                        ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:460:17: Context: This is one of the extension members.
  Pointer<Int8> elementAt(int index) =>
                ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:539:18: Context: This is one of the extension members.
  Pointer<Int16> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:620:18: Context: This is one of the extension members.
  Pointer<Int32> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:692:18: Context: This is one of the extension members.
  Pointer<Int64> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:767:18: Context: This is one of the extension members.
  Pointer<Uint8> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:846:19: Context: This is one of the extension members.
  Pointer<Uint16> elementAt(int index) =>
                  ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:927:19: Context: This is one of the extension members.
  Pointer<Uint32> elementAt(int index) =>
                  ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:999:19: Context: This is one of the extension members.
  Pointer<Uint64> elementAt(int index) =>
                  ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:1080:18: Context: This is one of the extension members.
  Pointer<Float> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:1152:19: Context: This is one of the extension members.
  Pointer<Double> elementAt(int index) =>
                  ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:1219:17: Context: This is one of the extension members.
  Pointer<Bool> elementAt(int index) =>
                ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/_internal/vm/lib/ffi_patch.dart:1277:23: Context: This is one of the extension members.
  Pointer<Pointer<T>> elementAt(int index) =>
                      ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/_internal/vm/lib/ffi_patch.dart:1312:14: Context: This is one of the extension members.
  Pointer<T> elementAt(int index) =>
             ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/_internal/vm/lib/ffi_patch.dart:1343:14: Context: This is one of the extension members.
  Pointer<T> elementAt(int index) =>
             ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/_internal/vm/lib/ffi_patch.dart:1375:14: Context: This is one of the extension members.
  Pointer<T> elementAt(int index) =>
             ^^^^^^^^^
lib/services/llm_service.dart:716:21: Error: 'Utf8' isn't a type.
int _strlen(Pointer<Utf8> ptr) {
                    ^^^^
lib/services/llm_service.dart:718:14: Error: The method 'elementAt' is defined in multiple extensions for 'Pointer<invalid-type>' and neither is more specific.
 - 'Pointer' is from 'dart:ffi'.
Try using an explicit extension application of the wanted extension or hiding unwanted extensions from scope.
  while (ptr.elementAt(len).value != 0) {
             ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:460:17: Context: This is one of the extension members.
  Pointer<Int8> elementAt(int index) =>
                ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:539:18: Context: This is one of the extension members.
  Pointer<Int16> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:620:18: Context: This is one of the extension members.
  Pointer<Int32> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:692:18: Context: This is one of the extension members.
  Pointer<Int64> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:767:18: Context: This is one of the extension members.
  Pointer<Uint8> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:846:19: Context: This is one of the extension members.
  Pointer<Uint16> elementAt(int index) =>
                  ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:927:19: Context: This is one of the extension members.
  Pointer<Uint32> elementAt(int index) =>
                  ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:999:19: Context: This is one of the extension members.
  Pointer<Uint64> elementAt(int index) =>
                  ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:1080:18: Context: This is one of the extension members.
  Pointer<Float> elementAt(int index) =>
                 ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:1152:19: Context: This is one of the extension members.
  Pointer<Double> elementAt(int index) =>
                  ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/ffi/ffi.dart:1219:17: Context: This is one of the extension members.
  Pointer<Bool> elementAt(int index) =>
                ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/_internal/vm/lib/ffi_patch.dart:1277:23: Context: This is one of the extension members.
  Pointer<Pointer<T>> elementAt(int index) =>
                      ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/_internal/vm/lib/ffi_patch.dart:1312:14: Context: This is one of the extension members.
  Pointer<T> elementAt(int index) =>
             ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/_internal/vm/lib/ffi_patch.dart:1343:14: Context: This is one of the extension members.
  Pointer<T> elementAt(int index) =>
             ^^^^^^^^^
org-dartlang-sdk:///flutter/third_party/dart/sdk/lib/_internal/vm/lib/ffi_patch.dart:1375:14: Context: This is one of the extension members.
  Pointer<T> elementAt(int index) =>
             ^^^^^^^^^
lib/ui/chat/message_bubble.dart:446:29: Error: No named parameter with the name 'overflow'.
                            overflow: TextOverflow.ellipsis,
                            ^^^^^^^^
/opt/hostedtoolcache/flutter/stable-3.27.4-x64/flutter/packages/flutter/lib/src/material/selectable_text.dart:158:9: Context: Found this candidate, but the arguments don't match.
  const SelectableText(
        ^^^^^^^^^^^^^^
lib/models/model_config.dart:87:59: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
        modelSize: (map['modelSize'] as num?)?.toInt() ?? 7_000_000_000,
                                                          ^^^^^^^^^^^^^
lib/models/model_config.dart:93:22: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
    if (modelSize >= 70_000_000_000) return '70B';
                     ^^^^^^^^^^^^^^
lib/models/model_config.dart:94:22: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
    if (modelSize >= 30_000_000_000) return '30B';
                     ^^^^^^^^^^^^^^
lib/models/model_config.dart:95:22: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
    if (modelSize >= 13_000_000_000) return '14B';
                     ^^^^^^^^^^^^^^
lib/models/model_config.dart:96:22: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
    if (modelSize >= 7_000_000_000) return '7B';
                     ^^^^^^^^^^^^^
lib/models/model_config.dart:97:22: Error: This requires the experimental 'digit-separators' language feature to be enabled.
Try passing the '--enable-experiment=digit-separators' command line option.
    if (modelSize >= 3_000_000_000) return '3B';
                     ^^^^^^^^^^^^^
lib/ui/widgets/common_widgets.dart:38:32: Error: Undefined name 'iat'.
                  strokeWidth: iat,
                               ^^^
lib/ui/widgets/common_widgets.dart:29:32: Error: The getter 'iat' isn't defined for the class 'LoadingDialog'.
 - 'LoadingDialog' is from 'package:local_ai_assistant/ui/widgets/common_widgets.dart' ('lib/ui/widgets/common_widgets.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'iat'.
                  strokeWidth: iat,
                               ^^^
lib/ui/widgets/common_widgets.dart:174:43: Error: Undefined name 'iat'.
        duration: const Duration(seconds: iat),
                                          ^^^
lib/ui/widgets/common_widgets.dart:199:43: Error: Undefined name 'iat'.
        duration: const Duration(seconds: iat),
                                          ^^^
lib/ui/widgets/common_widgets.dart:224:43: Error: Undefined name 'iat'.
        duration: const Duration(seconds: iat),
                                          ^^^
lib/ui/widgets/common_widgets.dart:298:17: Error: The getter 'ImageFilter' isn't defined for the class 'GlassmorphicContainer'.
 - 'GlassmorphicContainer' is from 'package:local_ai_assistant/ui/widgets/common_widgets.dart' ('lib/ui/widgets/common_widgets.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'ImageFilter'.
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                ^^^^^^^^^^^
lib/services/llm_service.dart:251:28: Error: Expected type 'Void Function(Pointer<Void>)' to be 'void Function(Pointer<Void>)', which is the Dart type corresponding to 'NativeFunction<Void Function(Pointer<Void>)>'.
 - 'Void' is from 'dart:ffi'.
 - 'Pointer' is from 'dart:ffi'.
 - 'NativeFunction' is from 'dart:ffi'.
    _llamaFreeModel = _lib.lookupFunction<LlamaFreeModelNative,
                           ^
lib/services/llm_service.dart:258:30: Error: Expected type 'Void Function(Pointer<Void>)' to be 'void Function(Pointer<Void>)', which is the Dart type corresponding to 'NativeFunction<Void Function(Pointer<Void>)>'.
 - 'Void' is from 'dart:ffi'.
 - 'Pointer' is from 'dart:ffi'.
 - 'NativeFunction' is from 'dart:ffi'.
    _llamaFreeContext = _lib.lookupFunction<LlamaFreeContextNative,
                             ^
lib/services/llm_service.dart:284:14: Error: Expected type 'Void Function(Pointer<Void>)' to be 'void Function(Pointer<Void>)', which is the Dart type corresponding to 'NativeFunction<Void Function(Pointer<Void>)>'.
 - 'Void' is from 'dart:ffi'.
 - 'Pointer' is from 'dart:ffi'.
 - 'NativeFunction' is from 'dart:ffi'.
        _lib.lookupFunction<LlamaKVNCacheClearNative,
             ^
lib/services/llm_service.dart:296:14: Error: Expected type 'Void Function(Pointer<Void>)' to be 'void Function(Pointer<Void>)', which is the Dart type corresponding to 'NativeFunction<Void Function(Pointer<Void>)>'.
 - 'Void' is from 'dart:ffi'.
 - 'Pointer' is from 'dart:ffi'.
 - 'NativeFunction' is from 'dart:ffi'.
        _lib.lookupFunction<LlamaCandidatesFreeNative,
             ^
lib/services/llm_service.dart:300:14: Error: Expected type 'Void Function(Pointer<Void>, double)' to be 'void Function(Pointer<Void>, double)', which is the Dart type corresponding to 'NativeFunction<Void Function(Pointer<Void>, Float)>'.
 - 'Void' is from 'dart:ffi'.
 - 'Pointer' is from 'dart:ffi'.
 - 'NativeFunction' is from 'dart:ffi'.
 - 'Float' is from 'dart:ffi'.
        _lib.lookupFunction<LlamaCandidatesSetTemperatureNative,
             ^
lib/services/llm_service.dart:313:14: Error: Expected type 'Void Function(Pointer<Void>)' to be 'void Function(Pointer<Void>)', which is the Dart type corresponding to 'NativeFunction<Void Function(Pointer<Void>)>'.
 - 'Void' is from 'dart:ffi'.
 - 'Pointer' is from 'dart:ffi'.
 - 'NativeFunction' is from 'dart:ffi'.
        _lib.lookupFunction<LlamaBatchFreeNative, LlamaBatchFreeDart>(
             ^
Target kernel_snapshot_program failed: Exception


FAILURE: Build failed with an exception.

* What went wrong:
Execution failed for task ':app:compileFlutterBuildRelease'.
> Process 'command '/opt/hostedtoolcache/flutter/stable-3.27.4-x64/flutter/bin/flutter'' finished with non-zero exit value 1

* Try:
> Run with --stacktrace option to get the stack trace.
> Run with --info or --debug option to get more log output.
> Run with --scan to get full insights.
> Get more help at https://help.gradle.org.

BUILD FAILED in 2m 42s
Running Gradle task 'assembleRelease'...                          163.4s
Gradle task assembleRelease failed with exit code 1
Resolving dependencies...
Downloading packages...
  async 2.11.0 (2.13.1 available)
  boolean_selector 2.1.1 (2.1.2 available)
  characters 1.3.0 (1.4.1 available)
  clock 1.1.1 (1.1.2 available)
  collection 1.19.0 (1.19.1 available)
  cupertino_icons 1.0.8 (1.0.9 available)
  fake_async 1.3.1 (1.3.3 available)
  ffi 2.1.3 (2.2.0 available)
  flutter_lints 3.0.2 (6.0.0 available)
  flutter_markdown 0.6.23 (discontinued replaced by flutter_markdown_plus)
  intl 0.19.0 (0.20.3 available)
  leak_tracker 10.0.7 (11.0.2 available)
  leak_tracker_flutter_testing 3.0.8 (3.0.10 available)
  leak_tracker_testing 3.0.1 (3.0.2 available)
  lints 3.0.0 (6.1.0 available)
  markdown 7.3.0 (7.3.1 available)
  matcher 0.12.16+1 (0.12.20 available)
  material_color_utilities 0.11.1 (0.13.0 available)
  meta 1.15.0 (1.19.0 available)
  path 1.9.0 (1.9.1 available)
  path_provider 2.1.5 (2.1.6 available)
  path_provider_android 2.2.17 (2.3.1 available)
  path_provider_foundation 2.4.1 (2.6.0 available)
  path_provider_linux 2.2.1 (2.2.2 available)
  path_provider_platform_interface 2.1.2 (2.1.3 available)
  permission_handler 11.4.0 (12.0.3 available)
  permission_handler_android 12.1.0 (13.0.1 available)
  shared_preferences 2.5.3 (2.5.5 available)
  shared_preferences_android 2.4.11 (2.4.27 available)
  shared_preferences_foundation 2.5.4 (2.5.6 available)
  shared_preferences_platform_interface 2.4.1 (2.4.2 available)
  source_span 1.10.0 (1.10.2 available)
  sqflite 2.4.1 (2.4.3 available)
  sqflite_android 2.4.0 (2.4.3 available)
  sqflite_common 2.5.4+6 (2.5.11 available)
  sqflite_darwin 2.4.1+1 (2.4.3+1 available)
  sqflite_platform_interface 2.4.0 (2.4.1 available)
  stack_trace 1.12.0 (1.12.1 available)
  stream_channel 2.1.2 (2.1.4 available)
  string_scanner 1.3.0 (1.4.1 available)
  synchronized 3.3.0+3 (3.4.1+1 available)
  term_glyph 1.2.1 (1.2.2 available)
  test_api 0.7.3 (0.7.13 available)
  vector_math 2.1.4 (2.4.1 available)
  vm_service 14.3.0 (15.2.0 available)
Got dependencies!
1 package is discontinued.
45 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
```
STEP1_OK
STEP2_OK
STEP3_OK
STEP4_OK
STEP4b_OK
[✗] Linux toolchain - develop for Linux desktop
    ✗ GTK 3.0 development libraries are required for Linux development.
              android:name="io.flutter.embedding.android.NormalTheme"
            android:name="flutterEmbedding"
lib/services/llm_service.dart:26:13: Error: Type 'Utf8' not found.
lib/services/llm_service.dart:28:13: Error: Type 'Utf8' not found.
lib/services/llm_service.dart:41:40: Error: Type 'Utf8' not found.
lib/services/llm_service.dart:42:38: Error: Type 'Utf8' not found.
lib/services/llm_service.dart:52:34: Error: Type 'Utf8' not found.
lib/services/llm_service.dart:55:34: Error: Type 'Utf8' not found.
