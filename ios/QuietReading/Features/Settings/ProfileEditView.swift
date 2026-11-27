import SwiftUI
import SwiftData
import PhotosUI

/// Flow 4 › Edit profile: photo, display name, account name, about me, show my name on widgets.
struct ProfileEditView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationCenterModel.self) private var notifications
    @Query(filter: #Predicate<Book> { $0.coverData != nil }) private var booksWithCovers: [Book]

    @AppStorage(ProfileKeys.name) private var savedName = ""
    @AppStorage(ProfileKeys.handle) private var savedHandle = ""
    @AppStorage(ProfileKeys.about) private var savedAbout = ""
    @AppStorage(ProfileKeys.showOnWidgets) private var savedShowOnWidgets = false

    @State private var name = ""
    @State private var handle = ""
    @State private var about = ""
    @State private var showOnWidgets = false
    @State private var photo: UIImage?
    @State private var originalPhoto: UIImage?
    @State private var photoMenu = false
    @State private var pickingLibrary = false
    @State private var pickedItem: PhotosPickerItem?
    @State private var takingPhoto = false
    @State private var choosingCover = false
    @State private var confirmDiscard = false

    private var handleValid: Bool { handle.isEmpty || handle.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" } }

    private var hasChanges: Bool {
        name != savedName || handle != savedHandle || about != savedAbout || showOnWidgets != savedShowOnWidgets || photo !== originalPhoto
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                HStack {
                    QsBackButton(title: "Cancel") { if hasChanges { confirmDiscard = true } else { dismiss() } }
                    Spacer()
                    Text("Edit profile").font(.body.weight(.semibold)).foregroundStyle(theme.palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Color.clear.frame(width: 80, height: 1)
                }
                VStack(spacing: Space.s8) {
                    ZStack(alignment: .bottomTrailing) {
                        AvatarView(image: photo, name: name, size: 96)
                        Image("qs.camera").resizable().frame(width: Size.iconS, height: Size.iconS)
                            .foregroundStyle(theme.palette.onAccent)
                            .frame(width: 28, height: 28)
                            .background(theme.palette.accent, in: Circle())
                            .overlay(Circle().strokeBorder(theme.palette.bg, lineWidth: 2))
                            .accessibilityHidden(true)
                    }
                    Button("Change photo") { photoMenu = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.palette.accentInk)
                        .frame(minHeight: Size.touchIos)
                }
                .frame(maxWidth: .infinity)
                field("Display name", text: $name)
                VStack(alignment: .leading, spacing: Space.s8) {
                    field("Account name", text: $handle, prefix: "@", error: !handleValid)
                    Text(handleValid ? "Shown on shared shelves. Letters, numbers, dots." : "Use letters, numbers and dots only.")
                        .font(.footnote)
                        .foregroundStyle(handleValid ? theme.palette.ink2 : theme.palette.error)
                }
                field("About me", text: $about)
                Toggle("Show my name on widgets", isOn: $showOnWidgets)
                    .font(.body).foregroundStyle(theme.palette.ink).tint(theme.palette.accent)
            }
            .padding(.horizontal, Space.s20)
            .padding(.top, Space.s8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Save", action: save)
                .buttonStyle(QsButtonStyle(priority: .primary))
                .disabled(!hasChanges || !handleValid)
                .padding(.horizontal, Space.s20)
                .padding(.top, Space.s12)
                .padding(.bottom, QsLayout.actionsAboveBottomLine)
                .background(theme.palette.bg)
        }
        .background(theme.palette.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Profile photo", isPresented: $photoMenu, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take photo") { takingPhoto = true } }
            Button("Choose from library") { pickingLibrary = true }
            if !booksWithCovers.isEmpty { Button("Use a book cover") { choosingCover = true } }
            if photo != nil { Button("Remove photo", role: .destructive) { photo = nil } }
        }
        .photosPicker(isPresented: $pickingLibrary, selection: $pickedItem, matching: .images)
        .onChange(of: pickedItem) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) { photo = image }
            }
        }
        .fullScreenCover(isPresented: $takingPhoto) { CameraCapture { photo = $0 } .ignoresSafeArea() }
        .sheet(isPresented: $choosingCover) {
            CoverPicker(books: booksWithCovers) { data in photo = UIImage(data: data) }
        }
        // Flow 4 › Unsaved changes
        .alert("Discard your changes?", isPresented: $confirmDiscard) {
            Button("Keep editing", role: .cancel) {}
            Button("Discard", role: .destructive) { dismiss() }
        } message: {
            Text("Your profile stays as it was.")
        }
        .onAppear {
            name = savedName; handle = savedHandle; about = savedAbout; showOnWidgets = savedShowOnWidgets
            photo = Avatar.load(); originalPhoto = photo
        }
    }

    private func field(_ label: LocalizedStringKey, text: Binding<String>, prefix: String? = nil, error: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Space.s8) {
            Text(label).font(.footnote.weight(.medium)).foregroundStyle(theme.palette.ink2)
            HStack(spacing: Space.s2) {
                if let prefix { Text(prefix).foregroundStyle(theme.palette.ink2) }
                TextField(label, text: text)
                    .textInputAutocapitalization(prefix == nil ? .words : .never)
                    .autocorrectionDisabled(prefix != nil)
            }
            .font(.body)
            .padding(.horizontal, Space.s16)
            .frame(minHeight: Size.field)
            .background(theme.palette.surface, in: RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.field, style: .continuous)
                .strokeBorder(error ? theme.palette.error : theme.palette.lineStrong, lineWidth: Size.stroke))
        }
    }

    private func save() {
        savedName = name.trimmingCharacters(in: .whitespaces)
        savedHandle = handle.trimmingCharacters(in: .whitespaces).lowercased()
        savedAbout = about.trimmingCharacters(in: .whitespaces)
        savedShowOnWidgets = showOnWidgets
        if photo !== originalPhoto { Avatar.save(photo) }
        dismiss()   // saving is silent
    }
}

/// System camera for a quick photo (front for the profile, back for a book cover).
struct CameraCapture: UIViewControllerRepresentable {
    var front = true
    let onPhoto: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = front ? .front : .rear
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCapture
        init(_ parent: CameraCapture) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPhoto(image) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// "Use a book cover" – pick one of your covers as the profile photo.
private struct CoverPicker: View {
    let books: [Book]
    let onPick: (Data) -> Void
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.s16) {
                Text("Use a book cover").font(theme.headline(22, relativeTo: .title2)).foregroundStyle(theme.palette.ink)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s12), count: 3), spacing: Space.s12) {
                    ForEach(books) { book in
                        Button {
                            if let data = book.coverData { onPick(data) }
                            dismiss()
                        } label: { BookCover(source: .data(book.coverData), title: book.title, width: nil) }
                            .buttonStyle(QsPressStyle())
                            .accessibilityLabel(book.title)
                    }
                }
            }
            .padding(Space.s20)
        }
        .background(theme.palette.surface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(theme.radii.sheet)
    }
}
