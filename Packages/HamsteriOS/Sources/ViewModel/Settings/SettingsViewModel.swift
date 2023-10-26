//
//  SettingViewModel.swift
//  Hamster
//
//  Created by morse on 2023/6/13.
//

import Combine
import HamsterKeyboardKit
import HamsterKit
import OSLog
import ProgressHUD
import RimeKit
import UIKit

public class SettingsViewModel: ObservableObject {
  private var cancelable = Set<AnyCancellable>()
  private unowned let mainViewModel: MainViewModel
  private let rimeContext: RimeContext

  init(mainViewModel: MainViewModel, rimeContext: RimeContext) {
    self.mainViewModel = mainViewModel
    self.rimeContext = rimeContext
  }

  public var enableColorSchema: Bool {
    get {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.enableColorSchema ?? false
    }
    set {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.enableColorSchema = newValue
    }
  }

  public var enableAppleCloud: Bool {
    get {
      HamsterAppDependencyContainer.shared.configuration.general?.enableAppleCloud ?? false
    }
    set {
      HamsterAppDependencyContainer.shared.configuration.general?.enableAppleCloud = newValue
    }
  }

  /// 设置选项
  public lazy var sections: [SettingSectionModel] = {
    let sections = [
      SettingSectionModel(title: "输入相关", items: [
        .init(
          icon: UIImage(systemName: "highlighter")!.withTintColor(.yellow),
          text: "输入方案设置",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.inputSchema)
          }
        ),
        .init(
          icon: UIImage(systemName: "network")!,
          text: "输入方案上传",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.uploadInputSchema)
          }
        ),
        .init(
          icon: UIImage(systemName: "folder")!,
          text: "方案文件管理",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.finder)
          }
        ),
      ]),
      SettingSectionModel(title: "键盘相关", items: [
        .init(
          icon: UIImage(systemName: "keyboard")!,
          text: "键盘设置",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.keyboardSettings)
          }
        ),
        .init(
          icon: UIImage(systemName: "paintpalette")!,
          text: "键盘配色",
          accessoryType: .disclosureIndicator,
          navigationLinkLabel: { [unowned self] in enableColorSchema ? "启用" : "禁用" },
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.colorSchema)
          }
        ),
        .init(
          icon: UIImage(systemName: "speaker.wave.3")!,
          text: "按键音与震动",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.feedback)
          }
        ),
      ]),
      SettingSectionModel(title: "同步与备份", items: [
        .init(
          icon: UIImage(systemName: "externaldrive.badge.icloud")!,
          text: "iCloud同步",
          accessoryType: .disclosureIndicator,
          navigationLinkLabel: { [unowned self] in enableAppleCloud ? "启用" : "禁用" },
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.iCloud)
          }
        ),
        .init(
          icon: UIImage(systemName: "externaldrive.badge.timemachine")!,
          text: "软件备份",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.backup)
          }
        ),
      ]),
      .init(title: "RIME", items: [
        .init(
          icon: UIImage(systemName: "r.square")!,
          text: "RIME",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.rime)
          }
        ),
      ]),
      .init(title: "关于", items: [
        .init(
          icon: UIImage(systemName: "info.circle")!,
          text: "关于",
          accessoryType: .disclosureIndicator,
          navigationAction: { [unowned self] in
            self.mainViewModel.subViewSubject.send(.about)
          }
        ),
      ]),
    ]
    return sections
  }()
}

