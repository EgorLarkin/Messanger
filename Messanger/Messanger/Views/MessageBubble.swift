import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        Group {
            if message.isFromMe {
                HStack {
                    Spacer(minLength: 0)
                    Text(message.text)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                HStack {
                    Text(message.text)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(16)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
    }
}
