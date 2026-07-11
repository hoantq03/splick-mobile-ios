import SwiftUI
import PhotosUI
import DesignSystem
import Common
import Localization
import SplickDomain
import FeatureStickers

private enum AllEmojiEntry: Identifiable {
    case custom(CustomEmoji)
    case system(SystemEmojiEntry)

    var id: String {
        switch self {
        case .custom(let emoji):
            return "custom-\(emoji.id.uuidString)"
        case .system(let emoji):
            return "system-\(emoji.emoji)"
        }
    }
}

private struct SystemEmojiEntry: Identifiable {
    let emoji: String
    let keywords: [String]

    var id: String { emoji }
}

private enum EmojiPickerTab: String, CaseIterable, Identifiable {
    case unicode
    case custom

    var id: String { rawValue }
}

/// Popup for picking a reaction emoji or inserting a custom emoji into text.
public struct EmojiPickerSheet: View {
    public enum Mode {
        /// Reaction bar: quick slots + optional Done to persist preferences.
        case reaction
        /// Comment composer: pick once and dismiss without quick-slot UI.
        case inlineInsert
    }

    @EnvironmentObject private var languageService: LanguageService
    @EnvironmentObject private var emojiStore: CustomEmojiStore
    @Environment(\.customEmojiDependencies) private var customEmojiDependencies
    @ObservedObject private var preferences = QuickReactionPreferences.shared

    let currentUserId: UUID?
    let mode: Mode
    let onPick: (String) -> Void
    var onOpenUpload: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draftQuickEmojis: [String] = QuickReactionPreferences.defaultEmojis
    @State private var selectedSlot: Int?
    @State private var selectedTab: EmojiPickerTab
    @State private var selectedUploadPhotoItem: PhotosPickerItem?
    @State private var uploadSourceImage: UIImage?
    @State private var isPreparingUpload = false
    @State private var uploadPreparationError: String?
    @State private var showEmojiComposer = false
    @State private var searchQuery = ""

    public init(
        currentUserId: UUID?,
        mode: Mode = .reaction,
        onPick: @escaping (String) -> Void,
        onOpenUpload: (() -> Void)? = nil
    ) {
        self.currentUserId = currentUserId
        self.mode = mode
        self.onPick = onPick
        self.onOpenUpload = onOpenUpload
        _selectedTab = State(initialValue: mode == .inlineInsert ? .custom : .unicode)
    }

