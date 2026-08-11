import SwiftUI
import PhotosUI
import AVFoundation
import Vision
import VisionKit

struct AddEditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("didOfferNotificationPermission") private var didOfferNotificationPermission = false

    @StateObject private var viewModel: AddEditFoodViewModel

    // Photo picker
    @State private var showPhotoOptions = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showReminderPermissionPrompt = false
    @State private var templates: [FoodTemplate] = []
    @State private var isExpirationCustomized = false
    @State private var showScanner = false
    private let onSaved: (() -> Void)?

    init(
        item: FoodItem? = nil,
        prefill: FoodFormDraft? = nil,
        onSaved: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: AddEditFoodViewModel(item: item, prefill: prefill)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                if !viewModel.isEditing && !templates.isEmpty {
                    templatesSection
                }
                basicInfoSection
                storageSection
                quantitySection
                datesSection
                notesSection
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(viewModel.isEditing ? "nav.editFood" : "nav.addFood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("button.save") { save() }
                        .fontWeight(.semibold)
                        .disabled(viewModel.isSaving)
                }
            }
            .alert("alert.errorTitle", isPresented: Binding(
                get: { viewModel.saveError != nil },
                set: { if !$0 { viewModel.saveError = nil } }
            )) {
                Button("button.ok") { viewModel.saveError = nil }
            } message: {
                Text(viewModel.saveError ?? "")
            }
            .confirmationDialog("photo.sourceTitle", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                Button("photo.camera") { requestCameraAccess() }
                Button("photo.library") { showPhotoPicker = true }
                if viewModel.selectedImage != nil {
                    Button("photo.remove", role: .destructive) { removePhoto() }
                }
                Button("button.cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "reminder.permissionTitle",
                isPresented: $showReminderPermissionPrompt,
                titleVisibility: .visible
            ) {
                Button("reminder.enable") {
                    didOfferNotificationPermission = true
                    Task {
                        let granted = await NotificationService.shared.requestAuthorization()
                        if granted {
                            NotificationService.shared.refreshSchedule(
                                using: FoodRepository(context: modelContext)
                            )
                        }
                        dismiss()
                    }
                }
                Button("reminder.notNow", role: .cancel) {
                    didOfferNotificationPermission = true
                    dismiss()
                }
            } message: {
                Text("reminder.permissionMessage")
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $viewModel.selectedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if let image = viewModel.selectedImage {
                            viewModel.setImage(image)
                        }
                    }
            }
            .fullScreenCover(isPresented: $showScanner) {
                FoodScannerSheet { result in
                    applyScanResult(result)
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    do {
                        guard let data = try await newItem?.loadTransferable(type: Data.self),
                              let uiImage = UIImage(data: data) else {
                            if newItem != nil {
                                viewModel.saveError = NSLocalizedString("error.photoLoad", comment: "")
                            }
                            return
                        }
                        viewModel.setImage(uiImage)
                    } catch {
                        viewModel.saveError = error.localizedDescription
                    }
                }
            }
            .onAppear(perform: loadTemplates)
            .onChange(of: viewModel.unit) { _, _ in
                viewModel.quantity = max(viewModel.quantity, selectedUnit.minimumQuantity)
            }
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        Section {
            HStack {
                Spacer()
                Button {
                    showPhotoOptions = true
                } label: {
                    if let img = viewModel.selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundStyle(.white, .blue)
                                    .padding(4)
                            }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("photo.addPhoto")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 120, height: 120)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous))
                    }
                }
                .accessibilityLabel("button.addPhoto")
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))

            Button(action: openScanner) {
                Label("scanner.scanFood", systemImage: "barcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .accessibilityHint("scanner.scanFoodHint")
        } header: {
            Text("photo.addPhoto")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    private var basicInfoSection: some View {
        Section {
            VStack(alignment: .leading) {
                TextField("field.name", text: $viewModel.name)
                    .autocorrectionDisabled()
                    .accessibilityLabel("field.name")
                if let err = viewModel.nameError {
                    Text(err).font(.footnote).foregroundStyle(Color(uiColor: .systemRed))
                }
            }

            Picker("field.category", selection: categoryBinding) {
                ForEach(FoodCategory.allCases) { cat in
                    Label(cat.localizedName, systemImage: "tag")
                        .tag(cat)
                }
            }

            if !viewModel.barcode.isEmpty {
                LabeledContent("field.barcode", value: viewModel.barcode)
                    .textSelection(.enabled)
            }
        } header: {
            Text("section.basicInfo")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    private var storageSection: some View {
        Section {
            Picker("field.location", selection: $viewModel.storageLocation) {
                ForEach(StorageLocation.allCases) { loc in
                    Text("\(loc.emoji)  \(loc.localizedName)").tag(loc)
                }
            }
        } header: {
            Text("section.storage")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    private var quantitySection: some View {
        Section {
            VStack(alignment: .leading) {
                HStack {
                    Text("field.quantity")
                    Spacer()
                    Stepper(value: $viewModel.quantity, in: quantityRange, step: quantityStep) {
                        Text(viewModel.quantity.formatted())
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
                if let err = viewModel.quantityError {
                    Text(err).font(.footnote).foregroundStyle(Color(uiColor: .systemRed))
                }
            }

            Picker("field.unit", selection: $viewModel.unit) {
                ForEach(FoodUnit.allCases) { unit in
                    Text(unit.localizedName).tag(unit.rawValue)
                }
            }
        } header: {
            Text("section.quantity")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    private var datesSection: some View {
        Section {
            DatePicker("field.purchaseDate", selection: $viewModel.purchaseDate, displayedComponents: .date)
            Toggle("field.hasExpiration", isOn: $viewModel.hasExpirationDate)
            if viewModel.hasExpirationDate {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.small) {
                        ForEach([3, 7, 14, 30], id: \.self) { days in
                            Button(
                                String(
                                    format: NSLocalizedString("expiration.quickDaysFormat", comment: ""),
                                    days
                                )
                            ) {
                                setExpirationDate(daysFromToday: days)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                DatePicker(
                    "field.expirationDate",
                    selection: expirationDateBinding,
                    displayedComponents: .date
                )
            }
        } header: {
            Text("section.dates")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    private var notesSection: some View {
        Section {
            TextField("field.notes", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
        } header: {
            Text("section.notes")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        }
    }

    // MARK: - Helpers

    private func save() {
        do {
            if try viewModel.save(to: FoodRepository(context: modelContext)) {
                onSaved?()
                offerReminderPermissionIfNeeded()
            }
        } catch {
            viewModel.saveError = error.localizedDescription
        }
    }

    private func offerReminderPermissionIfNeeded() {
        guard viewModel.hasExpirationDate, !didOfferNotificationPermission else {
            dismiss()
            return
        }

        Task {
            let status = await NotificationService.shared.authorizationStatus()
            if status == .notDetermined {
                showReminderPermissionPrompt = true
            } else {
                dismiss()
            }
        }
    }

    private func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            showCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { showCamera = true }
                }
            }
        default:
            viewModel.saveError = NSLocalizedString("error.cameraPermission", comment: "")
        }
    }

    private func openScanner() {
                    guard DataScannerViewController.isSupported,
                          DataScannerViewController.isAvailable else {
                        viewModel.saveError = NSLocalizedString("scanner.unavailable", comment: "")
                        return
                    }

                    switch AVCaptureDevice.authorizationStatus(for: .video) {
                    case .authorized:
                        showScanner = true
                    case .notDetermined:
                        AVCaptureDevice.requestAccess(for: .video) { granted in
                            DispatchQueue.main.async {
                                if granted {
                                    showScanner = true
                                } else {
                                    viewModel.saveError = NSLocalizedString("error.cameraPermission", comment: "")
                                }
                            }
                        }
                    default:
                        viewModel.saveError = NSLocalizedString("error.cameraPermission", comment: "")
                    }
    }

    private func applyScanResult(_ result: FoodScanResult) {
                    let parsed = FoodScanParser.parse(result)
                    var reusedKnownFood = false

                    if let barcode = parsed.barcode {
                        do {
                            if !viewModel.isEditing {
                                if let existing = try FoodRepository(context: modelContext)
                                    .fetchAll()
                                    .first(where: { $0.barcode == barcode }) {
                                    viewModel.apply(FoodFormDraft(reusing: existing))
                                    reusedKnownFood = true
                                } else if let record = try FoodRepository(context: modelContext)
                                    .fetchHistory()
                                    .first(where: { $0.barcode == barcode }) {
                                    viewModel.apply(FoodFormDraft(historyRecord: record))
                                    reusedKnownFood = true
                                }
                            }
                            viewModel.barcode = barcode
                        } catch {
                            viewModel.saveError = error.localizedDescription
                            return
                        }
                    }

                    if !reusedKnownFood,
                       viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       let name = parsed.suggestedName {
                        viewModel.name = name
                    }
                    if let expirationDate = parsed.expirationDate {
                        viewModel.expirationDate = expirationDate
                        viewModel.hasExpirationDate = true
                        isExpirationCustomized = true
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
    }

    struct FoodScanResult: Equatable {
                var barcode: String?
                var textLines: [String] = []

                var hasContent: Bool {
                    barcode != nil || !textLines.isEmpty
                }
            }

            struct ParsedFoodScan: Equatable {
                let barcode: String?
                let suggestedName: String?
                let expirationDate: Date?
            }

            enum FoodScanParser {
                private static let datePatterns: [(pattern: String, format: String)] = [
                    (#"\b20\d{2}[-/.]\d{1,2}[-/.]\d{1,2}\b"#, "yyyy-MM-dd"),
                    (#"20\d{2}年\d{1,2}月\d{1,2}日"#, "yyyy年M月d日"),
                    (#"\b\d{1,2}[-/.]\d{1,2}[-/.]20\d{2}\b"#, "MM-dd-yyyy"),
                    (#"\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2}\b"#, "MM-dd-yy")
                ]

                static func parse(_ result: FoodScanResult) -> ParsedFoodScan {
                    ParsedFoodScan(
                        barcode: result.barcode,
                        suggestedName: suggestedName(from: result.textLines),
                        expirationDate: expirationDate(from: result.textLines)
                    )
                }

                private static func suggestedName(from lines: [String]) -> String? {
                    let excludedTerms = [
                        "exp", "best before", "use by", "sell by", "lot", "barcode",
                        "到期", "有效期", "保质期", "生产日期"
                    ]

                    return lines.lazy
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .first {
                            guard (2...60).contains($0.count),
                                  $0.rangeOfCharacter(from: .letters) != nil else { return false }
                            let lowercased = $0.lowercased()
                            return !excludedTerms.contains { lowercased.contains($0) }
                        }
                }

                private static func expirationDate(from lines: [String]) -> Date? {
                    let today = Calendar.current.startOfDay(for: Date())
                    var candidates: [(date: Date, priority: Int)] = []

                    for line in lines {
                        let lowercased = line.lowercased()
                        let isExpirationLine = [
                            "exp", "best before", "use by", "到期", "有效期", "保质期"
                        ].contains { lowercased.contains($0) }

                        for datePattern in datePatterns {
                            guard let range = line.range(
                                of: datePattern.pattern,
                                options: .regularExpression
                            ) else { continue }

                            let rawDate = String(line[range])
                                .replacingOccurrences(of: "/", with: "-")
                                .replacingOccurrences(of: ".", with: "-")
                            let formatter = DateFormatter()
                            formatter.calendar = Calendar(identifier: .gregorian)
                            formatter.locale = Locale(identifier: "en_US_POSIX")
                            formatter.timeZone = .current
                            formatter.dateFormat = datePattern.format
                            formatter.isLenient = false

                            if let date = formatter.date(from: rawDate),
                               isExpirationLine ||
                               Calendar.current.startOfDay(for: date) >= today {
                                candidates.append((date, isExpirationLine ? 1 : 0))
                            }
                        }
                    }

                    return candidates.sorted {
                        if $0.priority != $1.priority {
                            return $0.priority > $1.priority
                        }
                        return $0.date < $1.date
                    }.first?.date
                }
            }

            private struct FoodScannerSheet: View {
                @Environment(\.dismiss) private var dismiss
                @State private var result = FoodScanResult()
                @State private var scannerError: String?

                let onUse: (FoodScanResult) -> Void

                var body: some View {
                    NavigationStack {
                        ZStack(alignment: .bottom) {
                            FoodDataScanner(result: $result, errorMessage: $scannerError)
                                .ignoresSafeArea()

                            VStack(spacing: AppSpacing.medium) {
                                if let scannerError {
                                    Label(scannerError, systemImage: "exclamationmark.triangle.fill")
                                        .font(.footnote)
                                        .foregroundStyle(Color(uiColor: .systemRed))
                                } else {
                                    Label {
                                        Text(scanSummary)
                                    } icon: {
                                        Image(systemName: result.hasContent ? "checkmark.circle.fill" : "viewfinder")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                }

                                Button("scanner.useResult") {
                                    onUse(result)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .frame(maxWidth: .infinity)
                                .disabled(!result.hasContent)
                            }
                            .padding(AppSpacing.large)
                            .background(.regularMaterial, in: RoundedRectangle(
                                cornerRadius: AppCornerRadius.xLarge,
                                style: .continuous
                            ))
                            .padding(AppSpacing.large)
                        }
                        .navigationTitle("scanner.title")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("button.cancel") { dismiss() }
                            }
                        }
                    }
                }

                private var scanSummary: String {
                    if let barcode = result.barcode {
                        return String(
                            format: NSLocalizedString("scanner.barcodeFoundFormat", comment: ""),
                            barcode
                        )
                    }
                    if !result.textLines.isEmpty {
                        return NSLocalizedString("scanner.textFound", comment: "")
                    }
                    return NSLocalizedString("scanner.aimHint", comment: "")
                }
            }

            private struct FoodDataScanner: UIViewControllerRepresentable {
                @Binding var result: FoodScanResult
                @Binding var errorMessage: String?

                func makeCoordinator() -> Coordinator {
                    Coordinator(parent: self)
                }

                func makeUIViewController(context: Context) -> FoodScannerHostViewController {
                    let scanner = DataScannerViewController(
                        recognizedDataTypes: [
                            .text(languages: ["en-US", "zh-Hans"]),
                            .barcode(symbologies: [.ean8, .ean13, .upce, .code128, .qr])
                        ],
                        qualityLevel: .balanced,
                        recognizesMultipleItems: true,
                        isHighFrameRateTrackingEnabled: true,
                        isPinchToZoomEnabled: true,
                        isGuidanceEnabled: true,
                        isHighlightingEnabled: true
                    )
                    scanner.delegate = context.coordinator
                    let host = FoodScannerHostViewController(scanner: scanner)
                    host.onError = { message in
                        errorMessage = message
                    }
                    return host
                }

                func updateUIViewController(
                    _ uiViewController: FoodScannerHostViewController,
                    context: Context
                ) {
                    context.coordinator.parent = self
                }

                static func dismantleUIViewController(
                    _ uiViewController: FoodScannerHostViewController,
                    coordinator: Coordinator
                ) {
                    uiViewController.scanner.stopScanning()
                }

                final class Coordinator: NSObject, DataScannerViewControllerDelegate {
                    var parent: FoodDataScanner

                    init(parent: FoodDataScanner) {
                        self.parent = parent
                    }

                    func dataScanner(
                        _ dataScanner: DataScannerViewController,
                        didAdd addedItems: [RecognizedItem],
                        allItems: [RecognizedItem]
                    ) {
                        var updatedResult = parent.result
                        for item in addedItems {
                            switch item {
                            case .barcode(let barcode):
                                if let value = barcode.payloadStringValue, !value.isEmpty {
                                    updatedResult.barcode = value
                                }
                            case .text(let text):
                                let line = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !line.isEmpty, !updatedResult.textLines.contains(line) {
                                    updatedResult.textLines.append(line)
                                }
                            @unknown default:
                                continue
                            }
                        }
                        parent.result = updatedResult
                    }
                }
            }

            private final class FoodScannerHostViewController: UIViewController {
                let scanner: DataScannerViewController
                var onError: ((String) -> Void)?

                init(scanner: DataScannerViewController) {
                    self.scanner = scanner
                    super.init(nibName: nil, bundle: nil)
                }

                @available(*, unavailable)
                required init?(coder: NSCoder) {
                    fatalError("init(coder:) has not been implemented")
                }

                override func viewDidLoad() {
                    super.viewDidLoad()
                    addChild(scanner)
                    scanner.view.frame = view.bounds
                    scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    view.addSubview(scanner.view)
                    scanner.didMove(toParent: self)
                }

                override func viewDidAppear(_ animated: Bool) {
                    super.viewDidAppear(animated)
                    do {
                        try scanner.startScanning()
                    } catch {
                        onError?(error.localizedDescription)
                    }
                }
            }

    private func removePhoto() {
        viewModel.removeImage()
    }

    private var templatesSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.small) {
                    ForEach(templates) { template in
                        Button {
                            viewModel.apply(template.draft)
                            isExpirationCustomized = true
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            VStack(alignment: .leading, spacing: AppSpacing.xSmall) {
                                Text("\(template.draft.category.emoji) \(template.draft.name)")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(
                                    String(
                                        format: NSLocalizedString("template.useCountFormat", comment: ""),
                                        template.useCount
                                    )
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, AppSpacing.medium)
                            .padding(.vertical, AppSpacing.small)
                            .background(
                                Color.accentColor.opacity(0.1),
                                in: RoundedRectangle(
                                    cornerRadius: AppCornerRadius.medium,
                                    style: .continuous
                                )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("template.frequentFoods")
                .textCase(nil)
                .font(.footnote.weight(.semibold))
        } footer: {
            Text("template.frequentFoodsFooter")
        }
    }

    private var categoryBinding: Binding<FoodCategory> {
        Binding(
            get: { viewModel.category },
            set: { category in
                viewModel.category = category
                guard !viewModel.isEditing,
                      viewModel.hasExpirationDate,
                      !isExpirationCustomized else { return }
                setExpirationDate(
                    daysFromToday: category.defaultShelfLifeDays,
                    marksCustomized: false
                )
            }
        )
    }

    private var expirationDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.expirationDate },
            set: {
                viewModel.expirationDate = $0
                isExpirationCustomized = true
            }
        )
    }

    private func setExpirationDate(
        daysFromToday days: Int,
        marksCustomized: Bool = true
    ) {
        viewModel.expirationDate = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: Date()
        ) ?? Date()
        if marksCustomized {
            isExpirationCustomized = true
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func loadTemplates() {
        guard !viewModel.isEditing, templates.isEmpty else { return }
        do {
            let records = try FoodRepository(context: modelContext).fetchHistory()
            templates = FoodTemplateBuilder.templates(from: records)
        } catch {
            viewModel.saveError = error.localizedDescription
        }
    }

    private var quantityStep: Double {
        selectedUnit.quantityStep
    }

    private var quantityRange: ClosedRange<Double> {
        selectedUnit.minimumQuantity...9_999
    }

    private var selectedUnit: FoodUnit {
        FoodUnit(rawValue: viewModel.unit) ?? .item
    }
}

// MARK: - CameraView

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let edited = info[.editedImage] as? UIImage {
                parent.image = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.image = original
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    AddEditFoodView(item: nil)
        .modelContainer(PersistenceController.preview.container)
}
