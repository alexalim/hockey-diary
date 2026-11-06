import SwiftUI
import PhotosUI
import UIKit

/// 시스템 사진 선택기로 고른 사진만 받는다. 앨범 전체 권한을 요청하지 않는다 (FR-08, T10).
/// 앱에는 축소본을 복사해 두고, 지워도 사진 앱 원본은 건드리지 않는다.
struct PhotoPickerRow: View {
    /// 이미 저장된 사진
    var existing: [PhotoAsset]
    /// 저장에서 뺄 기존 사진 id
    @Binding var removedIDs: Set<UUID>
    /// 새로 고른 사진(아직 저장 전)
    @Binding var added: [Data]

    @State private var items: [PhotosPickerItem] = []
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(existing.filter { !removedIDs.contains($0.id) }) { photo in
                        thumb(photo.imageData) { removedIDs.insert(photo.id) }
                    }
                    ForEach(Array(added.enumerated()), id: \.offset) { index, data in
                        thumb(data) { added.remove(at: index) }
                    }
                    PhotosPicker(selection: $items, maxSelectionCount: 6, matching: .images) {
                        VStack(spacing: 4) {
                            Image(systemName: loading ? "hourglass" : "photo.badge.plus").font(.title3)
                            Text("사진").font(.caption)
                        }
                        .frame(width: 72, height: 72)
                        .foregroundStyle(Theme.accent)
                        .background(Theme.cobaltSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .accessibilityLabel("사진 추가")
                }
            }
            Text("앱에 복사해 둬. 여기서 지워도 사진 앱 원본은 그대로야.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: items) { _, newItems in
            guard !newItems.isEmpty else { return }
            loading = true
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let small = ImageShrinker.jpeg(from: data) {
                        added.append(small)
                    }
                }
                items = []
                loading = false
            }
        }
    }

    private func thumb(_ data: Data, remove: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            PhotoThumb(data: data, size: 72)
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .buttonStyle(.borderless)
            .padding(2)
            .accessibilityLabel("사진 빼기")
        }
    }
}

struct PhotoThumb: View {
    var data: Data
    var size: CGFloat

    var body: some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// 사진을 긴 변 1600px JPEG로 줄인다. 위치(EXIF GPS) 정보는 다시 그리면서 빠진다 (11.2).
enum ImageShrinker {
    static func jpeg(from data: Data, maxSide: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.8)
    }
}
