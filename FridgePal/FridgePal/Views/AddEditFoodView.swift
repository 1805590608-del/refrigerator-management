import SwiftUI
import PhotosUI
import AVFoundation

struct AddEditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var viewModel: AddEditFoodViewModel

    // Photo picker
    @State private var showPhotoOptions = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    init(item: FoodItem? = nil, prefill: FoodFormDraft? = nil) {
        _viewModel = StateObject(
            wrappedValue: AddEditFoodViewModel(item: item, prefill: prefill)
        )
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
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(image: $viewModel.selectedImage)
                    .ignoresSafeArea()
                    .onDisappear {
                        if let image = viewModel.selectedImage {
                            viewModel.setImage(image)
                        }
                    }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        viewModel.setImage(uiImage)
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

            Picker("field.category", selection: $viewModel.category) {
                ForEach(FoodCategory.allCases) { cat in
                    Label(cat.localizedName, systemImage: "tag")
                        .tag(cat)
                }
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
                    Stepper(value: $viewModel.quantity, in: 0.1...9999, step: 1) {
                        Text(viewModel.quantity.formatted())
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                }
                if let err = viewModel.quantityError {
                    Text(err).font(.footnote).foregroundStyle(Color(uiColor: .systemRed))
                }
            }

            Picker("field.unit", selection: $viewModel.unit) {
                ForEach(units, id: \.self) { u in
                    Text(NSLocalizedString("unit.\(u)", comment: u)).tag(u)
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
                DatePicker("field.expirationDate", selection: $viewModel.expirationDate, displayedComponents: .date)
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
                dismiss()
            }
        } catch {
            viewModel.saveError = error.localizedDescription
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
            viewModel.saveError = NSLocalizedString("error.cameraPermission", comment: "")
        }
    }

    private func removePhoto() {
        viewModel.removeImage()
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
