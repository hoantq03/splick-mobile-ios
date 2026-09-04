import DesignSystem
import SwiftUI

struct EditorStickerContentView: View {
    let kind: EditorStickerKind
    var gifData: Data?

    var body: some View {
        switch kind {
        case .symbol(let name, let tint):
            Image(systemName: name)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color(tint))
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                .frame(width: 72, height: 72)

        case .emoji(let value):
            Text(value)
                .font(.system(size: 52))
                .frame(width: 72, height: 72)

        case .widget(let template):
            widgetView(template)
                .fixedSize(horizontal: true, vertical: true)

        case .gif:
            if let gifData {
                EditorGifImageView(data: gifData)
                    .frame(width: 120, height: 120)
            } else {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 120, height: 120)
            }
        }
    }

    @ViewBuilder
    private func widgetView(_ template: WidgetStickerTemplate) -> some View {
        switch template {
        case .weather:
            WeatherWidgetStickerView()
        case .clock:
            ClockWidgetStickerView()
        case .calendar:
            CalendarWidgetStickerView()
        case .music:
            MusicWidgetStickerView()
        case .fitness:
            FitnessWidgetStickerView()
        case .battery:
            BatteryWidgetStickerView()
        case .network:
            NetworkWidgetStickerView()
        case .location:
            LocationWidgetStickerView()
        case .reminder:
            ReminderWidgetStickerView()
        case .countdown:
            CountdownWidgetStickerView()
        case .storage:
            StorageWidgetStickerView()
        case .photos:
            PhotosWidgetStickerView()
        }
    }
}

// MARK: - Widget stickers (iOS-style cards)

struct WeatherWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hà Nội")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Text("28°")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Nắng đẹp")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.yellow)
            }
        }
    }
}

struct ClockWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            VStack(spacing: 2) {
                Text(Date.now, format: .dateTime.hour().minute())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(Date.now, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct CalendarWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 10) {
                VStack(spacing: 1) {
                    Text(Date.now, format: .dateTime.month(.abbreviated))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                    Text(Date.now, format: .dateTime.day())
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hôm nay")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Không có sự kiện")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct MusicWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(SplickTheme.Colors.primaryGradient)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Đang phát")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                    Text("Splick Vibes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Playlist · 3:42")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct FitnessWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bước chân")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("8,432")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Mục tiêu 10,000")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct BatteryWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                Image(systemName: batterySymbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(batteryColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pin")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(batteryPercentText)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Thiết bị")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
        }
    }

    private var level: Float {
        UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel : 0.72
    }

    private var batteryPercentText: String {
        "\(Int(level * 100))%"
    }

    private var batterySymbol: String {
        switch level {
        case ..<0.1: return "battery.0"
        case ..<0.35: return "battery.25"
        case ..<0.65: return "battery.50"
        case ..<0.9: return "battery.75"
        default: return "battery.100"
        }
    }

    private var batteryColor: Color {
        level < 0.2 ? .red : .green
    }
}

struct NetworkWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                Image(systemName: "wifi")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kết nối")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Wi‑Fi")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 4) {
                        Image(systemName: "cellularbars")
                        Text("Di động")
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct LocationWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vị trí")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(Locale.current.region?.identifier ?? "VN")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(TimeZone.current.identifier.split(separator: "/").last.map(String.init) ?? "Local")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct ReminderWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nhắc nhở")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("3 việc hôm nay")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("Hoàn thành 1/3")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

struct CountdownWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            VStack(spacing: 2) {
                Text("Cuối tuần")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(daysUntilWeekend, format: .number)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("ngày nữa")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var daysUntilWeekend: Int {
        let weekday = Calendar.current.component(.weekday, from: Date.now)
        return weekday <= 7 ? max(7 - weekday, 0) : 0
    }
}

struct StorageWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bộ nhớ")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(freeSpaceText)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("Còn trống")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var freeSpaceText: String {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let free = attrs[.systemFreeSize] as? NSNumber else {
            return "—"
        }
        return ByteCountFormatter.string(fromByteCount: free.int64Value, countStyle: .file)
    }
}

struct PhotosWidgetStickerView: View {
    var body: some View {
        WidgetStickerShell {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "photo.on.rectangle")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kỷ niệm")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Hôm nay")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(Date.now, format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