    private let unicodeColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 8)
    private let customColumns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 5)

    private static let emojiCatalog: [SystemEmojiEntry] = [
        .init(emoji: "❤️", keywords: ["heart", "love", "tim", "yeu"]),
        .init(emoji: "🧡", keywords: ["orange heart", "heart", "cam", "tim"]),
        .init(emoji: "💛", keywords: ["yellow heart", "heart", "vang", "tim"]),
        .init(emoji: "💚", keywords: ["green heart", "heart", "xanh", "tim"]),
        .init(emoji: "💙", keywords: ["blue heart", "heart", "duong", "tim"]),
        .init(emoji: "💜", keywords: ["purple heart", "heart", "tim", "tim"]),
        .init(emoji: "🖤", keywords: ["black heart", "heart", "den", "tim"]),
        .init(emoji: "🤍", keywords: ["white heart", "heart", "trang", "tim"]),
        .init(emoji: "😂", keywords: ["laugh", "funny", "haha", "cuoi"]),
        .init(emoji: "🤣", keywords: ["rolling laugh", "funny", "haha", "cuoi"]),
        .init(emoji: "😊", keywords: ["smile", "happy", "cuoi", "vui"]),
        .init(emoji: "😍", keywords: ["love eyes", "heart eyes", "me", "thich"]),
        .init(emoji: "🥰", keywords: ["love", "cute", "de thuong", "om tim"]),
        .init(emoji: "😘", keywords: ["kiss", "hon"]),
        .init(emoji: "😎", keywords: ["cool", "ngau", "kinh"]),
        .init(emoji: "🤩", keywords: ["star eyes", "wow", "sao", "thich"]),
        .init(emoji: "😮", keywords: ["surprised", "wow", "ngo ngang"]),
        .init(emoji: "😲", keywords: ["shocked", "wow", "bat ngo"]),
        .init(emoji: "😢", keywords: ["sad", "cry", "buon"]),
        .init(emoji: "😭", keywords: ["cry", "khoc", "buon"]),
        .init(emoji: "😡", keywords: ["angry", "mad", "gian"]),
        .init(emoji: "🤬", keywords: ["angry", "swear", "gian"]),
        .init(emoji: "👏", keywords: ["clap", "vo tay"]),
        .init(emoji: "🙌", keywords: ["raise hands", "yay", "tung ho"]),
        .init(emoji: "🔥", keywords: ["fire", "hot", "lua", "chat"]),
        .init(emoji: "💯", keywords: ["100", "perfect", "chuan"]),
        .init(emoji: "✨", keywords: ["sparkles", "shine", "lung linh"]),
        .init(emoji: "🎉", keywords: ["party", "celebrate", "chuc mung"]),
        .init(emoji: "👍", keywords: ["thumbs up", "like", "ok"]),
        .init(emoji: "👎", keywords: ["thumbs down", "dislike", "khong"]),
        .init(emoji: "🙏", keywords: ["pray", "thanks", "cam on"]),
        .init(emoji: "💪", keywords: ["strong", "muscle", "manh"]),
        .init(emoji: "😴", keywords: ["sleep", "tired", "ngu"]),
        .init(emoji: "🤔", keywords: ["thinking", "hmm", "nghi"]),
        .init(emoji: "😬", keywords: ["awkward", "grimace", "ngai"]),
        .init(emoji: "🥳", keywords: ["party", "birthday", "an mung"]),
        .init(emoji: "🤯", keywords: ["mind blown", "shock", "soc"]),
        .init(emoji: "😱", keywords: ["scream", "fear", "so"]),
        .init(emoji: "💀", keywords: ["dead", "skull", "hai huoc"]),
        .init(emoji: "🫶", keywords: ["heart hands", "love", "tim tay"]),
        .init(emoji: "😀", keywords: ["grinning", "smile", "happy", "cuoi"]),
        .init(emoji: "😁", keywords: ["beaming", "smile", "happy", "rang ro"]),
        .init(emoji: "😅", keywords: ["sweat smile", "relief", "hehe", "toat mo hoi"]),
        .init(emoji: "😉", keywords: ["wink", "nhay mat"]),
        .init(emoji: "🙃", keywords: ["upside down", "playful", "lon nguoc"]),
        .init(emoji: "😋", keywords: ["yummy", "delicious", "ngon"]),
        .init(emoji: "😜", keywords: ["playful", "tongue", "dua", "treu"]),
        .init(emoji: "🥺", keywords: ["pleading", "cute", "xin xo", "nai ni"]),
        .init(emoji: "😇", keywords: ["angel", "halo", "thien than"]),
        .init(emoji: "🤗", keywords: ["hug", "om"]),
        .init(emoji: "🫡", keywords: ["salute", "chao"]),
        .init(emoji: "🤭", keywords: ["giggle", "oops", "cuoi che mieng"]),
        .init(emoji: "🫠", keywords: ["melting", "tan chay"]),
        .init(emoji: "🥲", keywords: ["tear smile", "cam dong", "vua cuoi vua khoc"]),
        .init(emoji: "😤", keywords: ["triumph", "huff", "phan khich", "tuc"]),
        .init(emoji: "🥱", keywords: ["yawn", "sleepy", "ngap"]),
        .init(emoji: "🤐", keywords: ["zipper mouth", "secret", "im lang"]),
        .init(emoji: "🥴", keywords: ["woozy", "dizzy", "xay xam"]),
        .init(emoji: "🤢", keywords: ["sick", "nausea", "buon non"]),
        .init(emoji: "🤮", keywords: ["vomit", "oi"]),
        .init(emoji: "🤒", keywords: ["sick", "thermometer", "om"]),
        .init(emoji: "🤕", keywords: ["bandage", "injured", "bi thuong"]),
        .init(emoji: "🥵", keywords: ["hot face", "nong"]),
        .init(emoji: "🥶", keywords: ["cold face", "lanh"]),
        .init(emoji: "😈", keywords: ["devil", "evil", "quy"]),
        .init(emoji: "👻", keywords: ["ghost", "ma"]),
        .init(emoji: "🤡", keywords: ["clown", "he"]),
        .init(emoji: "💩", keywords: ["poop", "shit", "phan"]),
        .init(emoji: "🙈", keywords: ["see no evil", "monkey", "che mat"]),
        .init(emoji: "🙉", keywords: ["hear no evil", "monkey", "che tai"]),
        .init(emoji: "🙊", keywords: ["speak no evil", "monkey", "che mieng"]),
        .init(emoji: "👋", keywords: ["wave", "hello", "xin chao"]),
        .init(emoji: "🤝", keywords: ["handshake", "deal", "bat tay"]),
        .init(emoji: "👌", keywords: ["ok hand", "ok"]),
        .init(emoji: "✌️", keywords: ["peace", "victory", "hoa binh"]),
        .init(emoji: "🤞", keywords: ["crossed fingers", "hope", "may man"]),
        .init(emoji: "🤟", keywords: ["love you", "rock", "yeu"]),
        .init(emoji: "🫰", keywords: ["finger heart", "heart", "tim"]),
        .init(emoji: "👈", keywords: ["point left", "trai"]),
        .init(emoji: "👉", keywords: ["point right", "phai"]),
        .init(emoji: "👆", keywords: ["point up", "len"]),
        .init(emoji: "👇", keywords: ["point down", "xuong"]),
        .init(emoji: "💅", keywords: ["nail polish", "slay", "son mong"]),
        .init(emoji: "🫵", keywords: ["point at you", "ban"]),
        .init(emoji: "🤲", keywords: ["palms up", "offer", "ban tay"]),
        .init(emoji: "🙋", keywords: ["raise hand", "gio tay"]),
        .init(emoji: "🙆", keywords: ["ok gesture", "dong y"]),
        .init(emoji: "🙅", keywords: ["no gesture", "khong"]),
        .init(emoji: "💃", keywords: ["dance", "nhay"]),
        .init(emoji: "🕺", keywords: ["man dance", "nhay"]),
        .init(emoji: "🏃", keywords: ["run", "chay"]),
        .init(emoji: "🚶", keywords: ["walk", "di bo"]),
        .init(emoji: "🧎", keywords: ["kneel", "quy"]),
        .init(emoji: "🎈", keywords: ["balloon", "bong bay"]),
        .init(emoji: "🎁", keywords: ["gift", "present", "qua tang"]),
        .init(emoji: "🪩", keywords: ["disco ball", "party", "vu truong"]),
        .init(emoji: "🎊", keywords: ["confetti", "celebrate", "chuc mung"]),
        .init(emoji: "🏆", keywords: ["trophy", "cup", "giai"]),
        .init(emoji: "🥇", keywords: ["gold medal", "first", "huy chuong vang"]),
        .init(emoji: "🌈", keywords: ["rainbow", "cau vong"]),
        .init(emoji: "☀️", keywords: ["sun", "nang", "mat troi"]),
        .init(emoji: "⛅", keywords: ["cloud sun", "weather", "may"]),
        .init(emoji: "🌧️", keywords: ["rain", "mua"]),
        .init(emoji: "⛈️", keywords: ["storm", "bao", "sam set"]),
        .init(emoji: "❄️", keywords: ["snow", "tuyet"]),
        .init(emoji: "☕", keywords: ["coffee", "ca phe"]),
        .init(emoji: "🍵", keywords: ["tea", "tra"]),
        .init(emoji: "🍕", keywords: ["pizza"]),
        .init(emoji: "🍔", keywords: ["burger", "hamburger"]),
        .init(emoji: "🍟", keywords: ["fries", "khoai tay chien"]),
        .init(emoji: "🍜", keywords: ["noodles", "mi"]),
        .init(emoji: "🍣", keywords: ["sushi"]),
        .init(emoji: "🍩", keywords: ["donut", "banh"]),
        .init(emoji: "🍪", keywords: ["cookie", "banh quy"]),
        .init(emoji: "🍰", keywords: ["cake", "banh ngot"]),
        .init(emoji: "🎂", keywords: ["birthday cake", "sinh nhat"]),
        .init(emoji: "🍓", keywords: ["strawberry", "dau tay"]),
        .init(emoji: "🍉", keywords: ["watermelon", "dua hau"]),
        .init(emoji: "🍇", keywords: ["grapes", "nho"]),
        .init(emoji: "🍎", keywords: ["apple", "tao"]),
        .init(emoji: "🥑", keywords: ["avocado", "bo"]),
        .init(emoji: "🌶️", keywords: ["chili", "spicy", "ot"]),
        .init(emoji: "🍀", keywords: ["clover", "luck", "co 4 la"]),
        .init(emoji: "🌹", keywords: ["rose", "hoa hong"]),
        .init(emoji: "🌻", keywords: ["sunflower", "hoa huong duong"]),
        .init(emoji: "🌴", keywords: ["palm tree", "dua", "cay"]),
        .init(emoji: "🐶", keywords: ["dog", "cho"]),
        .init(emoji: "🐱", keywords: ["cat", "meo"]),
        .init(emoji: "🐼", keywords: ["panda", "gau truc"]),
        .init(emoji: "🦄", keywords: ["unicorn", "ky lan"]),
        .init(emoji: "🐸", keywords: ["frog", "ech"]),
        .init(emoji: "🐥", keywords: ["chick", "ga con"]),
        .init(emoji: "🦋", keywords: ["butterfly", "buom"]),
        .init(emoji: "🐝", keywords: ["bee", "ong"]),
        .init(emoji: "🚀", keywords: ["rocket", "ten lua"]),
        .init(emoji: "🎮", keywords: ["game", "gaming", "choi game"]),
        .init(emoji: "🎧", keywords: ["headphones", "music", "tai nghe"]),
        .init(emoji: "📸", keywords: ["camera", "photo", "chup anh"]),
        .init(emoji: "💡", keywords: ["idea", "light", "y tuong"]),
        .init(emoji: "📚", keywords: ["books", "study", "sach"]),
        .init(emoji: "😃", keywords: ["smile", "happy", "cuoi", "vui"]),
        .init(emoji: "😄", keywords: ["big smile", "happy", "cuoi"]),
        .init(emoji: "🙂", keywords: ["slight smile", "smile", "mim cuoi"]),
        .init(emoji: "😌", keywords: ["relieved", "calm", "nhe nhom"]),
        .init(emoji: "😏", keywords: ["smirk", "tease", "nhech"]),
        .init(emoji: "😔", keywords: ["sad", "thinking", "buon"]),
        .init(emoji: "😞", keywords: ["disappointed", "buon", "that vong"]),
        .init(emoji: "😟", keywords: ["worried", "lo lang"]),
        .init(emoji: "😕", keywords: ["confused", "boi roi"]),
        .init(emoji: "🫤", keywords: ["meh", "unsure", "chan"]),
        .init(emoji: "😳", keywords: ["flushed", "embarrassed", "ngai"]),
        .init(emoji: "🥹", keywords: ["teary eyes", "emotional", "xuc dong"]),
        .init(emoji: "🤠", keywords: ["cowboy", "cao boi", "ngau"]),
        .init(emoji: "🥸", keywords: ["disguise", "fake moustache", "cai trang"]),
        .init(emoji: "😶‍🌫️", keywords: ["face in clouds", "lost", "mo ho"]),
        .init(emoji: "🐰", keywords: ["rabbit", "tho"]),
        .init(emoji: "🦊", keywords: ["fox", "cao"]),
        .init(emoji: "🐻", keywords: ["bear", "gau"]),
        .init(emoji: "🐨", keywords: ["koala"]),
        .init(emoji: "🐯", keywords: ["tiger", "ho"]),
        .init(emoji: "🦁", keywords: ["lion", "su tu"]),
        .init(emoji: "🐮", keywords: ["cow", "bo"]),
        .init(emoji: "🐷", keywords: ["pig", "heo"]),
        .init(emoji: "🐵", keywords: ["monkey", "khi"]),
        .init(emoji: "🐔", keywords: ["chicken", "ga"]),
        .init(emoji: "🐧", keywords: ["penguin"]),
        .init(emoji: "🐢", keywords: ["turtle", "rua"]),
        .init(emoji: "🐙", keywords: ["octopus", "bach tuoc"]),
        .init(emoji: "🦀", keywords: ["crab", "cua"]),
        .init(emoji: "🐳", keywords: ["whale", "ca voi"]),
        .init(emoji: "📱", keywords: ["phone", "mobile", "dien thoai"]),
        .init(emoji: "💻", keywords: ["laptop", "computer", "may tinh"]),
        .init(emoji: "⌚", keywords: ["watch", "dong ho"]),
        .init(emoji: "🎥", keywords: ["movie", "video", "quay phim"]),
        .init(emoji: "📷", keywords: ["camera", "may anh"]),
        .init(emoji: "🎤", keywords: ["microphone", "sing", "hat"]),
        .init(emoji: "🎹", keywords: ["piano", "keyboard"]),
        .init(emoji: "🎸", keywords: ["guitar"]),
        .init(emoji: "🥁", keywords: ["drum", "trong"]),
        .init(emoji: "🎨", keywords: ["art", "paint", "ve"]),
        .init(emoji: "🧩", keywords: ["puzzle", "ghep hinh"]),
        .init(emoji: "♟️", keywords: ["chess", "co vua"]),
        .init(emoji: "🛒", keywords: ["cart", "shopping", "gio hang"]),
        .init(emoji: "🔒", keywords: ["lock", "khoa"]),
        .init(emoji: "🔑", keywords: ["key", "chia khoa"]),
        .init(emoji: "🧸", keywords: ["teddy", "gau bong"]),
        .init(emoji: "🍿", keywords: ["popcorn"]),
        .init(emoji: "🍫", keywords: ["chocolate", "socola"]),
        .init(emoji: "🍬", keywords: ["candy", "keo"]),
        .init(emoji: "🍭", keywords: ["lollipop", "keo mut"]),
        .init(emoji: "🥨", keywords: ["pretzel", "banh xoan"]),
        .init(emoji: "🧀", keywords: ["cheese", "pho mai"]),
        .init(emoji: "🍞", keywords: ["bread", "banh mi"]),
        .init(emoji: "🥐", keywords: ["croissant"]),
        .init(emoji: "🥞", keywords: ["pancakes", "banh pancake"]),
        .init(emoji: "🥓", keywords: ["bacon", "thit xong khoi"]),
        .init(emoji: "🍗", keywords: ["chicken leg", "dui ga"]),
        .init(emoji: "🌮", keywords: ["taco"]),
        .init(emoji: "🌯", keywords: ["burrito"]),
        .init(emoji: "🍦", keywords: ["ice cream", "kem"]),
        .init(emoji: "🥤", keywords: ["drink", "nuoc ngot"]),
        .init(emoji: "🧋", keywords: ["bubble tea", "tra sua"]),
        .init(emoji: "🍺", keywords: ["beer", "bia"]),
        .init(emoji: "🥂", keywords: ["cheers", "champagne", "chuc mung"]),
        .init(emoji: "🌙", keywords: ["moon", "trang"]),
        .init(emoji: "⭐", keywords: ["star", "sao"]),
        .init(emoji: "🌟", keywords: ["glowing star", "bright", "toa sang"]),
        .init(emoji: "🌺", keywords: ["hibiscus", "hoa"]),
        .init(emoji: "🌼", keywords: ["blossom", "hoa"]),
        .init(emoji: "🍁", keywords: ["maple leaf", "la phong"]),
        .init(emoji: "🌊", keywords: ["wave", "sea", "song bien"]),
        .init(emoji: "⚽", keywords: ["football", "soccer", "bong da"]),
        .init(emoji: "🏀", keywords: ["basketball", "bong ro"]),
        .init(emoji: "🏈", keywords: ["american football"]),
        .init(emoji: "⚾", keywords: ["baseball"]),
        .init(emoji: "🎾", keywords: ["tennis"]),
        .init(emoji: "🏐", keywords: ["volleyball", "bong chuyen"]),
        .init(emoji: "🏓", keywords: ["ping pong", "bong ban"]),
        .init(emoji: "🥊", keywords: ["boxing", "dam boc"]),
        .init(emoji: "🏋️", keywords: ["weightlifting", "tap ta"]),
        .init(emoji: "🚗", keywords: ["car", "xe hoi"]),
        .init(emoji: "🚕", keywords: ["taxi"]),
        .init(emoji: "🚌", keywords: ["bus", "xe buyt"]),
        .init(emoji: "🚲", keywords: ["bike", "xe dap"]),
        .init(emoji: "✈️", keywords: ["plane", "may bay"]),
        .init(emoji: "🚤", keywords: ["speedboat", "cano"]),
        .init(emoji: "🗺️", keywords: ["map", "ban do"]),
        .init(emoji: "🏝️", keywords: ["island", "dao"]),
        .init(emoji: "🏕️", keywords: ["camping", "cam trai"]),
        .init(emoji: "🏰", keywords: ["castle", "lau dai"]),
        .init(emoji: "✅", keywords: ["check", "done", "hoan tat"]),
        .init(emoji: "❌", keywords: ["cross", "wrong", "sai"]),
        .init(emoji: "⚠️", keywords: ["warning", "canh bao"]),
        .init(emoji: "❓", keywords: ["question", "hoi"]),
        .init(emoji: "❗", keywords: ["exclamation", "alert"]),
        .init(emoji: "💬", keywords: ["chat", "comment", "tin nhan"]),
        .init(emoji: "💤", keywords: ["sleep", "zzz", "buon ngu"]),
        .init(emoji: "🛎️", keywords: ["bell", "service", "chuong"]),
        .init(emoji: "🧠", keywords: ["brain", "smart", "nao"]),
        .init(emoji: "🎯", keywords: ["target", "goal", "muc tieu"]),
    ]

    private var myEmojis: [CustomEmoji] {
        currentUserId.map { emojiStore.emojis(ownedBy: $0) } ?? []
    }

    private var allEmojiEntries: [AllEmojiEntry] {
        myEmojis.map(AllEmojiEntry.custom) + Self.emojiCatalog.map(AllEmojiEntry.system)
    }

    private var normalizedSearchQuery: String {
        normalizedSearchText(searchQuery)
    }

    private var filteredAllEmojiEntries: [AllEmojiEntry] {
        guard !normalizedSearchQuery.isEmpty else { return allEmojiEntries }
        return allEmojiEntries.filter(matchesSearch(_:))
    }

    private var filteredMyEmojis: [CustomEmoji] {
        guard !normalizedSearchQuery.isEmpty else { return myEmojis }
        return myEmojis.filter { emoji in
            searchableText(for: emoji.shortcode).contains(normalizedSearchQuery)
                || searchableText(for: emoji.colonCode).contains(normalizedSearchQuery)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SplickTheme.Spacing.lg) {
                    if mode == .reaction {
                        quickBarSection
                    }
                    tabPicker
                    switch selectedTab {
                    case .unicode:
                        emojiGridSection
                    case .custom:
                        customEmojiSection
                    }
                }
                .padding(.horizontal, SplickTheme.Spacing.md)
                .padding(.vertical, SplickTheme.Spacing.md)
            }
            .background(SplickTheme.Colors.background)
            .navigationTitle(languageService.text(.feedEmojiPickerTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(languageService.text(.commonCancel)) { dismiss() }
                }
                if mode == .inlineInsert {
                    ToolbarItem(placement: .primaryAction) {
                        uploadPickerButton(style: .iconOnly)
                    }
                }
            }
            .onAppear {
                if mode == .reaction {
                    draftQuickEmojis = preferences.quickEmojis
                }
            }
            .onChange(of: selectedUploadPhotoItem) { item in
                guard item != nil else { return }
                Task { await prepareUploadImage(from: item) }
            }
            .alert(
                languageService.text(.commonError),
                isPresented: Binding(
                    get: { uploadPreparationError != nil },
                    set: { if !$0 { uploadPreparationError = nil } }
                )
            ) {
                Button(languageService.text(.commonOK), role: .cancel) { uploadPreparationError = nil }
            } message: {
                Text(uploadPreparationError ?? "")
            }
        }
        .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Tìm emoji")
        .presentationDetents([.medium, .large])
        .sheet(isPresented: $showEmojiComposer, onDismiss: {
            uploadSourceImage = nil
        }) {
            if let uploadSourceImage, let customEmojiDependencies {
                CustomEmojiComposerSheet(
                    sourceImage: uploadSourceImage,
                    uploadMediaUseCase: customEmojiDependencies.uploadMediaUseCase,
                    addEmojiUseCase: customEmojiDependencies.addEmojiUseCase,
                    onUploaded: { _ in
                        selectedTab = .custom
                    }
                )
            }
        }
    }

    private var tabPicker: some View {
        Picker("Emoji source", selection: $selectedTab) {
            Text(languageService.text(.feedEmojiPickerAllTitle)).tag(EmojiPickerTab.unicode)
                        Text("Emoji của bạn").tag(EmojiPickerTab.custom)
        }
        .pickerStyle(.segmented)
    }

    private var quickBarSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            HStack(alignment: .center, spacing: SplickTheme.Spacing.sm) {
                Text(languageService.text(.feedEmojiPickerQuickBarTitle))
                    .font(SplickTheme.Typography.headline)
                    .foregroundStyle(SplickTheme.Colors.textPrimary)
                Spacer()
                uploadPickerButton(style: .textOnly)
            }

            Text(languageService.text(.feedEmojiPickerQuickBarHint))
                .font(SplickTheme.Typography.caption)
                .foregroundStyle(SplickTheme.Colors.textSecondary)

            HStack(spacing: 6) {
                ForEach(0..<QuickReactionPreferences.slotCount, id: \.self) { index in
                    quickSlotButton(at: index)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func quickSlotButton(at index: Int) -> some View {
        let isSelected = selectedSlot == index
        return Button {
            selectedSlot = isSelected ? nil : index
        } label: {
            EmojiView(value: draftQuickEmojis[index], size: 26)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(
                            isSelected
                                ? SplickTheme.Colors.primaryGradientStart.opacity(0.18)
                                : SplickTheme.Colors.secondaryBackground
                        )
                )
                .overlay {
                    Circle()
                        .stroke(
                            isSelected
                                ? SplickTheme.Colors.primaryGradientStart
                                : SplickTheme.Colors.divider.opacity(0.35),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private var emojiGridSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            if filteredAllEmojiEntries.isEmpty {
                emptySearchState
            } else {
                LazyVGrid(columns: unicodeColumns, spacing: 10) {
                    ForEach(filteredAllEmojiEntries) { entry in
                        allEmojiButton(for: entry)
                    }
                }
            }
        }
    }

    private var customEmojiSection: some View {
        VStack(alignment: .leading, spacing: SplickTheme.Spacing.sm) {
            if myEmojis.isEmpty {
                Text(languageService.text(.feedCustomEmojiEmpty))
                    .font(SplickTheme.Typography.caption)
                    .foregroundStyle(SplickTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if filteredMyEmojis.isEmpty {
                emptySearchState
            } else {
                LazyVGrid(columns: customColumns, spacing: 10) {
                    ForEach(filteredMyEmojis) { emoji in
                        Button {
                            handleEmojiTap(emoji.colonCode)
                        } label: {
                            EmojiView(value: emoji.colonCode, size: 36)
                                .frame(height: 40)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(SplickTheme.Colors.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func allEmojiButton(for entry: AllEmojiEntry) -> some View {
        switch entry {
        case .custom(let emoji):
            Button {
                handleEmojiTap(emoji.colonCode)
            } label: {
                EmojiView(value: emoji.colonCode, size: 28)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        case .system(let emoji):
            Button {
                handleEmojiTap(emoji.emoji)
            } label: {
                Text(emoji.emoji)
                    .font(.system(size: 28))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(SplickTheme.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptySearchState: some View {
        Text("Không tìm thấy emoji phù hợp.")
            .font(SplickTheme.Typography.caption)
            .foregroundStyle(SplickTheme.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleEmojiTap(_ emoji: String) {
        if mode == .reaction, let slot = selectedSlot {
            var updatedQuickEmojis = draftQuickEmojis
            updatedQuickEmojis[slot] = emoji
            draftQuickEmojis = updatedQuickEmojis
            preferences.saveQuickEmojis(updatedQuickEmojis)
            selectedSlot = nil
            return
        }

        dismiss()

        // Dismiss first so the sheet animation stays responsive before mutating the feed.
        DispatchQueue.main.async {
            onPick(emoji)
        }
    }

    @ViewBuilder
    private func uploadPickerButton(style: UploadPickerButtonStyle) -> some View {
        PhotosPicker(selection: $selectedUploadPhotoItem, matching: .images) {
            if style == .iconOnly {
                if isPreparingUpload {
                    ProgressView()
                } else {
                    Image(systemName: "plus.circle")
                }
            } else {
                Group {
                    if isPreparingUpload {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Thêm Emoji")
                            .font(SplickTheme.Typography.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(SplickTheme.Colors.primaryGradientStart)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(SplickTheme.Colors.primaryGradientStart.opacity(0.10))
                .clipShape(Capsule())
            }
        }
        .disabled(isPreparingUpload || customEmojiDependencies == nil)
    }

    @MainActor
    private func prepareUploadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard customEmojiDependencies != nil else {
            uploadPreparationError = "Tính năng tải emoji hiện chưa sẵn sàng."
            selectedUploadPhotoItem = nil
            return
        }
        isPreparingUpload = true
        defer {
            isPreparingUpload = false
            selectedUploadPhotoItem = nil
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            uploadPreparationError = "Không thể mở ảnh đã chọn."
            return
        }

        uploadSourceImage = image
        showEmojiComposer = true
    }

    private func matchesSearch(_ entry: AllEmojiEntry) -> Bool {
        switch entry {
        case .custom(let emoji):
            return searchableText(for: emoji.shortcode).contains(normalizedSearchQuery)
                || searchableText(for: emoji.colonCode).contains(normalizedSearchQuery)
        case .system(let emoji):
            if searchableText(for: emoji.emoji).contains(normalizedSearchQuery) {
                return true
            }
            return emoji.keywords.contains { keyword in
                searchableText(for: keyword).contains(normalizedSearchQuery)
            }
        }
    }

    private func searchableText(for value: String) -> String {
        normalizedSearchText(value)
    }

    private func normalizedSearchText(_ value: String) -> String {
        let folded = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()

        return String(
            folded.unicodeScalars.filter { scalar in
                CharacterSet.alphanumerics.contains(scalar)
            }
        )
    }
}

private enum UploadPickerButtonStyle {
    case iconOnly
    case textOnly
}
