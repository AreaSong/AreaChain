import SwiftUI

/// 只呈现已经读取并解码的图像；存储、拥有者核验和访问资格仍由调用方负责。
struct LoadedAttachmentImage: View {
    let image: NSImage
    var body: some View {
        Image(nsImage: image).resizable().scaledToFit()
    }
}