extension SettingsViewModel {
  /// 启动加载数据
  func loadAppData() async throws {
    // PATCH: 仓1.0版本处理
    if let v1FirstRunning = UserDefaults.hamster._firstRunningForV1, v1FirstRunning == false {
      await ProgressHUD.show("迁移仓输入法1.0配置中……", interaction: false)

      // 读取 1.0 配置参数
      _setupConfigurationForV1Update()

      // 部署 RIME
      try await rimeContext.deployment(configuration: HamsterAppDependencyContainer.shared.configuration)

      // 修改应用首次运行标志
      UserDefaults.hamster.isFirstRunning = false

      /// 删除 V1 标识
      UserDefaults.hamster._removeFirstRunningForV1()

      await ProgressHUD.showSucceed("迁移完成", interaction: false, delay: 1.5)
      return
    }

    // 判断应用是否首次运行
    guard UserDefaults.hamster.isFirstRunning else { return }

    // 判断是否首次运行
    await ProgressHUD.show("初次启动，需要编译输入方案，请耐心等待……", interaction: false)

    // 首次启动始化输入方案目录
    do {
      try FileManager.initSandboxUserDataDirectory(override: true)
      try FileManager.initSandboxBackupDirectory(override: true)
    } catch {
      Logger.statistics.error("rime init file directory error: \(error.localizedDescription)")
      throw error
    }

    // 部署 RIME
    try await rimeContext.deployment(configuration: HamsterAppDependencyContainer.shared.configuration)

    // 修改应用首次运行标志
    UserDefaults.hamster.isFirstRunning = false

    await ProgressHUD.showSucceed("部署完成", interaction: false, delay: 1.5)
  }

