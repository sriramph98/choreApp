import SwiftUI

// This extension provides app colors to avoid the need for asset catalog color entries
extension Color {
    // App theme colors
    static var appBlue: Color {
        return Color.blue
    }
    
    static var appGreen: Color {
        return Color.green
    }
    
    static var appRed: Color {
        return Color.red
    }
    
    static var appPurple: Color {
        return Color.purple
    }
    
    // System colors that match iOS standard colors
    static var systemBlue: Color {
        return Color(UIColor.systemBlue)
    }
    
    static var systemGreen: Color {
        return Color(UIColor.systemGreen)
    }
    
    static var systemRed: Color {
        return Color(UIColor.systemRed)
    }
    
    static var systemPurple: Color {
        return Color(UIColor.systemPurple)
    }
}

// Helper functions to convert string color names to Color objects
func colorFromString(_ colorName: String) -> Color {
    switch colorName.lowercased() {
    case "blue", "systemblue":
        return Color.systemBlue
    case "green", "systemgreen":
        return Color.systemGreen
    case "red", "systemred":
        return Color.systemRed
    case "purple", "systempurple":
        return Color.systemPurple
    case "orange", "systemorange":
        return Color(UIColor.systemOrange)
    case "yellow", "systemyellow":
        return Color(UIColor.systemYellow)
    case "pink", "systempink":
        return Color(UIColor.systemPink)
    case "cyan", "systemcyan", "teal", "systemteal":
        return Color(UIColor.systemTeal)
    case "indigo", "systemindigo":
        return Color.indigo
    case "mint", "systemmint":
        return Color.mint
    default:
        return Color.systemBlue // Default fallback
    }
} 