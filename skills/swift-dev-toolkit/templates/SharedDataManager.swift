//
//  SharedDataManager.swift
//  App Groups 連携テンプレート
//
//  Widget / Live Activity とメインアプリ間でデータを共有するためのマネージャ。
//  使い方:
//    1. "group.xxx" を実際の App Group ID に置換
//    2. TimerState を自分のアプリのモデルに合わせて修正
//    3. Settings cache を必要に応じてカスタマイズ
//

import Foundation
import WidgetKit

// MARK: - Timer State (Widget/LiveActivity 用軽量構造体)

struct TimerState: Codable, Equatable {
    let mode: TimerMode
    let phase: TimerPhase
    let selectedPhase: TimerPhase
    let endDate: Date?
    let pausedRemaining: TimeInterval?
    let totalDuration: TimeInterval
    let completedFocusCount: Int
    let lastUpdated: Date
    let autoSwitch: Bool

    static let idle = TimerState(
        mode: .idle,
        phase: .focus,
        selectedPhase: .focus,
        endDate: nil,
        pausedRemaining: nil,
        totalDuration: 0,
        completedFocusCount: 0,
        lastUpdated: .now,
        autoSwitch: true
    )
}

// MARK: - Timer Mode

enum TimerMode: String, Codable {
    case idle
    case running
    case paused
}

// MARK: - Timer Phase

enum TimerPhase: String, Codable, CaseIterable {
    case focus
    case rest
    case longRest

    var defaultDuration: TimeInterval {
        switch self {
        case .focus: return 25 * 60
        case .rest: return 5 * 60
        case .longRest: return 15 * 60
        }
    }
}

// MARK: - Shared Data Manager

final class SharedDataManager {
    static let shared = SharedDataManager()

    // TODO: 実際の App Group ID に置換
    private let suiteName = "group.xxx"
    private let stateKey = "timerState"
    private let settingsKey = "cachedSettings"

    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private init() {}

    // MARK: - Timer State

    /// タイマー状態を保存
    /// - Parameters:
    ///   - state: 保存する状態
    ///   - notifyApp: true の場合、メインアプリに通知を送信
    func saveTimerState(_ state: TimerState, notifyApp: Bool = false) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        userDefaults?.set(data, forKey: stateKey)

        if notifyApp {
            // Darwin Notification でメインアプリに通知
            let notificationName = CFNotificationName(
                "group.xxx.timerStateChanged" as CFString  // TODO: App Group ID に置換
            )
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                notificationName,
                nil,
                nil,
                true
            )
        }
    }

    /// タイマー状態を読み込み
    func loadTimerState() -> TimerState {
        guard let data = userDefaults?.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(TimerState.self, from: data) else {
            return .idle
        }
        return state
    }

    // MARK: - Settings Cache (Widget/LiveActivity 用)

    private struct CachedSettings: Codable {
        let focusMinutes: Int
        let restMinutes: Int
        let longRestMinutes: Int
        let longRestEvery: Int
    }

    /// 設定をキャッシュ（Widget/LiveActivity がユーザー設定を参照できるように）
    func cacheSettings(
        focusMinutes: Int,
        restMinutes: Int,
        longRestMinutes: Int,
        longRestEvery: Int
    ) {
        let settings = CachedSettings(
            focusMinutes: focusMinutes,
            restMinutes: restMinutes,
            longRestMinutes: longRestMinutes,
            longRestEvery: longRestEvery
        )
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults?.set(data, forKey: settingsKey)
        }
    }

    /// キャッシュされた設定を読み込み
    private func loadCachedSettings() -> CachedSettings? {
        guard let data = userDefaults?.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(CachedSettings.self, from: data) else {
            return nil
        }
        return settings
    }

    /// 指定フェーズの duration を取得（ユーザー設定 or デフォルト）
    func durationForPhase(_ phase: TimerPhase) -> TimeInterval {
        if let cached = loadCachedSettings() {
            switch phase {
            case .focus: return TimeInterval(cached.focusMinutes * 60)
            case .rest: return TimeInterval(cached.restMinutes * 60)
            case .longRest: return TimeInterval(cached.longRestMinutes * 60)
            }
        }
        return phase.defaultDuration
    }

    /// キャッシュされた longRestEvery を取得（デフォルト: 4）
    func getLongRestEvery() -> Int {
        loadCachedSettings()?.longRestEvery ?? 4
    }

    // MARK: - Widget Reload

    /// 全ての Widget タイムラインをリロード
    func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
