import Foundation
import LocalAuthentication

class BiometricAuthHelper {
    enum BiometricType {
        case none
        case touchID
        case faceID
        
        var title: String {
            switch self {
            case .none:
                return "None"
            case .touchID:
                return "Touch ID"
            case .faceID:
                return "Face ID"
            }
        }
        
        var iconName: String {
            switch self {
            case .none:
                return "exclamationmark.shield"
            case .touchID:
                return "touchid"
            case .faceID:
                return "faceid"
            }
        }
    }
    
    // Get the current biometric type available on the device
    static func getBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        default:
            return .none
        }
    }
    
    // Authenticate with biometrics
    static func authenticate(completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            let errorMessage = error?.localizedDescription ?? "Biometric authentication is not available."
            completion(false, errorMessage)
            return
        }
        
        // Get proper reason based on biometric type
        let reason = context.biometryType == .faceID 
            ? "Unlock TaskManager with Face ID" 
            : "Unlock TaskManager with Touch ID"
        
        // Perform the authentication
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                } else {
                    let errorMessage = error?.localizedDescription ?? "Authentication failed."
                    completion(false, errorMessage)
                }
            }
        }
    }
} 