  /// 仓1.0迁移配置参数
  private func _setupConfigurationForV1Update() {
    if let _showKeyPressBubble = UserDefaults.hamster._showKeyPressBubble {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.displayButtonBubbles = _showKeyPressBubble
    }

    if let _enableKeyboardFeedbackSound = UserDefaults.hamster._enableKeyboardFeedbackSound {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.enableKeySounds = _enableKeyboardFeedbackSound
    }

    if let _enableKeyboardFeedbackHaptic = UserDefaults.hamster._enableKeyboardFeedbackHaptic {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.enableHapticFeedback = _enableKeyboardFeedbackHaptic
    }

    if let _showKeyboardDismissButton = UserDefaults.hamster._showKeyboardDismissButton {
      HamsterAppDependencyContainer.shared.configuration.toolbar?.displayKeyboardDismissButton = _showKeyboardDismissButton
    }

    if let _showSemicolonButton = UserDefaults.hamster._showSemicolonButton {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.displaySemicolonButton = _showSemicolonButton
    }

    if let _showSpaceLeftButton = UserDefaults.hamster._showSpaceLeftButton {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.displaySpaceLeftButton = _showSpaceLeftButton
    }

    if let _spaceLeftButtonValue = UserDefaults.hamster._spaceLeftButtonValue {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.keyValueOfSpaceLeftButton = _spaceLeftButtonValue
    }

    if let _showSpaceRightButton = UserDefaults.hamster._showSpaceRightButton {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.displaySpaceRightButton = _showSpaceRightButton
    }

    if let _spaceRightButtonValue = UserDefaults.hamster._spaceRightButtonValue {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.keyValueOfSpaceRightButton = _spaceRightButtonValue
    }

    if let _showSpaceRightSwitchLanguageButton = UserDefaults.hamster._showSpaceRightSwitchLanguageButton {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.displayChineseEnglishSwitchButton = _showSpaceRightSwitchLanguageButton
    }

    if let _switchLanguageButtonInSpaceLeft = UserDefaults.hamster._switchLanguageButtonInSpaceLeft {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.chineseEnglishSwitchButtonIsOnLeftOfSpaceButton = _switchLanguageButtonInSpaceLeft
    }

    if let _rimeMaxCandidateSize = UserDefaults.hamster._rimeMaxCandidateSize {
      HamsterAppDependencyContainer.shared.configuration.rime?.maximumNumberOfCandidateWords = _rimeMaxCandidateSize
    }

    if let _rimeCandidateTitleFontSize = UserDefaults.hamster._rimeCandidateTitleFontSize {
      HamsterAppDependencyContainer.shared.configuration.toolbar?.candidateWordFontSize = _rimeCandidateTitleFontSize
    }

    if let _rimeCandidateCommentFontSize = UserDefaults.hamster._rimeCandidateCommentFontSize {
      HamsterAppDependencyContainer.shared.configuration.toolbar?.candidateCommentFontSize = _rimeCandidateCommentFontSize
    }

    if let _candidateBarHeight = UserDefaults.hamster._candidateBarHeight {
      HamsterAppDependencyContainer.shared.configuration.toolbar?.heightOfToolbar = _candidateBarHeight
    }

    if let _rimeSimplifiedAndTraditionalSwitcherKey = UserDefaults.hamster._rimeSimplifiedAndTraditionalSwitcherKey {
      HamsterAppDependencyContainer.shared.configuration.rime?.keyValueOfSwitchSimplifiedAndTraditional = _rimeSimplifiedAndTraditionalSwitcherKey
    }

    if let _enableInputEmbeddedMode = UserDefaults.hamster._enableInputEmbeddedMode {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.enableEmbeddedInputMode = _enableInputEmbeddedMode
    }

    if let _enableKeyboardAutomaticallyLowercase = UserDefaults.hamster._enableKeyboardAutomaticallyLowercase {
      HamsterAppDependencyContainer.shared.configuration.keyboard?.lockShiftState = !_enableKeyboardAutomaticallyLowercase
    }

    if let _rimeSimplifiedAndTraditionalSwitcherKey = UserDefaults.hamster._rimeSimplifiedAndTraditionalSwitcherKey {
      HamsterAppDependencyContainer.shared.configuration.rime?.keyValueOfSwitchSimplifiedAndTraditional = _rimeSimplifiedAndTraditionalSwitcherKey
    }

    if let _keyboardSwipeGestureSymbol = UserDefaults.hamster._keyboardSwipeGestureSymbol {
      let translateShortCommand = { (name: String) -> ShortcutCommand? in
        if name.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#"), let command = ShortcutCommand(rawValue: name) {
          return command
        }
        return nil
      }

      var keySwipeMap = [KeyboardAction: [KeySwipe]]()
      for (fullKey, fullValue) in _keyboardSwipeGestureSymbol {
        let value = fullValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { continue }

        var key = fullKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = String(key.removeLast())
        let action: KeyboardAction = .character(key.lowercased())

        var direction: KeySwipe.Direction
        switch suffix {
        case Self._SlideUp:
          direction = .up
        case Self._SlideDown:
          direction = .down
        case Self._SlideLeft:
          direction = .left
        case Self._SlideRight:
          direction = .right
        default: continue
        }

        var keySwipe: KeySwipe
        if let command = translateShortCommand(value) {
          keySwipe = KeySwipe(direction: direction, action: .shortCommand(command), label: .empty)
        } else {
          keySwipe = KeySwipe(direction: direction, action: .character(value), label: .empty)
        }

        if var value = keySwipeMap[action] {
          value.append(keySwipe)
          keySwipeMap[action] = value
        } else {
          keySwipeMap[action] = [keySwipe]
        }
      }

      let keys = keySwipeMap.map { key, value in Key(action: key, swipe: value) }
      if let index = HamsterAppDependencyContainer.shared.configuration.swipe?.keyboardSwipe?.firstIndex(where: { $0.keyboardType?.isChinese ?? false }) {
        HamsterAppDependencyContainer.shared.configuration.swipe?.keyboardSwipe?[index] = KeyboardSwipe(keyboardType: .chinese(.lowercased), keys: keys)
      } else {
        HamsterAppDependencyContainer.shared.configuration.swipe?.keyboardSwipe?.append(KeyboardSwipe(keyboardType: .chinese(.lowercased), keys: keys))
      }
    }
  }
}

extension SettingsViewModel {
  static let _SlideUp = "↑" // 表示上滑 Upwards Arrow: https://www.compart.com/en/unicode/U+2191
  static let _SlideDown = "↓" // 表示下滑 Downwards Arrow: https://www.compart.com/en/unicode/U+2193
  static let _SlideLeft = "←" // 表示左滑 Leftwards Arrow: https://www.compart.com/en/unicode/U+2190
  static let _SlideRight = "→" // 表示右滑 Rightwards Arrow: https://www.compart.com/en/unicode/U+2192
}
