import Foundation

public enum MediaUploadPurpose: String, Sendable {
    case userAvatar = "USER_AVATAR"
    case userPaymentQr = "USER_PAYMENT_QR"
    case groupAvatar = "GROUP_AVATAR"
    case postImage = "POST_IMAGE"
    case commentAttachment = "COMMENT_ATTACHMENT"
}
