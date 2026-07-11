// Skill-19 状态机
// 独立 ImportStatus 状态机类 + 状态转换表 + 事件驱动
//
// 状态图（不可逆状态用粗体）：
//
//   idle ──[scan]──▶ scanning ──[filesReady]──▶ readyToImport
//     │                                              │
//     │                                              [import]
//     │                                              ▼
//     │                                          importing
//     │                                              │
//     │                                  ┌───────────┼───────────┐
//     │                              [progress]      [complete]  [cancel]
//     │                                  │              │          │
//     │                                  ▼              ▼          ▼
//     │                              importing      done ◀──    cancelled
//     │                                                          │
//     │                                                      [reset]
//     │                                                          ▼
//     └──────────────────────────────────────────────────────▶ idle
//
// 错误转移：任意状态 ──[error(msg)]──▶ error ──[reset]──▶ idle
// 进度事件：importing 接受 progress(current, total) 增量更新

/// 导入状态枚举
enum ImportStatus {
  /// 空闲（无导入任务）
  idle,

  /// 正在扫描目录
  scanning,

  /// 扫描完成，等待用户确认或直接进入导入
  readyToImport,

  /// 正在导入（带 progress: 0..1）
  importing,

  /// 导入完成（成功/失败计数已统计）
  done,

  /// 导入已取消
  cancelled,

  /// 错误状态（携带 message）
  error,
}

/// 状态机驱动事件
sealed class ImportEvent {
  const ImportEvent();
}

class ImportScanStart extends ImportEvent {
  const ImportScanStart();
}

class ImportFilesReady extends ImportEvent {
  final List<String> filePaths;
  const ImportFilesReady(this.filePaths);
}

class ImportStart extends ImportEvent {
  const ImportStart();
}

class ImportProgress extends ImportEvent {
  final int current;
  final int total;
  const ImportProgress(this.current, this.total);
}

class ImportComplete extends ImportEvent {
  final int successCount;
  final int failCount;
  const ImportComplete({required this.successCount, required this.failCount});
}

class ImportCancel extends ImportEvent {
  const ImportCancel();
}

class ImportReset extends ImportEvent {
  const ImportReset();
}

class ImportError extends ImportEvent {
  final String message;
  const ImportError(this.message);
}

/// 状态机（不可变值对象 + 事件驱动 transition）
class ImportStateMachine {
  final ImportStatus status;
  final List<String> files;
  final int current;
  final int total;
  final int successCount;
  final int failCount;
  final String? errorMessage;

  const ImportStateMachine({
    this.status = ImportStatus.idle,
    this.files = const [],
    this.current = 0,
    this.total = 0,
    this.successCount = 0,
    this.failCount = 0,
    this.errorMessage,
  });

  /// 当前进度（0..1）
  double get progress => total == 0 ? 0 : current / total;

  /// 是否处于"进行中"（scanning / importing）
  bool get isInProgress =>
      status == ImportStatus.scanning || status == ImportStatus.importing;

  /// 事件驱动状态转换
  ///
  /// 非法转换返回原状态（不抛错，便于 UI 鲁棒性）
  ImportStateMachine transition(ImportEvent event) {
    switch (event) {
      case ImportScanStart():
        if (status != ImportStatus.idle &&
            status != ImportStatus.done &&
            status != ImportStatus.cancelled &&
            status != ImportStatus.error) {
          return this; // 非法转换
        }
        return ImportStateMachine(
          status: ImportStatus.scanning,
          files: const [],
          current: 0,
          total: 0,
          successCount: 0,
          failCount: 0,
        );

      case ImportFilesReady(:final filePaths):
        if (status != ImportStatus.scanning) return this;
        return ImportStateMachine(
          status: ImportStatus.readyToImport,
          files: filePaths,
          total: filePaths.length,
        );

      case ImportStart():
        if (status != ImportStatus.readyToImport &&
            status != ImportStatus.cancelled &&
            status != ImportStatus.error) {
          return this;
        }
        return ImportStateMachine(
          status: ImportStatus.importing,
          files: files,
          current: 0,
          total: files.length,
        );

      case ImportProgress(:final current, :final total):
        if (status != ImportStatus.importing) return this;
        return ImportStateMachine(
          status: ImportStatus.importing,
          files: files,
          current: current,
          total: total,
        );

      case ImportComplete(:final successCount, :final failCount):
        if (status != ImportStatus.importing) return this;
        return ImportStateMachine(
          status: ImportStatus.done,
          files: files,
          current: total,
          total: total,
          successCount: successCount,
          failCount: failCount,
        );

      case ImportCancel():
        if (status != ImportStatus.importing &&
            status != ImportStatus.scanning) {
          return this;
        }
        return ImportStateMachine(
          status: ImportStatus.cancelled,
          files: files,
          current: current,
          total: total,
        );

      case ImportReset():
        return const ImportStateMachine();

      case ImportError(:final message):
        return ImportStateMachine(
          status: ImportStatus.error,
          files: files,
          current: current,
          total: total,
          errorMessage: message,
        );
    }
  }
}
