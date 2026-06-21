import Foundation

public enum MediaUploadPurpose: String, Sendable {
    case userAvatar = "USER_AVATAR"
    case userPaymentQr = "USER_PAYMENT_QR"
    case groupAvatar = "GROUP_AVATAR"
    case groupCustomEmoji = "GROUP_CUSTOM_EMOJI"
    case postImage = "POST_IMAGE"
    case commentAttachment = "COMMENT_ATTACHMENT"
}
