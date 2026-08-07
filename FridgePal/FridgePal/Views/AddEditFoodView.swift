import SwiftUI
import PhotosUI
import AVFoundation

struct AddEditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("reminderDays") private var reminderDaysRaw: String = "1,3,7"

    let item: FoodItem?

    @State private var name: String = ""
    @State private var category: FoodCategory = .other
    @State private var storageLocation: StorageLocation = .fridge
    @State private var quantity: Double = 1
    @State private var unit: String = "item"
    @State private var purchaseDate: Date = Date()
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var hasExpirationDate: Bool = true
    @State private var notes: String = ""
    @State private var selectedImage: UIImage? = nil
    @State private var photoData: Data? = nil

    // Validation
    @State private var nameError: String? = nil
    @State private var quantityError: String? = nil

    // Photo picker
    @State private var showPhotoOptions = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    // Save state
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private var reminderDays: [Int] {
        reminderDaysRaw.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private let units = ["item", "box", "bag", "bottle", "g", "kg", "oz", "lb", "L", "mL", "pack", "can", "piece"]

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                basicInfoSection
                storageSection
                quantitySection
                datesSection
                notesSection
            }
            .navigationTitle(item == nil ? "nav.addFood" : "nav.editFood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("button.cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("button.save") { save() }
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                }
            }
            .alert("alert.errorTitle", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("button.ok") { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .onAppear { populateFields() }
            .confirmationDialog("photo.sourceTitle", isPresented: $showPhotoOptions, titleVisibility: .visible) {
                Button("photo.camera") { requestCameraAccess() }
                Button("photo.library") { showPhotoPicker = true }
                if selectedImage != nil {
                    Button("photo.remove", role: .destructive) { removePhoto() }
                }
                Button("button.cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $selectedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if let img = selectedImage {
                            photoData = ImageService.compress(img)
                        }
                    }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        photoData = ImageService.compress(uiImage)
                    }
                }
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
                    if let img = selectedImage {
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
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("photo.addPhoto")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 120, height: 120)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .accessibilityLabel("button.addPhoto")
                Spacer()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
        }
    }

    private var basicInfoSection: some View {
        Section(header: Text("section.basicInfo")) {
            VStack(alignment: .leading) {
                TextField("field.name", text: $name)
                    .autocorrectionDisabled()
                    .accessibilityLabel("field.name")
                if let err = nameError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            Picker("field.category", selection: $category) {
                ForEach(FoodCategory.allCases) { cat in
                    Label(cat.localizedName, systemImage: "tag")
                        .tag(cat)
                }
            }
        }
    }

    private var storageSection: some View {
        Section(header: Text("section.storage")) {
            Picker("field.location", selection: $storageLocation) {
                ForEach(StorageLocation.allCases) { loc in
                    Text("\(loc.emoji)  \(loc.localizedName)").tag(loc)
                }
            }
        }
    }

    private var quantitySection: some View {
        Section(header: Text("section.quantity")) {
            VStack(alignment: .leading) {
                HStack {
                    Text("field.quantity")
                    Spacer()
                    Stepper(value: $quantity, in: 0.1...9999, step: 1) {
                        Text(quantity.formatted())
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
                if let err = quantityError {
                    Text(err).font(.caption).foregroundStyle(.red)
                }
            }

            Picker("field.unit", selection: $unit) {
                ForEach(units, id: \.self) { u in
                    Text(NSLocalizedString("unit.\(u)", comment: u)).tag(u)
                }
            }
        }
    }

    private var datesSection: some View {
        Section(header: Text("section.dates")) {
            DatePicker("field.purchaseDate", selection: $purchaseDate, displayedComponents: .date)
            Toggle("field.hasExpiration", isOn: $hasExpirationDate)
            if hasExpirationDate {
                DatePicker("field.expirationDate", selection: $expirationDate, displayedComponents: .date)
            }
        }
    }

    private var notesSection: some View {
        Section(header: Text("section.notes")) {
            TextField("field.notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Helpers

    private func populateFields() {
        guard let item else { return }
        name = item.name
        category = item.categoryEnum
        storageLocation = item.storageLocationEnum
        quantity = item.quantity
        unit = item.unit
        purchaseDate = item.purchaseDate
        if let exp = item.expirationDate {
            expirationDate = exp
            hasExpirationDate = true
        } else {
            hasExpirationDate = false
        }
        notes = item.notes
        if let data = item.photoData {
            photoData = data
            selectedImage = UIImage(data: data)
        }
    }

    private func validate() -> Bool {
        var valid = true
        nameError = nil
        quantityError = nil
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            nameError = NSLocalizedString("validation.nameRequired", comment: "")
            valid = false
        }
        if quantity <= 0 {
            quantityError = NSLocalizedString("validation.quantityPositive", comment: "")
            valid = false
        }
        return valid
    }

    private func save() {
        guard validate() else { return }
        isSaving = true
        do {
            let repo = FoodRepository(context: modelContext)
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            if let existing = item {
                existing.name = trimmed
                existing.category = category.rawValue
                existing.storageLocation = storageLocation.rawValue
                existing.quantity = quantity
                existing.unit = unit
                existing.purchaseDate = purchaseDate
                existing.expirationDate = hasExpirationDate ? expirationDate : nil
                existing.photoData = photoData
                existing.notes = notes
                existing.updatedAt = Date()
                try repo.save(existing)
                NotificationService.shared.cancelReminders(for: existing, advanceDays: reminderDays)
                NotificationService.shared.scheduleReminders(for: existing, advanceDays: reminderDays)
            } else {
                let newItem = FoodItem(
                    name: trimmed,
                    category: category,
                    storageLocation: storageLocation,
                    quantity: quantity,
                    unit: unit,
                    purchaseDate: purchaseDate,
                    expirationDate: hasExpirationDate ? expirationDate : nil,
                    photoData: photoData,
                    notes: notes
                )
                try repo.save(newItem)
                NotificationService.shared.scheduleReminders(for: newItem, advanceDays: reminderDays)
            }
            isSaving = false
            dismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
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
            // Show settings alert
            saveError = NSLocalizedString("error.cameraPermission", comment: "")
        }
    }

    private func removePhoto() {
        selectedImage = nil
        photoData = nil
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
